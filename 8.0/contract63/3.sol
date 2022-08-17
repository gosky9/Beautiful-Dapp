// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract ValueType {
    bool public b = true;
    uint256 public u = 123;
    int256 public i = -123;
    int256 public minInt = type(int256).min; //-2**255
    int256 public maxInt = type(int256).max; //2**255-1
    address public addr = address(0);
    // byte32s public b32 = 0x544564564564fsd454fdsa56fd1as5;
}
