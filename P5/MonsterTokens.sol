// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7.0 < 0.8.0;

library ArrayUtils {

    function compare(string memory s1, string memory s2) internal pure returns (bool) {
        return keccak256(bytes(s1)) == keccak256(bytes(s2));
    }

    function contains(string[] storage arr, string calldata val) external view returns (bool) {
        for (uint i = 0; i < arr.length; i++)
            if (compare(arr[i], val)) return true;
        return false;
    }

    function increment(uint[] storage arr, uint8 p) external{
        for(uint i = 0; i < arr.length; i++)        
            arr[i] += arr[i]*(p/100);
    }

    function sum(uint[] storage arr) external view returns (uint res){
        res = 0;

        for(uint i = 0; i < arr.length; i++)
            res += arr[i];
    }
}


contract MonsterTokens {

    struct Weapons {
        string[] names; // name of the weapon
        uint[] firePowers; // capacity of the weapon
    }
    struct Character {
        string name; // character name
        Weapons weapons; // weapons assigned to this character
    }

    address private autoridad;

    uint constant INIT = 10001;
    uint private nextToken;

    mapping(uint=>Character) private personajes;

    constructor(){
        autoridad = msg.sender;
        nextToken = INIT;
    }

    modifier onlyAuthority {
        require(msg.sender == autoridad, "No authority");
        _;
    }

    modifier AddrDistZero(address a) {
        require(a != address(0), "No authority");
        _;
    }

    function createMonsterToken(string calldata _name, address dir) external onlyAuthority AddrDistZero(dir) returns (uint ID) {
        require(bytes(_name).length > 0, "Nombre Invalido");
        ID = nextToken;
        personajes[ID] = Character({name: _name, weapons: Weapons({names : new string[](0), firePowers : new uint[](0)})});
        nextToken++;
    }

    modifier TokenOwner {
        require(true,"");
        _;
    }

    modifier ValidToken(uint token){
        require((token > INIT && token < nextToken), "Token no valido");
        _;
    }

    function addWeapon(uint tokenId, string calldata nWeapon, uint fPower) external TokenOwner ValidToken(tokenId) {
        require(bytes(nWeapon).length > 0, "Nombre Invalido");
        require(!ArrayUtils.contains(personajes[tokenId].weapons.names, nWeapon), "Existe Arma");

        personajes[tokenId].weapons.names.push(nWeapon);
        personajes[tokenId].weapons.firePowers.push(fPower);
    }

    function incrementFirePower(uint tokenId, uint8 p) external ValidToken(tokenId){
        require(p >= 0, "porcentaje negativo"); // permitimos aumentar un 0%

        ArrayUtils.increment(personajes[tokenId].weapons.firePowers, p);
    }

}