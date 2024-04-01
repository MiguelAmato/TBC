// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;

contract lab6ex6 {
    uint[] private  arr;

    function generate(uint n) external {
        bytes32 b = keccak256("seed");
        for (uint i = 0; i < n; i++) {
            uint8 number = uint8(b[i % 32]);
            arr.push(number);
        }
    }

    function getArr() public view returns (uint[] memory) {
        return arr;
    }


    function maxMinStorage() public view returns (uint maxmin) {

        uint256 s;

        assembly{
            s := arr.slot
        }

        bytes32 loc = keccak256(abi.encode(s));

        assembly {
            //no se si es asi, muy parecido al anterior
            function fmaxmin(slot, n) -> maxVal, minVal {
                let len := sload(n)
                maxVal := sload(slot)
                minVal := sload(slot)

                for {let i := 1} lt(i,len) { i := add(i,1) } {
                    let elem := sload(add(slot, i))
                     if gt(elem, maxVal) { // si es mayor el elemento q el maximo -> es el maximo
                        maxVal := elem
                    }
                    if lt(elem, minVal) { // si es menor el elemento que el minimo -> es el minimo
                        minVal := elem
                    }
                }
            }

            let maxVal, minVal := fmaxmin(loc, arr.slot)
            maxmin := sub(maxVal, minVal)
        }
    }
}