// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7.0 < 0.8.0;

contract PiggyMapping2 {

    struct Client {
        string _name;
        uint _amount;
    }

    mapping (address => Client) public clients;

    address[] public adds;

    function addClient(string memory name) external payable {
        require(bytes(name).length > 0 , "empty name");
        require(bytes(clients[msg.sender]._name).length == 0, "client already exists");
        clients[msg.sender] = Client({ _name : name, _amount : msg.value });
        adds.push(msg.sender);
    }

    function deposit() external payable {
        require(bytes(clients[msg.sender]._name).length > 0, "address not found");
        clients[msg.sender]._amount += msg.value;
    }

    function withdraw(uint amountInWei) external {
        require(bytes(clients[msg.sender]._name).length > 0, "address not found");
        require(amountInWei <= clients[msg.sender]._amount, "not enough money in your account");
        clients[msg.sender]._amount -= amountInWei;
        payable(msg.sender).transfer(amountInWei);
    }

    function getBalance() external view returns (uint) {
        require(bytes(clients[msg.sender]._name).length > 0, "address not found");
        return clients[msg.sender]._amount;
    }

    function checkBalances() external view returns (bool) {
        uint sum = 0;
        for (uint i = 0; i < adds.length; ++i)
            sum += clients[adds[i]]._amount;
        return (sum == (address(this).balance));
    }

}