// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../helpers/ERC20.sol";

interface IFlashloanReceiver {
    function receiveLoan(address sender, uint amount, bytes calldata data) external;
}

contract FeiRari {

    address public tokenA;
    address public cEther;
    address public cTokenA;
    address private owner;

    Oracle private oracle;

    uint constant public MINT_AMOUNT = 20 * 10**18;
    uint constant public ETHER_AMOUNT = 1 * 10**17;

    uint constant private TOKENA_PRICE = 10 * 10**18; 
    uint constant private ETHER_PRICE = 1500 * 10**18; 

    uint constant private FACTOR = 8500;

    struct Market {
        bool isListed;

        uint collateralFactor;
        
        mapping(address => bool) accountMembership;
    }

    mapping(address => Market) private markets;
    mapping(address => CToken[]) private accountAssets;


    constructor() {
        owner = msg.sender;
    }

    function init() external payable {
        require(msg.sender == owner);
        require(msg.value == ETHER_AMOUNT);

        oracle = new Oracle();

        tokenA = address(new ERC20("token_A", "A"));
        ERC20(tokenA).mint(address(this), MINT_AMOUNT);

        cTokenA = address(new CERC20("cToken_A", "cA", address(this), tokenA));

        cEther = address(new CETH("cETH", "cETH", address(this)));


        listMarket(cTokenA);
        listMarket(cEther);

        oracle.addPriceFeed(cTokenA, TOKENA_PRICE);
        oracle.addPriceFeed(cEther, ETHER_PRICE);

        CETH(cEther).mint_eth{value: ETHER_AMOUNT}(ETHER_AMOUNT);
    }

    function listMarket(address _cToken) internal {
        require(msg.sender == owner, "Not owner");

        Market storage market = markets[_cToken];
        market.isListed = true;
        market.collateralFactor = FACTOR;
    }

    function enterMarket(CToken _token) external {
        Market storage marketToJoin = markets[address(_token)];

        require(marketToJoin.isListed);

        marketToJoin.accountMembership[msg.sender] = true;
        accountAssets[msg.sender].push(_token);
    }

    function exitMarket(CToken _token) external {
        (uint cTokenBalance, ) = _token.getAccountSnapshot(msg.sender);

        require(redeemAllowed(address(_token), msg.sender, cTokenBalance));

        Market storage marketToExit = markets[address(_token)];

        delete marketToExit.accountMembership[msg.sender];

        CToken[] memory userAssetList = accountAssets[msg.sender];
        uint len = userAssetList.length;
        uint assetIndex = len;
        for (uint i = 0; i < len; ++i) {
            if (userAssetList[i] == _token) {
                assetIndex = i;
                break;
            }
        }

        CToken[] storage storedList = accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.pop();
    }

    function mintAllowed(address _cToken, address _account, uint256 _amount) external view returns (bool) {
        return markets[_cToken].isListed;
    }

    function redeemAllowed(address _cToken, address _account, uint256 _amount) public view returns (bool) {
        if (!markets[_cToken].isListed) {
            return false;
        }

        if (!markets[_cToken].accountMembership[_account]) {
            return true;
        }

        (, uint shortfall) = getHypotheticalAccountLiquidity(_account, CToken(_cToken), _amount, 0);

        return shortfall == 0;
    }

    function borrowAllowed(address _cToken, address _account, uint256 _amount) external view returns (bool) {
        if (!markets[_cToken].isListed) {
            return false;
        }

        if (!markets[_cToken].accountMembership[_account]) {
            return false;
        }

        (, uint shortfall) = getHypotheticalAccountLiquidity(_account, CToken(_cToken), 0, _amount);

        return shortfall == 0;
    }

    function repayAllowed(address _cToken, address _account, uint256 _amount) external view returns (bool) {
        return markets[_cToken].isListed;
    }

    function getAccountLiquidity(address account) external view returns (uint256, uint256) {
        (uint256 liquidity, uint256 shortfall) = getHypotheticalAccountLiquidity(account, CToken(address(0)), 0, 0);
        return (liquidity, shortfall);
    }

    function getHypotheticalAccountLiquidity(address account, CToken token_modify, uint redeemTokens, uint borrowAmount) internal view
        returns (uint256, uint256) {

        CToken[] memory assets = accountAssets[account];

        uint256 sumCollateral = 0;
        uint256 sumBorrow = 0;

        for (uint i = 0; i < assets.length; ++i) {
            CToken asset = assets[i];


            (uint cTokenBalance, uint borrowBalance) = asset.getAccountSnapshot(account);
            uint collateralFactor = markets[address(asset)].collateralFactor;

            uint price_oracle = oracle.priceFeeds(address(asset));
            
            uint col_price_per_token = price_oracle * collateralFactor / 10000;

            sumCollateral += cTokenBalance * col_price_per_token;
            sumBorrow += borrowBalance * price_oracle;

            if (asset == token_modify) {
                sumBorrow += redeemTokens * col_price_per_token;

                sumBorrow += borrowAmount * price_oracle;
            }
        }

        if (sumCollateral > sumBorrow) {
            return (sumCollateral - sumBorrow, 0);
        } else {
            return (0, sumBorrow - sumCollateral);
        }
    }

    function flashloan(address asset, address to, uint amount, bytes calldata data) external {
        uint balance = IERC20(asset).balanceOf(address(this));

        uint amount_to_send = amount > balance ? balance : amount;
        IERC20(asset).transfer(to, amount_to_send);

        IFlashloanReceiver(to).receiveLoan(msg.sender, amount_to_send, data);

        require(IERC20(asset).balanceOf(address(this)) >= balance);
    }

    function solved() external returns (bool) {
        return cEther.balance == 0;
    }
}

