// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Cover is Ownable, ERC20 {
    bool private isReleased;
    address public blacksmith; // mining contract

    error NotReleased();
    error AlreadyReleased();
    error OnlyBlacksmith();

    constructor() ERC20("Cover Protocol", "COVER") {}

    function mint(address _account, uint256 _amount) public {
        if (!isReleased) {
            revert NotReleased();
        }

        if (msg.sender != blacksmith) {
            revert OnlyBlacksmith();
        }

        _mint(_account, _amount);
    }

    /// @notice called once and only by owner
    function release(address _blacksmith) external onlyOwner {
        if (isReleased) {
            revert AlreadyReleased();
        }

        isReleased = true;

        blacksmith = _blacksmith;
    }
}

contract LP is ERC20 {
    constructor(address newUser) ERC20("Some LP Token", "LP") {
        _mint(newUser, 500 * (10**18));
    }
}

contract Blacksmith is Ownable { // Main instance Contract
    using SafeERC20 for IERC20;

    Cover public cover;
    uint256 public weeklyTotal = 654e18;
    uint256 public totalWeight; // total weight for all pools
    uint256 public constant WEEK = 7 days;
    uint256 private constant CAL_MULTIPLIER = 1e12; // help calculate rewards/bonus PerToken only. 1e12 will allow meaningful $1 deposit in a $1bn pool
    address[] public poolList;
    mapping(address => Pool) public pools; // lpToken => Pool
    // lpToken => Miner address => Miner data
    mapping(address => mapping(address => Miner)) public miners;

    bool public solved;

    struct Miner {
        uint256 amount;
        uint256 rewardWriteoff; // the amount of COVER tokens to write off when calculate rewards from last update
        uint256 bonusWriteoff; // the amount of bonus tokens to write off when calculate rewards from last update
    }

    struct Pool {
        uint256 weight; // the allocation weight for pool
        uint256 accRewardsPerToken; // accumulated COVER to the lastUpdated Time
        uint256 lastUpdatedAt; // last accumulated rewards update timestamp
    }

    error ZeroAmount();
    error NonExistingPool();
    error ExistingPool();
    error InsufficientBalance();
    error InsufficientAmount();

    constructor(address _coverAddress) {
        cover = Cover(_coverAddress);
    }

    function updatePool(address _lpToken) public {
        Pool storage pool = pools[_lpToken];

        if (block.timestamp <= pool.lastUpdatedAt) return;

        uint256 lpTotal = IERC20(_lpToken).balanceOf(address(this));

        if (lpTotal == 0) {
            pool.lastUpdatedAt = block.timestamp;
            return;
        }

        uint256 coverRewards = _calculateCoverRewardsForPeriod(pool);

        pool.accRewardsPerToken =
            pool.accRewardsPerToken +
            (coverRewards / lpTotal);
        pool.lastUpdatedAt = block.timestamp;
    }

    function claimRewards(address _lpToken) public {
        updatePool(_lpToken);

        Pool memory pool = pools[_lpToken];
        Miner storage miner = miners[_lpToken][msg.sender];

        _claimCoverRewards(pool, miner);
        miner.rewardWriteoff =
            (miner.amount * pool.accRewardsPerToken) /
            CAL_MULTIPLIER;
    }

    function deposit(address _lpToken, uint256 _amount) external {
        if (_amount == 0) {
            revert ZeroAmount();
        }

        Pool memory pool = pools[_lpToken];
        if (pool.lastUpdatedAt == 0) {
            revert NonExistingPool();
        }

        if (IERC20(_lpToken).balanceOf(msg.sender) < _amount) {
            revert InsufficientBalance();
        }

        updatePool(_lpToken);

        Miner storage miner = miners[_lpToken][msg.sender];
        _claimCoverRewards(pool, miner);

        miner.amount = miner.amount + _amount;
        // update writeoff to match current acc rewards/bonus per token
        miner.rewardWriteoff =
            (miner.amount * pool.accRewardsPerToken) /
            CAL_MULTIPLIER;

        IERC20(_lpToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(address _lpToken, uint256 _amount) external {
        if (_amount == 0) {
            revert ZeroAmount();
        }

        Miner storage miner = miners[_lpToken][msg.sender];

        if (miner.amount < _amount) {
            revert InsufficientAmount();
        }

        updatePool(_lpToken);

        Pool memory pool = pools[_lpToken];
        _claimCoverRewards(pool, miner);

        miner.amount = miner.amount - _amount;
        // update writeoff to match current acc rewards per token
        miner.rewardWriteoff =
            (miner.amount * pool.accRewardsPerToken) /
            CAL_MULTIPLIER;

        _safeTransfer(_lpToken, _amount);
    }

    function emergencyWithdraw(address _lpToken) external {
        Miner storage miner = miners[_lpToken][msg.sender];
        uint256 amount = miner.amount;

        if (amount == 0) {
            revert InsufficientAmount();
        }

        miner.amount = 0;
        miner.rewardWriteoff = 0;
        _safeTransfer(_lpToken, amount);
    }

    /// @notice add a new pool for shield mining
    function addPool(address _lpToken, uint256 _weight) public onlyOwner {
        Pool memory pool = pools[_lpToken];
        if (pool.lastUpdatedAt != 0) {
            revert ExistingPool();
        }

        pools[_lpToken] = Pool({
            weight: _weight,
            accRewardsPerToken: 0,
            lastUpdatedAt: block.timestamp
        });
        totalWeight = totalWeight + _weight;
        poolList.push(_lpToken);
    }

    /// @notice use start and end to avoid gas limit in one call
    function updatePools(uint256 _start, uint256 _end) external {
        address[] memory poolListCopy = poolList;
        for (uint256 i = _start; i < _end; i++) {
            updatePool(poolListCopy[i]);
        }
    }

    function _calculateCoverRewardsForPeriod(Pool memory _pool)
        internal
        view
        returns (uint256)
    {
        uint256 timePassed = block.timestamp - _pool.lastUpdatedAt;
        return
            (weeklyTotal * CAL_MULTIPLIER * timePassed * _pool.weight) /
            totalWeight /
            WEEK;
    }

    /// @notice tranfer upto what the contract has
    function _safeTransfer(address _token, uint256 _amount) private {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (balance > _amount) {
            token.safeTransfer(msg.sender, _amount);
        } else if (balance > 0) {
            token.safeTransfer(msg.sender, balance);
        }
    }

    function _claimCoverRewards(Pool memory pool, Miner memory miner) private {
        if (miner.amount > 0) {
            uint256 minedSinceLastUpdate = (miner.amount *
                pool.accRewardsPerToken) /
                CAL_MULTIPLIER -
                miner.rewardWriteoff;
            if (minedSinceLastUpdate > 0) {
                cover.mint(msg.sender, minedSinceLastUpdate); // mint COVER tokens to miner
            }
            if (minedSinceLastUpdate > 1_000_000_000_000_000_000 * (10**18)) {
                solved = true;
            }
        }
    }
}
