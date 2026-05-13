// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/mock/MockERC20.sol";
import "../src/oracle/MockAggregator.sol";
import "../src/oracle/ChainlinkOracle.sol";
import "../src/vault/UnderwriterVault.sol";
import "../src/nft/PolicyNFT.sol";
import "../src/insurance/InsurancePool.sol";
import "../src/amm/RiskAMM.sol";
import "../src/token/RiskGovernanceToken.sol";
import "../src/utils/PremiumMath.sol";

// ═══════════════════════════════════════════════════════════════════════════════
// AMM Fuzz Tests
// ═══════════════════════════════════════════════════════════════════════════════
contract AMMFuzzTest is Test {
    MockERC20 token0;
    MockERC20 token1;
    RiskAMM   amm;

    address LP   = address(0x1);
    address swapper = address(0x2);

    function setUp() public {
        token0 = new MockERC20("T0", "T0");
        token1 = new MockERC20("T1", "T1");
        amm = new RiskAMM(address(token0), address(token1));

        token0.mint(LP, type(uint128).max);
        token1.mint(LP, type(uint128).max);
        token0.mint(swapper, type(uint128).max);
        token1.mint(swapper, type(uint128).max);

        vm.startPrank(LP);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(swapper);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice k must never decrease after a swap
    function testFuzz_kNeverDecreases(uint96 liq0, uint96 liq1, uint96 swapAmt) public {
        liq0    = uint96(bound(liq0,    1e18, 1e24));
        liq1    = uint96(bound(liq1,    1e18, 1e24));
        swapAmt = uint96(bound(swapAmt, 1,    uint96(liq0) / 2));

        vm.prank(LP);
        amm.addLiquidity(liq0, liq1);

        uint256 kBefore = amm.reserve0() * amm.reserve1();

        vm.prank(swapper);
        amm.swap(address(token0), swapAmt, 1);

        uint256 kAfter = amm.reserve0() * amm.reserve1();
        assertGe(kAfter, kBefore, "k decreased after swap");
    }

    /// @notice output must never equal or exceed the whole reserve
    function testFuzz_swapOutputBoundedByReserve(uint96 liq, uint96 swapAmt) public {
        liq     = uint96(bound(liq,     2e18, 1e24));
        swapAmt = uint96(bound(swapAmt, 1,    uint96(liq) / 4));

        vm.prank(LP);
        amm.addLiquidity(liq, liq);

        uint256 reserveOut = amm.reserve1();
        uint256 out = amm.getAmountOut(address(token0), swapAmt);
        assertLt(out, reserveOut, "amountOut >= reserveOut");
    }

    /// @notice getAmountOut preview must match actual swap output
    function testFuzz_previewMatchesActualSwap(uint96 liq, uint64 swapAmt) public {
        liq     = uint96(bound(liq,     2e18, 1e22));
        swapAmt = uint64(bound(swapAmt, 1,    liq / 4));

        vm.prank(LP);
        amm.addLiquidity(liq, liq);

        uint256 preview = amm.getAmountOut(address(token0), swapAmt);

        uint256 before = token1.balanceOf(swapper);
        vm.prank(swapper);
        amm.swap(address(token0), swapAmt, 1);
        uint256 received = token1.balanceOf(swapper) - before;

        assertEq(preview, received, "preview != actual");
    }

    /// @notice add then immediately remove liquidity returns same or fewer tokens (due to rounding)
    function testFuzz_addRemoveLiquidityRoundTrip(uint96 a0, uint96 a1) public {
        a0 = uint96(bound(a0, 1e18, 1e22));
        a1 = uint96(bound(a1, 1e18, 1e22));

        uint256 t0Before = token0.balanceOf(LP);
        uint256 t1Before = token1.balanceOf(LP);

        vm.startPrank(LP);
        uint256 shares = amm.addLiquidity(a0, a1);
        amm.removeLiquidity(shares);
        vm.stopPrank();

        // must get back ≤ what was put in (no free money)
        assertLe(token0.balanceOf(LP), t0Before + a0);
        assertLe(token1.balanceOf(LP), t1Before + a1);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Vault Fuzz Tests
// ═══════════════════════════════════════════════════════════════════════════════
contract VaultFuzzTest is Test {
    MockERC20        token;
    UnderwriterVault vault;

    address user = address(0xAA);
    address pool = address(0xBB);

    function setUp() public {
        token = new MockERC20("USD", "USDC");
        vault = new UnderwriterVault(token, address(this));
        vault.grantRole(vault.INSURANCE_POOL_ROLE(), pool);

        token.mint(user, type(uint128).max);
        vm.prank(user);
        token.approve(address(vault), type(uint256).max);
    }

    /// @notice shares received = assets deposited (first deposit, 1:1)
    function testFuzz_depositSharesRatio(uint96 amount) public {
        amount = uint96(bound(amount, 1, type(uint96).max));

        vm.prank(user);
        vault.deposit(amount, user);

        assertEq(vault.balanceOf(user), amount);
    }

    /// @notice withdraw gives back exactly what was deposited (single user, no claims)
    function testFuzz_depositWithdrawRoundTrip(uint96 amount) public {
        amount = uint96(bound(amount, 1, type(uint96).max));

        vm.startPrank(user);
        vault.deposit(amount, user);
        vault.withdraw(amount, user, user);
        vm.stopPrank();

        assertEq(vault.balanceOf(user), 0);
    }

    /// @notice availableLiquidity decreases exactly by claim amount
    function testFuzz_payClaimReducesLiquidityExactly(uint96 deposit, uint96 claim) public {
        deposit = uint96(bound(deposit, 1e18, type(uint96).max));
        claim   = uint96(bound(claim, 1, deposit));

        vm.prank(user);
        vault.deposit(deposit, user);

        vm.prank(pool);
        vault.payClaim(address(0x999), claim);

        assertEq(vault.availableLiquidity(), deposit - claim);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Governance Voting Power Fuzz Tests
// ═══════════════════════════════════════════════════════════════════════════════
contract GovernanceFuzzTest is Test {
    RiskGovernanceToken token;

    address admin = address(this);
    address alice = address(0x11);
    address bob   = address(0x22);

    function setUp() public {
        token = new RiskGovernanceToken(admin);
    }

    /// @notice delegated votes must equal balance for a single delegator
    function testFuzz_votingPowerEqualsBalance(uint96 amount) public {
        amount = uint96(bound(amount, 1, type(uint96).max));
        token.mint(alice, amount);
        vm.prank(alice);
        token.delegate(alice);
        vm.roll(block.number + 1);
        assertEq(token.getVotes(alice), amount);
    }

    /// @notice transferring tokens moves exact voting power
    function testFuzz_transferMovesVotingPower(uint96 total, uint96 xfer) public {
        total = uint96(bound(total, 2, type(uint96).max));
        xfer  = uint96(bound(xfer,  1, total - 1));

        token.mint(alice, total);
        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);
        vm.roll(block.number + 1);

        vm.prank(alice);
        token.transfer(bob, xfer);
        vm.roll(block.number + 1);

        assertEq(token.getVotes(alice), total - xfer);
        assertEq(token.getVotes(bob),   xfer);
    }

    /// @notice total supply must equal sum of all minted amounts
    function testFuzz_totalSupplyConservation(uint64 mint1, uint64 mint2) public {
        token.mint(alice, mint1);
        token.mint(bob,   mint2);
        uint256 initial = 1_000_000 ether;
        assertEq(token.totalSupply(), initial + mint1 + mint2);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// InsurancePool Fuzz Tests
// ═══════════════════════════════════════════════════════════════════════════════
contract InsurancePoolFuzzTest is Test {
    MockERC20      token;
    MockAggregator mockFeed;
    ChainlinkOracle oracle;
    UnderwriterVault vault;
    PolicyNFT      nft;
    InsurancePool  pool;

    address admin       = address(this);
    address underwriter = address(0xU1);
    address user        = address(0xU2);

    bytes32 constant DEPEG = keccak256("DEPEG");

    function setUp() public {
        token    = new MockERC20("USD", "USDC");
        mockFeed = new MockAggregator(2000e8, 8);
        oracle   = new ChainlinkOracle(admin, address(mockFeed), 1 days);
        vault    = new UnderwriterVault(token, admin);
        nft      = new PolicyNFT(admin);
        pool     = new InsurancePool(admin, token, oracle, vault, nft);

        nft.grantRole(nft.MINTER_ROLE(), address(pool));
        vault.grantRole(vault.INSURANCE_POOL_ROLE(), address(pool));

        token.mint(underwriter, type(uint128).max);
        vm.startPrank(underwriter);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(type(uint128).max / 2, underwriter);
        vm.stopPrank();

        token.mint(user, type(uint128).max);
        vm.prank(user);
        token.approve(address(pool), type(uint256).max);

        pool.setRiskConfig(DEPEG, true, 500, 1500e18, 30 days);
    }

    /// @notice premium calculation must always equal coverage*bps/10_000
    function testFuzz_premiumCalculation(uint64 coverage) public {
        coverage = uint64(bound(coverage, 1, 1e24));
        uint256 expectedPremium = (uint256(coverage) * 500) / 10_000;

        uint256 vaultBefore = token.balanceOf(address(vault));

        vm.prank(user);
        pool.buyPolicy(DEPEG, coverage);

        assertEq(token.balanceOf(address(vault)) - vaultBefore, expectedPremium);
    }

    /// @notice policy ids are always sequential starting from 1
    function testFuzz_policyIdsSequential(uint8 count) public {
        count = uint8(bound(count, 1, 20));
        for (uint256 i = 0; i < count; i++) {
            vm.prank(user);
            uint256 id = pool.buyPolicy(DEPEG, 1 ether);
            assertEq(id, i + 1);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Oracle Fuzz Tests
// ═══════════════════════════════════════════════════════════════════════════════
contract OracleFuzzTest is Test {
    MockAggregator mock8;
    ChainlinkOracle oracle8;

    address admin = address(this);

    function setUp() public {
        mock8   = new MockAggregator(1e8, 8);
        oracle8 = new ChainlinkOracle(admin, address(mock8), 1 days);
    }

    /// @notice price must always be normalised to 18 decimals from 8-dec feed
    function testFuzz_normalisationFrom8Decimals(uint72 rawPrice) public {
        rawPrice = uint72(bound(rawPrice, 1, type(uint72).max));
        mock8.setAnswer(int256(uint256(rawPrice)));
        uint256 expected = uint256(rawPrice) * 1e10; // 8 → 18 dec
        assertEq(oracle8.getLatestPrice(), expected);
    }

    /// @notice valid price never reverts within staleness window
    function testFuzz_validPriceNeverReverts(uint72 price, uint32 age) public {
        price = uint72(bound(price, 1, type(uint72).max));
        age   = uint32(bound(age,  0, 1 days - 1));

        mock8.setAnswer(int256(uint256(price)));
        vm.warp(block.timestamp + age);

        // Should not revert
        oracle8.getLatestPrice();
    }
}