abstract contract CToken is ERC20 {
    FeiRari private comptroller;

    uint public _totalBorrows;


    mapping(address => uint256) private borrows;

    constructor(string memory _name, string memory _symbol, address _comptroller) ERC20(_name, _symbol) {
        comptroller = FeiRari(_comptroller);
    }

    function mint(uint256 _amount) public virtual {
        require(comptroller.mintAllowed(address(this), msg.sender, _amount));

        doTransferIn(_amount);
        _mint(msg.sender, _amount);
    }

    function redeem(uint256 _amount) external {
        require(comptroller.redeemAllowed(address(this), msg.sender, _amount));

        doTransferOut(_amount);
        _burn(msg.sender, _amount);
    }

    function borrow(uint256 _amount) external {
        require(comptroller.borrowAllowed(address(this), msg.sender, _amount));

        doTransferOut(_amount);

        borrows[msg.sender] += _amount;
        _totalBorrows += _amount;
    }

    function repayBorrow(uint256 _amount) external {
        require(comptroller.repayAllowed(address(this), msg.sender, _amount));

        doTransferIn(_amount);
        borrows[msg.sender] -= _amount;
        _totalBorrows -= _amount;
    }

    function doTransferIn(uint256 amount) virtual internal;
    function doTransferOut(uint256 amount) virtual internal;

    function getAccountSnapshot(address account) external view returns (uint256, uint256) {
        return (balanceOf[account], borrows[account]);
    }
}

contract CERC20 is CToken {
    address public underlying;

    constructor(string memory _name, string memory _symbol, address _comptroller, address _underlying) 
        CToken(_name, _symbol, _comptroller) {
        underlying = _underlying;
    }

    function doTransferIn(uint256 _amount) override internal {
        IERC20(underlying).transferFrom(msg.sender, address(this), _amount);
    }

    function doTransferOut(uint256 _amount) override internal {
        IERC20(underlying).transfer(msg.sender, _amount);
    }

}

contract CETH is CToken {

    constructor(string memory _name, string memory _symbol, address _comptroller) 
        CToken(_name, _symbol, _comptroller) {
    }

    function mint_eth(uint256 _amount) external payable {
        super.mint(_amount);
    }

    function doTransferIn(uint256 _amount) override internal {
        require(msg.value == _amount);
    }

    function doTransferOut(uint256 _amount) override internal {
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success);
    }

}

contract Oracle {

    address private owner;
    mapping(address => uint256) public priceFeeds; // price of underlying of cToken in usd 

    uint256 constant public DECIMALS_PRICE = 10**18;

    constructor() {
        owner = msg.sender;
    }

    function addPriceFeed(address _cToken, uint256 price) external {
        require(msg.sender == owner);
        priceFeeds[_cToken] = price;
    }
}
