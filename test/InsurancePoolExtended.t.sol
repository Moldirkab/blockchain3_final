// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/mock/MockERC20.sol";
import "../src/oracle/MockAggregator.sol";
import "../src/oracle/ChainlinkOracle.sol";
import "../src/vault/UnderwriterVault.sol";
import "../src/nft/PolicyNFT.sol";
import "../src/insurance/InsurancePool.sol";

contract InsurancePoolExtendedTest is Test {
    MockERC20 token;
    MockAggregator mockFeed;
    ChainlinkOracle oracle;
    UnderwriterVault vault;
    PolicyNFT nft;
    InsurancePool pool;

    address admin      = address(this);
    address user       = address(0x1001);
    address underwriter = address(0x1002);
    address stranger   = address(0x1003);

    bytes32 constant DEPEG   = keccak256("DEPEG");
    bytes32 constant UNKNOWN = keccak256("UNKNOWN_RISK");

    // trigger price: price must DROP BELOW this to allow claim
    uint256 constant TRIGGER = 1_500e18; // 1500 USD (18-dec normalised)
    uint256 constant PREMIUM_BPS = 500;
    uint256 constant DURATION    = 7 days;

    function setUp() public {
        token    = new MockERC20("USD", "USDC");
        mockFeed = new MockAggregator(2000e8, 8);
        oracle   = new ChainlinkOracle(admin, address(mockFeed), 1 days);
        vault    = new UnderwriterVault(token, admin);
        nft      = new PolicyNFT(admin);
        pool     = new InsurancePool(admin, token, oracle, vault, nft);

        nft.grantRole(nft.MINTER_ROLE(), address(pool));
        vault.grantRole(vault.INSURANCE_POOL_ROLE(), address(pool));

        // Fund underwriter & pool liquidity
        token.mint(underwriter, 100_000 ether);
        vm.startPrank(underwriter);
        token.approve(address(vault), 100_000 ether);
        vault.deposit(100_000 ether, underwriter);
        vm.stopPrank();

        // Fund user
        token.mint(user, 10_000 ether);
        vm.prank(user);
        token.approve(address(pool), type(uint256).max);

        pool.setRiskConfig(DEPEG, true, PREMIUM_BPS, TRIGGER, DURATION);
    }

    // ─── setRiskConfig ────────────────────────────────────────────────────────

    function testSetRiskConfigEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit InsurancePool.RiskTypeUpdated(DEPEG, true, PREMIUM_BPS, TRIGGER, DURATION);
        pool.setRiskConfig(DEPEG, true, PREMIUM_BPS, TRIGGER, DURATION);
    }

    function testSetRiskConfigOnlyGovernance() public {
        vm.prank(stranger);
        vm.expectRevert();
        pool.setRiskConfig(DEPEG, true, 100, TRIGGER, DURATION);
    }

    function testDisableRiskConfig() public {
        pool.setRiskConfig(DEPEG, false, PREMIUM_BPS, TRIGGER, DURATION);
        (bool accepted,,,) = pool.riskConfigs(DEPEG);
        assertFalse(accepted);
    }

    function testRiskConfigStoredCorrectly() public {
        bytes32 newRisk = keccak256("HACK");
        pool.setRiskConfig(newRisk, true, 200, 500e18, 14 days);
        (bool accepted, uint256 pBps, uint256 tp, uint256 dur) = pool.riskConfigs(newRisk);
        assertTrue(accepted);
        assertEq(pBps, 200);
        assertEq(tp, 500e18);
        assertEq(dur, 14 days);
    }

    // ─── buyPolicy ────────────────────────────────────────────────────────────

    function testBuyPolicyTransfersPremiumToVault() public {
        uint256 coverage = 1000 ether;
        uint256 expectedPremium = (coverage * PREMIUM_BPS) / 10_000; // 50 ether

        uint256 vaultBefore = token.balanceOf(address(vault));

        vm.prank(user);
        pool.buyPolicy(DEPEG, coverage);

        assertEq(token.balanceOf(address(vault)) - vaultBefore, expectedPremium);
    }

    function testBuyPolicyMintsNFTToUser() public {
        vm.prank(user);
        uint256 id = pool.buyPolicy(DEPEG, 500 ether);
        assertEq(nft.ownerOf(id), user);
    }

    function testBuyPolicyStatusIsActive() public {
        vm.prank(user);
        uint256 id = pool.buyPolicy(DEPEG, 500 ether);
        assertEq(uint256(pool.policyStatus(id)), uint256(InsurancePool.PolicyStatus.Active));
    }

    function testBuyPolicyEmitsEvent() public {
        uint256 coverage = 500 ether;
        uint256 premium  = (coverage * PREMIUM_BPS) / 10_000;

        vm.expectEmit(true, true, true, true);
        emit InsurancePool.PolicyPurchased(user, 1, DEPEG, coverage, premium);

        vm.prank(user);
        pool.buyPolicy(DEPEG, coverage);
    }

    function testBuyPolicySequentialIds() public {
        vm.startPrank(user);
        uint256 id1 = pool.buyPolicy(DEPEG, 100 ether);
        uint256 id2 = pool.buyPolicy(DEPEG, 100 ether);
        uint256 id3 = pool.buyPolicy(DEPEG, 100 ether);
        vm.stopPrank();

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(id3, 3);
    }

    function testBuyPolicyRevertsWhenPaused() public {
        pool.pause();
        vm.prank(user);
        vm.expectRevert();
        pool.buyPolicy(DEPEG, 100 ether);
    }

    function testBuyPolicyRevertsRiskNotAccepted() public {
        vm.prank(user);
        vm.expectRevert(InsurancePool.RiskNotAccepted.selector);
        pool.buyPolicy(UNKNOWN, 100 ether);
    }

    function testBuyPolicyRevertsZeroCoverage() public {
        vm.prank(user);
        vm.expectRevert(InsurancePool.InvalidCoverage.selector);
        pool.buyPolicy(DEPEG, 0);
    }

    // ─── claim ────────────────────────────────────────────────────────────────

    function _buyAndTrigger(uint256 coverage) internal returns (uint256 id) {
        vm.prank(user);
        id = pool.buyPolicy(DEPEG, coverage);
        // Drop price below trigger
        mockFeed.setAnswer(int256(TRIGGER / 1e10) - 1); // just below in 8-dec
    }

    function testClaimPaysCoverageAmount() public {
        uint256 coverage = 1000 ether;
        uint256 id = _buyAndTrigger(coverage);

        uint256 before = token.balanceOf(user);
        vm.prank(user);
        pool.claim(id);

        assertEq(token.balanceOf(user) - before, coverage);
    }

    function testClaimUpdatesStatus() public {
        uint256 id = _buyAndTrigger(200 ether);
        vm.prank(user);
        pool.claim(id);
        assertEq(uint256(pool.policyStatus(id)), uint256(InsurancePool.PolicyStatus.Claimed));
    }

    function testClaimEmitsEvent() public {
        uint256 coverage = 300 ether;
        uint256 id = _buyAndTrigger(coverage);

        vm.expectEmit(true, true, false, true);
        emit InsurancePool.ClaimPaid(user, id, coverage);
        vm.prank(user);
        pool.claim(id);
    }

    function testClaimRevertsNotOwner() public {
        uint256 id = _buyAndTrigger(100 ether);
        vm.prank(stranger);
        vm.expectRevert(InsurancePool.NotPolicyOwner.selector);
        pool.claim(id);
    }

    function testClaimRevertsPriceAboveTrigger() public {
        // price is 2000 > TRIGGER(1500), so no claim
        vm.prank(user);
        uint256 id = pool.buyPolicy(DEPEG, 100 ether);
        vm.prank(user);
        vm.expectRevert(InsurancePool.TriggerNotMet.selector);
        pool.claim(id);
    }

    function testClaimRevertsExpiredPolicy() public {
        uint256 id = _buyAndTrigger(100 ether);
        vm.warp(block.timestamp + DURATION + 1);
        vm.prank(user);
        vm.expectRevert(InsurancePool.PolicyExpired.selector);
        pool.claim(id);
    }

    function testClaimRevertsAlreadyClaimed() public {
        uint256 id = _buyAndTrigger(100 ether);
        vm.startPrank(user);
        pool.claim(id);
        vm.expectRevert(InsurancePool.PolicyNotActive.selector);
        pool.claim(id);
        vm.stopPrank();
    }

    function testClaimRevertsWhenPaused() public {
        uint256 id = _buyAndTrigger(100 ether);
        pool.pause();
        vm.prank(user);
        vm.expectRevert();
        pool.claim(id);
    }

    // ─── pause / unpause ──────────────────────────────────────────────────────

    function testPauseOnlyPauser() public {
        vm.prank(stranger);
        vm.expectRevert();
        pool.pause();
    }

    function testUnpauseOnlyPauser() public {
        pool.pause();
        vm.prank(stranger);
        vm.expectRevert();
        pool.unpause();
    }

    function testPauseStateToggle() public {
        assertFalse(pool.paused());
        pool.pause();
        assertTrue(pool.paused());
        pool.unpause();
        assertFalse(pool.paused());
    }

    // ─── access control roles ─────────────────────────────────────────────────

    function testAdminHasDefaultAdminRole() public view {
        assertTrue(pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), admin));
    }

    function testAdminHasGovernanceRole() public view {
        assertTrue(pool.hasRole(pool.GOVERNANCE_ROLE(), admin));
    }

    function testAdminHasPauserRole() public view {
        assertTrue(pool.hasRole(pool.PAUSER_ROLE(), admin));
    }

    // ─── price-at-exactly-trigger boundary ───────────────────────────────────

    function testClaimAtExactTriggerPriceReverts() public {
        // oracle normalises 8-dec feed → 18-dec; TRIGGER == 1500e18
        // feed answer that maps to exactly 1500e18 is 1500e8
        mockFeed.setAnswer(1500e8);

        vm.prank(user);
        uint256 id = pool.buyPolicy(DEPEG, 100 ether);

        // currentPrice == triggerPrice → NOT strictly less → TriggerNotMet
        vm.prank(user);
        vm.expectRevert(InsurancePool.TriggerNotMet.selector);
        pool.claim(id);
    }

    function testClaimOneBelowTriggerSucceeds() public {
        // 1499.99999999 in 8-dec → normalised just under 1500e18
        mockFeed.setAnswer(149999999999); // 1499.99999999e8

        vm.prank(user);
        uint256 id = pool.buyPolicy(DEPEG, 100 ether);

        vm.prank(user);
        pool.claim(id); // should succeed
    }
}
