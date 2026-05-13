// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract ForkTests is Test {
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envOr("MAINNET_RPC_URL", string("https://eth.llamarpc.com"));

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    function testFork_ChainlinkFeed() public {
        vm.selectFork(mainnetFork);
        // Standard ETH/USD feed address
        address feedAddress = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        ( , int256 price, , , ) = AggregatorV3Interface(feedAddress).latestRoundData();
        assertTrue(price > 0);
    }
}

interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}