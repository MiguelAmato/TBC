// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;

contract lab7Simple {

     uint [] public arr;

    function generate(uint n) external {
        bytes32 b = keccak256("seed");
        for(uint i = 0; i<n; i++){
            uint8 number = uint8(b[i % 32]);
            arr.push(number);
        }
    }

    function maxMinStorage() public view returns (uint maxmin) {
        uint max = arr[0];
        uint min = arr[0];
        uint elem;

        for(uint i = 1; i < arr.length; i++){
            elem = arr[i];

            if(elem > max) max = elem;
            if(elem < min) min = elem;
        }

        maxmin = max - min;
    }
}
