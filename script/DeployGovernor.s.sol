// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/governance/RiskGovernor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployGovernor is Script {
    function run() external {
        vm.startBroadcast();

        address governanceToken = vm.envAddress("GOVERNANCE_TOKEN");
        address thresholdToken = vm.envAddress("STABLE_TOKEN");
        address timelock = vm.envAddress("TIMELOCK");

        RiskGovernor governor = new RiskGovernor(
            IVotes(governanceToken),
            IERC20(thresholdToken),
            TimelockController(payable(timelock))
        );

        vm.stopBroadcast();

        console2.log("Governor deployed at:", address(governor));
        console2.log("Voting token:", governanceToken);
        console2.log("Threshold token:", thresholdToken);
        console2.log("Timelock:", timelock);
    }
}
