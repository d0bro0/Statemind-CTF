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



 // bytecode: 0x6064600c60003960646000f36080604052348015600f57600080fd5b506004361060285760003560e01c80630c49c36c14602d575b600080fd5b6020608052600f60a0527f68656c6c6f2073746174656d696e64000000000000000000000000000000000060c05260606080f3
