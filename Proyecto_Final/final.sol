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

    modifier votingIsClose {
        require(open == false, "Voting is open");
        _;
    }

    modifier propOwner(uint pId) {
        require(proposals[pId].owner == msg.sender, "Must be de owner of the proposal");
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
        require(!proposals[pId].accepted, "You can not interactuate with an acepted proposal");
        _;
    }

    modifier isFinancingProp(uint pId) {
        require(proposals[pId].budget > 0, "Must be a financing proposal to be accepted and executed");
        _;
    }

    modifier notRegisteredPart() {
        require(participants[msg.sender].nTokens == 0, "this account already exist");
        _;
    }

    modifier enoughMoneyToBuy() {
        require(msg.value >= weiPrice, "Not enough money");
        require(msg.value % weiPrice == 0, "Must be enough money to buy an exact number of tokens");
        _;
    }

    // ===================================== GETTERS PRUEBAS ============================

    function getProposalAccepted(uint pId) external view returns (bool){
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
    }


    // ===================================== FUNCIONES =====================================

    function openVoting() external payable onlyOwner votingIsClose {
        require(msg.value > 0, "Budget must be a positive number");
        totalBudget = msg.value;
        open = true;
    }

    function addParticipant() external payable  notRegisteredPart positiveValue enoughMoneyToBuy {
        uint tokens = msg.value / weiPrice;
        participants[msg.sender].nTokens = tokens;
        nParticipants++;
        gestorToken.newTokens(msg.sender, tokens);

    }

    function removeParticipantNotApprovedProposals(uint[] storage arr) private returns(uint eth, uint tokens){
        uint length = arr.length;
        uint recuperar = 0;

        for(uint i = 0; i < length; i++){
            uint id = arr[i];
            uint votes = participants[msg.sender].pVotes[id];
            if(votes != 0){ //tiene votos en esa propuesta
                recuperar =  votes**2;
                tokens += recuperar;
                eth += recuperar * weiPrice;

                proposals[id].votes -= votes;
                proposals[id].nTokens -= recuperar;

                delete participants[msg.sender].pVotes[id];
            }
        }
    }

    function removeParticipant() external payable existParticipant{
        uint eth;
        uint tokens;
        uint fEth;
        uint fTokens;

        nParticipants--;
        delete(participants[msg.sender]);
        
        (fEth, fTokens) = removeParticipantNotApprovedProposals(financingProposalsPend);
        (eth, tokens) = removeParticipantNotApprovedProposals(signalingProposals);

        delete participants[msg.sender];

        eth += fEth;
        tokens += fTokens;

        if(tokens != 0){
            gestorToken.deleteTokens(address(this), tokens);
        }        
        if(eth != 0){
            payable(msg.sender).transfer(eth);
        }


    }

    function addProposal(string memory pName, string memory pDesc, uint pBudget , address pRec) external votingIsOpen existParticipant returns(uint Id){
        require(pBudget >= 0, "budget must be positive");
        require(pRec != address(0), "receptor address can not be zero");

        bool isNewAddr = true;

        for(uint i = 0; i < nProposals; i++){
            if(address(proposals[Id].owner) == pRec){
                isNewAddr = false;
                break;
            }
        }

        require(isNewAddr, "This proposal exists");

        Id = nProposals;
        nProposals++;
        proposals[Id] = Proposal({name:pName, desc:pDesc, budget:pBudget, owner:msg.sender, votes:0,nTokens:0, accepted:false, cancel:false, threshold:0, nParts:0, parts: new address[](0), addr:IExecutableProposal(pRec)});

        if(proposals[Id].budget == 0){
            signalingProposals.push(Id);
        }
        else {
            financingProposalsPend.push(Id);
        }
    }

    function delPropArray(uint pId, uint[] storage arr) private {
        uint i = 0;
        bool found = false;
        uint length = arr.length;
        
        for(i; i < length && !found; i++){
            if(arr[i] == pId){
                found = true;
            }
        }
        if(found){// lo paso a ultima posicion y ultimo a su posicion y hago pop
            for (i; i < length - 1; i++){
                arr[i] = arr[i + 1];
            }
            delete arr[length - 1];
            arr.pop();
        }
    }

    function returnTokensProposal(uint pId) private {
        uint length = proposals[pId].parts.length;

        for(uint i = 0; i < length; i++){
            address part = proposals[pId].parts[i];
            uint votes = participants[part].pVotes[pId];
            if(votes != 0){
                uint recuperar = votes**2; // al cuadrado directamente porque devuelve todos
                participants[part].nTokens += recuperar;
                gestorToken.transfer(part, recuperar);
                delete proposals[pId].parts[i];
                delete participants[part].pVotes[pId];
            }
        }
    }

    function cancelProposal(uint pId) external votingIsOpen proposalExist(pId) propOwner(pId) notAceptedProposal(pId) {
        
        proposals[pId].cancel = true;

        returnTokensProposal(pId);

        if(proposals[pId].budget == 0){
            delPropArray(pId, signalingProposals);
        }
        else{
             delPropArray(pId, financingProposalsPend);
        }
    }

    function buyTokens() external payable existParticipant enoughMoneyToBuy {
        uint nTokens = msg.value/weiPrice;
        gestorToken.newTokens(msg.sender, nTokens); // no hace falta comprobar maxTokens ya que se comprueba en funcion newTokens en MyERC20
        participants[msg.sender].nTokens += nTokens;

    }

    function sellTokens() external existParticipant {
        uint balance = gestorToken.balanceOf(msg.sender);
        participants[msg.sender].nTokens -= balance; 
        gestorToken.deleteTokens(msg.sender, balance);
        uint recuperarETH = balance * weiPrice; 
        require(address(this).balance >= recuperarETH, "Not enough ether to sell tokens.");
        payable(msg.sender).transfer(recuperarETH);

    }

    function getERC20() external view returns (address){
        return address(gestorToken);
    }

    function getPendingProposals() public view votingIsOpen returns(uint[] memory pending){
        return financingProposalsPend;
    }

    function getApprovedProposals() public view votingIsOpen returns(uint[] memory pending){
        return approvedProposals;
    }
    
    function getSignalingProposals() public view votingIsOpen returns (uint[] memory pending){
        return signalingProposals;        
    }

    function getProposalInfo(uint id) external view votingIsOpen proposalExist(id) returns (string memory, string memory){ //TODO PROBAR
        return (proposals[id].name, proposals[id].desc);
    }


    // a MISMA PROPUESTA: primer voto  1 token segundo voto 4 tercer voto 9...
    // a distintas propuestas cada voto a cada propuesta 1 token 
    function stake(uint pId, uint votes) external existParticipant votingIsOpen notAceptedProposal(pId) proposalExist(pId) positiveVotesNotZero(votes) {
        uint gasto = votes;
        uint voted = participants[msg.sender].pVotes[pId];
        
        if(votes > 1 || voted > 1) gasto = (votes + voted)**2; //para que no te deje en distintas veces votar si no tienes suficiente

        //require(participants[msg.sender].nTokens >= gasto, "Not enough tokens to vote this proposal");
        // la debe realizar el participante con el contrato ERC20 antes de ejecutar esta funcion;
        // el contrato ERC20 se puede obtener con getERC20). 
        require(gestorToken.checkApprovement(msg.sender, address(this), gasto), "Not enough tokens approved");
        
        gestorToken.transferFrom(msg.sender, address(this), gasto);
        proposals[pId].votes += votes;
        proposals[pId].nTokens += gasto;
        participants[msg.sender].nTokens -= gasto; // gasto los tokens
        participants[msg.sender].pVotes[pId] += votes; // cuantos votos tengo en esa propuesta

        if(voted == 0){
            proposals[pId].nParts++;
            proposals[pId].parts.push(msg.sender);
        }

        // hago que 0,2 + (budget[i] / totalBudget)
        // pase a (0,2*totalBudget + budget[i]) / totalBudget
        // finalmente multiplico por 10 para evitar que de 0 por la division
        // (2*totalBudget + 10*budget[i]) / 10*totalBudget
        // realizamos el producto antes de la division para que el resultado no sea 0

        proposals[pId].threshold = ((totalBudget + 5*proposals[pId].budget) *nParticipants) / (5*totalBudget) + financingProposalsPend.length; // actualizo el umbral ya que recibe votos

        if(proposals[pId].budget != 0) {
            _checkAndExecuteProposal(pId);
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
            _checkAndExecuteProposal(pId);
        }

    }

    function _checkAndExecuteProposal(uint pId) internal proposalExist(pId) notAceptedProposal(pId) isFinancingProp(pId) {

        if((address(this).balance >= proposals[pId].budget) && (proposals[pId].votes > proposals[pId].threshold)){
            delPropArray(pId, financingProposalsPend);
            approvedProposals.push(pId);

            totalBudget = totalBudget - proposals[pId].budget + (weiPrice*proposals[pId].nTokens);
            gestorToken.deleteTokens(address(this), proposals[pId].nTokens);

            require(address(this).balance >= proposals[pId].budget, "Not enough wei");
            (IExecutableProposal(proposals[pId].addr)).executeProposal{value: proposals[pId].budget, gas: 100000}(pId, proposals[pId].votes, proposals[pId].nTokens);

            proposals[pId].accepted = true;
        }

    }

    function closeVoting() external onlyOwner { //falta por hacer
        open = false;

        uint length = signalingProposals.length;

        for(uint i = 0; i < length; i++){
            uint pId = signalingProposals[i];
            proposals[pId].accepted = true;
            returnTokensProposal(pId);
            (IExecutableProposal(proposals[pId].addr)).executeProposal(pId, proposals[pId].votes, proposals[pId].nTokens);
        }
        
        length = financingProposalsPend.length;

        for(uint i = 0; i < length; i++){
            uint pId = financingProposalsPend[i];
            returnTokensProposal(pId);
        }

        delete signalingProposals;
        delete financingProposalsPend;
        delete approvedProposals;

        if(totalBudget > 0) {
            owner.transfer(totalBudget);
            delete totalBudget;
        }
 
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

    function newTokens(address account, uint nTokens) external onlyOwner oneOrMoreTokens(nTokens){
        require(nTokens + totalSupply() <= maxTokens, "You can not create this tokens, you are exceeding maxTokens");
        _mint(account, nTokens);
    }

    function deleteTokens(address account, uint nTokens) external oneOrMoreTokens(nTokens) {
        require(totalSupply() >= nTokens, "Not enough tokens to delete");
        _burn(account, nTokens);
    }

    function deleteAllTokens(address account) external {
        uint balance = balanceOf(account);
        require(balance > 0, "You do not have balance to eliminate tokens");
        _burn(account, balance);
    }

    function checkApprovement(address from, address to, uint nTokens) external view returns (bool){
        return allowance(from, to) >= nTokens;
    }

}