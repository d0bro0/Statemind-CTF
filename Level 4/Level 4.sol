// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
      uint amountIn,
      uint amountOutMin,
      address[] calldata path,
      address to,
      uint deadline
    ) external returns (uint[] memory amounts);
}


contract FakeSwap {
  address constant public UNI_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  address constant public UNI_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

  address public tokenA;
  address public tokenB;
  address public pool;
  bool public swapped;

  uint256 constant public INIT_LIQ = 123456 * 10**18;
  uint256 constant public SWAP_AMOUNT = 5000 * 10**18;
  uint256 constant public MIN_AMOUNT_OUT = 1337 * 10**18;


  function createPair(address _tokenA, address _tokenB) external returns (address) {
    tokenA = _tokenA;
    tokenB = _tokenB;
    pool = IUniswapV2Factory(UNI_FACTORY).createPair(_tokenA, _tokenB);
    swapped = false;
    return pool;
  }

  function swap() external returns (bool) {
    require(IERC20(tokenA).balanceOf(address(this)) == SWAP_AMOUNT, "insufficient balance");

    address[] memory path = new address[](2);
    path[0] = tokenA;
    path[1] = tokenB;

    IUniswapV2Router(UNI_ROUTER).swapExactTokensForTokens(SWAP_AMOUNT, MIN_AMOUNT_OUT, path, address(this), block.timestamp);

    swapped = true;
  }

  function getBalances() external view returns (uint256, uint256) {
    uint256 balA = IERC20(tokenA).balanceOf(address(this));
    uint256 balB = IERC20(tokenB).balanceOf(address(this));
    return (balA, balB);
  }
}
