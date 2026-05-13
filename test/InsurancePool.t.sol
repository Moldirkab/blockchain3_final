// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/mock/MockERC20.sol";
import "../src/oracle/MockAggregator.sol";
import "../src/oracle/ChainlinkOracle.sol";
import "../src/vault/UnderwriterVault.sol";
import "../src/nft/PolicyNFT.sol";
import "../src/insurance/InsurancePool.sol";

contract InsurancePoolTest is Test {
    MockERC20 token;
    MockAggregator mock;
    ChainlinkOracle oracle;
    UnderwriterVault vault;
    PolicyNFT nft;
    InsurancePool pool;

    address user = address(1);
    address underwriter = address(2);

    bytes32 riskType = keccak256("DEPEG");

    function setUp() public {
        token = new MockERC20("USD", "USDC");
        mock = new MockAggregator(2000e8, 8);
        oracle = new ChainlinkOracle(address(this), address(mock), 1 days);
        vault = new UnderwriterVault(token, address(this));
        nft = new PolicyNFT(address(this));

        pool = new InsurancePool(address(this), token, oracle, vault, nft);

        nft.grantRole(nft.MINTER_ROLE(), address(pool));
        vault.grantRole(vault.INSURANCE_POOL_ROLE(), address(pool));

        token.mint(user, 1000 ether);
        token.mint(underwriter, 10_000 ether);

        vm.startPrank(underwriter);
        token.approve(address(vault), 10_000 ether);
        vault.deposit(10_000 ether, underwriter);
        vm.stopPrank();

        pool.setRiskConfig(riskType, true, 500, 1500e18, 7 days);
    }

    function testBuyPolicy() public {
        vm.startPrank(user);
        token.approve(address(pool), 100 ether);

        uint256 id = pool.buyPolicy(riskType, 100 ether);

        assertEq(id, 1);
        assertEq(nft.ownerOf(id), user);

        vm.stopPrank();
    }

    function testBuyPolicyRevertRiskNotAccepted() public {
        vm.startPrank(user);
        token.approve(address(pool), 100 ether);

        vm.expectRevert();
        pool.buyPolicy(keccak256("UNKNOWN"), 100 ether);

        vm.stopPrank();
    }

    function testBuyPolicyRevertZeroCoverage() public {
        vm.startPrank(user);
        token.approve(address(pool), 100 ether);

        vm.expectRevert();
        pool.buyPolicy(riskType, 0);

        vm.stopPrank();
    }

    function testClaimSuccessWhenTriggered() public {
        vm.startPrank(user);
        token.approve(address(pool), 100 ether);

        uint256 id = pool.buyPolicy(riskType, 100 ether);

        vm.stopPrank();

        mock.setAnswer(1000e8);

        vm.prank(user);
        pool.claim(id);

        assertEq(
            uint256(pool.policyStatus(id)),
            uint256(InsurancePool.PolicyStatus.Claimed)
        );
    }

    function testClaimRevertWhenNotTriggered() public {
        vm.startPrank(user);
        token.approve(address(pool), 100 ether);

        uint256 id = pool.buyPolicy(riskType, 100 ether);

        vm.expectRevert();
        pool.claim(id);

        vm.stopPrank();
    }

    function testClaimRevertNotOwner() public {
        vm.startPrank(user);
        token.approve(address(pool), 100 ether);

        uint256 id = pool.buyPolicy(riskType, 100 ether);

        vm.stopPrank();

        mock.setAnswer(1000e8);

        vm.prank(address(99));
        vm.expectRevert();
        pool.claim(id);
    }

    function testClaimRevertExpired() public {
        vm.startPrank(user);
        token.approve(address(pool), 100 ether);

        uint256 id = pool.buyPolicy(riskType, 100 ether);

        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);
        mock.setAnswer(1000e8);

        vm.prank(user);
        vm.expectRevert();
        pool.claim(id);
    }

    function testPause() public {
        pool.pause();

        assertEq(pool.paused(), true);
    }

    function testUnpause() public {
        pool.pause();
        pool.unpause();

        assertEq(pool.paused(), false);
    }
}
