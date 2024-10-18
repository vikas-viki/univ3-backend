// SPDX-License-Identifier: UNILICENSED

pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./TestUtils.sol";

import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Manager.sol";

contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;
    UniswapV3Manager manager;

    bytes public callbackdata;

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
        manager = new UniswapV3Manager();
    }

    function setupTestCase(
        TestCaseParams memory params
    ) public returns (uint256 poolBalance0, uint256 poolBalance1) {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);
        token0.approve(address(manager), params.wethBalance);
        token1.approve(address(manager), params.usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );
        UniswapV3Pool.CallbackData memory data = UniswapV3Pool.CallbackData({
            payer: address(this),
            token0: address(token0),
            token1: address(token1)
        });
        callbackdata = abi.encode(data);

        if (params.mintLiquidity) {
            vm.expectEmit(true, true, false, false);
            (poolBalance0, poolBalance1) = manager.mint(
                address(pool),
                params.lowerTick,
                params.upperTick,
                params.liquidity,
                callbackdata
            );
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

        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

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
            wethBalance: 1 wei,
            usdcBalance: 5000 wei,
            currentTick: 0,
            lowerTick: 0,
            upperTick: 0,
            liquidity: 0,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: false,
            mintLiquidity: false
        });

        setupTestCase(params);

        vm.expectRevert(TestUtils.encodeError("InvalidTickRange()"));
        manager.mint(
            address(pool),
            type(int24).min,
            type(int24).max,
            0,
            callbackdata
        );

        vm.expectRevert(TestUtils.encodeError("ZeroLiquidity()"));
        manager.mint(address(pool), 84222, 86129, params.liquidity, callbackdata);

        vm.expectRevert();
        manager.mint(
            address(pool),
            84222,
            86129,
            1517882343751509868544,
            callbackdata
        );
    }

    function testSwapBuyEth() public {
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

        setupTestCase(params);
        token1.mint(address(this), 42 ether);
        token1.approve(address(manager), 42 ether);

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));
        (int256 amount0Delta, int256 amount1Delta) = manager.swap(
            address(pool),
            callbackdata
        );
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();

        assertEq(amount0Delta, -0.008396714242162444 ether, "invalid ETH out");
        assertEq(amount1Delta, 42 ether, "invalid USDC in");
        assertEq(
            token0.balanceOf(address(this)),
            uint256(userBalance0Before - amount0Delta),
            "invalid user ETH balance"
        );
        assertEq(
            token1.balanceOf(address(this)),
            0,
            "invalid user USDC balance"
        );
        assertEq(
            sqrtPriceX96,
            5604469350942327889444743441197,
            "invalid current sqrtP"
        );
        assertEq(tick, 85184, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1517882343751509868544,
            "invalid current liquidity"
        );
    }
}
