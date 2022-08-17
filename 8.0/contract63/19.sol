// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract Array {
    uint256[] public nums = [1, 2, 3];
    uint256[3] public numsFixed = [4, 5, 6];

    function foo() external {
        nums.push(4);
        uint256 x = nums[1];
        nums[0] = 777;
        delete nums[1]; //修改为0，不会改变数组长度
        nums.pop(); //弹出，改变长度
        uint256 len = nums.length;

        uint256[] memory a = new uint256[](5); //内存中不能是动态数组，不能pop,push,因为这俩会改变长度
        a[1] = 123; //可以赋值
    }

    function returnArray() external view returns (uint256[] memory) {
        return nums;
    }

// 删除1
    function removeArray(uint256 _index) public {
        // 删除中间的，右侧的移动过来
        require(_index < arr.length, "index out of bound");

        for (uint256 i = _index; i < arr.length - 1; i++) {
            arr[i] = arr[i + 1];
        }
        arr.pop();
    }

    function text() external {
        uint256[] public arr1 = [1, 2, 3];
        removeArray(2);
        assert(arr[0]==1); 
        assert(arr1.length == 2);


    }

    // 删除2，最后一个元素和这个元素替换掉，然后pop
}
