// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7.0 < 0.8.0;

contract PiggyArray {

    struct Client {
        string _name;
        address _add;
        uint _amount;
    }

    Client[] public clients;

    function getAddress() internal view returns (uint) {
        uint i = 0;
        while (i < clients.length && msg.sender != clients[i]._add)
            ++i;
        return i;
    }

    function addClient(string memory name) external payable {
        require(bytes(name).length > 0 , "empty name");
        uint i = getAddress();
        require(i == clients.length, "client already exists");
        clients.push(Client({ _name : name, _add : msg.sender, _amount : msg.value }));
    }

    function deposit() external payable {
        uint i = getAddress();
        require(i != clients.length, "address not found");
        clients[i]._amount += msg.value;
    }

    function withdraw(uint amountInWei) external {
        uint i = getAddress();
        require(i != clients.length, "address not found");
        require(amountInWei <= clients[i]._amount, "not enough money in your account");
        clients[i]._amount -= amountInWei;
        payable(msg.sender).transfer(amountInWei);
    }

    function getBalance() external view returns (uint) {
        uint i = getAddress();
        require(i != clients.length, "address not found");
        return clients[i]._amount;
    }


}