// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7.0 < 0.8.0;

contract hello {

    event Print(string message);

    function helloWorld() public {
        emit Print("Hello, World!");
    }

    function factorial(uint n) public pure returns (uint) {
        if (n == 1) return n;
        else return (factorial(n-1) * n);
    }

}
