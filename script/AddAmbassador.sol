// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/Vera3DistributionModel.sol";

import {Script, console} from "forge-std/Script.sol";
import {ASC721Manager} from "../src/ASC721Manager.sol";
// import {ASC721Manager_V2} from "../src/ASC721Manager_V2.sol";

contract AddAmbassador is Script {
    function setUp() public {}

    function run() public {
        address admin = vm.envAddress("WALLET_ADDRESS");
        address MANAGER_PROXY = vm.envAddress("ASC_MANAGER");
        address payable AMBASSADOR_ADDRESS = payable(vm.envAddress("AMBASSADOR_ADDRESS"));
        vm.startBroadcast(admin);

        ASC721Manager asc = ASC721Manager(payable(MANAGER_PROXY));
        asc.assignRole(payable(address(0)), Vera3DistributionModel.Role.Ambassador, AMBASSADOR_ADDRESS);

        vm.stopBroadcast();
    }
}
