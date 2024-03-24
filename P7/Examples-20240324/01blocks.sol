// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract YulBlocks {
  uint public xx = 1;
  uint public yy;
  function ff() public  {
    assembly {
      let zero 
      let v := sload(zero)
      {
        let y := add(sload(v), 1)
        v := y
      } // y is not visible outside this block
      sstore(1, v)
    }
  }
}
