// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/utils/PremiumMath.sol";

contract PremiumMathTest is Test {
    PremiumMath math;

    function setUp() public {
        math = new PremiumMath();
    }

    function testYulMatchesSolidity() public {
        uint256 coverage = 10_000 ether;
        uint256 riskBps = 500;
        uint256 durationDays = 30;

        uint256 solidityResult = math.calculatePremiumSolidity(
            coverage,
            riskBps,
            durationDays
        );

        uint256 yulResult = math.calculatePremiumYul(
            coverage,
            riskBps,
            durationDays
        );

        assertEq(solidityResult, yulResult);
    }

    function testGasComparison() public {
        uint256 coverage = 10_000 ether;
        uint256 riskBps = 500;
        uint256 durationDays = 30;

        uint256 gasBeforeSolidity = gasleft();
        math.calculatePremiumSolidity(coverage, riskBps, durationDays);
        uint256 gasUsedSolidity = gasBeforeSolidity - gasleft();

        uint256 gasBeforeYul = gasleft();
        math.calculatePremiumYul(coverage, riskBps, durationDays);
        uint256 gasUsedYul = gasBeforeYul - gasleft();

        emit log_named_uint("Solidity gas", gasUsedSolidity);
        emit log_named_uint("Yul gas", gasUsedYul);

        assertTrue(gasUsedSolidity > 0);
        assertTrue(gasUsedYul > 0);
    }
}
