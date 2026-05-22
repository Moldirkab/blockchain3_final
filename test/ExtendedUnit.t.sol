// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/mock/MockERC20.sol";
import "../src/oracle/MockAggregator.sol";
import "../src/oracle/ChainlinkOracle.sol";
import "../src/vault/UnderwriterVault.sol";
import "../src/nft/PolicyNFT.sol";
import "../src/token/RiskGovernanceToken.sol";
import "../src/governance/ProtocolTreasury.sol";
import "../src/governance/ProtocolTreasuryV2.sol";
import "../src/factory/InsuranceMarketFactory.sol";
import "../src/utils/PremiumMath.sol";

// ═══════════════════════════════════════════════════════════════════════════════
// Vault extended
// ═══════════════════════════════════════════════════════════════════════════════
contract VaultExtendedTest is Test {
    MockERC20 token;
    UnderwriterVault vault;

    address admin = address(this);
    address user = address(0xA1);
    address pool = address(0xA2);
    address rando = address(0xA3);

    function setUp() public {
        token = new MockERC20("USD", "USDC");
        vault = new UnderwriterVault(token, admin);
        vault.grantRole(vault.INSURANCE_POOL_ROLE(), pool);

        token.mint(user, 10_000 ether);
        vm.prank(user);
        token.approve(address(vault), type(uint256).max);
    }

    function testDepositMintsSharesOneToOne() public {
        vm.prank(user);
        vault.deposit(500 ether, user);
        assertEq(vault.balanceOf(user), 500 ether);
    }

    function testMultipleDepositsAccumulate() public {
        vm.prank(user);
        vault.deposit(200 ether, user);
        vm.prank(user);
        vault.deposit(300 ether, user);
        assertEq(vault.balanceOf(user), 500 ether);
    }

    function testWithdrawReturnsCorrectTokens() public {
        vm.startPrank(user);
        vault.deposit(1000 ether, user);
        vault.withdraw(400 ether, user, user);
        vm.stopPrank();
        assertEq(token.balanceOf(user), 9_400 ether);
    }

    function testRedeem() public {
        vm.startPrank(user);
        vault.deposit(1000 ether, user);
        uint256 shares = vault.balanceOf(user);
        vault.redeem(shares, user, user);
        vm.stopPrank();
        assertEq(vault.balanceOf(user), 0);
        assertEq(token.balanceOf(user), 10_000 ether);
    }

    function testAvailableLiquidity() public {
        vm.prank(user);
        vault.deposit(800 ether, user);
        assertEq(vault.availableLiquidity(), 800 ether);
    }

    function testPayClaimReducesLiquidity() public {
        vm.prank(user);
        vault.deposit(1000 ether, user);

        vm.prank(pool);
        vault.payClaim(rando, 200 ether);

        assertEq(vault.availableLiquidity(), 800 ether);
        assertEq(token.balanceOf(rando), 200 ether);
    }

    function testPayClaimOnlyInsurancePool() public {
        vm.prank(user);
        vault.deposit(500 ether, user);

        vm.prank(rando);
        vm.expectRevert();
        vault.payClaim(rando, 100 ether);
    }

    function testVaultShareSymbol() public view {
        assertEq(vault.symbol(), "uvRISK");
    }

    function testVaultShareName() public view {
        assertEq(vault.name(), "Underwriter Vault Share");
    }

    function testAdminHasDefaultAdminRole() public view {
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Oracle extended
// ═══════════════════════════════════════════════════════════════════════════════
contract OracleExtendedTest is Test {
    MockAggregator mock;
    ChainlinkOracle oracle;

    address admin = address(this);
    address attacker = address(0xB1);

    function setUp() public {
        mock = new MockAggregator(2000e8, 8);
        oracle = new ChainlinkOracle(admin, address(mock), 1 days);
    }

    function testNormalisesLowDecimalFeedTo18() public view {
        // 8-dec feed → price * 10^10
        assertEq(oracle.getLatestPrice(), 2000e18);
    }

    function testNormalisesHighDecimalFeed() public {
        // deploy fresh oracle with 20-decimal feed
        MockAggregator high = new MockAggregator(int256(2000e20), 20);
        ChainlinkOracle o2 = new ChainlinkOracle(admin, address(high), 1 days);
        assertEq(o2.getLatestPrice(), 2000e18);
    }

    function testNormalisesExact18DecimalFeed() public {
        MockAggregator exact = new MockAggregator(int256(2000e18), 18);
        ChainlinkOracle o3 = new ChainlinkOracle(admin, address(exact), 1 days);
        assertEq(o3.getLatestPrice(), 2000e18);
    }

    function testNegativePriceReverts() public {
        mock.setAnswer(-1);
        vm.expectRevert(ChainlinkOracle.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function testSetPriceFeedOnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        oracle.setPriceFeed(address(1));
    }

    function testSetPriceFeed() public {
        MockAggregator newFeed = new MockAggregator(3000e8, 8);
        oracle.setPriceFeed(address(newFeed));
        assertEq(oracle.getLatestPrice(), 3000e18);
    }

    function testSetMaxStalenessOnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        oracle.setMaxStaleness(2 days);
    }

    function testMaxStalenessExtended() public {
        oracle.setMaxStaleness(3 days);

        vm.warp(block.timestamp + 2 days + 1);
        // Should NOT revert (within 3-day window)
        uint256 price = oracle.getLatestPrice();
        assertGt(price, 0);
    }

    function testPriceUpdatesReflected() public {
        mock.setAnswer(3500e8);
        assertEq(oracle.getLatestPrice(), 3500e18);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PolicyNFT extended
// ═══════════════════════════════════════════════════════════════════════════════
contract PolicyNFTExtendedTest is Test {
    PolicyNFT nft;

    address admin = address(this);
    address holder = address(0xC1);
    address minter = address(0xC2);
    address attacker = address(0xC3);

    bytes32 constant DEPEG = keccak256("DEPEG");

    function setUp() public {
        nft = new PolicyNFT(admin);
        nft.grantRole(nft.MINTER_ROLE(), minter);
    }

    function _mint(address to) internal returns (uint256) {
        vm.prank(minter);
        return
            nft.mintPolicy(
                to,
                100 ether,
                5 ether,
                block.timestamp + 7 days,
                DEPEG
            );
    }

    function testNFTName() public view {
        assertEq(nft.name(), "Insurance Policy NFT");
    }
    function testNFTSymbol() public view {
        assertEq(nft.symbol(), "POLICY");
    }

    function testGetPolicyReturnsCorrectData() public {
        uint256 id = _mint(holder);
        PolicyNFT.PolicyData memory p = nft.getPolicy(id);
        assertEq(p.coverageAmount, 100 ether);
        assertEq(p.premium, 5 ether);
        assertEq(p.riskType, DEPEG);
        assertTrue(p.active);
        assertFalse(p.claimed);
    }

    function testIsActiveTrue() public {
        uint256 id = _mint(holder);
        assertTrue(nft.isActive(id));
    }

    function testIsActiveFalseAfterDeactivate() public {
        uint256 id = _mint(holder);
        vm.prank(minter);
        nft.deactivatePolicy(id);
        assertFalse(nft.isActive(id));
    }

    function testMarkClaimedSetsClaimedAndInactive() public {
        uint256 id = _mint(holder);
        vm.prank(minter);
        nft.markClaimed(id);
        PolicyNFT.PolicyData memory p = nft.getPolicy(id);
        assertTrue(p.claimed);
        assertFalse(p.active);
    }

    function testMarkClaimedTwiceReverts() public {
        uint256 id = _mint(holder);
        vm.prank(minter);
        nft.markClaimed(id);
        vm.prank(minter);
        vm.expectRevert();
        nft.markClaimed(id);
    }

    function testDeactivateAlreadyInactiveReverts() public {
        uint256 id = _mint(holder);
        vm.prank(minter);
        nft.deactivatePolicy(id);
        vm.prank(minter);
        vm.expectRevert();
        nft.deactivatePolicy(id);
    }

    function testUnauthorizedMintReverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        nft.mintPolicy(
            holder,
            100 ether,
            5 ether,
            block.timestamp + 1 days,
            DEPEG
        );
    }

    function testUnauthorizedMarkClaimedReverts() public {
        uint256 id = _mint(holder);
        vm.prank(attacker);
        vm.expectRevert();
        nft.markClaimed(id);
    }

    function testMintInvalidHolderReverts() public {
        vm.prank(minter);
        vm.expectRevert();
        nft.mintPolicy(
            address(0),
            100 ether,
            5 ether,
            block.timestamp + 1 days,
            DEPEG
        );
    }

    function testMintInvalidCoverageReverts() public {
        vm.prank(minter);
        vm.expectRevert();
        nft.mintPolicy(holder, 0, 5 ether, block.timestamp + 1 days, DEPEG);
    }

    function testMintExpiredExpiryReverts() public {
        vm.prank(minter);
        vm.expectRevert();
        nft.mintPolicy(holder, 100 ether, 5 ether, block.timestamp - 1, DEPEG);
    }

    function testMintZeroRiskTypeReverts() public {
        vm.prank(minter);
        vm.expectRevert();
        nft.mintPolicy(
            holder,
            100 ether,
            5 ether,
            block.timestamp + 1 days,
            bytes32(0)
        );
    }

    function testSupportsInterfaceERC721() public view {
        assertTrue(nft.supportsInterface(0x80ac58cd)); // ERC721
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Token extended
// ═══════════════════════════════════════════════════════════════════════════════
contract TokenExtendedTest is Test {
    RiskGovernanceToken token;

    address admin = address(this);
    address alice = address(0xD1);
    address bob = address(0xD2);

    function setUp() public {
        token = new RiskGovernanceToken(admin);
    }

    function testInitialMintToAdmin() public view {
        assertEq(token.totalSupply(), 1_000_000 ether);
    }

    function testMintIncreasesTotalSupply() public {
        token.mint(alice, 500 ether);
        assertEq(token.totalSupply(), 1_000_500 ether);
    }

    function testDelegateBeforeTransferVotingPower() public {
        token.transfer(alice, 1000 ether);
        vm.prank(alice);
        token.delegate(alice);
        vm.roll(block.number + 1);
        assertEq(token.getVotes(alice), 1000 ether);
    }

    function testVotingPowerAfterMint() public {
        token.delegate(admin);
        vm.roll(block.number + 1);
        uint256 votesBefore = token.getVotes(admin);
        token.mint(admin, 100 ether);
        vm.roll(block.number + 1);
        assertEq(token.getVotes(admin) - votesBefore, 100 ether);
    }

    function testTransferMovesVotingPower() public {
        token.delegate(admin);
        token.transfer(alice, 200 ether);
        vm.prank(alice);
        token.delegate(alice);
        vm.roll(block.number + 1);
        assertEq(token.getVotes(alice), 200 ether);
    }

    function testTokenName() public view {
        assertEq(token.name(), "Risk Governance Token");
    }
    function testTokenSymbol() public view {
        assertEq(token.symbol(), "RISK");
    }

    function testNonMinterCannotMint() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1 ether);
    }

    function testNoncesInitiallyZero() public view {
        assertEq(token.nonces(alice), 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Factory extended
// ═══════════════════════════════════════════════════════════════════════════════
contract FactoryExtendedTest is Test {
    InsuranceMarketFactory factory;

    address admin = address(0xE1);
    address other = address(0xE2);

    function setUp() public {
        factory = new InsuranceMarketFactory();
    }

    function testCreateGivesAdminMinterRole() public {
        address nftAddr = factory.createPolicyNFT(admin);
        PolicyNFT nft = PolicyNFT(nftAddr);
        assertTrue(nft.hasRole(nft.MINTER_ROLE(), admin));
    }

    function testDifferentAdminsProduceDifferentNFTs() public {
        address a = factory.createPolicyNFT(admin);
        address b = factory.createPolicyNFT(other);
        assertTrue(a != b);
    }

    function testCreate2SameSaltSameAdmin() public {
        bytes32 salt = keccak256("SALT_A");
        address predicted = factory.predictPolicyNFTAddress(admin, salt);
        address actual = factory.createPolicyNFTDeterministic(admin, salt);
        assertEq(predicted, actual);
    }

    function testCreate2DifferentSaltsAreDifferent() public {
        bytes32 s1 = keccak256("SALT_1");
        bytes32 s2 = keccak256("SALT_2");
        address a1 = factory.createPolicyNFTDeterministic(admin, s1);
        address a2 = factory.createPolicyNFTDeterministic(admin, s2);
        assertTrue(a1 != a2);
    }

    function testEmitsEventOnCreate() public {
        vm.expectEmit(false, true, false, false);
        emit InsuranceMarketFactory.PolicyNFTCreated(address(0), admin);
        factory.createPolicyNFT(admin);
    }

    function testEmitsEventOnCreateDeterministic() public {
        bytes32 salt = keccak256("EMIT_SALT");
        vm.expectEmit(false, true, true, false);
        emit InsuranceMarketFactory.PolicyNFTCreatedDeterministic(
            address(0),
            admin,
            salt
        );
        factory.createPolicyNFTDeterministic(admin, salt);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PremiumMath extended
// ═══════════════════════════════════════════════════════════════════════════════
contract PremiumMathExtendedTest is Test {
    PremiumMath math;

    function setUp() public {
        math = new PremiumMath();
    }

    function testZeroCoverageReturnsZero() public view {
        assertEq(math.calculatePremiumSolidity(0, 500, 30), 0);
        assertEq(math.calculatePremiumYul(0, 500, 30), 0);
    }

    function testZeroRiskBpsReturnsZero() public view {
        assertEq(math.calculatePremiumSolidity(1000 ether, 0, 30), 0);
        assertEq(math.calculatePremiumYul(1000 ether, 0, 30), 0);
    }

    function testZeroDurationReturnsZero() public view {
        assertEq(math.calculatePremiumSolidity(1000 ether, 500, 0), 0);
        assertEq(math.calculatePremiumYul(1000 ether, 500, 0), 0);
    }

    function testKnownValue() public view {
        // 10_000 ether * 500 bps * 30 days / 36500 = ~410958904109589041095 wei
        uint256 expected = (uint256(10_000 ether) * 500 * 30) / 365 / 100;
        assertEq(
            math.calculatePremiumSolidity(10_000 ether, 500, 30),
            expected
        );
    }

    function testSolidityAndYulAlwaysMatch(
        uint256 coverage,
        uint256 riskBps,
        uint256 durationDays
    ) public view {
        // bound to avoid arithmetic overflow
        coverage = bound(coverage, 0, 1e28);
        riskBps = bound(riskBps, 0, 10_000);
        durationDays = bound(durationDays, 0, 3650);
        assertEq(
            math.calculatePremiumSolidity(coverage, riskBps, durationDays),
            math.calculatePremiumYul(coverage, riskBps, durationDays)
        );
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Treasury extended
// ═══════════════════════════════════════════════════════════════════════════════
contract TreasuryExtendedTest is Test {
    MockERC20 token;
    ProtocolTreasury treasury;

    address admin = address(this);
    address treasurer = address(0xF1);
    address attacker = address(0xF2);
    address receiver = address(0xF3);

    function setUp() public {
        token = new MockERC20("USD", "USDC");

        ProtocolTreasury impl = new ProtocolTreasury();
        bytes memory data = abi.encodeCall(
            ProtocolTreasury.initialize,
            (admin, 300)
        );
        treasury = ProtocolTreasury(
            address(new ERC1967Proxy(address(impl), data))
        );

        treasury.grantRole(treasury.TREASURER_ROLE(), treasurer);
    }

    function testInitialFee() public view {
        assertEq(treasury.protocolFeeBps(), 300);
    }

    function testSetFeeByTreasurer() public {
        vm.prank(treasurer);
        treasury.setProtocolFeeBps(800);
        assertEq(treasury.protocolFeeBps(), 800);
    }

    function testSetFeeRevertsTooHigh() public {
        vm.prank(treasurer);
        vm.expectRevert();
        treasury.setProtocolFeeBps(1001);
    }

    function testSetFeeRevertsUnauthorised() public {
        vm.prank(attacker);
        vm.expectRevert();
        treasury.setProtocolFeeBps(100);
    }

    function testWithdrawToken() public {
        token.mint(address(treasury), 500 ether);

        vm.prank(treasurer);
        treasury.withdrawToken(address(token), receiver, 200 ether);

        assertEq(token.balanceOf(receiver), 200 ether);
    }

    function testWithdrawTokenUnauthorised() public {
        token.mint(address(treasury), 500 ether);
        vm.prank(attacker);
        vm.expectRevert();
        treasury.withdrawToken(address(token), attacker, 100 ether);
    }

    function testWithdrawToZeroAddressReverts() public {
        token.mint(address(treasury), 500 ether);
        vm.prank(treasurer);
        vm.expectRevert();
        treasury.withdrawToken(address(token), address(0), 100 ether);
    }

    function testUpgradeV1ToV2PreservesState() public {
        vm.prank(treasurer);
        treasury.setProtocolFeeBps(700);

        ProtocolTreasuryV2 v2impl = new ProtocolTreasuryV2();
        treasury.upgradeToAndCall(address(v2impl), "");

        ProtocolTreasuryV2 v2 = ProtocolTreasuryV2(address(treasury));
        assertEq(v2.protocolFeeBps(), 700); // state preserved
        assertEq(v2.version(), "V2");
    }

    function testV2EmergencyReserveCap() public {
        ProtocolTreasuryV2 v2impl = new ProtocolTreasuryV2();
        treasury.upgradeToAndCall(address(v2impl), "");
        ProtocolTreasuryV2 v2 = ProtocolTreasuryV2(address(treasury));

        vm.expectRevert();
        v2.setEmergencyReserveBps(5001);
    }

    function testDoubleInitializeReverts() public {
        vm.expectRevert();
        treasury.initialize(admin, 100);
    }

    function testFeeUpdatedEventEmitted() public {
        vm.prank(treasurer);
        vm.expectEmit(false, false, false, true);
        emit ProtocolTreasury.ProtocolFeeUpdated(300, 500);
        treasury.setProtocolFeeBps(500);
    }
}
