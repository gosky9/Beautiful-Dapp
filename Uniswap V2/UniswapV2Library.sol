// https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
library UniswapV2Library {
    using SafeMath for uint256;

    ////两个token排序，address实际也是一个uint160，可以相互转换，所以可以比大小，排序,小是0，确认在交易对中的token0,token1
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }

    // 通过create2的方式计算交易对的地址，注意initCode,每次部署的时候，可能都不一样，需要生成
    //用法套格式即可，对应factory中的createPair， 要深入的，可以具体去了解下create2
    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex"ff",
                        factory,
                        keccak256(abi.encodePacked(token0, token1)),
                        hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                    )
                )
            )
        );
    }

    //获取两个币的储备量， 通过pair查询， 内部返回值会根据入参的币种进行调整位置返回
    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(
            pairFor(factory, tokenA, tokenB)
        ).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    // 添加流动性的时候，通过该方法查询输入A的数量，需要多少个B
    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        ////判断数量， 首次添加流动性，随意定价，不需要查询该方法
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        //B数量 = 预期输入A的数量 * B的储备量 / A的储备量；  //实际公式就是 A/B = reserveA/reserveB, 两个币的数量比例一致
        amountB = amountA.mul(reserveB) / reserveA;
    }

    //通过精确输入金额,输入币的储备量，输出币的储备量，计算输出币的最大输出量
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        //具体看下面的公式推导，要看该公式，首先要理解uniswap AMM, X * Y= K
        ////手续费都是扣输入额的千三，所以需要去掉千三后才是实际用于交易的金额
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut); //套下面公式理解
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
        /*
         *   查看下面的由in计算out公式 out = in * f * rOut / rIn + in *f
         *   手续费是千三， 扣除手续费后去交易的金额是输入额的0.997, 公式中的f是0.997 内部计算用的uint,所以分子分母都 * 1000
         *   最终的公式是    out = in * 997 * rOut / ((rIn + in *f) * 1000)
         *                  out = in * 997 * rOut / (rIn*1000 + in * 997)
         */
    }

    /**
    *
    *
    * 推导公式
    * in 输入金额， out 输出金额
    * rIn tokenIn的流动性， rOut，tokenOut的流动性
    * fee 手续费，注：当前带入0.997   也就是997/1000
    *
    * 两个计算公式实际是一样的， 只是一个求in,一个求out
    * (rIn + in * f) * (rOut - out) = rIn * rOut
    * (x+△x) * (y-△y) = x * y
    *
    * 由out计算in  getAmountIn
    *      (rIn + in * f) * (rOut - out) = rIn * rOut

    *      rIn * rOut + in * f * rOut  - rIn * out - in * f * out = rIn * rOut

    *      rIn * out = in * f * rOut - in * f * out

    *      in = rIn * out / (f * (rOut - out)) + 1  (尾部的 +1应该是避免精度计算，最后一位小了，会成交不了)
    *
    *
    * 由in计算out  getAmountOut 下面是公式转换过程，最终就简化成代码中的
    *      (rIn + in * f) * (rOut - out) = rIn * rOut

    *      rIn * rOut + in * f * rOut  - rIn * out - in * f * out = rIn * rOut

    *      in * f * rOut = rIn * out + in * f * out

    *      out = in * f * rOut / rIn + in * f
    *
    */
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        //先看上面的由out计算in 公式推导
        //对应公式中的rIn * out, 乘以1000是0.997需要换算成整数
        uint256 numerator = reserveIn.mul(amountOut).mul(1000);
        //对应上面的分母 (f * (rOut - out)),乘以1000后就是 997 * (rOut - out)
        uint256 denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // 根据path,计算出每个交易对的输入/输出量(如果path>2,前一个交易对的输出量，就是下一个交易对交易的输入量)
    //内部实际还是调用的上面getAmountOut方法， 返回值amounts长度和path的长度一致，
    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            //每两个token组成一个交易对，计算out
            (uint256 reserveIn, uint256 reserveOut) = getReserves(
                factory,
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // 根据path,计算出每个交易对的输入/输出量(如果path>2,前一个交易对的输出量，就是下一个交易对交易的输入量)
    //内部实际还是调用的上面getAmountIn方法， 返回值amounts长度和path的长度一致，
    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            //倒序遍历计算
            (uint256 reserveIn, uint256 reserveOut) = getReserves(
                factory,
                path[i - 1],
                path[i]
            );
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
