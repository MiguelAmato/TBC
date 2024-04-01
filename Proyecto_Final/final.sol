// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract QuadraticVoting {

    myERC20 private gestorToken;

    address payable owner;

    uint private weiPrice;
    uint private nMaxTokens;
    uint private totalBudget;

    mapping (address => bool) participants;

    constructor(uint _weiPrice, uint _nMaxTokens) {
        gestorToken = new myERC20("token", "tok");
        weiPrice = _weiPrice;
        nMaxTokens = _nMaxTokens;
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

    // ===================================== FUNCIONES =====================================

    function openVoting(uint initBudget) public onlyOwner {
        require(initBudget >= 0, "Budget must be a positive number");
        totalBudget = initBudget;
    }

    function addParticipant() external payable positiveValue {
        require(participants[msg.sender] == true, "addParticipant");
        require(msg.value >= weiPrice, "Not enough money");
        participants[msg.sender] = true;
        uint value = msg.value;
        while (value >= weiPrice) {
            gestorToken.newToken(msg.sender, weiPrice);
            value -= weiPrice;
        }
    }

}

contract myERC20 is ERC20 {
    constructor(string memory name, string memory symb) ERC20(name, symb) {}

    function newToken(address account, uint value) external {
        _mint(account, value);
    }
}