// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IExecutableProposal {
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable;
}

contract ExecProposal is IExecutableProposal {

    event ProposalExecuted(address prop_addr, uint proposalId, uint numVotes, uint numTokens, uint balance);

    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable override {
        emit ProposalExecuted(address(this), proposalId, numVotes, numTokens, address(this).balance);
    }
}


contract QuadraticVoting {

    myERC20 private gestorToken;

    struct Participant {
        uint nTokens;
        bool exist;
        mapping(uint => uint) pVotes; // pId -> votos
    }

    struct Proposal {
        string name;
        string desc;
        uint256 budget; // presupuesto en ether propuesta
        address owner;
        uint votes;
        uint nTokens;
        bool accepted;
        bool cancel;
        uint threshold;
        uint nParts;
        address[] parts; //participantes
        IExecutableProposal addr;
    }

    address payable owner;

    uint private weiPrice;
    uint private nMaxTokens;
    uint private totalBudget;
    uint private nProposals;
    uint private nParticipants;

    uint[] financingProposalsPend;
    uint[] signalingProposals;
    uint[] approvedProposals;

    bool open;

    mapping (address => Participant) participants; // (address participante -> Participant)
    mapping (uint => Proposal) proposals; // (proposalId -> Proposal)

    constructor(uint _weiPrice, uint _nMaxTokens) {
        weiPrice = _weiPrice;
        nMaxTokens = _nMaxTokens;
        gestorToken = new myERC20(nMaxTokens);
        open = false;
        nProposals = 0;
        nParticipants = 0;
        owner = payable(msg.sender);
    }

    // ===================================== MODIFIERS =====================================

    modifier onlyOwner { // solo puede ejecutarlo el owner del contrato
        require(msg.sender == owner, "No Owner");
        _;
    }

    modifier positiveValue { // debe pasarse una cantidad value mayor o igual a 0
        require(msg.value >= 0, "positiveValue");
        _;
    }

    modifier votingIsOpen { // la votacion esta abierta
        require(open == true, "Voting is not open yet");
        _;
    }

    modifier votingIsClose { // la votacion esta cerrada
        require(open == false, "Voting is open");
        _;
    }

    modifier propOwner(uint pId) { //es el creador de la propuesta
        require(proposals[pId].owner == msg.sender, "Must be de owner of the proposal");
        _;
    }

    modifier existParticipant() { // existe el participante
        require(participants[msg.sender].exist, "must exist the participant");
        _;
    }

    modifier enoughTokens(uint n) { // suficientes tokens para realizar la votacion
        require(participants[msg.sender].nTokens >= n, "Not enough tokens");
        _;
    }

    modifier proposalExist(uint id) { // existe la propuesta
        require(id < nProposals && proposals[id].cancel == false, "Proposal does not exist");
        _;
    }

    modifier enoughVotes(uint n, uint pId) { // suficientes votos en la propuesta para poder retirarlos
        require(n <= participants[msg.sender].pVotes[pId], "You spend less votes in this proposal");
        _;
    }

    modifier positiveVotesNotZero(uint votes) { // mas de 0 votos
        require(votes > 0, "Votes must be bigger than zero");
        _;
    }

    modifier notAceptedProposal(uint pId) { // no este aprobada la propuesta
        require(!proposals[pId].accepted, "You can not interactuate with an acepted proposal");
        _;
    }

    modifier isFinancingProp(uint pId) { // es una propuesta de tipo signaling
        require(proposals[pId].budget > 0, "Must be a financing proposal to be accepted and executed");
        _;
    }

    modifier notRegisteredPart() { // no existe el participante
        require(!participants[msg.sender].exist, "this account already exist");
        _;
    }

    modifier enoughMoneyToBuy() { //suficietne dinero para comprar al menos 1 token y que sean un numero exacto de tokens
        require(msg.value >= weiPrice, "Not enough eth to buy at least one token");
        _;
    }

    // ===================================== GETTERS PRUEBAS ============================

    /*function getProposalAccepted(uint pId) external view returns (bool){
        return proposals[pId].accepted;
    }

    function getProposalThreshold(uint pId) external view returns (uint){
        return proposals[pId].threshold;
    }

    function getProposalVotes(uint pId) external view returns (uint){
        return proposals[pId].votes;
    }

    function getProposalTokens(uint pId) external view returns (uint){
        return proposals[pId].nTokens;
    }

    function getProposalnParts(uint pId) external view returns (uint){
        return proposals[pId].nParts;
    }
    function getProposalCanceles(uint pId) external view returns (bool){
        return proposals[pId].cancel;
    }

    function getTotalBudget() external view returns (uint) {
        return totalBudget;
    } */


    // ===================================== FUNCIONES =====================================

    function openVoting() external payable onlyOwner votingIsClose { // abrir la votacion
        require(msg.value > 0, "Budget must be a positive number"); // el total budget debe ser mayor que 0
        totalBudget = msg.value;
        open = true;
    }

    function addParticipant() external payable  notRegisteredPart positiveValue enoughMoneyToBuy { //añadimos un participante a la votacion
        uint tokens = msg.value / weiPrice;
        gestorToken.newTokens(msg.sender, tokens); //el gestor de tokens crea los nuevos tokens comprados comprobando si se pueden crear
        participants[msg.sender].nTokens = tokens;
        participants[msg.sender].exist = true;
        nParticipants++;
    }

    function removeParticipantNotApprovedProposals(uint[] storage arr) private returns(uint eth, uint tokens){ //eliminamos los participantes de las propuestas no aprobadas
        uint length = arr.length;
        uint recuperar = 0; //numero de tokens a recuperar de la propuesta

        for(uint i = 0; i < length; i++){
            recuperar = 0;
            uint id = arr[i];
            uint votes = participants[msg.sender].pVotes[id]; //numero de votos del participante en esa propuesta
            if(votes != 0){ //tiene votos en esa propuesta
                recuperar =  votes**2; // recuperamos el numero de tokens cuadratico a los votos
                tokens += recuperar;
                eth += recuperar * weiPrice; // ether recuperado por tokens con el precio de cada token

                proposals[id].votes -= votes;
                proposals[id].nTokens -= recuperar;

                delete participants[msg.sender].pVotes[id]; //eliminamos la participacion del participante en esa propuesta
            }
        }
    }

    function removeParticipant() external existParticipant{ //eliminamos a un participante
        uint eth;
        uint tokens;
        uint fEth;
        uint fTokens;

        nParticipants--;
        participants[msg.sender].exist = false;
        
        (fEth, fTokens) = removeParticipantNotApprovedProposals(financingProposalsPend);// rliminamos y recuperamos tokens y eth de todas las propuestas financing pending 
        (eth, tokens) = removeParticipantNotApprovedProposals(signalingProposals); // rliminamos y recuperamos tokens y eth de todas las propuestas signaling pending

        delete participants[msg.sender]; //eliminamos al participante

        eth += fEth;
        tokens += fTokens;

        if(tokens != 0){
            gestorToken.deleteTokens(address(this), tokens); // si ha recuperado algun token se eliminan
        }        
        if(eth != 0){
            payable(msg.sender).transfer(eth); // si ha recuperado eth se devuelve
        }


    }

    function addProposal(string memory pName, string memory pDesc, uint pBudget , address pRec) external votingIsOpen existParticipant returns(uint Id){ // creamos nueva propuesta
        require(pBudget >= 0, "budget must be positive");
        require(pRec != address(0), "receptor address can not be zero");

        bool isNewAddr = true;

        for(uint i = 0; i < nProposals; i++){ // OJO Miguel
            if(address(proposals[Id].addr) == pRec){ // recorremos las propuestas a ver si alguna ya tiene el address que recibira el budget de la propuesta
                isNewAddr = false; // si lo encuentra fallara ya que debe ser nueva la propuesta
                break;
            }
        }

        require(isNewAddr, "This proposal exists");

        Id = nProposals;
        nProposals++;
        proposals[Id] = Proposal({name:pName, desc:pDesc, budget:pBudget, owner:msg.sender, votes:0,nTokens:0, accepted:false, cancel:false, threshold:0, nParts:0, parts: new address[](0), addr:IExecutableProposal(pRec)});
        //creamos la propuesta
        if(proposals[Id].budget == 0){ 
            signalingProposals.push(Id); // si es signaling la añadimos a array de signaling
        }
        else {
            financingProposalsPend.push(Id);// si es financing la añadimos a array de financing
        }
    }

    function delPropArray(uint pId, uint[] storage arr) private { // eliminamos una propuesta de alguno de los arrays
        uint i = 0;
        bool found = false;
        uint length = arr.length;
        
        for(i; i < length && !found; i++){
            if(arr[i] == pId){
                found = true; //encontramos la propuesta en el array
            }
        }
        i--;
        if(found){// lo paso a ultima posicion y ultimo a su posicion y hago pop
            for (i; i < length - 1; i++){
                arr[i] = arr[i + 1];
            }
            delete arr[length - 1];
            arr.pop();
        }
    }

    function returnTokensProposal(uint pId) private { //devolvemos los tokens de las propuestas asus participantes
        uint length = proposals[pId].parts.length;

        for(uint i = 0; i < length; i++){
            address part = proposals[pId].parts[i]; // participante que pertenece a la propuesta
            uint votes = participants[part].pVotes[pId]; // votos de ese participante a la propuesta
            if(votes != 0){
                uint recuperar = votes**2; // al cuadrado directamente porque devuelve todos
                participants[part].nTokens += recuperar;
                gestorToken.transfer(part, recuperar);
                delete proposals[pId].parts[i]; // eliminamos al participante de la propuesta
                delete participants[part].pVotes[pId]; // quitamos los votos a esa propuesta del participante
            }
        }
    }

    function cancelProposal(uint pId) external votingIsOpen proposalExist(pId) propOwner(pId) notAceptedProposal(pId) { // cancelamos la propuesta
        
        proposals[pId].cancel = true;

        returnTokensProposal(pId); // devolvemos los tokens de la propuesta

        if(proposals[pId].budget == 0){
            delPropArray(pId, signalingProposals); // la eliminamos del array en el que se encuentre
        }
        else{
            delPropArray(pId, financingProposalsPend);
        }
    }

    function buyTokens() external payable existParticipant enoughMoneyToBuy { //compramos mas tokens
        uint nTokens = msg.value/weiPrice;
        gestorToken.newTokens(msg.sender, nTokens); // no hace falta comprobar maxTokens ya que se comprueba en funcion newTokens en MyERC20
        participants[msg.sender].nTokens += nTokens;
    }

    function sellTokens() external existParticipant { //vendemos tokens restantes
        uint balance = gestorToken.balanceOf(msg.sender); //tokens que tiene el participante
        require(balance > 0, "tokens must be bigger than zero"); // debe tener al menos 1 token
        gestorToken.deleteTokens(msg.sender, balance); // los elimina
        participants[msg.sender].nTokens -= balance; 
        uint recuperarETH = balance * weiPrice; 
        require(address(this).balance >= recuperarETH, "Not enough ether to sell tokens.");
        payable(msg.sender).transfer(recuperarETH); //recupera el eth

    }

    function getERC20() external view returns (address){ //devuelve el ERC20 creado en el constructor
        return address(gestorToken);
    }

    function getPendingProposals() public view votingIsOpen returns(uint[] memory pending){ // devuelve array de propuestas pendientes financing
        return financingProposalsPend;
    }

    function getApprovedProposals() public view votingIsOpen returns(uint[] memory pending){ // // devuelve array de propuestas aprobadas
        return approvedProposals;
    }
    
    function getSignalingProposals() public view votingIsOpen returns (uint[] memory pending){ // devuelve array de propuestas pendientes signaling
        return signalingProposals;        
    }

    function getProposalInfo(uint id) external view votingIsOpen proposalExist(id) returns (string memory, string memory){ //TODO PROBAR deuvelve nombre y descripcion
        return (proposals[id].name, proposals[id].desc);
    }


    // a MISMA PROPUESTA: primer voto  1 token segundo voto 4 tercer voto 9...
    // a distintas propuestas cada voto a cada propuesta 1 token 
    function stake(uint pId, uint votes) external existParticipant votingIsOpen notAceptedProposal(pId) proposalExist(pId) positiveVotesNotZero(votes) { // proceso de votacion
        uint gasto = votes; // gasto de tokens para votar
        uint voted = participants[msg.sender].pVotes[pId]; //votos ya realizados en esta votacion
        
        if(votes > 1 || voted > 1) gasto = (votes + voted)**2 - voted**2; //gasto cuadratico

        require(gestorToken.checkApprovement(msg.sender, address(this), gasto), "Not enough tokens approved"); // comprobamos si hay suficientes tokens aprobados
        
        gestorToken.transferFrom(msg.sender, address(this), gasto); // transferimos los tokens al contrato de votacion cuadratica
        proposals[pId].votes += votes;
        proposals[pId].nTokens += gasto;
        participants[msg.sender].nTokens -= gasto; // gasto los tokens
        participants[msg.sender].pVotes[pId] += votes; // cuantos votos tengo en esa propuesta

        if(voted == 0){ // si es la primera vez que vota en esta propuesta añadimos al participante
            proposals[pId].nParts++;
            proposals[pId].parts.push(msg.sender);
        }

        // hago que 0,2 + (budget[i] / totalBudget)
        // pase a (0,2*totalBudget + budget[i]) / totalBudget
        // finalmente multiplico por 5 para evitar que de 0 por la division
        // (totalBudget + 5*budget[i]) / 5*totalBudget
        // realizamos el producto antes de la division para que el resultado no sea 0

        proposals[pId].threshold = ((totalBudget + 5*proposals[pId].budget) *nParticipants) / (5*totalBudget) + financingProposalsPend.length; // actualizo el umbral ya que recibe votos

        if(proposals[pId].budget != 0) {
            _checkAndExecuteProposal(pId); // si es financing miro si puede ejecutarse y aprobarse al votar
        }
        
    }

    function withdrawFromProposal(uint votes, uint pId) external notAceptedProposal(pId) proposalExist(pId) positiveVotesNotZero(votes) enoughVotes(votes,pId){

        uint recuperar = votes;
        uint votosP = participants[msg.sender].pVotes[pId];

        if(votosP > 1) {
            uint res = votosP - votes;
            recuperar = votosP**2 - res**2;
        }

        gestorToken.transfer(msg.sender, recuperar);

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

        proposals[pId].votes -= votes;
        proposals[pId].nTokens -= recuperar;
        participants[msg.sender].pVotes[pId] -= votes;
        participants[msg.sender].nTokens += recuperar;

        if(proposals[pId].budget != 0){
            _checkAndExecuteProposal(pId); // si es financing miro si puede ejecutarse y aprobarse al votar
        }

    }

    function _checkAndExecuteProposal(uint pId) internal proposalExist(pId) notAceptedProposal(pId) isFinancingProp(pId) {

        if((address(this).balance >= proposals[pId].budget) && (proposals[pId].votes > proposals[pId].threshold)){ // supera el umbral y hay suficiente presupuesto
            delPropArray(pId, financingProposalsPend); // se elimina de pending
            approvedProposals.push(pId); // se añade en aprobadas

            totalBudget = totalBudget - proposals[pId].budget + (weiPrice*proposals[pId].nTokens); // actualizamos presupuesto total
            gestorToken.deleteTokens(address(this), proposals[pId].nTokens); // eliminamos los tokens consumidos

            require(address(this).balance >= proposals[pId].budget, "Not enough budget");
            (IExecutableProposal(proposals[pId].addr)).executeProposal{value: proposals[pId].budget, gas: 100000}(pId, proposals[pId].votes, proposals[pId].nTokens); // se ejecuta la propuesta

            proposals[pId].accepted = true; // se aprueba
        }

    }

    function closeVoting() external onlyOwner { //se cierra la votacion
        open = false;

        uint length = signalingProposals.length;

        for(uint i = 0; i < length; i++){ // se recorre el array de signaling, se devuelven los tokens, se aprueban y se ejecutan
            uint pId = signalingProposals[i];
            proposals[pId].accepted = true;
            returnTokensProposal(pId); // devolvemos los tokens usados en la propuesta signalinf
            (IExecutableProposal(proposals[pId].addr)).executeProposal(pId, proposals[pId].votes, proposals[pId].nTokens);
        }
        
        length = financingProposalsPend.length;

        for(uint i = 0; i < length; i++){ // se recorren las financing y se decuelcen los tokens de las no aprobadas
            uint pId = financingProposalsPend[i];
            returnTokensProposal(pId); // devolvemos los tokens utilizados en la propuesta financing
        }

        delete signalingProposals;
        delete financingProposalsPend;
        delete approvedProposals;

        if(totalBudget > 0) { // si sobra presupuesto se le devuelve al owner
            owner.transfer(totalBudget);
            delete totalBudget;
        }

        for(uint i = 0; i < nProposals; i++){ // vaciamos el mapa de proposals
            delete proposals[i];
        }

        nProposals = 0; // al cerrar la votacion se vuelve a empezar de 0 el id de las proposals
 
    }
}

