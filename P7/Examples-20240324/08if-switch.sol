// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract condSol {

  function cond(uint b) public pure returns (uint){
    if (b == 0) { return  11; }
    else if (b == 1) { return 22; }
    else { return 33; }
  }
}

contract condAsm {

  function cond(uint b) public pure returns (uint result){
    assembly{
      switch b
      case 0 { result:= 11 }
      case 1 { result:= 22 }
      default{ result:= 33 }
    }
  } 
}
