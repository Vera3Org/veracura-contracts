// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "../src/AnimalSocialClubERC1155.sol";

contract DeployAnimalSocialClub is Script {
    address public vera3Address = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Replace with actual Vera3 address
    address public ascAddress = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Replace with actual ASC address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new AnimalSocialClubERC1155(
            "ipfs://baseURI/",
            vera3Address,
            ascAddress
        );
        vm.stopBroadcast();
    }
}
