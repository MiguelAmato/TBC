// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract sum00 {
  function sum(uint a, uint b) external pure returns (uint){
    return a+b;
  }
}

contract sum01 {
  function sumAsm(uint a, uint b) external pure returns (uint){
        assembly{
            let result := add(a,b)
            mstore(0x00,result)
            return(0x00,0x20) // terminates execution!
        }
  }
}

contract sum02 {
  function sumAsm(uint a, uint b) external pure returns (uint){
      assembly{
          let result := add(a,b)
          let ptr := msize()
          let safe_ptr := add(ptr,1)
          mstore(safe_ptr,result)
          return(safe_ptr,0x20) // terminates execution!
      }
  } 
}

contract sum03 {
  function sumAsm(uint a, uint b) external pure returns (uint result){
        assembly{
            result := add(a,b)
        } 
  }
}