contract myERC20 is ERC20 {

    address private owner;
    uint maxTokens;

    constructor(uint _tMax) ERC20("token", "tok") {
        require(_tMax > 0, "Provided max number of tokens == 0, invalid.");
        maxTokens = _tMax;
        owner = msg.sender;
    }

    //--------------------------------------- MODIFIERS --------------------------------------

    modifier onlyOwner {
        require(msg.sender == owner, "Must be the Owner of myERC20");
        _;
    }

    modifier oneOrMoreTokens(uint nTokens) {
        require(nTokens > 0, "nTokens to create must be bigger than zero");
        _;
    }

    modifier OwnerOrTokenOwner(address tkOwner) {
        require((msg.sender == tkOwner) || (msg.sender == owner), "Must be the token Owner or the Owner of myERC20");
        _;

    }


    // -------------------------------------- FUNCIONES --------------------------------------

    function newTokens(address account, uint nTokens) external onlyOwner oneOrMoreTokens(nTokens){ // crea nuevos tokens
        require(nTokens + totalSupply() <= maxTokens, "You can not create this tokens, you are exceeding maxTokens"); //OJO vulnerabilidad TODO
        _mint(account, nTokens);
    }

    function deleteTokens(address account, uint nTokens) external oneOrMoreTokens(nTokens) { // elimina una cantidad de tokens
        require(totalSupply() >= nTokens, "Not enough tokens to delete");
        _burn(account, nTokens);
    }

    function deleteAllTokens(address account) external { // elimina todos los tokens de una cuenta
        uint balance = balanceOf(account);
        require(balance > 0, "You do not have balance to eliminate tokens");
        _burn(account, balance);
    }

    function checkApprovement(address from, address to, uint nTokens) external view returns (bool){ // comprueba si hay suficientes tokens aprobados
        return allowance(from, to) >= nTokens;
    }

}