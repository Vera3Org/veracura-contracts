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
import {ASC721Manager} from "src/ASC721Manager.sol";

contract StartLottery is Script {
    ASC721Manager public asc;
    address public constant ADMIN_ADDRESS = 0x98A5c7E6eb3DEaf7Db34d14d63D46ec5a5A2f775; // dummy CHANGE THIS FOR MAINNET
    address public constant TREASURY_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // dummy CHANGE THIS FOR MAINNET

    // address public constant ETH_FEE_PROXY_ADDRESS = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // base sepolia
    // address public constant LINK_ADDRESS = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410; // base sepolia
    // address public constant VRF_WRAPPER_ADDRESS = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed; // base sepolia

    address public constant LINK_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // eth sepolia
    address public constant VRF_WRAPPER_ADDRESS = 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1; // eth sepolia
    address public constant ETH_FEE_PROXY_ADDRESS = 0xe11BF2fDA23bF0A98365e1A4c04A87C9339e8687; // eth sepolia

    uint256 public constant ELEPHANT_ID = 0;
    uint256 public constant TIGER_ID = 1;
    uint256 public constant SHARK_ID = 2;
    uint256 public constant EAGLE_ID = 3;
    uint256 public constant STAKEHOLDER_ID = 4;

    function setUp() public {}

    function run() public {
        vm.deal(ADMIN_ADDRESS, 40 ether);
        vm.startBroadcast(ADMIN_ADDRESS);

        asc = ASC721Manager(
            // payable(0xD992580213E98874deb760C7C05903d2dbF8a21a)
            payable(0x6a14b7745DfAC89A1fE673D034c2E574D8BF06E4) // asc on eth sepolia
        );

        asc.setKYC(0x0BAA2292c6A028FB532ca6cE9321ba3e22C3EE29, true);
        asc.setKYC(0x657376F553814Adb084Cd44C31D418833F0594f8, true);
        asc.setKYC(0xA09C4e64826a1483Ee72EE60513EC9cEE49F8F3b, true);
        asc.setKYC(0xee3e63892768b9cb54520EB189959140019E0231, true);
        asc.setKYC(0x7F7a49334b34B6296CAE4b608d2012eB20fe5cd2, true);
        asc.setKYC(0x09D4a3d729B13d1Fadc586D8A5E26FED9F41c43c, true);
        asc.setKYC(0x0FdF2350397a2a0fb2Eb5FfD4ae0d128779B02f9, true);
        asc.setKYC(0x52FEe296d49672c904170858066Ecc5E9908B7ab, true);
        asc.setKYC(0x0052b3d9519B4A45d796A9513Dcf34E6577D0a03, true);
        asc.setKYC(0xc5fF763d5f545a2eB84A253A986678f02E055e23, true);

        asc.adminMint(0x0BAA2292c6A028FB532ca6cE9321ba3e22C3EE29, asc.ELEPHANT_ID());
        asc.adminMint(0x657376F553814Adb084Cd44C31D418833F0594f8, asc.ELEPHANT_ID());
        asc.adminMint(0xA09C4e64826a1483Ee72EE60513EC9cEE49F8F3b, asc.ELEPHANT_ID());
        asc.adminMint(0xee3e63892768b9cb54520EB189959140019E0231, asc.ELEPHANT_ID());
        asc.adminMint(0x7F7a49334b34B6296CAE4b608d2012eB20fe5cd2, asc.ELEPHANT_ID());
        asc.adminMint(0x09D4a3d729B13d1Fadc586D8A5E26FED9F41c43c, asc.ELEPHANT_ID());

        asc.adminMint(0x0FdF2350397a2a0fb2Eb5FfD4ae0d128779B02f9, asc.ELEPHANT_ID());

        asc.adminMint(0x52FEe296d49672c904170858066Ecc5E9908B7ab, asc.ELEPHANT_ID());

        asc.adminMint(0x0052b3d9519B4A45d796A9513Dcf34E6577D0a03, asc.ELEPHANT_ID());

        asc.adminMint(0xc5fF763d5f545a2eB84A253A986678f02E055e23, asc.ELEPHANT_ID());

        asc.startLottery{value: 0.02 ether}();

        vm.stopBroadcast();
    }
}
