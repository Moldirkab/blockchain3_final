// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

contract ProtocolTreasury is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    uint256 public protocolFeeBps;

    event ProtocolFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event TokenWithdrawn(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    function initialize(
        address admin,
        uint256 initialFeeBps
    ) public initializer {
        require(admin != address(0), "invalid admin");
        require(initialFeeBps <= 1000, "fee too high");

        __AccessControl_init();

        protocolFeeBps = initialFeeBps;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(TREASURER_ROLE, admin);
    }

    function setProtocolFeeBps(
        uint256 newFeeBps
    ) external onlyRole(TREASURER_ROLE) {
        require(newFeeBps <= 1000, "fee too high");

        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = newFeeBps;

        emit ProtocolFeeUpdated(oldFee, newFeeBps);
    }

    function withdrawToken(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(TREASURER_ROLE) {
        require(to != address(0), "invalid receiver");

        SafeERC20.safeTransfer(IERC20(token), to, amount);

        emit TokenWithdrawn(token, to, amount);
    }

    function version() external pure virtual returns (string memory) {
        return "V1";
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
