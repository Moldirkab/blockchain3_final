// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ProtocolTreasury.sol";

contract ProtocolTreasuryV2 is ProtocolTreasury {
    uint256 public emergencyReserveBps;

    event EmergencyReserveUpdated(uint256 reserveBps);

    function setEmergencyReserveBps(
        uint256 reserveBps
    ) external onlyRole(TREASURER_ROLE) {
        require(reserveBps <= 5000, "reserve too high");
        emergencyReserveBps = reserveBps;
        emit EmergencyReserveUpdated(reserveBps);
    }

    function version() external pure override returns (string memory) {
        return "V2";
    }
}
