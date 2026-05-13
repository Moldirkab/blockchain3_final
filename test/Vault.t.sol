// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/mock/MockERC20.sol";
import "../src/vault/UnderwriterVault.sol";

contract VaultTest is Test {
    MockERC20 token;
    UnderwriterVault vault;

    address user = address(1);
    address pool = address(2);

    function setUp() public {
        token = new MockERC20("USD", "USDC");
        vault = new UnderwriterVault(token, address(this));

        token.mint(user, 1000 ether);

        vault.grantRole(vault.INSURANCE_POOL_ROLE(), pool);
    }

    function testDeposit() public {
        vm.startPrank(user);
        token.approve(address(vault), 100 ether);
        vault.deposit(100 ether, user);
        vm.stopPrank();

        assertEq(vault.balanceOf(user), 100 ether);
    }

    function testWithdraw() public {
        vm.startPrank(user);
        token.approve(address(vault), 100 ether);
        vault.deposit(100 ether, user);
        vault.withdraw(50 ether, user, user);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 950 ether);
    }

    function testPayClaim() public {
        vm.startPrank(user);
        token.approve(address(vault), 100 ether);
        vault.deposit(100 ether, user);
        vm.stopPrank();

        vm.prank(pool);
        vault.payClaim(user, 20 ether);

        assertEq(token.balanceOf(user), 920 ether);
    }

    function testPayClaimUnauthorizedRevert() public {
        vm.expectRevert();
        vault.payClaim(user, 20 ether);
    }
}
