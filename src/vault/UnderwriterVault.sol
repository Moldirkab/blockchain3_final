// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract UnderwriterVault is ERC4626, AccessControl {
    bytes32 public constant INSURANCE_POOL_ROLE =
        keccak256("INSURANCE_POOL_ROLE");

    constructor(
        IERC20 asset_,
        address admin
    ) ERC20("Underwriter Vault Share", "uvRISK") ERC4626(asset_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function payClaim(
        address receiver,
        uint256 amount
    ) external onlyRole(INSURANCE_POOL_ROLE) {
        SafeERC20.safeTransfer(IERC20(asset()), receiver, amount);
    }

    function availableLiquidity() external view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }
}
