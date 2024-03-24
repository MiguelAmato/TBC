// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract maxSol {
  function getMax(uint[] memory arr) public pure returns (uint){
    uint maxVal = arr[0];
    for (uint i = 0; i< arr.length;i++)
      { if (arr[i] > maxVal) maxVal = arr[i]; }
    return maxVal;
  }
}

contract maxAsm1 {
  function getMax(uint[] memory arr) public pure returns (uint){
    uint maxVal = arr[0];
    for (uint i = 0; i< arr.length;i++){
      assembly{
        let felem := add(arr,0x20)
        let offset := mul(i,0x20)
        let pos := add(felem,offset)
        let elem := mload(pos)
        if gt(elem,maxVal){ maxVal := elem }
    } }
    return maxVal;
  }
}

contract maxAsm2 {
  function completeMaxAsm(uint[] memory arr) public pure returns (uint maxVal){
    // Complete for loop in Yul
    assembly{
      let len := mload(arr)
      let data := add(arr, 0x20)
      maxVal := mload(data)
      let i := 1
      for {} lt(i,len) {i:= add(i,1)}
      {
       let elem := mload(add(data,mul(i,0x20)))
       if gt(elem,maxVal) { maxVal := elem }
      }
    }
  } 
}
