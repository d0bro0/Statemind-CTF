// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Helper ERC 777.sol";

interface IUniswapV1Factory {
    function createExchange(address) external returns (address);
}

interface IUniswapV1Pair {
    function addLiquidity(uint256,uint256,uint256) external payable returns (uint256);
    function removeLiquidity(uint256,uint256,uint256,uint256) external returns (uint256,uint256);
    function ethToTokenSwapInput(uint256,uint256) external returns (uint256);
    function ethToTokenTransferInput(uint256,uint256) external returns (uint256);
    function ethToTokenSwapOutput(uint256,uint256) external returns (uint256);
    function ethToTokenTransferOutput(uint256,uint256) external returns (uint256);
    function tokenToEthSwapInput(uint256,uint256,uint256) external returns (uint256);
    function tokenToEthTransferInput(uint256,uint256,uint256,address) external returns (uint256);
    function tokenToEthSwapOutput(uint256,uint256,uint256) external returns (uint256);
    function tokenToEthTransferOutput(uint256,uint256,uint256,address) external returns (uint256);
}

contract ImBTC {
    IUniswapV1Pair public  pair;
    MyERC777 public  imBTC;
    constructor(address player) payable {
        imBTC = new MyERC777("imBTC", "imBTC", new address[](0));
        imBTC.mint(address(this), 100 * 10**18);
        imBTC.mint(player, 80 * 10**18);
        IUniswapV1Factory univ1Factory = IUniswapV1Factory(0x6Ce570d02D73d4c384b46135E87f8C592A8c86dA);
        pair = IUniswapV1Pair(univ1Factory.createExchange(address(imBTC)));
        imBTC.approve(address(pair), 100 * 10**18);
        pair.addLiquidity{value: msg.value}(0, 100 * 10**18, block.timestamp + 1);
    }

    function solved() external returns(bool) {
        return address(pair).balance < 0.1 ether;
    }
}
