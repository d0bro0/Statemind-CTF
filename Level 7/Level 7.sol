// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Helper.sol";

library SafeERC20 {
    function safeTransfer(
        ERC20 token,
        address to,
        uint256 value
    ) internal {
        require(token.transfer(to, value));
    }

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        require(token.transferFrom(from, to, value));
    }

    function safeApprove(
        ERC20 token,
        address spender,
        uint256 value
    ) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        require(token.approve(spender, value));
    }
}

// free money farming contract!
contract cToken is ERC20 {
    using SafeERC20 for ERC20;
    
    ERC20 public token;
    uint256 public rewardConstant = 10**14;
    mapping(address => uint256) public lastRedeem;

    constructor(address _token, string memory symbol, string memory name) ERC20(symbol, name) {
        token = ERC20(_token);
    }

    function balanceOfUnderlying(address sender) view public returns (uint256) {
        return token.balanceOf(sender);        
    }

    function doTransferIn(address from, uint256 amount) internal returns (uint256){
        ERC20 _token = token;
        
        uint256 balanceBefore = _token.balanceOf(address(this));
        _token.safeTransferFrom(from, address(this), amount); 
        uint256 balanceAfter = _token.balanceOf(address(this));
        
        return balanceAfter - balanceBefore;
    }

    function mint(uint256 amount) external returns (bool) {
        require(amount > 0);

        uint256 amountTransfered = doTransferIn(msg.sender, amount); // get Token

        _mint(msg.sender, amountTransfered); // mint cToken

        return true;
    }

    function addLastReward(address sender) internal {
        uint256 lastTime = lastRedeem[sender];
        lastRedeem[sender] = block.timestamp;
        
        uint256 balance = balanceOf[address(this)];

        _mint(sender,  balance * (block.timestamp - lastTime) / rewardConstant);
    }

    function redeem(uint redeemTokens) external returns (bool){
        addLastReward(msg.sender);

        uint256 senderBalance = balanceOf[msg.sender];
        redeemTokens = redeemTokens > senderBalance ? senderBalance : redeemTokens;
        
        _burn(msg.sender, redeemTokens); // burn cToken 
        token.safeTransfer(msg.sender, redeemTokens); // give Token back

        return true;
    }

}

// https://github.com/iearn-finance/vaults/blob/master/contracts/vaults/yVault.sol
// Jar with pickles
contract Jar is ERC20 {
    using SafeERC20 for ERC20;

    ERC20 public token;

    address public governance;
    address public controller;

    constructor() ERC20(
        string(abi.encodePacked("pickling ", "DAI")), string(abi.encodePacked("p", "DAI"))
    ) {}

    function init(
        address _token, 
        address _governance, 
        address _controller
    ) public {
        require(address(token) == address(0), "!init");

        token = ERC20(_token);
        governance = _governance;
        controller = _controller;

        name = string(abi.encodePacked("pickling ", ERC20(_token).name()));
        symbol = string(abi.encodePacked("p", ERC20(_token).symbol()));
        transferOwner(msg.sender);
    }

    function balance() public view returns (uint256) {
        return
            token.balanceOf(address(this)) + PickleFi(controller).balanceOf(address(token));
    }

    function earn() public {
        uint256 _bal = token.balanceOf(address(this));
        token.safeTransfer(controller, _bal);
        PickleFi(controller).earn(address(token), _bal);
    }

    function deposit(uint256 _amount) public {
        uint256 _pool = balance();
        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after - _before; // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply == 0) {
            shares = _amount;
        } else {
            shares = _amount * totalSupply / _pool;
        }
        _mint(msg.sender, shares);
    }

    function harvest(address reserve, uint256 amount) external {
        require(msg.sender == controller, "!controller");
        require(reserve != address(token), "token");
        ERC20(reserve).safeTransfer(controller, amount);
    }

    function withdraw(uint256 _shares) public {
        uint256 r = balance() * _shares / totalSupply;
        _burn(msg.sender, _shares);

        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r - b;
            PickleFi(controller).withdraw(address(token), _withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after - b;
            if (_diff < _withdraw) {
                r = b + _diff;
            }
        }

        token.safeTransfer(msg.sender, r);
    }

    function getRatio() public view returns (uint256) {
        return balance() * 1e18 / totalSupply;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "!governance");
        _;
    }
}

