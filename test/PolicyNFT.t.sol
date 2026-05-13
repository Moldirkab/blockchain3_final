// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/nft/PolicyNFT.sol";

contract PolicyNFTTest is Test {
    PolicyNFT nft;

    address user = address(1);

    function setUp() public {
        nft = new PolicyNFT(address(this));
    }

    function testMintPolicy() public {
        uint256 id = nft.mintPolicy(
            user,
            100 ether,
            5 ether,
            block.timestamp + 7 days,
            keccak256("DEPEG")
        );

        assertEq(id, 1);
        assertEq(nft.ownerOf(id), user);
    }

    function testMarkClaimed() public {
        uint256 id = nft.mintPolicy(
            user,
            100 ether,
            5 ether,
            block.timestamp + 7 days,
            keccak256("DEPEG")
        );

        nft.markClaimed(id);

        PolicyNFT.PolicyData memory policy = nft.getPolicy(id);

        assertEq(policy.claimed, true);
    }

    function testUnauthorizedMintRevert() public {
        vm.prank(user);
        vm.expectRevert();
        nft.mintPolicy(
            user,
            100 ether,
            5 ether,
            block.timestamp + 7 days,
            keccak256("DEPEG")
        );
    }
}
