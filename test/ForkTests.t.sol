// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ─────────────────────────────────────────────────────────────────────────────
// Fork Tests
//
// Requires the following env vars (set in .env or CI secrets):
//
//   ETH_SEPOLIA_RPC_URL          – for ForkTestChainlinkSepolia
//   MAINNET_RPC_URL              – for MainnetForkVaultWithRealUSDC / MainnetForkUniswapV2
//   RPC_URL_ARBITRUM_SEPOLIA     – for ForkTests
//
// Run all fork tests:
//   forge test --match-path test/Fork.t.sol -vv
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
    function getAmountsOut(
        uint256,
        address[] calldata
    ) external view returns (uint256[] memory);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
}

// ── minimal Chainlink interface ───────────────────────────────────────────────
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function decimals() external view returns (uint8);
}

// ─────────────────────────────────────────────────────────────────────────────
// Fork Test 1: Real Chainlink ETH/USD feed (Sepolia)
// ─────────────────────────────────────────────────────────────────────────────
contract ForkTestChainlinkSepolia is Test {
    address constant ETH_USD_FEED_SEPOLIA =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;

    ChainlinkOracle oracle;
    address admin = address(this);

    function setUp() public {
        string memory rpc = vm.envOr("ETH_SEPOLIA_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);

        oracle = new ChainlinkOracle(admin, ETH_USD_FEED_SEPOLIA, 2 hours);
    }

    /// @notice Real Chainlink feed returns a positive price
    function testFork_sepoliaChainlinkPricePositive() public {
        if (block.chainid != 11155111) return;
        uint256 price = oracle.getLatestPrice();
        assertGt(price, 0, "price must be > 0");
        assertGt(price, 100e18, "price suspiciously low");
        assertLt(price, 100_000e18, "price suspiciously high");
    }

    /// @notice Oracle normalises 8-dec Chainlink feed to 18 decimals
    function testFork_sepoliaNormalisedTo18Dec() public {
        if (block.chainid != 11155111) return;

        IPriceFeed feed = IPriceFeed(ETH_USD_FEED_SEPOLIA);
        (, int256 rawAnswer, , , ) = feed.latestRoundData();
        uint256 expected = uint256(rawAnswer) * 1e10;
        assertEq(oracle.getLatestPrice(), expected);
    }

    /// @notice Stale check fires when warp beyond max staleness
    function testFork_sepoliaStaleCheckReverts() public {
        if (block.chainid != 11155111) return;

        vm.warp(block.timestamp + 3 hours);
        vm.expectRevert(ChainlinkOracle.StalePrice.selector);
        oracle.getLatestPrice();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fork Test 2: Real USDC on Mainnet — deposit into our Vault
// ─────────────────────────────────────────────────────────────────────────────
contract MainnetForkVaultWithRealUSDC is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_WHALE = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;

    UnderwriterVault vault;
    address admin = address(this);
    address user = address(0xBEEF);

    function setUp() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);

        vault = new UnderwriterVault(IERC20(USDC), admin);
        vault.grantRole(vault.INSURANCE_POOL_ROLE(), admin);

        vm.prank(USDC_WHALE);
        IERC20Min(USDC).transfer(user, 1_000e6);
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
        vm.prank(admin);
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
// ─────────────────────────────────────────────────────────────────────────────
contract MainnetForkUniswapV2 is Test {
    address constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC_WHALE = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;

    address trader = address(0xDEAD);

    function setUp() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);

        vm.prank(USDC_WHALE);
        IERC20Min(USDC).transfer(trader, 10_000e6);
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
        assertGt(amounts[1], 0.1 ether, "amountOut too low");
        assertLt(amounts[1], 10 ether, "amountOut too high");
    }

    /// @notice Execute USDC→WETH swap via Uniswap V2 Router
    function testFork_uniswapV2SwapUSDCForWETH() public {
        if (block.chainid != 1) return;

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WETH;

        uint256 amountIn = 1_000e6;

        vm.startPrank(trader);
        IERC20Min(USDC).approve(UNISWAP_V2_ROUTER, amountIn);

        uint256[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                amountIn,
                1,
                path,
                trader,
                block.timestamp + 300
            );
        vm.stopPrank();

        assertGt(IERC20Min(WETH).balanceOf(trader), 0, "no WETH received");
        assertEq(amounts[0], amountIn, "amountIn mismatch");
    }

    /// @notice Chainlink ETH/USD price is consistent with Uniswap V2 price
    function testFork_chainlinkPriceConsistentWithUniswap() public {
        if (block.chainid != 1) return;

        address ETH_USD_MAINNET = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        ChainlinkOracle oracle = new ChainlinkOracle(
            address(this),
            ETH_USD_MAINNET,
            1 hours
        );
        uint256 chainlinkPrice = oracle.getLatestPrice();

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        uint256[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .getAmountsOut(1 ether, path);

        uint256 uniswapPrice = amounts[1] * 1e12;

        uint256 diff = chainlinkPrice > uniswapPrice
            ? chainlinkPrice - uniswapPrice
            : uniswapPrice - chainlinkPrice;

        uint256 tolerance = chainlinkPrice / 20; // 5%
        assertLt(diff, tolerance, "Chainlink and Uniswap prices diverge >5%");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fork Test 4: Chainlink ETH/USD feed on Arbitrum Sepolia
// ─────────────────────────────────────────────────────────────────────────────
contract ForkTests is Test {
    // Chainlink ETH/USD on Arbitrum Sepolia
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

    AggregatorV3Interface feed;

    function setUp() public {
        string memory rpc = vm.envOr(
            "RPC_URL_ARBITRUM_SEPOLIA",
            string("https://arb-sepolia.g.alchemy.com/v2/CP2imA50kqeBQroKNyVKJ")
        );
        vm.createSelectFork(rpc);

        feed = AggregatorV3Interface(ETH_USD_FEED);
    }

    /// @notice Chainlink ETH/USD feed returns a positive price on Arb Sepolia
    function testFork_ChainlinkFeed() public {
        (, int256 price, , uint256 updatedAt, ) = feed.latestRoundData();

        assertGt(price, 0, "price must be positive");

        uint256 normalised = uint256(price) * (10 ** (18 - feed.decimals()));
        assertGt(normalised, 100e18, "price suspiciously low");
        assertLt(normalised, 100_000e18, "price suspiciously high");

        assertGt(updatedAt, block.timestamp - 1 hours, "stale price");
    }

    /// @notice Feed reports 8 decimals as expected
    function testFork_FeedDecimals() public {
        assertEq(feed.decimals(), 8, "expected 8-decimal feed");
    }

    /// @notice Normalising 8-dec answer to 18 dec works correctly
    function testFork_NormalisedPrice() public {
        (, int256 rawAnswer, , , ) = feed.latestRoundData();
        uint256 normalised = uint256(rawAnswer) *
            (10 ** (18 - feed.decimals()));
        uint256 expected = uint256(rawAnswer) * 1e10;
        assertEq(normalised, expected, "normalisation mismatch");
        assertGt(normalised, 0, "normalised price must be positive");
    }
}
