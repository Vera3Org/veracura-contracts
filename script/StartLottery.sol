// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/AnimalSocialClubERC721.sol";
import "src/Vera3DistributionModel.sol";

import {Script, console} from "forge-std/Script.sol";
import {ASC721Manager} from "../src/ASC721Manager.sol";

contract StartLottery is Script {
    ASC721Manager public asc;
    address public constant ADMIN_ADDRESS =
        0x98A5c7E6eb3DEaf7Db34d14d63D46ec5a5A2f775; // dummy CHANGE THIS FOR MAINNET
    address public constant TREASURY_ADDRESS =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // dummy CHANGE THIS FOR MAINNET

    address public constant ETH_FEE_PROXY_ADDRESS =
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // base sepolia
    address public constant LINK_ADDRESS =
        0xE4aB69C077896252FAFBD49EFD26B5D171A32410; // base sepolia
    address public constant VRF_WRAPPER_ADDRESS =
        0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed; // base sepolia

    uint256 public constant ELEPHANT_ID = 0;
    uint256 public constant TIGER_ID = 1;
    uint256 public constant SHARK_ID = 2;
    uint256 public constant EAGLE_ID = 3;
    uint256 public constant STAKEHOLDER_ID = 4;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        asc = ASC721Manager(
            // payable(0xD992580213E98874deb760C7C05903d2dbF8a21a)
            payable(0x4F64a1f34F4aF09d0546e7a873BE0f03cD62e1cf)
        );

        vm.deal(address(asc), 4 ether);
        asc.startLottery{value: 4 ether}();

        vm.stopBroadcast();
    }
}
