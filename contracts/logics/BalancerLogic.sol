//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IBalancerPool.sol";
import "../interfaces/IBalancerRegistry.sol";
import "../interfaces/IWETH.sol";
import "../utils/UniversalERC20.sol";
import "hardhat/console.sol";

contract BalancerLogic {
    using SafeMath for uint256;
    using UniversalERC20 for IERC20;
    using UniversalERC20 for IWETH;

    IBalancerRegistry internal constant REGISTRY = IBalancerRegistry(
        0x65e67cbc342712DF67494ACEfc06fe951EE93982
    );

    IWETH internal constant WETH = IWETH(
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    );

     // EVENTS
    event LogSwap(address indexed src, address indexed dest, uint amount);
    event LogLiquidityAdd(address indexed tokenA, address indexed tokenB, uint amountA, uint amountB);
    event LogLiquidityRemove(address indexed tokenA, address indexed tokenB, uint amountA, uint amountB);

    /**
     * @dev unlimited approval
     */
     function setApproval(
        IERC20 erc20,
        uint256 srcAmt,
        address to
    ) internal {
        uint256 tokenAllowance = erc20.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20.approve(to, uint(-1));
        }
    }

    /**
     * @dev swap tokens in balancer in a certain pool index
     */
    function swap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 poolIndex
    ) external payable{
        uint256 realAmount = amount == uint256(-1)
            ? fromToken.universalBalanceOf(address(this))
            : amount;

        address[] memory pools = REGISTRY.getBestPoolsWithLimit(
            address(fromToken.isETH() ? WETH : fromToken),
            address(destToken.isETH() ? WETH : destToken),
            poolIndex + 1
        );

        if (fromToken.isETH()) {
            WETH.deposit{value:amount}();
        }

        uint initialBalance;

        if (destToken.isETH()) {
            initialBalance = WETH.balanceOf(address(this));
        }

        setApproval(fromToken.isETH() ? WETH : fromToken, realAmount, pools[poolIndex]);

        IBalancerPool(pools[poolIndex]).swapExactAmountIn(
            fromToken.isETH() ? WETH : fromToken,
            realAmount,
            destToken.isETH() ? WETH : destToken,
            0,
            uint256(-1)
        );

        if (destToken.isETH()) {
            // Withdraw WETH received only
            WETH.withdraw(WETH.balanceOf(address(this)).sub(initialBalance));
        }

        emit LogSwap(address(fromToken), address(destToken), realAmount);
    }

    /**
     * @dev add one-side liquidity to Balance Pool
     */
    function addLiquidity(
        address poolAddress,
        IERC20 tokenIn,
        uint256 amountIn
    ) external {
        uint256 realAmountIn = amountIn == uint256(-1)
            ? tokenIn.balanceOf(address(this))
            : amountIn;

        setApproval(tokenIn, realAmountIn, poolAddress);

        uint256 bptOut = IBalancerPool(poolAddress).joinswapExternAmountIn(
            address(tokenIn),
            realAmountIn,
            1
        );

        require(bptOut > 0, "Balancer: Failed Adding Liquidity");

        emit LogLiquidityAdd(address(tokenIn), address(0), amountIn, 0);
    }

    /**
     * @dev remove one-side liquidity from Balance Pool
     */
    function removeLiquidity(
        IERC20 poolAddress,
        address tokenOut,
        uint256 poolAmtIn
    ) external {
        uint256 realAmountIn = poolAmtIn == uint256(-1)
            ? poolAddress.balanceOf(address(this))
            : poolAmtIn;

        uint256 tokenAmtOut = IBalancerPool(address(poolAddress))
            .exitswapPoolAmountIn(tokenOut, realAmountIn, 1);

        require(tokenAmtOut > 0, "Balancer: Failed Removing Liquidity");

        emit LogLiquidityRemove(address(tokenOut), address(0), tokenAmtOut, 0);
    }
}
