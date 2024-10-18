// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./UniswapV3Pool.sol";

contract UniswapV3Manager {
    function mint(
        address pool,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) public returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = UniswapV3Pool(pool).mint(
            msg.sender,
            lowerTick,
            upperTick,
            amount,
            data
        );
    }

    function swap(
        address pool,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        (amount0, amount1) = UniswapV3Pool(pool).swap(msg.sender, data);
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes memory data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
        IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes memory data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount0)
            );
        }
        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount1)
            );
        }
    }
}
