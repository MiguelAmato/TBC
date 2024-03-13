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

interface ERC721simplified{

    //Sacado de https://eips.ethereum.org/EIPS/eip-721

    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId); 
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    function approve(address _approved, uint256 _tokenId) external payable;

    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function getApproved(uint256 _tokenId) external view returns (address);


}


contract MonsterTokens is ERC721simplified{

    struct Weapons {
        string[] names; // name of the weapon
        uint[] firePowers; // capacity of the weapon
    }
    struct Character {
        string name; // character name
        Weapons weapons; // weapons assigned to this character
        address tokenOwner; // address of the token owner
    }

    address payable authority;

    uint constant INIT = 10001;
    uint private nextToken;

    mapping(uint=>Character) private characters;
    mapping(uint => address) approvedMap; // (TokenId -> address) mapa de tokensId que almacena la direccion que tiene permiso para usarlo

    constructor(){
        authority = payable(msg.sender);
        nextToken = INIT;
    }

    modifier onlyAuthority {
        require(msg.sender == authority, "No authority");
        _;
    }

    modifier AddrDistZero(address a) {
        require(a != address(0), "Address can not be zero");
        _;
    }

    function createMonsterToken(string calldata _name, address dir) external onlyAuthority AddrDistZero(dir) returns (uint ID) {
        require(bytes(_name).length > 0, "Invalid Name");
        ID = nextToken;
        characters[ID] = Character({name: _name, weapons: Weapons({names : new string[](0), firePowers : new uint[](0)}), tokenOwner: dir});
        nextToken++;
    }

    modifier TokenOwner(uint tokenId) {
        require(msg.sender == characters[tokenId].tokenOwner ,"Must be the tokenOwner");
        _;
    }

    modifier ValidToken(uint token){
        require((token >= INIT && token < nextToken), "Invalid Token");
        _;
    }

    modifier ApprovedOrTokenOwner(uint tokenID){
        require((approvedMap[tokenID] == msg.sender) || 
                    (msg.sender == characters[tokenID].tokenOwner), "Must be the tokenOwner or Approved address");
        _;
    }

    function addWeapon(uint tokenId, string calldata nWeapon, uint fPower) external ApprovedOrTokenOwner(tokenId) ValidToken(tokenId) {
        require(bytes(nWeapon).length > 0, "Invalid Weapon Name");
        require(!ArrayUtils.contains(characters[tokenId].weapons.names, nWeapon), "Weapon alredy exists");

        characters[tokenId].weapons.names.push(nWeapon);
        characters[tokenId].weapons.firePowers.push(fPower);
    }

    function incrementFirePower(uint tokenId, uint8 p) external ValidToken(tokenId){
        require(p >= 0, "porcentage must be >= 0"); // permitimos aumentar un 0%

        ArrayUtils.increment(characters[tokenId].weapons.firePowers, p);
    }

    function collectProfits() external onlyAuthority {
        authority.transfer(address(this).balance);
    }

    // Interface Functions

    modifier EnoughValue(uint _tokenId){
        require(msg.value >= ArrayUtils.sum(characters[_tokenId].weapons.firePowers), "Not enough weis");
        _;
    }

    function approve(address _approved, uint256 _tokenId) external payable override ValidToken(_tokenId) TokenOwner(_tokenId) EnoughValue(_tokenId){
        approvedMap[_tokenId] = _approved; // añadimos la nueva address que puede usar el token

        emit Approval(msg.sender, _approved, _tokenId);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external payable override ValidToken(_tokenId) ApprovedOrTokenOwner(_tokenId)
     EnoughValue(_tokenId) AddrDistZero(_from) AddrDistZero(_to) {
        require(characters[_tokenId].tokenOwner == _from, "_from must be the address of the token");

        approvedMap[_tokenId] = address(0);
        characters[_tokenId].tokenOwner = _to; //el token pasa a pertenecer a _to

        emit Transfer(_from, _to, _tokenId);
    }

    function balanceOf(address _owner) external view override AddrDistZero(_owner) returns (uint256 balance){
        uint ID = INIT;
        Character memory c = characters[ID];
        balance = 0;

        while(ID < nextToken){
            if(c.tokenOwner == _owner) balance++;
            ID++;
            c = characters[ID];
        }

    }
    function ownerOf(uint256 _tokenId) external view override ValidToken(_tokenId) returns (address){
        Character memory c = characters[_tokenId];
        require(c.tokenOwner != address(0), "_tokenId must be different to zero");
        return c.tokenOwner;
    }
    function getApproved(uint256 _tokenId) external view override ValidToken(_tokenId) returns (address){
        return approvedMap[_tokenId]; // si no hay ninguna direccion devolvera address(0) que es como esta inicializado por defecto el mapa
    }

}