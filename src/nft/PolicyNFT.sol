// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract PolicyNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private nextTokenId;

    struct PolicyData {
        address policyholder;
        uint256 coverageAmount;
        uint256 premium;
        uint256 expiry;
        bytes32 riskType;
        bool active;
        bool claimed;
    }

    mapping(uint256 => PolicyData) private policies;

    event PolicyMinted(
        uint256 indexed tokenId,
        address indexed policyholder,
        uint256 coverageAmount,
        uint256 premium,
        uint256 expiry,
        bytes32 indexed riskType
    );

    event PolicyDeactivated(uint256 indexed tokenId);

    constructor(address admin) ERC721("Insurance Policy NFT", "POLICY") {
        require(admin != address(0), "invalid admin");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    function mintPolicy(
        address policyholder,
        uint256 coverageAmount,
        uint256 premium,
        uint256 expiry,
        bytes32 riskType
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(policyholder != address(0), "invalid holder");
        require(coverageAmount > 0, "invalid coverage");
        require(expiry > block.timestamp, "invalid expiry");
        require(riskType != bytes32(0), "invalid risk");

        uint256 tokenId = ++nextTokenId;

        policies[tokenId] = PolicyData({
            policyholder: policyholder,
            coverageAmount: coverageAmount,
            premium: premium,
            expiry: expiry,
            riskType: riskType,
            active: true,
            claimed: false
        });

        _safeMint(policyholder, tokenId);

        emit PolicyMinted(
            tokenId,
            policyholder,
            coverageAmount,
            premium,
            expiry,
            riskType
        );

        return tokenId;
    }

    function deactivatePolicy(uint256 tokenId) external onlyRole(MINTER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "nonexistent");
        require(policies[tokenId].active, "already inactive");

        policies[tokenId].active = false;

        emit PolicyDeactivated(tokenId);
    }
    function markClaimed(uint256 tokenId) external onlyRole(MINTER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "nonexistent");
        require(policies[tokenId].active, "not active");
        require(!policies[tokenId].claimed, "already claimed");

        policies[tokenId].claimed = true;
        policies[tokenId].active = false;

        emit PolicyDeactivated(tokenId);
    }

    function getPolicy(
        uint256 tokenId
    ) external view returns (PolicyData memory) {
        require(_ownerOf(tokenId) != address(0), "nonexistent");
        return policies[tokenId];
    }

    function isActive(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "nonexistent");
        return policies[tokenId].active;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
