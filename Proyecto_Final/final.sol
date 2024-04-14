// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IExecutableProposal {
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable;
}

contract Exec is IExecutableProposal { // NI IDEA DE COMO HACERLO

    address rec;

    constructor(address _rec){
        rec = _rec;
    }
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable override {       
        payable(rec).transfer(numTokens); //TODO probablemente no sea así
    }
}


contract QuadraticVoting {

    myERC20 private gestorToken;

    struct Participant {
        uint nTokens;
        uint value;
        mapping(uint => uint) pVotes; // pId -> votos
    }

    struct Proposal {
        string name;
        string desc;
        uint256 budget;
        address rec;
        uint votes;
        bool accepted;
        bool cancel;
        uint threshold;
        uint nParts;
        address[] parts; //participantes
    }

    //TODO La proposal estaba en un struct pero apartado 2.1 entiendo que dice q es un contrato que implementa a IExecutableProposal pero no se

    address payable owner;

    uint private weiPrice;
    uint private nMaxTokens;
    uint private totalBudget;
    uint private nProposals;
    uint private nParticipants;
    uint private nPendingProp;


    bool open;

    mapping (address => Participant) participants; // (address participante -> Participant)
    mapping (uint => Proposal) proposals; // (proposalId -> Proposal)

    constructor(uint _weiPrice, uint _nMaxTokens) {
        gestorToken = new myERC20("token", "tok");
        weiPrice = _weiPrice;
        nMaxTokens = _nMaxTokens;
        open = false;
        nProposals = 0;
        nParticipants = 0;
        owner = payable(msg.sender);
    }

    // ===================================== EVENTS =====================================

    event ProposalCreated(uint indexed proposalId, string title);
    //event ProposalCanceled(uint indexed proposalId);
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

    modifier positiveVotesNotZero(uint votes) {
        require(votes > 0, "Votes must be bigger than zero");
        _;
    }

    modifier notAceptedProposal(uint pId) {
        require(!proposals[pId].accepted, "You can not retire your votes from an acepted proposal");
        _;
    }

    modifier isFinancingProp(uint pId) {
        require(proposals[pId].budget > 0, "Must be a financing proposal to be accepted and executed");
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
        nParticipants++;

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
        nParticipants--;
        delete(participants[msg.sender]);
    }

    function addProposal(string memory pName, string memory pDesc, uint pBudget , address pRec) external votingIsOpen returns(uint Id){
        require(pBudget >= 0, "budget must be positive"); // TODO comprobar que solo es 0 si la descripcion es signaling
        require(pRec != address(0), "receptor address can not be zero");
        Id = nProposals;
        nProposals++;
        proposals[Id] = Proposal({name:pName, desc:pDesc, budget:pBudget, rec:pRec, votes:0, accepted:false, cancel:false, threshold:0, nParts:0, parts: new address[](0)});

        emit ProposalCreated(Id, pName); // TODO no se si hay que hacerlos
    }

    function cancelProposal(uint pId) external votingIsOpen proposalExist(pId) propOwner(pId){
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

    function getPendingProposals() public view votingIsOpen returns(uint[] memory pending){
        //recorro el mapa como array porque su clave es un id que comienza en 0 y tenemos en tamaño del mapa en nProposals
        uint x = 0;
        for(uint i = 0; i < nProposals; i++){
            if(!proposals[i].accepted && proposals[i].budget > 0 && !proposals[i].cancel){ // financing tiene presupuesto > 0 y signaling == 0
                pending[x] = i;
                x++;
            } 
        }
    }

    function getApprovedProposals() public view votingIsOpen returns(uint[] memory pending){
        //recorro el mapa como array porque su clave es un id que comienza en 0 y tenemos en tamaño del mapa en nProposals
        uint x = 0;
        for(uint i = 0; i < nProposals; i++){
            if(proposals[i].accepted && proposals[i].budget > 0){ // financing tiene presupuesto > 0 y signaling == 0
                pending[x] = i;
                x++;
            } 
        }
    }
    //TODO estos get son public???
    function getSignalingProposals() public view votingIsOpen returns (uint[] memory pending){
        //recorro el mapa como array porque su clave es un id que comienza en 0 y tenemos en tamaño del mapa en nProposals
        uint x = 0;
        for(uint i = 0; i < nProposals; i++){
            if((proposals[i].budget) == 0){ // financing tiene presupuesto > 0 y signaling == 0
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
    function stake(uint pId, uint votes) external notAceptedProposal(pId) proposalExist(pId) positiveVotesNotZero(votes) {
        uint gasto = votes;
        uint voted = participants[msg.sender].pVotes[pId];
        
        if(votes > 1 || voted > 1) gasto = votes**2;

        require(participants[msg.sender].nTokens >= gasto, "Not enough tokens to vote this proposal");
        // la debe realizar el participante con el contrato ERC20 antes de ejecutar esta funcion;
        // el contrato ERC20 se puede obtener con getERC20). 
        gestorToken.approveTokens(msg.sender, proposals[pId].rec, gasto); // TODO si los transfiero aqui hace falta comprobarlo??
        participants[msg.sender].pVotes[pId] += votes; // cuantos votos tengo en esa propuesta

        if(voted == 0){
            proposals[pId].nParts++;
            proposals[pId].parts.push(msg.sender);
        }

        uint newVotes = proposals[pId].votes + votes;

        proposals[pId].votes = newVotes; // realizo la votación
        participants[msg.sender].nTokens -= gasto; // gasto los tokens

        uint ratio = (proposals[pId].budget * 100) / totalBudget;
        uint presupuesto = ((2 + ratio) * nParticipants) / 10 + nPendingProp; // no se si es equivalente pero no se puede hacer directamente


        proposals[pId].threshold = presupuesto; // actualizo el umbral ya que recibe votos
        
    }

    function withdrawFromProposal(uint votes, uint pId) external notAceptedProposal(pId) proposalExist(pId) positiveVotesNotZero(votes) enoughVotes(votes,pId){

        uint recuperar = votes;
        uint votosP = participants[msg.sender].pVotes[pId];

        if(votosP > 1) {
            uint res = votosP - votes;
            recuperar = votosP**2 - res**2;
        }

        participants[msg.sender].pVotes[pId] -= votes;
        participants[msg.sender].nTokens += recuperar;

        if(votosP == votes) { // si retiro TODOS los votos le saco de los participantes de esa propuesta
            uint nParts = proposals[pId].nParts;
            bool b = false;
            for(uint i = 0; i < nParts && !b; i++){
                if(address(msg.sender) == address(proposals[pId].parts[i])){
                    proposals[pId].parts[i] = proposals[pId].parts[nParts - 1];
                    proposals[pId].parts.pop();
                    b = true;
                }   
            }
            proposals[pId].nParts--;
        }

        // recalcular umbral tras retirar votos?? pone solo al recibir

    }

    function _checkAndExecuteProposal(uint pId) internal isFinancingProp(pId) {
        uint presupuesto = proposals[pId].votes + participants[owner].value;
        require(presupuesto >= proposals[pId].budget, "No enough money to finance propousal");

        //uint umbral = ((0.2 + (proposals[pId].getBudget() / presupuesto))*nParticipants) + nPendingProp;
        // proposals[pId].setThreshold(presupuesto, nParticipants, nPendingProp);

        require(proposals[pId].votes > proposals[pId].threshold, "Not enough votes to pass the threshold");

        uint gasto = proposals[pId].budget - proposals[pId].votes; // TODO ns si se restan los votos como que todos han sido solo 1 token o llevar el numero de tokens y eso es lo q restar
        totalBudget -= gasto; // al aprovar la propuesta restamos al presupuesto lo que cuesta la propuesta aprovada

        // TODO no hace falta quitar los votos a las propuestas en los participantes ya que cuando se compruebe la propuesta estara aceptada?? 

        proposals[pId].accepted = true;

        Exec rec = new Exec(proposals[pId].rec);

        rec.executeProposal(pId, proposals[pId].votes, proposals[pId].budget);

        //  limitar la cantidad maxima de gas de la funcion a 100.000 en contrato externo
    }

    function returnTokensF() internal {

        uint[] memory pending = getPendingProposals();

        for(uint i = 0; i < pending.length; i++){
            for(uint j = 0; j < proposals[pending[i]].nParts; j++){
                //cada participante que haya votado a cada propuesta pendiente recibe sus tokens
                uint recuperar = participants[proposals[pending[i]].parts[j]].pVotes[pending[i]];
                if(recuperar > 1){
                    recuperar = recuperar**2;
                }
                participants[proposals[pending[i]].parts[j]].nTokens += recuperar;
                participants[proposals[pending[i]].parts[j]].pVotes[pending[i]] = 0;
            }
        }

    }

    function acceptAndReturnS() internal {
        uint[] memory signaling = getSignalingProposals();

        for(uint i = 0; i < signaling.length; i++){
            proposals[signaling[i]].accepted = true;

            for(uint j = 0; j < proposals[signaling[i]].nParts; j++){
                //cada participante que haya votado a cada propuesta pendiente recibe sus tokens
                uint recuperar = participants[proposals[signaling[i]].parts[j]].pVotes[signaling[i]];
                if(recuperar > 1){
                    recuperar = recuperar**2;
                }
                participants[proposals[signaling[i]].parts[j]].nTokens += recuperar;
                participants[proposals[signaling[i]].parts[j]].pVotes[signaling[i]] = 0;
            }

        }
    }

    function returnBudget() internal {
        participants[msg.sender].value += totalBudget;
    }

    function closeVoting() external onlyOwner {
        open = false;

        returnTokensF();
        acceptAndReturnS();
        returnBudget();
 
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