interface Converter {
    function convert(address) external returns (uint256);
}


// https://github.com/iearn-finance/jars/blob/master/contracts/controllers/StrategyControllerV1.sol
contract PickleFi {
    using SafeERC20 for ERC20;

    address public DAI;
    address public cDAI;
    address public curveProxyLogic;
    address public burn;
    address public governance;

    mapping(address => address) public jars;
    mapping(address => address) public strategies;
    mapping(address => mapping(address => address)) public converters;
    mapping(address => mapping(address => bool)) public approvedStrategies;
    mapping(address => bool) public approvedJarConverters;

    function init(address _governance, address _DAI, address _cDAI, address _curveProxyLogic) public {
        require(burn == address(0), "!init");

        burn = 0x000000000000000000000000000000000000dEaD;
        governance = _governance;
        DAI = _DAI;
        cDAI = _cDAI;
        curveProxyLogic = _curveProxyLogic;
    }

    function setGovernance(address _governance) public onlyGovernance {
        governance = _governance;
    }

    function setJar(address _token, address _jar) public onlyGovernance {
        require(jars[_token] == address(0), "jar");
        jars[_token] = _jar;
    }

    function approveJarConverter(address _converter) public onlyGovernance {
        approvedJarConverters[_converter] = true;
    }

    function revokeJarConverter(address _converter) public onlyGovernance {
        approvedJarConverters[_converter] = false;
    }

    function approveStrategy(address _token, address _strategy) public onlyGovernance {
        approvedStrategies[_token][_strategy] = true;
    }

    function revokeStrategy(address _token, address _strategy) public onlyGovernance {
        require(strategies[_token] != _strategy, "cannot revoke active strategy");
        approvedStrategies[_token][_strategy] = false;
    }

    function setStrategy(address _token, address _strategy) public onlyGovernance {
        require(approvedStrategies[_token][_strategy] == true, "!approved");

        address _current = strategies[_token];
        if (_current != address(0)) {
            StrategyBase(_current).withdrawAll();
        }
        strategies[_token] = _strategy;
    }

    function earn(address _token, uint256 _amount) public {
        address _strategy = strategies[_token];
        address _want = StrategyBase(_strategy).want();
        if (_want != _token) { // !!! do not forget to add some converters, otherwise this will always revert
            address converter = converters[_token][_want];
            ERC20(_token).safeTransfer(converter, _amount);
            _amount = Converter(converter).convert(_strategy);
            ERC20(_want).safeTransfer(_strategy, _amount);
        } else {
            ERC20(_token).safeTransfer(_strategy, _amount);
        }
        StrategyBase(_strategy).deposit();
    }

    function balanceOf(address _token) external view returns (uint256) {
        return StrategyBase(strategies[_token]).balanceOf();
    }

    function withdrawAll(address _token) public onlyGovernance {
        StrategyBase(strategies[_token]).withdrawAll();
    }

    function withdraw(address _token, uint256 _amount) public {
        require(msg.sender == jars[_token], "!jar");
        StrategyBase(strategies[_token]).withdraw(_amount);
    }

    // Function to swap between jars
    function swapExactJarForJar(
        address _fromJar, // From which Jar
        address _toJar, // To which Jar
        uint256 _fromJarAmount, // How much jar tokens to swap
        uint256 _toJarMinAmount, // How much jar tokens you'd like at a minimum
        address payable[] calldata _targets,
        bytes[] calldata _data
    ) external returns (uint256) {
        require(_targets.length == _data.length, "!length");

        // Only return last response
        for (uint256 i = 0; i < _targets.length; i++) {
            require(_targets[i] != address(0), "!converter");
            require(approvedJarConverters[_targets[i]], "!converter");
        }

        address _fromJarToken = address(Jar(_fromJar).token());
        address _toJarToken = address(Jar(_toJar).token());

        // Get pTokens from msg.sender
        ERC20(_fromJar).safeTransferFrom(
            msg.sender,
            address(this),
            _fromJarAmount
        );

        // Calculate how much underlying
        // is the amount of pTokens worth
        uint256 _fromJarUnderlyingAmount = _fromJarAmount * Jar(_fromJar).getRatio()
            / (10**uint256(Jar(_fromJar).decimals()));
        // Call 'withdrawForSwap' on Jar's current strategy if Jar
        // doesn't have enough initial capital.
        // This has moves the funds from the strategy to the Jar's
        // 'earnable' amount. Enabling 'free' withdrawals
        uint256 _fromJarAvailUnderlying = ERC20(_fromJarToken).balanceOf(
            _fromJar
        );
        if (_fromJarAvailUnderlying < _fromJarUnderlyingAmount) {
            StrategyBase(strategies[_fromJarToken]).withdrawForSwap(
                _fromJarUnderlyingAmount - _fromJarAvailUnderlying
            );
        }

        // Withdraw from Jar
        // Note: this is free since its still within the "earnable" amount
        //       as we transferred the access
        ERC20(_fromJar).safeApprove(_fromJar, 0);
        ERC20(_fromJar).safeApprove(_fromJar, _fromJarAmount);
        Jar(_fromJar).withdraw(_fromJarAmount);

        // Calculate fee
        uint256 _fromUnderlyingBalance = ERC20(_fromJarToken).balanceOf(
            address(this)
        );

        // Executes sequence of logic
        for (uint256 i = 0; i < _targets.length; i++) {
            _execute(_targets[i], _data[i]);
        }

        // Deposit into new Jar
        uint256 _toBal = ERC20(_toJarToken).balanceOf(address(this));
        ERC20(_toJarToken).safeApprove(_toJar, 0);
        ERC20(_toJarToken).safeApprove(_toJar, _toBal);
        Jar(_toJar).deposit(_toBal);

        // Send Jar Tokens to user
        uint256 _toJarBal = Jar(_toJar).balanceOf(address(this));
        if (_toJarBal < _toJarMinAmount) {
            revert("!min-jar-amount");
        }

        Jar(_toJar).transfer(msg.sender, _toJarBal);

        return _toJarBal;
    }

    function _execute(address _target, bytes memory _data)
        internal
        returns (bytes memory response)
    {
        require(_target != address(0), "!target");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                _target,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )
            let size := returndatasize()

            response := mload(0x40)
            mstore(
                0x40,
                add(response, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    revert(add(response, 0x20), size)
                }
        }
    }
    modifier onlyGovernance() {
        require(msg.sender == governance, "!governance");
        _;
    }

    function solved(address player) external returns (bool) {
        return ERC20(DAI).balanceOf(player) >= 1_337_777 * 10 ** 18;
    }
}

