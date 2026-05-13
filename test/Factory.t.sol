// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/factory/InsuranceMarketFactory.sol";
import "../src/nft/PolicyNFT.sol";

contract FactoryTest is Test {
    InsuranceMarketFactory factory;
    address admin = address(1);

    function setUp() public {
        factory = new InsuranceMarketFactory();
    }

    function testCreatePolicyNFT() public {
        address nftAddress = factory.createPolicyNFT(admin);

        PolicyNFT nft = PolicyNFT(nftAddress);

        assertTrue(nft.hasRole(nft.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(nft.hasRole(nft.MINTER_ROLE(), admin));
    }

    function testCreate2PredictsCorrectAddress() public {
        bytes32 salt = keccak256("MARKET_1");

        address predicted = factory.predictPolicyNFTAddress(admin, salt);
        address actual = factory.createPolicyNFTDeterministic(admin, salt);

        assertEq(predicted, actual);
    }
}
