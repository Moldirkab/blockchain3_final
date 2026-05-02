// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RiskAMM is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public constant FEE_BPS = 30;
    uint256 public constant BPS = 10_000;

    event LiquidityAdded(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event Swapped(
        address indexed user,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );

    error InvalidToken();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error InvalidAmount();

    constructor(
        address token0_,
        address token1_
    ) ERC20("Risk AMM LP", "RISK-LP") {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
    }

    function addLiquidity(
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant returns (uint256 shares) {
        if (amount0 == 0 || amount1 == 0) revert InvalidAmount();

        if (totalSupply() == 0) {
            shares = sqrt(amount0 * amount1);
        } else {
            shares = min(
                (amount0 * totalSupply()) / reserve0,
                (amount1 * totalSupply()) / reserve1
            );
        }

        if (shares == 0) revert InsufficientLiquidity();

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        reserve0 += amount0;
        reserve1 += amount1;

        _mint(msg.sender, shares);

        emit LiquidityAdded(msg.sender, amount0, amount1, shares);
    }

    function removeLiquidity(
        uint256 shares
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        if (shares == 0) revert InvalidAmount();

        amount0 = (shares * reserve0) / totalSupply();
        amount1 = (shares * reserve1) / totalSupply();

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        _burn(msg.sender, shares);

        reserve0 -= amount0;
        reserve1 -= amount1;

        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1, shares);
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmount();

        bool isToken0 = tokenIn == address(token0);
        bool isToken1 = tokenIn == address(token1);

        if (!isToken0 && !isToken1) revert InvalidToken();

        IERC20 input = isToken0 ? token0 : token1;
        IERC20 output = isToken0 ? token1 : token0;

        uint256 reserveIn = isToken0 ? reserve0 : reserve1;
        uint256 reserveOut = isToken0 ? reserve1 : reserve0;

        uint256 amountInWithFee = amountIn * (BPS - FEE_BPS);
        amountOut =
            (amountInWithFee * reserveOut) /
            ((reserveIn * BPS) + amountInWithFee);

        if (amountOut < minAmountOut) revert SlippageExceeded();
        if (amountOut == 0 || amountOut >= reserveOut)
            revert InsufficientLiquidity();

        input.safeTransferFrom(msg.sender, address(this), amountIn);
        output.safeTransfer(msg.sender, amountOut);

        if (isToken0) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        emit Swapped(msg.sender, tokenIn, amountIn, amountOut);
    }

    function getAmountOut(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256) {
        bool isToken0 = tokenIn == address(token0);
        bool isToken1 = tokenIn == address(token1);

        if (!isToken0 && !isToken1) revert InvalidToken();

        uint256 reserveIn = isToken0 ? reserve0 : reserve1;
        uint256 reserveOut = isToken0 ? reserve1 : reserve0;

        uint256 amountInWithFee = amountIn * (BPS - FEE_BPS);

        return
            (amountInWithFee * reserveOut) /
            ((reserveIn * BPS) + amountInWithFee);
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
