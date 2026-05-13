// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/token/RiskGovernanceToken.sol";
import "../src/governance/RiskGovernor.sol";
import "../src/governance/ProtocolTreasury.sol";

contract GovernanceTest is Test {
    address voter = address(1);

    RiskGovernanceToken token;
    TimelockController timelock;
    RiskGovernor governor;
    ProtocolTreasury treasury;

    function setUp() public {
        token = new RiskGovernanceToken(address(this));

        token.mint(voter, 100_000 ether);

        vm.prank(voter);
        token.delegate(voter);
        vm.roll(block.number + 1);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(
            2 days,
            proposers,
            executors,
            address(this)
        );

        governor = new RiskGovernor(token, token, timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        ProtocolTreasury implementation = new ProtocolTreasury();

        bytes memory initData = abi.encodeCall(
            ProtocolTreasury.initialize,
            (address(this), 300)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        treasury = ProtocolTreasury(address(proxy));

        treasury.grantRole(treasury.TREASURER_ROLE(), address(timelock));
    }

    function testGovernanceCanChangeTreasuryFee() public {
        address[] memory targets = new address[](1);
        targets[0] = address(treasury);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(
            ProtocolTreasury.setProtocolFeeBps,
            (500)
        );

        string memory description = "Change protocol fee to 5 percent";

        vm.prank(voter);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voter);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        bytes32 descriptionHash = keccak256(bytes(description));

        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + 2 days + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(treasury.protocolFeeBps(), 500);
    }
}
