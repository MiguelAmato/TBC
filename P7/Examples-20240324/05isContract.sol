// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract C {
  function isContract (address a) public view returns (bool){
    uint size;
    assembly{
        size := extcodesize(a)
    }
    if (size == 0) return false;
    else return true;
  }
}
