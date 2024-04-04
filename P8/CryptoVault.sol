// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0; // Do not change the compiler version.

/*
 * VaultLib: Library contract used to handle the owner of CryptoVault 
 * contract and other utility functions.
 */
contract VaultLib {
    address public owner;

    // init is used to set the CryptoVault contract owner. It must be
    // called using delegatecall.
    function init(address _owner) public {
        owner = _owner;
    }

    // Standard response for any non-standard call to CryptoVault. 
    fallback () external payable {
        revert("Calling a non-existent function!");
    }

    // Standard response for plain transfers to CryptoVault. 
    receive () external payable {
        revert("This contract does not accept transfers with empty call data");
    }
}

/*
 * CryptoVault contract: A service for storing Ether.
 */
contract CryptoVault {
    address public owner;      // Contract owner.
    uint prcFee;               // Percentage to be subtracted from deposited
                               // amounts to charge fees.
    uint public collectedFees; // Amount of this contract balance that
                               // corresponds to fees.
    address tLib;              // Library used for handling ownership.
    mapping (address => uint256) public accounts;

    modifier onlyOwner() {
        require(msg.sender == owner,"You are not the contract owner!");
        _;
    }

    // Constructor sets the owner of this contract using a VaultLib
    // library contract, and an initial value for prcFee.
    constructor(address _vaultLib, uint _prcFee) public {
        tLib = _vaultLib;
        prcFee = _prcFee;
        (bool success,) = tLib.delegatecall(abi.encodeWithSignature("init(address)",msg.sender));
        require(success,"delegatecall failed");
    }

    // getBalance returns the balance of this contract. 
    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    // deposit allows clients to deposit amounts of Ether. A percentage
    // of the deposited amount is set aside as a fee for using this
    // vault. 
    function deposit() public payable{
        require (msg.value >= 100, "Insufficient deposit");
        uint fee = msg.value * prcFee / 100;
        accounts[msg.sender] += msg.value - fee;
        collectedFees += fee;
    }

    // withdraw allows clients to recover part of the amounts deposited
    // in this vault.
    function withdraw(uint _amount) public {
        require (accounts[msg.sender] - _amount >= 0, "Insufficient funds");
        accounts[msg.sender] -= _amount;
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send funds");
    }

    // withdrawAll is similar to withdraw, but withdrawing all Ether
    // deposited by a client.
    function withdrawAll() public {
        uint amount = accounts[msg.sender];
        require (amount > 0, "Insufficient funds");
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send funds");
        accounts[msg.sender] = 0;
    }

    // collectFees is used by the contract owner to transfer all fees
    // collected from clients so far.
    function collectFees() public onlyOwner {
        require (collectedFees > 0, "No fees collected");
        (bool sent, ) = owner.call{value: collectedFees}("");
        require(sent, "Failed to send fees");
        collectedFees = 0;
    }

    // Any other function call is redirected to VaultLib library
    // functions. 
    fallback () external payable {
        (bool success,) = tLib.delegatecall(msg.data);
        require(success,"delegatecall failed");
    }
    receive () external payable {
        (bool success,) = tLib.delegatecall(msg.data);
        require(success,"delegatecall failed");
    }
}

