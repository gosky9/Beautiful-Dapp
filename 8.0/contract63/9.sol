// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract Counter {
    uint256 public count;

    function inc() external returns (uint256) {
        count += 1;
        return count;
    }
}
