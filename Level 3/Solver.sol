// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract MicroHello {
 address public helloaddress;
 bytes public result;

 function create(bytes memory data) public{
     address addr;
     assembly{
         addr := create(0, add(data,0x20), mload(data))
     }
     helloaddress = addr;
 }

 function getSize(address _adr) public view returns(uint256){
     return _adr.code.length;
 }

 function caller(address _adr) public{
     (bool success, bytes memory data) = _adr.call("0x0");
     require(success);
     result = data;
 }
}
