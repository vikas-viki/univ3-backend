// SPDX-License-Identifier: UNILICENSED

pragma solidity ^0.8.14;

import "forge-std/Test.sol";
// import "forge-std/console.sol";

import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool public shouldTransferInCallback;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool shouldTransferInCallback;
        bool mintLiquidity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function setUpTestCase(
        TestCaseParams memory params
    ) public returns (uint256 poolBalance0, uint256 poolBalance1) {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );

        shouldTransferInCallback = params.shouldTransferInCallback;

        if (params.mintLiquidity) {
            vm.expectEmit(true, true, false, false);
            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity
            );
        }
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) public {
        if (shouldTransferInCallback) {
            token0.transfer(msg.sender, amount0);
            token1.transfer(msg.sender, amount1);
        }
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);

        uint256 expectedAmount0 = 0.998976618347425280 ether;
        uint256 expectedAmount1 = 5000 ether;

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect token0 amount deposited"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect token1 amount deposited"
        );

        assertEq(token0.balanceOf(address(pool)), expectedAmount0);
        assertEq(token1.balanceOf(address(pool)), expectedAmount1);

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), params.lowerTick, params.upperTick)
        );
        uint128 posliquidity = pool.positions(positionKey);

        assertEq(posliquidity, params.liquidity);

        (bool tickInitialised, uint128 tickLiquidity) = pool.ticks(
            params.lowerTick
        );

        assertTrue(tickInitialised);
        assertEq(tickLiquidity, params.liquidity);

        (tickInitialised, tickLiquidity) = pool.ticks(params.lowerTick);

        assertTrue(tickInitialised);
        assertEq(tickLiquidity, params.liquidity);

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();

        assertEq(
            sqrtPriceX96,
            params.currentSqrtP,
            "invalid current sqrt price"
        );
        assertEq(tick, params.currentTick, "invalid current tick");
        assertEq(
            pool.liquidity(),
            params.liquidity,
            "invalid current liquidity"
        );
    }

    function testMintFailures() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 0,
            lowerTick: 0,
            upperTick: 0,
            liquidity: 0,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: false,
            mintLiquidity: false
        });

        setUpTestCase(params);

        vm.expectRevert(abi.encodeWithSignature("InvalidTickRange()"));
        pool.mint(address(this), type(int24).min, type(int24).max, 0);

        vm.expectRevert(abi.encodeWithSignature("ZeroLiquidity()"));
        pool.mint(address(this), 84222, 86129, params.liquidity);

        vm.expectRevert(abi.encodeWithSignature("InsufficientInputAmount()"));
        pool.mint(address(this), 84222, 86129, 1517882343751509868544);
    }
}
