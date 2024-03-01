// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7.0 < 0.8.0;

contract DhontElectionRegion {

    uint immutable private regionId;

    mapping(uint => uint) private weights;

    uint[] internal results;

    constructor(uint _nPartidos, uint _regionId) {
        savedRegionInfo();
        regionId = _regionId;
        results = new uint[](_nPartidos);
    }

    function savedRegionInfo() internal {
        weights[28] = 1; // Madrid
        weights[8] = 1; // Barcelona
        weights[41] = 1; // Sevilla
        weights[44] = 5; // Teruel
        weights[42] = 5; // Soria
        weights[49] = 4; // Zamora
        weights[9] = 4; // Burgos
        weights[29] = 2; // Malaga
    }

    function registerVote(uint partido) internal returns (bool) {
        if (partido < 0 || results.length <= partido)
            return false;
        results[partido] += weights[regionId];
        return true;
    } 

}

abstract contract PollingStation {

    bool public votingFinished;

    bool private votingOpen;

    address private president;

    constructor(address _president) {
        president = _president;
        votingOpen = false;
        votingFinished = false;
    }

    modifier execPresident {
        require(msg.sender == president, "error (execPresident)");
        _;
    }

    modifier isVotingOpen {
        require(votingOpen, "error (isVotingOpen)");
        _;
    }

    function openVoting() external execPresident {
        require(!votingOpen, "error (openVoting)"); 
        votingOpen = true;
    }

    function closeVoting() external execPresident {
        require(!votingFinished, "error (closeVoting)");
        votingOpen = false;
        votingFinished = true;
    }

    function castVote(uint id) external virtual {}

    function getResults() external view virtual returns(uint[] memory) {}

}

contract DhontPollingStation is DhontElectionRegion, PollingStation {

    constructor(address presi, uint _nPartidos, uint regionId) DhontElectionRegion(_nPartidos, regionId) PollingStation(presi) {}

    function castVote(uint id) external override {
        require(registerVote(id), "error (castVote)");
    }

    function getResults() external view override returns(uint[] memory) {
        require(votingFinished, "error (getResults)");
        return results;
    }
}

contract Election {

    mapping (address => bool) public votantes; // Es un mapa que funciona como un set
    
    address public autoridad; // Poner la visibilidad de esto

    uint private nPartidos;

    mapping (uint => DhontPollingStation) public sedes;

    uint[] private regiones; 

    modifier onlyAuthority {
        require(msg.sender == autoridad, "error (onlyAuthority)");
        _;
    }

    modifier freshId(uint regionId) {
        require((address)(sedes[regionId]) == address(0), "error (freshId)");
        _;
    }
    
    modifier validId(uint regionId) {
        require((address)(sedes[regionId]) != address(0), "error (validId)");
        _;
    }

    modifier validPartido(uint partido) {
        require(partido < nPartidos, "error (validPartido)");
        _;
    }

    constructor(uint _nPartidos)  {
        autoridad = msg.sender;
        nPartidos = _nPartidos;
    }

    function createPollingStation(uint regionId, address president) external freshId(regionId) onlyAuthority returns (DhontPollingStation) {
        sedes[regionId] = new DhontPollingStation(president, nPartidos, regionId);
        regiones.push(regionId);
        return sedes[regionId];
    }

    function castVote(uint regionId, uint partido) external validId(regionId) validPartido(partido) {
        require(!votantes[msg.sender], "error (castVote)");
        sedes[regionId].castVote(partido);
        votantes[msg.sender] = true;
    }

    function getResults() external view onlyAuthority returns (uint[] memory) {
        uint[] memory resultadosTotales = new uint[](nPartidos); // Se inicializa a 0 todos los partidos
        for (uint i = 0; i < regiones.length; ++i) {
            uint[] memory resultados = sedes[regiones[i]].getResults(); // Aqui se maneja que todas esten cerradas
            for (uint j = 0; j < resultados.length; ++j)
                resultadosTotales[j] += resultados[j];
        }
        return resultadosTotales;
    }

}