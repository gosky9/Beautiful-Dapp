// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract PiggyBank {
    event Withdraw(uint256 amount);
    address public owner = msg.sender;

    // constructor() {
    //     owner = msg.sender;
    // }

    receive() external payable {}

    function withdraw() external {
        require(msg.sender == owner);
        emit Withdraw(address(this).balance);
        selfdestruct(payable(msg.sender));
    }
}
