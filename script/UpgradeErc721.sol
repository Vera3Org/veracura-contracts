// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AnimalSocialClubERC721} from "src/AnimalSocialClubERC721.sol";
import "src/Vera3DistributionModel.sol";

import {Script, console} from "forge-std/Script.sol";
import {ASC721Manager} from "../src/ASC721Manager.sol";

contract UpgradeErc721 is Script {
    ASC721Manager public asc;
    uint256 public constant ELEPHANT_ID = 0;
    uint256 public constant TIGER_ID = 1;
    uint256 public constant SHARK_ID = 2;
    uint256 public constant EAGLE_ID = 3;
    uint256 public constant STAKEHOLDER_ID = 4;

    function setUp() public {}

    function run() public {
        address admin = vm.envAddress("WALLET_ADDRESS");
        address MANAGER_PROXY = vm.envAddress("ASC_MANAGER");
        asc = ASC721Manager(payable(address(MANAGER_PROXY)));
        vm.startBroadcast(admin);

        for (uint256 i = 0; i <= 4; i++) {
            address proxy = address(asc.contracts(i));
            bytes memory empty;
            console.log("upgrading contract", i);
            Upgrades.upgradeProxy(
                proxy,
                "AnimalSocialClubERC721_V2.sol",
                empty
            );
            console.log("upgraded contract", i);
        }
        console.log("upgrade done");

        vm.stopBroadcast();
    }
}
