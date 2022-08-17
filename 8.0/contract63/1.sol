// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// safe math
contract SafeMath {
    function testUnderflow() public pure returns (uint256) {
        uint256 x = 0;
        x--;
        return x;
    }

    function testUncheckedUnderflow() public pure returns (uint256) {
        uint256 x = 0;
        unchecked {
            x--;
        }
        return x;
    }
}
