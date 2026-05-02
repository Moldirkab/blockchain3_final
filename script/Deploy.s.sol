// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/mock/MockERC20.sol";
import "../src/oracle/MockAggregator.sol";
import "../src/oracle/ChainlinkOracle.sol";
import "../src/vault/UnderwriterVault.sol";
import "../src/nft/PolicyNFT.sol";
import "../src/insurance/InsurancePool.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        MockERC20 token = new MockERC20("USD Stable", "USDC");

        MockAggregator mock = new MockAggregator(2000e8, 8);

        ChainlinkOracle oracle = new ChainlinkOracle(
            msg.sender,
            address(mock),
            1 days
        );

        UnderwriterVault vault = new UnderwriterVault(token, msg.sender);

        PolicyNFT nft = new PolicyNFT(msg.sender);

        InsurancePool pool = new InsurancePool(
            msg.sender,
            token,
            oracle,
            vault,
            nft
        );

        vm.stopBroadcast();
    }
}
