// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.4.26;

contract lab6 {
    uint[] arr;
    uint sum;
    
    function generate(uint n) external {
        for(uint i = 0; i < n; i++){
            arr.push(i*i);
        }
    }

    function computeSum() external {
        sum = 0;
        uint len = arr.length; // nos ahorramos acceder en cada vuelta al arr.length y la traemos a cache
        for (uint i = 0; i < len; i++){
            sum += arr[i]; // nos ahorramos una lectura adicional
        }
    }
}