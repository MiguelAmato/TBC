// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7.0 < 0.8.0;

contract piggyBank0 {

    event Print(string message);

    function deposit() external payable {}

    function withdraw(uint amountInWei) external {
        if (address(this).balance > amountInWei) 
            payable(msg.sender).transfer(amountInWei);
        else 
            emit Print("not enough money in your account");
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

}
