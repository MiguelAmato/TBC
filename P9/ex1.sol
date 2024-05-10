// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.0;
contract ex1 {
  uint[] arr = new uint[](5);
  function p1() external view returns (uint) {
    uint sumEven = 0;
    for (uint i = 0; i < arr.length; i+=2) {
      sumEven += arr[i];
    }
    return sumEven;
  }
  function p2() external view { uint[] memory local = arr; }
  function p3() external view { uint[] storage local = arr; }
}


