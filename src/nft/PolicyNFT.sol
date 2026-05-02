// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract PolicyNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public nextTokenId;

    struct PolicyData {
        uint256 coverageAmount;
        uint256 premium;
        uint256 expiry;
        bytes32 riskType;
        bool claimed;
    }

    mapping(uint256 => PolicyData) public policies;

    constructor(address admin) ERC721("Insurance Policy NFT", "POLICY") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    function mintPolicy(
        address to,
        uint256 coverageAmount,
        uint256 premium,
        uint256 expiry,
        bytes32 riskType
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = ++nextTokenId;

        policies[tokenId] = PolicyData({
            coverageAmount: coverageAmount,
            premium: premium,
            expiry: expiry,
            riskType: riskType,
            claimed: false
        });

        _safeMint(to, tokenId);

        return tokenId;
    }
    function getPolicy(
        uint256 tokenId
    ) external view returns (PolicyData memory) {
        return policies[tokenId];
    }

    function markClaimed(uint256 tokenId) external onlyRole(MINTER_ROLE) {
        policies[tokenId].claimed = true;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
