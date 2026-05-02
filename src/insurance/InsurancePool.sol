// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../oracle/ChainlinkOracle.sol";
import "../vault/UnderwriterVault.sol";
import "../nft/PolicyNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract InsurancePool is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    enum PolicyStatus {
        Active,
        Expired,
        Claimed
    }

    struct RiskConfig {
        bool accepted;
        uint256 premiumBps;
        uint256 triggerPrice;
        uint256 duration;
    }

    IERC20 public immutable asset;
    ChainlinkOracle public oracle;
    UnderwriterVault public vault;
    PolicyNFT public policyNFT;

    mapping(bytes32 => RiskConfig) public riskConfigs;
    mapping(uint256 => PolicyStatus) public policyStatus;

    event RiskTypeUpdated(
        bytes32 indexed riskType,
        bool accepted,
        uint256 premiumBps,
        uint256 triggerPrice,
        uint256 duration
    );
    event PolicyPurchased(
        address indexed buyer,
        uint256 indexed policyId,
        bytes32 indexed riskType,
        uint256 coverage,
        uint256 premium
    );
    event ClaimPaid(
        address indexed user,
        uint256 indexed policyId,
        uint256 amount
    );

    error RiskNotAccepted();
    error InvalidCoverage();
    error PolicyNotActive();
    error PolicyExpired();
    error AlreadyClaimed();
    error TriggerNotMet();
    error NotPolicyOwner();

    constructor(
        address admin,
        IERC20 asset_,
        ChainlinkOracle oracle_,
        UnderwriterVault vault_,
        PolicyNFT policyNFT_
    ) {
        asset = asset_;
        oracle = oracle_;
        vault = vault_;
        policyNFT = policyNFT_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setRiskConfig(
        bytes32 riskType,
        bool accepted,
        uint256 premiumBps,
        uint256 triggerPrice,
        uint256 duration
    ) external onlyRole(GOVERNANCE_ROLE) {
        riskConfigs[riskType] = RiskConfig({
            accepted: accepted,
            premiumBps: premiumBps,
            triggerPrice: triggerPrice,
            duration: duration
        });

        emit RiskTypeUpdated(
            riskType,
            accepted,
            premiumBps,
            triggerPrice,
            duration
        );
    }

    function buyPolicy(
        bytes32 riskType,
        uint256 coverageAmount
    ) external nonReentrant whenNotPaused returns (uint256) {
        RiskConfig memory config = riskConfigs[riskType];

        if (!config.accepted) revert RiskNotAccepted();
        if (coverageAmount == 0) revert InvalidCoverage();

        uint256 premium = (coverageAmount * config.premiumBps) / 10_000;

        asset.safeTransferFrom(msg.sender, address(vault), premium);

        uint256 policyId = policyNFT.mintPolicy(
            msg.sender,
            coverageAmount,
            premium,
            block.timestamp + config.duration,
            riskType
        );

        policyStatus[policyId] = PolicyStatus.Active;

        emit PolicyPurchased(
            msg.sender,
            policyId,
            riskType,
            coverageAmount,
            premium
        );

        return policyId;
    }

    function claim(uint256 policyId) external nonReentrant whenNotPaused {
        if (policyNFT.ownerOf(policyId) != msg.sender) revert NotPolicyOwner();

        PolicyNFT.PolicyData memory policy = policyNFT.getPolicy(policyId);
        RiskConfig memory config = riskConfigs[policy.riskType];

        if (policyStatus[policyId] != PolicyStatus.Active)
            revert PolicyNotActive();
        if (block.timestamp > policy.expiry) revert PolicyExpired();
        if (policy.claimed) revert AlreadyClaimed();

        uint256 currentPrice = oracle.getLatestPrice();

        if (currentPrice > config.triggerPrice) revert TriggerNotMet();

        policyStatus[policyId] = PolicyStatus.Claimed;
        policyNFT.markClaimed(policyId);

        vault.payClaim(msg.sender, policy.coverageAmount);

        emit ClaimPaid(msg.sender, policyId, policy.coverageAmount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
