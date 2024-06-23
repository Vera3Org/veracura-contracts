// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/AnimalSocialClub.sol";

contract DeployAnimalSocialClub is Script {
    address public vera3Address = 0x0000000000000000000000000000000000000001; // Replace with actual Vera3 address
    address public ascAddress = 0x0000000000000000000000000000000000000002; // Replace with actual ASC address

    function run() external {
        vm.startBroadcast();
        new AnimalSocialClub("ipfs://baseURI/", vera3Address, ascAddress);
        vm.stopBroadcast();
    }
}
