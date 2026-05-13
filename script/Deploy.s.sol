// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../src/mock/MockERC20.sol";
import "../src/oracle/MockAggregator.sol";

import "../src/oracle/ChainlinkOracle.sol";
import "../src/vault/UnderwriterVault.sol";
import "../src/nft/PolicyNFT.sol";
import "../src/insurance/InsurancePool.sol";

import "../src/token/RiskGovernanceToken.sol";
import "../src/governance/ProtocolTreasury.sol";
import "../src/governance/RiskGovernor.sol";

import "../src/factory/InsuranceMarketFactory.sol";
import "../src/utils/PremiumMath.sol";
import "../src/amm/RiskAMM.sol";

contract Deploy is Script {
    address deployer;

    MockERC20 stableToken;
    RiskGovernanceToken govToken;
    MockAggregator mockFeed;
    ChainlinkOracle oracle;

    UnderwriterVault vault;
    PolicyNFT policyNFT;
    InsurancePool pool;

    ProtocolTreasury treasuryImpl;
    ProtocolTreasury treasuryProxy;

    TimelockController timelock;
    RiskGovernor governor;

    InsuranceMarketFactory factory;
    PremiumMath premiumMath;
    RiskAMM amm;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        deployCore();
        deployGovernance();
        deployUtilities();
        wireRoles();

        vm.stopBroadcast();

        log();
    }

    function deployCore() internal {
        stableToken = new MockERC20("USD Stable", "USDC");
        govToken = new RiskGovernanceToken(deployer);

        mockFeed = new MockAggregator(2000e8, 8);
        oracle = new ChainlinkOracle(deployer, address(mockFeed), 1 days);

        vault = new UnderwriterVault(IERC20(address(stableToken)), deployer);
        policyNFT = new PolicyNFT(deployer);

        pool = new InsurancePool(
            deployer,
            IERC20(address(stableToken)),
            oracle,
            vault,
            policyNFT
        );

        amm = new RiskAMM(address(stableToken), address(govToken));
    }

    function deployGovernance() internal {
        address[] memory proposers = new address[](1);
        proposers[0] = address(0);

        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(
            2 days,
            proposers,
            executors,
            deployer
        );

        governor = new RiskGovernor(
            IVotes(address(govToken)),
            govToken,
            timelock
        );

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        treasuryImpl = new ProtocolTreasury();

        bytes memory initData = abi.encodeCall(
            ProtocolTreasury.initialize,
            (deployer, 300)
        );

        treasuryProxy = ProtocolTreasury(
            address(new ERC1967Proxy(address(treasuryImpl), initData))
        );
    }

    function deployUtilities() internal {
        factory = new InsuranceMarketFactory();
        premiumMath = new PremiumMath();
    }

    function wireRoles() internal {
        policyNFT.grantRole(policyNFT.MINTER_ROLE(), address(pool));
        vault.grantRole(vault.INSURANCE_POOL_ROLE(), address(pool));
        treasuryProxy.grantRole(
            treasuryProxy.TREASURER_ROLE(),
            address(timelock)
        );
        treasuryProxy.grantRole(
            treasuryProxy.UPGRADER_ROLE(),
            address(timelock)
        );

        pool.grantRole(pool.GOVERNANCE_ROLE(), address(timelock));
        pool.grantRole(pool.PAUSER_ROLE(), address(timelock));

        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), address(timelock));

        govToken.delegate(deployer);

        pool.setRiskConfig(keccak256("DEPEG"), true, 500, 95_000_000, 30 days);
    }

    function log() internal view {
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Deployer:        ", deployer);
        console.log("");
        console.log("--- Core ---");
        console.log("Stable Token:    ", address(stableToken));
        console.log("Governance Token:", address(govToken));
        console.log("MockAggregator:  ", address(mockFeed));
        console.log("Oracle:          ", address(oracle));
        console.log("Vault:           ", address(vault));
        console.log("PolicyNFT:       ", address(policyNFT));
        console.log("InsurancePool:   ", address(pool));
        console.log("AMM:             ", address(amm));
        console.log("");
        console.log("--- Governance ---");
        console.log("Timelock:        ", address(timelock));
        console.log("Governor:        ", address(governor));
        console.log("Treasury Impl:   ", address(treasuryImpl));
        console.log("Treasury Proxy:  ", address(treasuryProxy));
        console.log("");
        console.log("--- Utilities ---");
        console.log("Factory:         ", address(factory));
        console.log("PremiumMath:     ", address(premiumMath));
    }
}
