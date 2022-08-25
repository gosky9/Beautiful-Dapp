v2 新功能：

- `任意两个代币互换`
- `闪电贷`
- `预言机`

主要合约 :包括 core 合约和 periphery 合约

- `UniswapV2Router02`: 路由合约，负责跟用户交互； periphery
- `UniswapV2Factory`: 工厂合约，常见 pair(即 pool); core
- `UniswapV2Pair`: 具体交易对合约，负责实际交易。 core

Router01 是废弃合约

闪电贷主要作用:借贷平仓、交易所搬砖、黑客攻击等.它赋予了所有人用极小成本(gas 费)，使用极大资金的能力

预言机只记录一个值，需要二次开发。v3 预言机为数组实现，更为方便

# 参考资料

https://github.com/Dapp-Learning-DAO/Dapp-Learning/tree/main/defi/Uniswap-V2/contract

https://github.com/33357/smartcontract-apps/tree/main/DEX/Uniswap_v2

[白皮书](https://zhuanlan.zhihu.com/p/255190320)

core 地址: https://github.com/Uniswap/v2-core/tree/master/contracts

periphery 地址:https://github.com/Uniswap/v2-periphery
