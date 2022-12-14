// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract ForAndWhileLoops {
    function loops() external pure {
        for (uint256 i = 0; i < 10; i++) {
            // code
            if (i == 3) {
                continue; //跳过本次循环
            }
            if (i == 5) {
                break; //跳出整个循环
            }
        }

        uint256 j = 0;
        while (j < 10) {
            j++;
        }
    }

    function sum(uint256 _n) external pure returns (uint256) {
        uint256 s;
        for (uint256 i = 1; i <= _n; i++) {
            s += i;
        }
        return s;
    }
}
