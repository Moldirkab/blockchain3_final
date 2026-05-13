// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/oracle/MockAggregator.sol";
import "../src/oracle/ChainlinkOracle.sol";

contract OracleTest is Test {
    MockAggregator mock;
    ChainlinkOracle oracle;

    function setUp() public {
        mock = new MockAggregator(2000e8, 8);
        oracle = new ChainlinkOracle(address(this), address(mock), 1 days);
    }

    function testValidPrice() public view {
        uint256 price = oracle.getLatestPrice();

        assertEq(price, 2000e18);
    }

    function testInvalidPriceRevert() public {
        mock.setAnswer(0);

        vm.expectRevert();
        oracle.getLatestPrice();
    }

    function testStalePriceRevert() public {
        vm.warp(10 days);

        mock.setStaleTimestamp(block.timestamp - 2 days);

        vm.expectRevert(ChainlinkOracle.StalePrice.selector);
        oracle.getLatestPrice();
    }

    function testUpdateMaxStaleness() public {
        oracle.setMaxStaleness(2 days);

        assertEq(oracle.maxStaleness(), 2 days);
    }
}
