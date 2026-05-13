// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/mock/MockERC20.sol";
import "../src/amm/RiskAMM.sol";

contract AMMTest is Test {
    MockERC20 token0;
    MockERC20 token1;
    RiskAMM amm;

    address user = address(1);

    function setUp() public {
        token0 = new MockERC20("Token A", "TKA");
        token1 = new MockERC20("Token B", "TKB");
        amm = new RiskAMM(address(token0), address(token1));

        token0.mint(user, 10_000 ether);
        token1.mint(user, 10_000 ether);

        vm.startPrank(user);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        vm.prank(user);
        amm.addLiquidity(1000 ether, 1000 ether);

        assertEq(amm.reserve0(), 1000 ether);
        assertEq(amm.reserve1(), 1000 ether);
        assertGt(amm.balanceOf(user), 0);
    }

    function testRemoveLiquidity() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 shares = amm.balanceOf(user);
        amm.removeLiquidity(shares);

        assertEq(amm.reserve0(), 0);
        assertEq(amm.reserve1(), 0);
        vm.stopPrank();
    }

    function testSwapToken0ForToken1() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 beforeBalance = token1.balanceOf(user);
        amm.swap(address(token0), 100 ether, 1);

        assertGt(token1.balanceOf(user), beforeBalance);
        vm.stopPrank();
    }

    function testSwapToken1ForToken0() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 beforeBalance = token0.balanceOf(user);
        amm.swap(address(token1), 100 ether, 1);

        assertGt(token0.balanceOf(user), beforeBalance);
        vm.stopPrank();
    }

    function testSlippageRevert() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);

        vm.expectRevert();
        amm.swap(address(token0), 100 ether, 999 ether);

        vm.stopPrank();
    }

    function testInvalidTokenRevert() public {
        MockERC20 fake = new MockERC20("Fake", "FAKE");

        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);

        vm.expectRevert();
        amm.swap(address(fake), 100 ether, 1);

        vm.stopPrank();
    }

    function testKDoesNotDecreaseAfterSwap() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 kBefore = amm.reserve0() * amm.reserve1();

        amm.swap(address(token0), 100 ether, 1);

        uint256 kAfter = amm.reserve0() * amm.reserve1();

        assertGe(kAfter, kBefore);
        vm.stopPrank();
    }
}
