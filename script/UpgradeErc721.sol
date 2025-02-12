// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/AnimalSocialClubERC721.sol";
import "src/Vera3DistributionModel.sol";

import {Script, console} from "forge-std/Script.sol";
import {ASC721Manager} from "../src/ASC721Manager.sol";

contract Upgrader is Script {
    ASC721Manager public asc;
    address public constant MANAGER_ADDRESS = 0xe5Efaa2470EDDBc32Dbc83027F08e06d408E8606;
    uint256 public constant ELEPHANT_ID = 0;
    uint256 public constant TIGER_ID = 1;
    uint256 public constant SHARK_ID = 2;
    uint256 public constant EAGLE_ID = 3;
    uint256 public constant STAKEHOLDER_ID = 4;

    function setUp() public {}

    function run() public {
        address admin = vm.envAddress("WALLET_ADDRESS");
        asc = ASC721Manager(payable(address(MANAGER_ADDRESS)));
        vm.startBroadcast(admin);

        for (uint256 i = 0; i <= 4; i++) {
            Options memory opts;
            opts.referenceContract = "AnimalSocialClubERC721_v0_0.sol";

            console.log("upgrading contract", i);
            Upgrades.upgradeProxy(address(asc.contracts(i)), "AnimalSocialClubERC721.sol", "", opts);
            console.log("upgrade done for contract", i);
        }
        console.log("upgrade done");

        vm.stopBroadcast();
    }
}
