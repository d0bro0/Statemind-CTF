// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyERC777 is ERC777, Ownable {
    constructor(string memory name_, string memory symbol_, address[] memory defaultOperators_) ERC777(name_, symbol_, defaultOperators_) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount, new bytes(0), new bytes(0), false);
    }
}
