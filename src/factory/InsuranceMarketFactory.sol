// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../nft/PolicyNFT.sol";

contract InsuranceMarketFactory {
    event PolicyNFTCreated(address indexed nft, address indexed admin);
    event PolicyNFTCreatedDeterministic(
        address indexed nft,
        address indexed admin,
        bytes32 salt
    );

    function createPolicyNFT(address admin) external returns (address) {
        PolicyNFT nft = new PolicyNFT(admin);

        emit PolicyNFTCreated(address(nft), admin);

        return address(nft);
    }

    function createPolicyNFTDeterministic(
        address admin,
        bytes32 salt
    ) external returns (address) {
        PolicyNFT nft = new PolicyNFT{salt: salt}(admin);

        emit PolicyNFTCreatedDeterministic(address(nft), admin, salt);

        return address(nft);
    }

    function predictPolicyNFTAddress(
        address admin,
        bytes32 salt
    ) external view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(PolicyNFT).creationCode,
            abi.encode(admin)
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }
}
