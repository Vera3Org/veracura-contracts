// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "../src/AnimalSocialClubERC1155.sol";

contract DeployAnimalSocialClub is Script {
    address public vera3Address = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Replace with actual Vera3 address
    address public ascAddress = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Replace with actual ASC address

    address[] public waitlistedAddresses = [
        address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f),
        address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720)
    ];
    uint256[] public waitlistedIDs = [1, 2];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new AnimalSocialClubERC1155(
            "ipfs://baseURI/",
            vera3Address,
            ascAddress,
            waitlistedAddresses,
            waitlistedIDs
        );
        vm.stopBroadcast();
    }
}
