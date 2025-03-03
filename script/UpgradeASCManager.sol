// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/Vera3DistributionModel.sol";

import {Script, console} from "forge-std/Script.sol";
import {ASC721Manager} from "../src/ASC721Manager.sol";
// import {ASC721Manager_V2} from "../src/ASC721Manager_V2.sol";

contract UpgradeASCManager is Script {
    function setUp() public {}

    function run() public {
        address admin = vm.envAddress("WALLET_ADDRESS");
        address MANAGER_PROXY = vm.envAddress("ASC_MANAGER");
        vm.startBroadcast(admin);

        bytes memory empty;
        Upgrades.upgradeProxy(MANAGER_PROXY, "ASC721Manager_V2.sol", empty);

        console.log("upgrade done");

        vm.stopBroadcast();
    }
}
