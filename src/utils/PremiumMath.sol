// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PremiumMath {
    function calculatePremiumSolidity(
        uint256 coverage,
        uint256 riskBps,
        uint256 durationDays
    ) external pure returns (uint256) {
        return (coverage * riskBps * durationDays) / 36500;
    }

    function calculatePremiumYul(
        uint256 coverage,
        uint256 riskBps,
        uint256 durationDays
    ) external pure returns (uint256 result) {
        assembly {
            result := div(mul(mul(coverage, riskBps), durationDays), 36500)
        }
    }
}
