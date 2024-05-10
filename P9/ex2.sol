// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.0;
contract ex2 {
  uint[] arr = new uint[](5);
  function powers() external {
    for (uint i = 0; i < arr.length; i++) {
      arr[i] = i**i;
    }
  }
}

