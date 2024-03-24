// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;

contract lab6ex6 {
    uint [] public arr;

    function generate(uint n) external {
        bytes32 b = keccak256("seed");
        for(uint i = 0; i<n; i++){
            uint8 number = uint8(b[i % 32]);
            arr.push(number);
        }
    }

    function getArr() public view returns (uint[] memory){
       return arr;
    }

    function maxMinStorage() public view returns (uint maxmin) {
        assembly {
            //no se si es asi, muy parecido al anterior
            function fmaxmin(slot) -> maxVal, minVal {

                let len := sload(slot) // cargamos de memoria la longitud del array
                let data := add(slot, 0x20) // avanzamos a la posicion de memoria del primer elemento
                maxVal := sload(data)
                minVal := sload(data)
                let i := 1


                for {} lt(i, len) { i := add(i, 1) } {
                    let elem := sload(add(data, mul(i, 0x20))) // cargamos el siguiente elemento
                    if gt(elem, maxVal) { // si es mayor el elemento q el maximo -> es el maximo
                        maxVal := elem
                    }
                    if lt(elem, minVal) { // si es menor el elemento que el minimo -> es el minimo
                        minVal := elem
                    }
                }
            }

            let maxVal, minVal := fmaxmin(arr.slot)
            maxmin := sub(maxVal, minVal)
        }

        return maxmin;
    }
}