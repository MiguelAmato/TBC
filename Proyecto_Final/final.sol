// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IExecutableProposal {
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable;
}


contract QuadraticVoting {

    myERC20 private gestorToken;

    struct Proposal {
        string name;
        string desc;
        uint256 budget;
        address rec;
        uint votes;
        bool accepted;
        bool cancel;
    }

    struct Participant {
        uint nTokens;
        uint value;
        mapping(uint => uint) pVotes; // pId -> votos
    }

    address payable owner;

    uint private weiPrice;
    uint private nMaxTokens;
    uint private totalBudget;
    uint private nProposals;

    bool open;

    mapping (address => Participant) participants; // (address participante -> Participant)
    mapping (uint => Proposal) proposals; // (proposalId -> Proposal)

    constructor(uint _weiPrice, uint _nMaxTokens) {
        gestorToken = new myERC20("token", "tok");
        weiPrice = _weiPrice;
        nMaxTokens = _nMaxTokens;
        open = false;
        nProposals = 0;
        owner = payable(msg.sender);
    }

    // ===================================== EVENTS =====================================

    event ProposalCreated(uint indexed proposalId, string title);
    event ProposalCanceled(uint indexed proposalId);
    event ProposalExecuted(uint indexed proposalId, uint amountSent);

    // ===================================== MODIFIERS =====================================

    modifier onlyOwner {
        require(msg.sender == owner, "No Owner");
        _;
    }

    modifier positiveValue {
        require(msg.value >= 0, "positiveValue");
        _;
    }

    modifier votingIsOpen {
        require(open == true, "Voting is not open yet");
        _;
    }

    modifier propOwner(uint pId) {
        require(proposals[pId].rec == msg.sender, "Must be de owner of the proposal");
        _;
    }

    modifier existParticipant() {
        require(participants[msg.sender].nTokens >= 1, "must exist the participant");
        _;
    }

    modifier enoughTokens(uint n) {
        require(participants[msg.sender].nTokens >= n, "Not enough tokens");
        _;
    }

    modifier enoughValue(uint n) {
        require(participants[msg.sender].value >= n*weiPrice, "Not enough tokens");
        _;
    }
    modifier proposalExist(uint id) {
        require(id < nProposals && proposals[id].cancel == false, "Proposal does not exist");
        _;
    }

    modifier enoughVotes(uint n, uint pId) {
        require(n <= participants[msg.sender].pVotes[pId], "You spend less votes in this proposal");
        _;
    }

    // ===================================== FUNCIONES =====================================

    function openVoting(uint initBudget) public onlyOwner {
        require(initBudget >= 0, "Budget must be a positive number");
        totalBudget = initBudget;
        open = true;
    }

    function addParticipant() external payable positiveValue {
        require(participants[msg.sender].nTokens == 0, "this account already exist");
        require(msg.value >= weiPrice, "Not enough money");

        uint value = msg.value;
        gestorToken.newToken(msg.sender, weiPrice);
        value -= weiPrice;
        participants[msg.sender].nTokens = 1;
        participants[msg.sender].value = value;

    }

    function removeParticipant() external payable existParticipant{
        
        //participants[msg.sender] = false;
        //he intentado devolverle el dinero que tenia al borrarse pero no se si es asi
        // o lo ponemos como false para que no pueda actuar pero complicaría el addParticipant habría que ver si esta en false o no existe
        payable(msg.sender).transfer(participants[msg.sender].value);

        for(uint i = 0; i < participants[msg.sender].nTokens; i++){ // TODO al cancelar su participacion se venden sus tokens??
            payable(msg.sender).transfer(weiPrice);
        }

        // TODO borrar los tokens que le pertenecen

        delete(participants[msg.sender]);
    }

    function addProposal(string memory pName, string memory pDesc, uint pBudget , address pRec) external votingIsOpen returns(uint Id){
        require(pBudget >= 0, "budget must be positive"); // TODO comprobar que solo es 0 si la descripcion es signaling
        require(pRec != address(0), "receptor address can not be zero");
        Id = nProposals;
        nProposals++;

        proposals[Id] = Proposal({name: pName, desc: pDesc, budget: pBudget, rec:pRec, votes:0, accepted:false, cancel:false});

        emit ProposalCreated(Id, pName); // TODO no se si hay que hacerlos
    }

    function cancelProposal(uint pId) external votingIsOpen propOwner(pId){
        proposals[pId].cancel = true;
        //delete(proposals[pId]);
        //emit ProposalCanceled(pId); // TODO no se si hay que hacerlos
    }

    function buyTokens(uint n) external payable existParticipant enoughValue(n){
        // TODO no se como hacerlo, si pasandole cuantos quieres, si de uno en uno o todos los posibles
        // en caso de pasando los que quieres como este caso, si no hay suficiente dinero para los n decir que no hay dinero
        // o comprar los posibles -> && participants[msg.sender].value >= weiPrice
        for(uint i = 0; i < n ; i++){
            gestorToken.newToken(msg.sender, weiPrice);
            participants[msg.sender].value -= weiPrice;
            participants[msg.sender].nTokens++;
        }

    }

    function sellTokens(uint n) external payable existParticipant enoughTokens(n){
        //gestorToken.Transfer(from, to, value); TODO No se como devolver el token
        for(uint i = 0; i < n; i++){ // TODO al cancelar su participacion se venden sus tokens??
            participants[msg.sender].value += weiPrice;
            participants[msg.sender].nTokens--;
        }

    }

    function getERC20() external view returns (address){
        //TODO esto no es asi verdad?
        return address(gestorToken);
    }

    function getPendingProposals() external view votingIsOpen returns(uint[] memory pending){
        //recorro el mapa como array porque su clave es un id que comienza en 0 y tenemos en tamaño del mapa en nProposals
        uint x = 0;
        for(uint i = 0; i < nProposals; i++){
            if(!proposals[i].accepted && proposals[i].budget > 0 && !proposals[i].cancel){ // financing tiene presupuesto > 0 y signaling == 0
                pending[x] = i;
                x++;
            } 
        }
    }

    function getApprovedProposals() external view votingIsOpen returns(uint[] memory pending){
        //recorro el mapa como array porque su clave es un id que comienza en 0 y tenemos en tamaño del mapa en nProposals
        uint x = 0;
        for(uint i = 0; i < nProposals; i++){
            if(proposals[i].accepted && proposals[i].budget > 0){ // financing tiene presupuesto > 0 y signaling == 0
                pending[x] = i;
                x++;
            } 
        }
    }

    function getSignalingProposals() external view votingIsOpen returns (uint[] memory pending){
        //recorro el mapa como array porque su clave es un id que comienza en 0 y tenemos en tamaño del mapa en nProposals
        uint x = 0;
        for(uint i = 0; i < nProposals; i++){
            if(proposals[i].budget == 0){ // financing tiene presupuesto > 0 y signaling == 0
                pending[x] = i;
                x++;
            }
        }
    }

    function getProposalInfo(uint id) external view votingIsOpen proposalExist(id) returns (Proposal memory p){
        p = proposals[id];
    }

    // a MISMA PROPUESTA: primer voto  1 token segundo voto 4 tercer voto 9...
    // a distintas propuestas cada voto a cada propuesta 1 token 
    function stake(uint pId, uint votes) external {
        uint gasto = votes;
        uint voted = participants[msg.sender].pVotes[pId];
        
        if(votes > 1 || voted > 1) gasto = votes**2;

        require(participants[msg.sender].nTokens >= gasto, "Not enough tokens to vote this proposal");
        // la debe realizar el participante con el contrato ERC20 antes de ejecutar esta funcion;
        // el contrato ERC20 se puede obtener con getERC20). 
        gestorToken.approveTokens(msg.sender, proposals[pId].rec, gasto); // TODO si los transfiero aqui hace falta comprobarlo??
        participants[msg.sender].pVotes[pId] += votes; // cuantos votos tengo en esa propuesta
        proposals[pId].votes += votes; // realizo la votación
        participants[msg.sender].nTokens -= gasto; // gasto los tokens
        
    }

    function withdrawFromProposal(uint votes, uint pId) external enoughVotes(votes,pId){
        require(!proposals[pId].accepted, "You can not retire your votes from an acepted proposal");
        require(!proposals[pId].cancel, "Proposal canceled");

        uint recuperar = votes;
        uint votosP = participants[msg.sender].pVotes[pId];

        if(votosP > 1) {
            uint res = votosP - votes;
            recuperar = votosP**2 - res**2;
        }

        participants[msg.sender].pVotes[pId] -= votes;
        participants[msg.sender].nTokens += recuperar;

    }
}

contract myERC20 is ERC20 {
    constructor(string memory name, string memory symb) ERC20(name, symb) {}

    function newToken(address account, uint value) external {
        _mint(account, value);
    }

    function approveTokens(address owner, address pOwner, uint value) external {
        _approve(owner, pOwner, value);
    }
}