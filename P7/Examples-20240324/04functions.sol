// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract YulFunctions {
  function power(uint b, uint e) public pure returns (uint) {
    uint res;
    assembly {
      function power(base, exponent) -> result {
        switch exponent
        case 0  { result := 1 }
        case 1  { result := base }
        default {
          result := power(mul(base, base), div(exponent, 2))
          if eq(mod(exponent, 2), 1) { result := mul(base, result) }
        }
      }
      res := power(b, e)
    }
    return res;
  }
} 
