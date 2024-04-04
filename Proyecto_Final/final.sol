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
        bool accepted;
    }

    struct Participant {
        uint nTokens;
        uint value;
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

    modifier proposalExist(uint id) {
        require(id < nProposals, "Proposal does not exist");
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

        proposals[Id] = Proposal({name: pName, desc: pDesc, budget: pBudget, rec:pRec, accepted:false});

        emit ProposalCreated(Id, pName); // TODO no se si hay que hacerlos
    }

    function cancelProposal(uint pId) external votingIsOpen propOwner(pId){
        nProposals--;
        delete(proposals[pId]);

        emit ProposalCanceled(pId); // TODO no se si hay que hacerlos
    }

    function buyTokens(uint n) external payable existParticipant{

        for(uint i = 0; i < n && participants[msg.sender].value >= weiPrice; i++){
            gestorToken.newToken(msg.sender, weiPrice);
            participants[msg.sender].value -= weiPrice;
        }

    }

    function sellTokens(uint n) external payable existParticipant enoughTokens(n){
        //gestorToken.Transfer(from, to, value); TODO No se como devolver el token
        for(uint i = 0; i < n; i++){ // TODO al cancelar su participacion se venden sus tokens??
            payable(msg.sender).transfer(weiPrice);
        }

    }

    function getERC20() external returns (address){
        //TODO
    }

    function getPendingProposals() external view votingIsOpen returns(uint[] memory pending){
        //recorro el mapa como array porque su clave es un id que comienza en 0 y tenemos en tamaño del mapa en nProposals
        uint x = 0;
        for(uint i = 0; i < nProposals; i++){
            if(!proposals[i].accepted && proposals[i].budget > 0){ // financing tiene presupuesto > 0 y signaling == 0
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


}

contract myERC20 is ERC20 {
    constructor(string memory name, string memory symb) ERC20(name, symb) {}

    function newToken(address account, uint value) external {
        _mint(account, value);
    }
}