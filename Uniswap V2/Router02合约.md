https://etherscan.io/address/0x7a250d5630b4cf539739df2c5dacb4c659f2488d#code

主要功能：

- 添加流动性 (\_addLiquidity, addLiquidity, addLiquidityETH)
- 移除流动性 (removeLiquidity,removeLiquidityETH,removeLiquidityWithPermit,removeLiquidityETHWithPermit)
- 移除流动性（支持代付 GAS 代币）removeLiquidityETHSupportingFeeOnTransferTokens，removeLiquidityETHWithPermitSupportingFeeOnTransferTokens
- 交易 (\_swap, swapExactTokensForTokens, swapTokensForExactTokens,swapExactETHForTokens,swapTokensForExactETH,swapExactTokensForETH,swapETHForExactTokens)
- 交易（支持代付 GAS 代币）(\_swapSupportingFeeOnTransferTokens,swapExactTokensForTokensSupportingFeeOnTransferTokens,swapExactETHForTokensSupportingFeeOnTransferTokens,swapExactTokensForETHSupportingFeeOnTransferTokens)
- library：token 排序（sortTokens），计算交易对地址 pairFor，获取储备量（getReserves），计算另一个数量(quote,getAmountOut,getAmountIn,getAmountsOut,getAmountsIn)
