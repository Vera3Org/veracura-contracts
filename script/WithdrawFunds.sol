// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/Vera3DistributionModel.sol";
// import {AnimalSocialClubERC721_V2} from "src/AnimalSocialClubERC721_V2.sol";
import {IAnimalSocialClubERC721} from "interfaces/IAnimalSocialClubERC721.sol";

import {Script, console} from "forge-std/Script.sol";
import {ASC721Manager_V2} from "../src/ASC721Manager_V2.sol";
// import {ASC721Manager_V2_V2} from "../src/ASC721Manager_V2_V2.sol";

contract WithdrawFunds is Script {
    function setUp() public {}

    function run() public {
        address admin = vm.envAddress("WALLET_ADDRESS");
        address MANAGER_PROXY = vm.envAddress("ASC_MANAGER");

        vm.startBroadcast(admin);

        ASC721Manager_V2 asc = ASC721Manager_V2(payable(MANAGER_PROXY));
        if (address(asc).balance > 0) {
            asc.withdrawFunds();
            console.log("withdrew from manager");
        }
        for (uint i = 0; i <= asc.STAKEHOLDER_ID(); i++) {
            if (address(asc.contracts(i)).balance > 0) {
                IAnimalSocialClubERC721(asc.contracts(i)).withdrawFunds();
                console.log("withdrew from id %s", i);
            }
        }

        vm.stopBroadcast();
    }
}