// Strategy Contract Basics
abstract contract StrategyBase {
    using SafeERC20 for ERC20;

    address public want;
    address public governance;
    address public controller;

    function init(
        address _want,
        address _governance,
        address _controller
    ) public {
        require(want == address(0), "!init");

        want = _want;
        governance = _governance;
        controller = _controller;
    }

    modifier onlyBenevolent {
        require(
            msg.sender == tx.origin || msg.sender == governance 
        );
        _;
    }

    function balanceOfWant() public view returns (uint256) {
        return ERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public virtual view returns (uint256);

    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool();
    }

    function getName() external virtual pure returns (string memory);

    function deposit() public virtual;

    // Controller only function for creating additional rewards from dust
    function withdraw(ERC20 _asset) external onlyController returns (uint256 balance) {
        require(want != address(_asset), "want");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(controller, balance);
    }

    // Withdraw partial funds, normally used with a jar withdrawal
    function withdraw(uint256 _amount) external onlyController {
        uint256 _balance = ERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount - _balance);
            _amount = _amount + _balance;
        }

        address _jar = PickleFi(controller).jars(address(want));
        require(_jar != address(0), "!jar"); // additional protection so we don't burn the funds

        ERC20(want).safeTransfer(_jar, _amount);
    }

    // Withdraw funds, used to swap between strategies
    function withdrawForSwap(uint256 _amount)
        external
        onlyController
        returns (uint256 balance)
    {
        _withdrawSome(_amount);

        balance = ERC20(want).balanceOf(address(this));

        address _jar = PickleFi(controller).jars(address(want));
        require(_jar != address(0), "!jar");
        ERC20(want).safeTransfer(_jar, balance);
    }

    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external onlyController returns (uint256 balance) {
        _withdrawAll();

        balance = ERC20(want).balanceOf(address(this));

        address _jar = PickleFi(controller).jars(address(want));
        require(_jar != address(0), "!jar"); // additional protection so we don't burn the funds
        ERC20(want).safeTransfer(_jar, balance);
    }

    function _withdrawAll() internal {
        _withdrawSome(balanceOfPool());
    }

    function _withdrawSome(uint256 _amount) internal virtual returns (uint256);

    function harvest() public virtual;

    function execute(address _target, bytes memory _data)
        public
        payable
        returns (bytes memory response)
    {
        require(_target != address(0), "!target");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                _target,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )
            let size := returndatasize()

            response := mload(0x40)
            mstore(
                0x40,
                add(response, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    revert(add(response, 0x20), size)
                }
        }
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "!governance");
        _;
    }

    modifier onlyController() {
        require(msg.sender == controller, "!controller");
        _;
    }
}

