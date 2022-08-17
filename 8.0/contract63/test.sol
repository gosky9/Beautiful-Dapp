pragma solidity ^0.8.0;

contract Test {
    function test(uint256[20] calldata a) public pure returns (uint256) {
        return a[10] * 2;
    }

    function test2(uint256[20] calldata a) external pure returns (uint256) {
        return a[10] * 2;
    }
}
