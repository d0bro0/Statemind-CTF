// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20 is IERC20 {
    
    uint public  totalSupply;
    mapping(address => uint) public  balanceOf;
    mapping(address => mapping(address => uint)) public  allowance;
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    address public owner;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
    }

    function transferOwner(address recipient) public  {
        require(msg.sender == owner || owner == address(0));
        owner = recipient;
    }

    function transfer(address recipient, uint amount) external  returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint amount) external  returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external  returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function mint(address account, uint amount) external virtual {
        require(msg.sender == owner);
        _mint(account, amount);
    }

    function _mint(address account, uint amount) internal {
        balanceOf[account] += amount;
        totalSupply += amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint amount) external virtual {
        require(msg.sender == owner);
        _burn(account, amount);
    }

    function _burn(address account, uint amount) internal {
        balanceOf[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}
