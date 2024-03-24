// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract MemoryHandling {
  function mem() public pure returns (uint, uint, uint) {
    uint[] memory arr = new uint[](5);
    uint p; uint a; uint freePtr;

    assembly {
      p := arr               //pointer to arr in memory.
      a := mload(arr)        //arr.length (stored at mem[p]).
      freePtr := mload(0x40) //pointer to first free mem.location
    }
    return (p,a,freePtr);
  }
}
