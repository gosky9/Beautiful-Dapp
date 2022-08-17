// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Fallback {
    //  Which function is called, fallback() or receive()?

    //            send Ether
    //                |
    //          msg.data is empty?
    //               / \
    //             yes  no
    //             /     \
    // receive() exists?  fallback()
    //          /   \
    //         yes   no
    //         /      \
    //     receive()   fallback()
    //     */

    event Log(string func, address sender, uint256 value, bytes data);

    //能够接受直接发送的eth
    fallback() external payable {
        emit Log("fallback", msg.sender, msg.value, msg.data);
    }

    // 必须加payable.
    receive() external payable {
        emit Log("receive", msg.sender, msg.value, "");
    }
}
