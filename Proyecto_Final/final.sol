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

    address payable owner;

    uint private weiPrice;
    uint private nMaxTokens;
    uint private totalBudget;
    uint private nProposals;

    bool open;

    mapping (address => bool) participants;
    mapping (uint => Proposal) proposals; // (ptoposalId -> Proposal)

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
        require(participants[msg.sender] == true, "must exist the participant");
        _;
    }

    // ===================================== FUNCIONES =====================================

    function openVoting(uint initBudget) public onlyOwner {
        require(initBudget >= 0, "Budget must be a positive number");
        totalBudget = initBudget;
        open = true;
    }

    function addParticipant() external payable positiveValue {
        require(participants[msg.sender] == true, "addParticipant");
        require(msg.value >= weiPrice, "Not enough money");
        participants[msg.sender] = true;
        uint value = msg.value;
        if (value >= weiPrice) {
            gestorToken.newToken(msg.sender, weiPrice);
            value -= weiPrice;
        }
    }

    function removeParticipant() external payable existParticipant{
        
        //participants[msg.sender] = false;
        uint value = msg.value;
        //he intentado devolverle el dinero que tenia al borrarse pero no se si es asi
        // o lo ponemos como false para que no pueda actuar pero complicaría el addParticipant habría que ver si esta en false o no existe
        payable(msg.sender).transfer(value);
        delete(participants[msg.sender]);
    }

    function addProposal(string memory pName, string memory pDesc, uint pBudget , address pRec) external votingIsOpen returns(uint Id){
        require(pBudget >= 0, "budget must be positive");
        require(pRec != address(0), "receptor address can not be zero");
        Id = nProposals;
        nProposals++;

        proposals[Id] = Proposal({name: pName, desc: pDesc, budget: pBudget, rec:pRec, accepted:false});

        emit ProposalCreated(Id, pName); // no se si hay que hacerlos
    }

    function cancelProposal(uint pId) external votingIsOpen propOwner(pId){
        nProposals--;
        delete(proposals[pId]);

        emit ProposalCanceled(pId); // no se si hay que hacerlos
    }

    function buyTokens(uint n) external payable existParticipant{
        uint value = msg.value;

        for(uint i = 0; i < n && value >= weiPrice; i++){
            gestorToken.newToken(msg.sender, weiPrice);
            value -= weiPrice;
        }

    }

    function sellTokens() external payable existParticipant{
        //gestorToken.Transfer(from, to, value); No se como devolver el token
        payable(msg.sender).transfer(weiPrice);

    }


}

contract myERC20 is ERC20 {
    constructor(string memory name, string memory symb) ERC20(name, symb) {}

    function newToken(address account, uint value) external {
        _mint(account, value);
    }
}