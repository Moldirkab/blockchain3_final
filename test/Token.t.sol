// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/token/RiskGovernanceToken.sol";

contract TokenTest is Test {
    RiskGovernanceToken token;

    address user = address(1);

    function setUp() public {
        token = new RiskGovernanceToken(address(this));
    }

    function testInitialSupply() public {
        assertEq(token.balanceOf(address(this)), 1_000_000 ether);
    }

    function testMint() public {
        token.mint(user, 100 ether);

        assertEq(token.balanceOf(user), 100 ether);
    }

    function testDelegateVotingPower() public {
        token.mint(user, 100 ether);

        vm.prank(user);
        token.delegate(user);

        assertEq(token.getVotes(user), 100 ether);
    }

    function testUnauthorizedMintRevert() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 100 ether);
    }
}
