// 这部分注释主要来自
// 1.33357  https://learnblockchain.cn/article/3581, https://learnblockchain.cn/article/3589
// 2.Dapp-Learning  https://github.com/Dapp-Learning-DAO/Dapp-Learning/blob/main/defi/Uniswap-V2/contract/UniswapV2Router02.md
pragma solidity =0.6.6;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./interfaces/IUniswapV2Router02.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";

contract UniswapV2Router02 is IUniswapV2Router02 {
    using SafeMath for uint256;

    address public immutable override factory; // 工厂地址，在core合约
    address public immutable override WETH; // WETH地址，符号ERC 20

    modifier ensure(uint256 deadline) {
        // 每笔交易有限制时间
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        // 只能接受WETH地址的转账？是transfer吗？
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired, // 期望添加 tokenA 的数量
        uint256 amountBDesired,
        uint256 amountAMin, // 添加 tokenA 的最小数量
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // 实际添加 tokenA 的数量, // 实际添加 tokenB 的数量
        // tokenA 和 tokenB 很好理解，但是为什么要有 amountADesired、amountADesired、amountAMin、amountBMin 呢？实际上因为用户在区块链上添加流动性并不是实时完成的，因此会因为其他用户的操作产生数据偏差，因此需要在这里指定一个为 tokenA 和 tokenB 添加流动性的数值范围。在添加流动性的过程中，首先会根据 amountADesired 计算出实际要添加的 amountB，如果 amountB 大于 amountBDesired 就换成根据 amountBDesired 计算出实际要添加的 amountA。
        // create the pair if it doesn't exist yet// 如果 tokenA,tokenB 的流动池不存在，就创建流动池
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(
            factory,
            tokenA,
            tokenB
        ); // 获取 tokenA,tokenB 的目前库存数量
        if (reserveA == 0 && reserveB == 0) {
            // 如果库存数量为0，也就是新建 tokenA,tokenB 的流动池，那么实际添加的amountA, amountB 就是 amountADesired 和 amountBDesired
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // amountADesired*reserveB/reserveA，算出实际要添加的 tokenB 数量 amountBOptimal.即aB = aA*reserveB/reserveA
            uint256 amountBOptimal = UniswapV2Library.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                // 如果 amountBMin <= amountBOptimal <= amountBDesired，amountA 和 amountB 就是 amountADesired 和 amountBOptimal
                require(
                    amountBOptimal >= amountBMin,
                    "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                // amountAOptimal = amountBDesired*reserveA/reserveB，算出实际要添加的 tokenA 数量 amountAOptimal
                uint256 amountAOptimal = UniswapV2Library.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                // 如果 amountAMin <= amountAOptimal <= amountADesired，amountA 和 amountB 就是 amountAOptimal 和 amountBDesired
                assert(amountAOptimal <= amountADesired); // 为什么这里用assert 而下面用 require?
                require(
                    amountAOptimal >= amountAMin,
                    "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA, // 添加流动性 tokenA 的地址
        address tokenB,
        uint256 amountADesired, // 期望添加 tokenA 的数量
        uint256 amountBDesired,
        uint256 amountAMin, // 添加 tokenA 的最小数量
        uint256 amountBMin,
        address to, // 获得的 LP 发送到的地址,一般是添加人。设置 to 实际上方便了第三方合约添加流动性，这为后来聚合交易所的出现，埋下了伏笔。
        uint256 deadline // 交易过期时间
    )
        external
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        // 实际添加 tokenA 的数量，获得 LP 的数量
        // ensure(deadline) 检查交易是否过期
        // 相比于内部函数 _addLiquidity，addLiquidity 函数的入参多了 to 和 deadline，to 可以指定 LP（流动性凭证）发送到哪个地址，而 deadline 则设置交易过期时间。出参则多了一个 liquidity，指 LP 的数量。
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        ); // 计算实际添加的 amountA, amountB
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB); // 获取 tokenA, tokenB 的流动池地址
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA); // 用户向流动池发送数量为 amountA 的 tokenA，amountB 的 tokenB
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to); // 流动池pair？？向 to 地址mint数量为 liquidity 的 LP
    }

    function addLiquidityETH(
        // 相比于addLiquidity，addLiquidityETH 函数的不同之处在于使用了 ETH 作为 tokenB，
        // 因此不需要指定 tokenB 的地址和期望数量，因为 tokenB 的地址就是 WETH 的地址，tokenB 的期望数量就是用户发送的 ETH 数量。但这样也多了将 ETH 换成 WETH，并向用户返还多余 ETH 的操作。
        address token,
        uint256 amountTokenDesired, // 期望添加 tokenA 的数量
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        (amountToken, amountETH) = _addLiquidity( // 计算实际添加的 amountToken, amountETH
            token, // address token A
            WETH, // address token WETH
            amountTokenDesired, // 期望添加 tokenA 的数量
            msg.value, //  期望添加 WETH 的数量,
            amountTokenMin, // 添加 tokenA 的最小数量
            amountETHMin // 添加 WETH 的最小数量
        );
        address pair = UniswapV2Library.pairFor(factory, token, WETH); // 获取 token, WETH 的流动池地址
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken); // 从用户向流动池发送数量为 amountToken 的 tokenA
        IWETH(WETH).deposit{value: amountETH}(); // Router将用户发送的 ETH 置换成 WETH
        assert(IWETH(WETH).transfer(pair, amountETH)); // Router向流动池pair发送数量为 amountETH 的 WETH
        liquidity = IUniswapV2Pair(pair).mint(to); // 流动池向 to 地址发送数量为 liquidity 的 LP
        // refund dust eth, if any // 如果用户发送的 ETH > amountETH，Router就向用户返还多余的 ETH
        if (msg.value > amountETH)
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    } // 由于 ETH 本身不是 ERC20 标准的代币，因此在涉及添加 ETH 流动性的操作时要把它换成兼容 ERC20 接口 WETH。

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity, // 销毁 LP 的数量
        uint256 amountAMin, // 获得 tokenA 数量的最小值
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        // 实际获得 tokenA 的数量
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to); // 流动池销毁 LP 并向 to 地址发送数量为 amount0 的 token0 和 amount1 的 token1？？？
        (address token0, ) = UniswapV2Library.sortTokens(tokenA, tokenB); // 计算出 tokenA, tokenB 中谁是 token0，
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(
            amountA >= amountAMin,
            "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
        );
    } // 移除流动性并不会检查你是否是流动性的添加者，只要你拥有 LP，那么就拥有了流动性的所有权。

    function removeLiquidityETH(
        // 比 removeLiquidity 函数少了一个 tokenB 地址的参数
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountETH)
    {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken); // 向 to 地址发送数量为 amountToken 的 token
        IWETH(WETH).withdraw(amountETH); // 将数量为 amountETH 的 WETH 换成 ETH
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityWithPermit(
        // 外部函数（仅供合约外部调用）
        address tokenA, // 移除流动性 tokenA 的地址
        address tokenB,
        uint256 liquidity, // 销毁 LP 的数量
        uint256 amountAMin, // 获得 tokenA 数量的最小值
        uint256 amountBMin,
        address to, // 获得的 tokenA、tokenB 发送到的地址
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s // 是否授权为最大值 // 签名 v,r,s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        // 实际获得 tokenA 的数量
        // 函数 removeLiquidityWithPermit 这个实现了签名授权 Router 使用用户的 LP。首先要明确的是，合约调用用户的代币需要用户的授权才能进行，而 LP 的授权既可以发送一笔交易，也可以使用签名。而使用 removeLiquidityWithPermit 可以让用户免于发送一笔授权交易，转而使用签名，从而简化用户的操作。
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB); // 获取 tokenA, tokenB 的流动池地址
        uint256 value = approveMax ? uint256(-1) : liquidity; // 获取授权 LP 的数量
        IUniswapV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        ); // 授权 Router 使用用户数量为 value 的 LP
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        ); // 移除流动性
    } // 使用签名进行授权，简化了用户的操作，但有些人可能会利用用户对签名的不了解，盗窃用户资产。

    function removeLiquidityETHWithPermit(
        address token, // 移除流动性 token 的地址
        uint256 liquidity, // 销毁 LP 的数量
        uint256 amountTokenMin, // 获得 token 数量的最小值
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        virtual
        override
        returns (uint256 amountToken, uint256 amountETH)
    {
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IUniswapV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountETH) = removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****（支持代付GAS代币）
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountETH) {
        // 从参数上看，相比于 removeLiquidityETH，removeLiquidityETHSupportingFeeOnTransferTokens 少了一个出参。这是因为函数 removeLiquidityETHSupportingFeeOnTransferTokens 的主要功能是支持第三方为用户支付手续费并收取一定的代币，因此 amountToken 中有一部分会被第三方收取，用户真实获取的代币数量会比 amountToken 少。具体见 ERC865 协议。
        (, amountETH) = removeLiquidity(
            token, // 移除流动性 token 的地址
            WETH,
            liquidity, // 销毁 LP 的数量
            amountTokenMin, // 获得 token 数量的最小值
            amountETHMin,
            address(this), // 获得的 tokenA、tokenB 发送到的地址
            deadline
        );
        TransferHelper.safeTransfer(
            token,
            to,
            IERC20(token).balanceOf(address(this))
        ); // 向 to 地址发送全部 token
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    } // 实际上 removeLiquidityETHSupportingFeeOnTransferTokens 支持了所有在移除流动性时，数量会变化的代币，有一些代币的经济模式利用到了这点。

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountETH) {
        // removeLiquidityETHWithPermitSupportingFeeOnTransferTokens同样比 removeLiquidityETHWithPermit 少了一个出参，这同样是为了支持在移除流动性时，数量会变化的代币。
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IUniswapV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        //              交易期望数量列表, 交易路径列表, 交易获得的 token 发送到的地址
        // 函数 _swap 实现了由多重交易组成的交易集合。path 数组里定义了执行代币交易的顺序，amounts 数组里定义了每次交换获得代币的期望数量，_to 则是最后获得代币发送到的地址。
        for (uint256 i; i < path.length - 1; i++) {
            // 循环交易路径列表
            (address input, address output) = (path[i], path[i + 1]); // 从 path 中取出 input 和 output
            (address token0, ) = UniswapV2Library.sortTokens(input, output); // 从 input 和 output 中算出谁是 token0
            uint256 amountOut = amounts[i + 1]; // 期望交易获得的代币数量
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0)); // 如果 input == token0，那么 amount0Out 就是0，amount1Out 就是 amountOut；反之则相反
            address to = i < path.length - 2
                ? UniswapV2Library.pairFor(factory, output, path[i + 2])
                : _to; // 如果这是最后的一笔交易，那么 to 地址就是 _to，否则 to 地址是下一笔交易的流动池地址
            // 为什么to是下一笔交易的流动池地址,而不是router？
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0)); // 执行 input 和 output 的交易
        }
    } // 由于执行 swap 时，需要排列 amount0Out、amount1Out 的顺序，因此需要计算 input、output 中谁是 token0。

    function swapExactTokensForTokens(
        uint256 amountIn, // 交易支付代币数量
        uint256 amountOutMin, // 交易获得代币最小值
        address[] calldata path, // 交易路径
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        // 函数 swapExactTokensForTokens 实现了用户使用数量精确的 tokenA 交易数量不精确的 tokenB 的流程。用户使用确定的 amountIn 数量的 tokenA ，交易获得 tokenB 的数量不会小于 amountOutMin，但具体 tokenB 的数量只有交易完成之后才能知道。这同样是由于区块链上交易不是实时的，实际交易和预期交易相比会有一定的偏移。
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path); // 获取 path 列表下，支付 amountIn 数量的 path[0] 代币，各个代币交易的预期数量
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        ); // 如果最终获得的代币数量小于 amountOutMin，则交易失败
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        ); // 将 amounts[0] 数量的 path[0] 代币从用户账户中转移到 path[0], path[1] 的流动池
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut, // 交易获得的代币数量
        uint256 amountInMax, // 交易支付代币的最多数量
        address[] calldata path, // 交易路径列表
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        // 交易期望数量列表
        // 函数 swapTokensForExactTokens 实现了用户使用数量不精确的 tokenA 交易数量精确的 tokenB 的流程。用户会使用数量不大于 amountInMax 数量的 tokenA，交易获得 amountOut 数量的 tokenB。
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path); // 获取 path 列表下，获得 amountIn 数量的 path[path.length-1] 代币，各个代币交易的预期数量
        require(
            amounts[0] <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        ); // 如果 path[0] 代币数量大于 amountInMax，则交易失败
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        ); // 将 amounts[0] 数量的 path[0] 代币从用户账户中转移到 path[0], path[1] 的流动池
        _swap(amounts, path, to); // 按 path 列表执行交易集合
    } // 函数 swapTokensForExactTokens 完全是函数 swapExactTokensForTokens 的相反操作。一般来说，swapExactTokensForTokens 用于出售确定数量的代币，swapTokensForExactTokens 用于购买确定数量的代币。

    // 这时计算出的amountIn数量可以精确兑换amountout，因为对于区块链的状态来说，这个函数的整个操作是原子的。或者说，进行这一系列操作时，没有其他交易进行，区块链的状态不会更改。

    function swapExactETHForTokens(
        uint256 amountOutMin, // 交易获得代币最小值
        address[] calldata path, // 交易路径列表
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        // returns交易期望数量列表
        // 函数 swapExactETHForTokens 和函数 swapExactTokensForTokens 的逻辑几乎一样，只是把支付精确数量的 token 换成了支付精确数量的 ETH。因此多了一些和 ETH 相关的额外操作。
        require(path[0] == WETH, "UniswapV2Router: INVALID_PATH"); // 检查 path[0] 是否为 WETH 地址
        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path); // 获取 path 列表下，支付 amountIn 数量的 path[0] 代币，各个代币交易的预期数量
        require(
            amounts[amounts.length - 1] >= amountOutMin, // 如果最终获得的代币数量小于 amountOutMin，则交易失败
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWETH(WETH).deposit{value: amounts[0]}(); // 把用户支付的 ETH 换成 WETH
        assert(
            IWETH(WETH).transfer(
                UniswapV2Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            ) // 将 amounts[0] 数量的 WETH 代币从 Router 中转移到 path[0], path[1] 的流动池
        );
        _swap(amounts, path, to); // 按 path 列表执行交易集合
    } //此函数一般用于出售确定数量的 ETH，获得不确定数量代币。

    // 函数 swapTokensForExactTokens 完全是函数 swapExactTokensForTokens 的相反操作。一般来说，swapExactTokensForTokens 用于出售确定数量的代币，swapTokensForExactTokens 用于购买确定数量的代币。
    function swapTokensForExactETH(
        uint256 amountOut, // 交易获得的代币数量
        uint256 amountInMax, // 交易支付代币的最多数量
        address[] calldata path, // 交易路径列表
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        // 检查交易是否过期// 交易期望数量列表

        require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH"); // 检查 path[path.length - 1] 是否为 WETH 地址
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path); // 获取 path 列表下，获得 amountOut 数量的 path[path.length-1] 代币，各个代币交易的预期数量
        require(
            amounts[0] <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        ); // 如果最终获得的代币数量小于 amountOutMin，则交易失败
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        ); // 将 amounts[0] 数量的 path[0] 代币从用户账户中转移到 path[0], path[1] 的流动池
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]); // 把用户支付的 ETH 换成 WETH
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]); // 把 ETH 发送给 to 地址
    } //此函数一般用于购买确定数量的 ETH，用不定数量的代币交换。

    function swapExactTokensForETH(
        uint256 amountIn, // 交易支付代币数量
        uint256 amountOutMin, // 交易获得代币最小值
        address[] calldata path, // 交易路径列表
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        // 交易期望数量列表
        //函数 swapExactTokensForETH 和 函数 swapTokensForExactETH 相比，是更换了输入精确数量代币的顺序。
        require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH"); // 检查 path[path.length - 1] 是否为 WETH 地址
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path); // 获取 path 列表下，支付 amountIn 数量的 path[0] 代币，各个代币交易的预期数量
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        ); // 如果最终获得的代币数量小于 amountOutMin，则交易失败
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        ); // 将 amounts[0] 数量的 path[0] 代币从用户账户中转移到 path[0], path[1] 的流动池
        _swap(amounts, path, address(this)); // 按 path 列表执行交易集合
        IWETH(WETH).withdraw(amounts[amounts.length - 1]); // 将 WETH 换成 ETH
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]); // 把 ETH 发送给 to 地址
    } //此函数一般用于出售确定数量代币，获得不确定数量的 ETH。

    function swapETHForExactTokens(
        uint256 amountOut, // 交易获得的代币数量
        address[] calldata path, // 交易路径列表
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        // 交易期望数量列表
        // 函数 swapETHForExactTokens 和 函数 swapExactTokensForETH 相比，更换了代币交易的顺序。
        require(path[0] == WETH, "UniswapV2Router: INVALID_PATH"); // 检查 path[0] 是否为 WETH 地址
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path); // 获取 path 列表下，获得 amountOut 数量的 path[path.length-1] 代币，各个代币交易的预期数量
        require(
            amounts[0] <= msg.value,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        ); // 如果 ETH 数量小于 amounts[0]，交易失败
        IWETH(WETH).deposit{value: amounts[0]}(); // 将 WETH 换成 ETH
        assert(
            IWETH(WETH).transfer(
                UniswapV2Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        ); // 将 amounts[0] 数量的 path[0] 代币从用户账户中转移到 path[0], path[1] 的流动池
        _swap(amounts, path, to); // 按 path 列表执行交易集合
        // refund dust eth, if any
        if (msg.value > amounts[0])
            // 如果 ETH 数量大于 amounts[0]，返还多余的 ETH
            TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    } //此函数一般用于购买确定数量代币，支付不确定数量的 ETH。

    // **** SWAP (supporting fee-on-transfer tokens) ****（支持代付GAS代币）
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path, // 交易路径列表
        address _to // 交易获得的 token 发送到的地址
    ) internal virtual {
        // 函数 _swapSupportingFeeOnTransferTokens 相比函数 _swap 为了支持 path 中有交易后可变数量的代币，不需要输入 amounts，但需要额外做一些操作。
        for (uint256 i; i < path.length - 1; i++) {
            // 循环交易路径列表
            (address input, address output) = (path[i], path[i + 1]); // 从 path 中取出 input 和 output
            (address token0, ) = UniswapV2Library.sortTokens(input, output); // 从 input 和 output 中算出谁是 token0
            IUniswapV2Pair pair = IUniswapV2Pair(
                UniswapV2Library.pairFor(factory, input, output)
            ); // 获得 input, output 的流动池
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves(); // 获取流动池库存 reserve0, reserve1
                // 如果 input == token0，那么 (reserveInput,reserveOutput) 就是 (reserve0, reserve1)；反之则相反
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                // amountInput 等于流动池余额减去 reserveInput
                amountInput = IERC20(input).balanceOf(address(pair)).sub(
                    reserveInput
                );
                // 获取 amountOutput
                amountOutput = UniswapV2Library.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
            }
            // 如果 input == token0，那么 amount0Out 就是0，amount1Out 就是 amountOut；反之则相反
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            // 如果这是最后的一笔交易，那么 to 地址就是 _to，否则 to 地址是下一笔交易的流动池地址
            address to = i < path.length - 2
                ? UniswapV2Library.pairFor(factory, output, path[i + 2])
                : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0)); // 执行 input 和 output 的交易
        }
    } //可以看到，因为没有 amounts，需要使用流动池余额减去库存来计算amountInput。

    // 函数 swapExactTokensForTokensSupportingFeeOnTransferTokens 相比函数 swapExactTokensForTokens，少了 amounts，因为交易后可变数量的代币不能做amounts的预测。
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn, // 交易支付代币数量
        uint256 amountOutMin, // 交易获得代币最小值
        address[] calldata path, // 交易路径列表
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amountIn
        ); // 将 amountIn 数量的 path[0] 代币从用户账户中转移到 path[0], path[1] 的流动池
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to); // 记录 to 地址 path[path.length - 1] 代币的余额
        _swapSupportingFeeOnTransferTokens(path, to); // 按 path 列表执行交易集合
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        ); // 如果 to 地址获得的代币数量小于 amountOutMin，交易失败
    } //该函数适用于支付确定数量的代币，获得不定数量的代币，且在 path 路径列表中有交易后数量可变的代币。

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin, // 交易获得代币最小值
        address[] calldata path, // 交易路径列表
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    ) external payable virtual override ensure(deadline) {
        // 函数 swapExactETHForTokensSupportingFeeOnTransferTokens 相比函数 swapExactETHForTokens，同样少了 amounts，因为交易后可变数量的代币不能做amounts的预测。
        require(path[0] == WETH, "UniswapV2Router: INVALID_PATH"); // 检查 path[0] 是否为 WETH
        uint256 amountIn = msg.value; // 获取 amountIn
        IWETH(WETH).deposit{value: amountIn}(); // 把 ETH 换成 WETH
        assert(
            IWETH(WETH).transfer(
                UniswapV2Library.pairFor(factory, path[0], path[1]),
                amountIn
            )
        ); // 将 amountIn 数量的 path[0] 代币从用户账户中转移到 path[0], path[1] 的流动池
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to); // 记录 to 地址 path[path.length - 1] 代币的余额
        _swapSupportingFeeOnTransferTokens(path, to); // 按 path 列表执行交易集合
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        ); // 如果 to 地址获得的代币数量小于 amountOutMin，交易失败
    } // 该函数适用于支付确定数量的 ETH，获得不定数量的代币，且在 path 路径列表中有交易后数量可变的代币。

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn, // 交易支付代币数量
        uint256 amountOutMin, // 交易获得代币最小值
        address[] calldata path, // 交易路径列表
        address to, // 交易获得的 token 发送到的地址
        uint256 deadline // 过期时间
    ) external virtual override ensure(deadline) {
        // 函数 swapExactTokensForETHSupportingFeeOnTransferTokens 相比函数 swapExactTokensForETH，也少了 amounts，因为交易后可变数量的代币不能做amounts的预测。
        require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH"); // 检查 path[path.length - 1] 是否为 WETH
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amountIn
        ); // 将 amountIn 数量的 path[0] 代币从用户账户中转移到 path[0], path[1] 的流动池
        _swapSupportingFeeOnTransferTokens(path, address(this)); // 按 path 列表执行交易集合
        uint256 amountOut = IERC20(WETH).balanceOf(address(this)); // 获取 Router 中的 WETH 余额
        require(
            amountOut >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        ); // amountOut 大于 amountOutMin，否则交易失败
        IWETH(WETH).withdraw(amountOut); // 将 WETH 换成 ETH
        TransferHelper.safeTransferETH(to, amountOut); // 将 ETH 发送给 to 地址
    } // 该函数适用于支付确定数量的 token，获得不定数量的 WETH，且在 path 路径列表中有交易后数量可变的代币。

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual override returns (uint256 amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountOut) {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountIn) {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
