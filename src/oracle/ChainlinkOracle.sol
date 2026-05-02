// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IPriceFeed.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ChainlinkOracle is AccessControl {
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");

    IPriceFeed public priceFeed;
    uint256 public maxStaleness;

    error StalePrice();
    error InvalidPrice();

    constructor(address admin, address feed, uint256 maxStaleness_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_ADMIN_ROLE, admin);

        priceFeed = IPriceFeed(feed);
        maxStaleness = maxStaleness_;
    }

    function setPriceFeed(address feed) external onlyRole(ORACLE_ADMIN_ROLE) {
        priceFeed = IPriceFeed(feed);
    }

    function setMaxStaleness(
        uint256 value
    ) external onlyRole(ORACLE_ADMIN_ROLE) {
        maxStaleness = value;
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        if (answer <= 0) revert InvalidPrice();
        if (block.timestamp - updatedAt > maxStaleness) revert StalePrice();

        uint8 decimals = priceFeed.decimals();

        if (decimals < 18) {
            return uint256(answer) * 10 ** (18 - decimals);
        }

        if (decimals > 18) {
            return uint256(answer) / 10 ** (decimals - 18);
        }

        return uint256(answer);
    }
}
