// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;

contract lab7 {

    function maxMinMemory(uint[] memory arr) public pure returns (uint maxmin){
        assembly {

            function fmaxmin(array_pointer) -> maxVal, minVal {

                let len := mload(array_pointer) // cargamos de memoria la longitud del array
                let data := add(array_pointer, 0x20) // avanzamos a la posicion de memoria del primer elemento
                maxVal := mload(data)
                minVal := mload(data)
                let i := 1


                for {} lt(i, len) { i := add(i, 1) } {
                    let elem := mload(add(data, mul(i, 0x20))) // cargamos el siguiente elemento
                    if gt(elem, maxVal) { // si es mayor el elemento q el maximo -> es el maximo
                        maxVal := elem
                    }
                    if lt(elem, minVal) { // si es menor el elemento que el minimo -> es el minimo
                        minVal := elem
                    }
                }
            }

            let maxVal, minVal := fmaxmin(arr)
            maxmin := sub(maxVal, minVal)
        }
    }
}