contract StrategyDAI is StrategyBase{
    using SafeERC20 for ERC20;

    address public cdai;

    function init(
        address _governance, 
        address _controller,
        address _dai,
        address _cdai
    ) public {
        StrategyBase.init(_dai, _governance, _controller);
        cdai = _cdai;
    }

    function getName() external override pure returns (string memory) {
        return "Just_a_Strategy";
    }

    function balanceOfPool() public override view returns (uint256) {
        return cToken(cdai).balanceOfUnderlying(address(this));
    }

    function harvest() public override onlyBenevolent {
        deposit();
    }

    function deposit() public override {
        uint256 _want = ERC20(want).balanceOf(address(this));
        if (_want > 0) {
            ERC20(want).safeApprove(cdai, 0);
            ERC20(want).safeApprove(cdai, _want);
            require(cToken(cdai).mint(_want), "!deposit");
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        uint256 _want = balanceOfWant();
        if (_want < _amount) {
            uint256 _redeem = _amount - _want;

            // Redeems underlying
            require(cToken(cdai).redeem(_redeem), "!redeem");
        }

        return _amount;
    }
}

// Converts Curve LP Tokens some Other LP Tokens; will need later
contract CurveProxyLogic {
    using SafeERC20 for ERC20;

    function add_liquidity(
        address curve,
        bytes4 curveFunctionSig,
        uint256 curvePoolSize,
        uint256 curveUnderlyingIndex,
        address underlying
    ) public {
        uint256 underlyingAmount = ERC20(underlying).balanceOf(address(this));

        uint256[] memory liquidity = new uint256[](curvePoolSize);
        liquidity[curveUnderlyingIndex] = underlyingAmount;

        bytes memory callData = abi.encodePacked(
            curveFunctionSig,
            liquidity,
            uint256(0)
        );

        ERC20(underlying).safeApprove(curve, 0);
        ERC20(underlying).safeApprove(curve, underlyingAmount);
        (bool success, ) = curve.call(callData);
        require(success, "!success");
    }
}
