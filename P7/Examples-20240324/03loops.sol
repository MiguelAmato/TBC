// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract YulFor {
  function fact(uint n) public pure returns (uint) {
    uint res;
    assembly {
      let x := 1
      if gt(n,1) {
        let i
        for { i := 2 } iszero(gt(i, n)) { i := add(i,1) } {
          x := mul(x, i)
        }
      }
      res := x
    }
    return res;
  }
} 


