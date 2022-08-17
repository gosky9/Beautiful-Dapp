// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Kill {
    // 合约可以接受主币
    constructor() payable {}

    // 可以强制发送主币
    function kill(address _addr) external {
        selfdestruct(payable(_addr));
    }

    // 测试函数，是否自毁成功
    function testCall() external pure returns (uint256) {
        return 123;
    }
}
