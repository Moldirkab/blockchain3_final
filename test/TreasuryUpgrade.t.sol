// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/governance/ProtocolTreasury.sol";
import "../src/governance/ProtocolTreasuryV2.sol";

contract TreasuryUpgradeTest is Test {
    address admin = address(this);

    ProtocolTreasury treasury;
    ProtocolTreasury implementationV1;
    ProtocolTreasuryV2 implementationV2;

    function setUp() public {
        implementationV1 = new ProtocolTreasury();

        bytes memory initData = abi.encodeCall(
            ProtocolTreasury.initialize,
            (admin, 300)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementationV1),
            initData
        );

        treasury = ProtocolTreasury(address(proxy));
    }

    function testVersionBeforeUpgradeIsV1() public {
        assertEq(treasury.version(), "V1");
    }

    function testUpgradeToV2() public {
        implementationV2 = new ProtocolTreasuryV2();

        treasury.upgradeToAndCall(address(implementationV2), "");

        ProtocolTreasuryV2 upgraded = ProtocolTreasuryV2(address(treasury));

        assertEq(upgraded.version(), "V2");

        upgraded.setEmergencyReserveBps(2000);

        assertEq(upgraded.emergencyReserveBps(), 2000);
    }
}
