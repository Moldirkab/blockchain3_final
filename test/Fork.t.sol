// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ─────────────────────────────────────────────────────────────────────────────
// Fork Tests
//
// These tests run against a live fork.  Set ETH_SEPOLIA_RPC_URL (Sepolia) or
// MAINNET_RPC_URL (mainnet) in your environment before running:
//
//   forge test --match-contract ForkTest --fork-url $ETH_SEPOLIA_RPC_URL -vv
//   forge test --match-contract MainnetFork --fork-url $MAINNET_RPC_URL -vv
//
// In CI supply the env var via GitHub secrets.
// ─────────────────────────────────────────────────────────────────────────────

import "forge-std/Test.sol";
import "../src/oracle/ChainlinkOracle.sol";
import "../src/oracle/IPriceFeed.sol";
import "../src/vault/UnderwriterVault.sol";
import "../src/nft/PolicyNFT.sol";
import "../src/insurance/InsurancePool.sol";

// ── minimal ERC-20 interface for real tokens ──────────────────────────────────
interface IERC20Min {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

// ── Uniswap V2 Router interface (subset) ─────────────────────────────────────
interface IUniswapV2Router {
    function getAmountsOut(uint256, address[] calldata) external view returns (uint256[] memory);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
}

// ─────────────────────────────────────────────────────────────────────────────
// Fork Test 1: Real Chainlink ETH/USD feed (Sepolia)
// ─────────────────────────────────────────────────────────────────────────────
contract ForkTestChainlinkSepolia is Test {
    // Chainlink ETH/USD on Sepolia (Aug 2024 address – still active as of 2025)
    address constant ETH_USD_FEED_SEPOLIA = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    ChainlinkOracle oracle;
    address admin = address(this);

    function setUp() public {
        // Fork Sepolia; skip if RPC not set
        string memory rpc = vm.envOr("ETH_SEPOLIA_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);

        oracle = new ChainlinkOracle(admin, ETH_USD_FEED_SEPOLIA, 2 hours);
    }

    /// @notice Real Chainlink feed returns a positive price
    function testFork_sepoliaChainlinkPricePositive() public {
        if (block.chainid != 11155111) return; // skip if not on Sepolia fork
        uint256 price = oracle.getLatestPrice();
        assertGt(price, 0, "price must be > 0");
        // ETH price should be between $100 and $100,000
        assertGt(price, 100e18,    "price suspiciously low");
        assertLt(price, 100_000e18,"price suspiciously high");
    }

    /// @notice Oracle normalises 8-dec Chainlink feed to 18 decimals
    function testFork_sepoliaNormalisedTo18Dec() public {
        if (block.chainid != 11155111) return;

        // raw Chainlink answer has 8 decimals; oracle should return 18-dec value
        IPriceFeed feed = IPriceFeed(ETH_USD_FEED_SEPOLIA);
        (, int256 rawAnswer,,,) = feed.latestRoundData();
        uint256 expected = uint256(rawAnswer) * 1e10;
        assertEq(oracle.getLatestPrice(), expected);
    }

    /// @notice Stale check fires when warp beyond max staleness
    function testFork_sepoliaStaleCheckReverts() public {
        if (block.chainid != 11155111) return;

        // The fork reflects a recent block; warp 3 hours ahead (> 2h staleness)
        vm.warp(block.timestamp + 3 hours);
        vm.expectRevert(ChainlinkOracle.StalePrice.selector);
        oracle.getLatestPrice();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fork Test 2: Real USDC on Mainnet — deposit into our Vault
// ─────────────────────────────────────────────────────────────────────────────
contract MainnetForkVaultWithRealUSDC is Test {
    // Mainnet USDC (6 decimals)
    address constant USDC         = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // A large USDC holder (Circle treasury / Binance hot wallet; still well-funded)
    address constant USDC_WHALE   = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;

    UnderwriterVault vault;
    address admin = address(this);
    address user  = address(0xBEEF);

    function setUp() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);

        // Deploy vault backed by real USDC
        vault = new UnderwriterVault(IERC20Min(USDC), admin);
        vault.grantRole(vault.INSURANCE_POOL_ROLE(), admin);

        // Give our test user some USDC by impersonating the whale
        vm.prank(USDC_WHALE);
        IERC20Min(USDC).transfer(user, 1_000e6); // 1,000 USDC
    }

    /// @notice User can deposit real USDC into our vault
    function testFork_depositRealUSDC() public {
        if (block.chainid != 1) return;

        vm.startPrank(user);
        IERC20Min(USDC).approve(address(vault), 1_000e6);
        vault.deposit(1_000e6, user);
        vm.stopPrank();

        assertEq(vault.balanceOf(user), 1_000e6);
        assertEq(vault.availableLiquidity(), 1_000e6);
    }

    /// @notice Vault can pay a claim in real USDC
    function testFork_payClaimInRealUSDC() public {
        if (block.chainid != 1) return;

        vm.startPrank(user);
        IERC20Min(USDC).approve(address(vault), 1_000e6);
        vault.deposit(1_000e6, user);
        vm.stopPrank();

        address claimant = address(0xCAFE);
        vm.prank(admin); // admin has INSURANCE_POOL_ROLE
        vault.payClaim(claimant, 500e6);

        assertEq(IERC20Min(USDC).balanceOf(claimant), 500e6);
        assertEq(vault.availableLiquidity(), 500e6);
    }

    /// @notice Withdraw real USDC after deposit
    function testFork_withdrawRealUSDC() public {
        if (block.chainid != 1) return;

        vm.startPrank(user);
        IERC20Min(USDC).approve(address(vault), 1_000e6);
        vault.deposit(1_000e6, user);
        vault.withdraw(400e6, user, user);
        vm.stopPrank();

        assertEq(IERC20Min(USDC).balanceOf(user), 400e6);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fork Test 3: Uniswap V2 Router interaction on Mainnet
//   — get a USDC→WETH quote, then execute it
// ─────────────────────────────────────────────────────────────────────────────
contract MainnetForkUniswapV2 is Test {
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant USDC              = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH              = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC_WHALE        = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;

    address trader = address(0xDEAD);

    function setUp() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);

        // Fund trader with USDC
        vm.prank(USDC_WHALE);
        IERC20Min(USDC).transfer(trader, 10_000e6); // 10,000 USDC
    }

    /// @notice getAmountsOut returns a positive WETH amount for 1,000 USDC
    function testFork_uniswapV2GetAmountsOut() public {
        if (block.chainid != 1) return;

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WETH;

        uint256[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .getAmountsOut(1_000e6, path);

        assertEq(amounts.length, 2);
        assertGt(amounts[1], 0, "amountOut should be positive");
        // 1000 USDC → between 0.1 and 1 ETH at reasonable prices
        assertGt(amounts[1], 0.1 ether,  "amountOut too low");
        assertLt(amounts[1], 10 ether,   "amountOut too high");
    }

    /// @notice Execute USDC→WETH swap via Uniswap V2 Router
    function testFork_uniswapV2SwapUSDCForWETH() public {
        if (block.chainid != 1) return;

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WETH;

        uint256 amountIn = 1_000e6; // 1,000 USDC

        vm.startPrank(trader);
        IERC20Min(USDC).approve(UNISWAP_V2_ROUTER, amountIn);

        uint256[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                amountIn,
                1,                       // minAmountOut = 1 wei (test environment)
                path,
                trader,
                block.timestamp + 300
            );
        vm.stopPrank();

        assertGt(IERC20Min(WETH).balanceOf(trader), 0, "no WETH received");
        assertEq(amounts[0], amountIn, "amountIn mismatch");
    }

    /// @notice Real Chainlink ETH/USD price is consistent with Uniswap V2 price
    function testFork_chainlinkPriceConsistentWithUniswap() public {
        if (block.chainid != 1) return;

        // Mainnet Chainlink ETH/USD
        address ETH_USD_MAINNET = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        ChainlinkOracle oracle = new ChainlinkOracle(address(this), ETH_USD_MAINNET, 1 hours);
        uint256 chainlinkPrice = oracle.getLatestPrice(); // 18-dec USD per ETH

        // Get Uniswap implied price: how many USDC for 1 WETH
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        uint256[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .getAmountsOut(1 ether, path);

        // amounts[1] is in 6-dec USDC; normalise to 18 dec
        uint256 uniswapPrice = amounts[1] * 1e12;

        // Prices should be within 5% of each other
        uint256 diff = chainlinkPrice > uniswapPrice
            ? chainlinkPrice - uniswapPrice
            : uniswapPrice - chainlinkPrice;

        uint256 tolerance = chainlinkPrice / 20; // 5%
        assertLt(diff, tolerance, "Chainlink and Uniswap prices diverge >5%");
    }
}
