// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockAggregator {
    int256 private answer;
    uint8 private feedDecimals;
    uint256 private updatedAt;

    constructor(int256 answer_, uint8 decimals_) {
        answer = answer_;
        feedDecimals = decimals_;
        updatedAt = block.timestamp;
    }

    function setAnswer(int256 answer_) external {
        answer = answer_;
        updatedAt = block.timestamp;
    }

    function setStaleTimestamp(uint256 timestamp) external {
        updatedAt = timestamp;
    }

    function decimals() external view returns (uint8) {
        return feedDecimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}
