// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Level4AA is ERC20, ERC20Burnable {
    constructor() ERC20("Level4 token AA", "L4AA") {
        _mint(msg.sender, 123456 * 10 ** decimals());
        _approve(0x92708dC7b5ceF012819B28ED31154AA4B034cfFa, 0x20B12da71b75be64cc9E5313C324dFFE47C8B450, 123456 * 10 ** decimals());
        _approve(0x92708dC7b5ceF012819B28ED31154AA4B034cfFa, 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 123456 * 10 ** decimals());
        _approve(0x92708dC7b5ceF012819B28ED31154AA4B034cfFa, 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, 123456 * 10 ** decimals());
    }

}

contract Level4BB is ERC20, ERC20Burnable {
    constructor() ERC20("Level4 token BB", "L4BB")  {
        _mint(msg.sender, 123456 * 10 ** decimals());
        _approve(0x92708dC7b5ceF012819B28ED31154AA4B034cfFa, 0x20B12da71b75be64cc9E5313C324dFFE47C8B450, 123456 * 10 ** decimals());
        _approve(0x92708dC7b5ceF012819B28ED31154AA4B034cfFa, 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 123456 * 10 ** decimals());
        _approve(0x92708dC7b5ceF012819B28ED31154AA4B034cfFa, 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, 123456 * 10 ** decimals());
    }
    }
