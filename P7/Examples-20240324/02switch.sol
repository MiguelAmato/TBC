// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/* 
   Function ff retrieves the value passed as an argument accessing to
   calldata, and updates the value of the state variable xx accessing
   to storage addresses directly. Yul code bypasses both Solidity
   identifiers.

   Warning! This piece of code is obscure and disrespectful towards
   other programmers that might read it (including the creator of this
   code!).  It is included here just to illustrate the switch
   instruction and the capabilities (and dangers) of this low-level
   language. Please use with care.
*/
contract YulSwitch {
  uint public xx;
  function ff(uint p) public  {
    assembly {
      let x := 0
      switch calldataload(4) // checks value of 1st arg accessing to calldata
      case 1 {  x := 37  }
      default {  x := calldataload(4)  }
      sstore(0, div(x, 2))    // Updates first storage slot!
    }
  }
} 
