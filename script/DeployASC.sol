// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Vera3DistributionModel} from "src/Vera3DistributionModel.sol";
import {AnimalSocialClubERC721} from "src/AnimalSocialClubERC721.sol";
import {Script, console} from "forge-std/Script.sol";
import {ASC721Manager} from "../src/ASC721Manager.sol";
import {ASCLottery} from "../src/ASCLottery.sol";

contract DeployASC is Script {
    ASC721Manager public asc;
    address payable public asc_address;
    address public ADMIN_ADDRESS = vm.envAddress("ADMIN_ADDRESS");
    address public OPERATOR_ADDRESS = vm.envAddress("OPERATOR_ADDRESS");

    address public TREASURY_ADDRESS = vm.envAddress("MAINNET_TREASURY_ADDRESS");
    address public ETH_FEE_PROXY_ADDRESS = vm.envAddress("ETH_FEE_PROXY_ADDRESS");
    address public LINK_ADDRESS = vm.envAddress("LINK_ADDRESS");
    address public VRF_WRAPPER_ADDRESS = vm.envAddress("VRF_WRAPPER_ADDRESS");

    uint256 public constant ELEPHANT_ID = 0;
    uint256 public constant TIGER_ID = 1;
    uint256 public constant SHARK_ID = 2;
    uint256 public constant EAGLE_ID = 3;
    uint256 public constant STAKEHOLDER_ID = 4;

    string public constant BASE_URI = "ipfs://bafybeigx7tedejallu35lvitfp7ejkeb3aorttfmlk2dp7exo25ymr7uyy/";

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        ASCLottery lottery = new ASCLottery(LINK_ADDRESS, VRF_WRAPPER_ADDRESS, TREASURY_ADDRESS);
        console.log("lottery address %s", address(lottery));
        asc_address = payable(
            Upgrades.deployUUPSProxy(
                "ASC721Manager.sol", abi.encodeCall(ASC721Manager.initialize, (TREASURY_ADDRESS, address(lottery)))
            )
        );
        console.log("asc proxy address %s", asc_address);
        asc = ASC721Manager(asc_address);
        lottery.transferOwnership(asc_address);

        address elephantAddress = Upgrades.deployUUPSProxy(
            "AnimalSocialClubERC721.sol",
            abi.encodeCall(
                AnimalSocialClubERC721.initialize,
                (
                    "Animal Social Club Elephant Membership",
                    "ASC.Elephant",
                    9000,
                    0.1 ether,
                    ADMIN_ADDRESS,
                    TREASURY_ADDRESS,
                    asc,
                    0,
                    ETH_FEE_PROXY_ADDRESS,
                    ELEPHANT_ID,
                    BASE_URI,
                    false
                )
            )
        );
        console.log("elephant proxy address %s", elephantAddress);

        address sharkAddress = Upgrades.deployUUPSProxy(
            "AnimalSocialClubERC721.sol",
            abi.encodeCall(
                AnimalSocialClubERC721.initialize,
                (
                    "Animal Social Club Shark Membership",
                    "ASC.Shark",
                    520,
                    0.5 ether,
                    ADMIN_ADDRESS,
                    TREASURY_ADDRESS,
                    asc,
                    0,
                    ETH_FEE_PROXY_ADDRESS,
                    SHARK_ID,
                    BASE_URI,
                    false
                )
            )
        );
        console.log("shark proxy address %s", sharkAddress);

        address eagle = Upgrades.deployUUPSProxy(
            "AnimalSocialClubERC721.sol",
            abi.encodeCall(
                AnimalSocialClubERC721.initialize,
                (
                    "Animal Social Club Eagle Membership",
                    "ASC.Eagle",
                    200,
                    1 ether,
                    ADMIN_ADDRESS,
                    TREASURY_ADDRESS,
                    asc,
                    9, // 9 eagle reserved for lottery
                    ETH_FEE_PROXY_ADDRESS,
                    EAGLE_ID,
                    BASE_URI,
                    false
                )
            )
        );
        console.log("eagle proxy address %s", eagle);

        address tiger = Upgrades.deployUUPSProxy(
            "AnimalSocialClubERC721.sol",
            abi.encodeCall(
                AnimalSocialClubERC721.initialize,
                (
                    "Animal Social Club Tiger Membership",
                    "ASC.Tiger",
                    30,
                    2 ether,
                    ADMIN_ADDRESS,
                    TREASURY_ADDRESS,
                    asc,
                    11, // 1 tiger reserved for lottery, 10 tigers in auction
                    ETH_FEE_PROXY_ADDRESS,
                    TIGER_ID,
                    BASE_URI,
                    true
                )
            )
        );
        console.log("tiger proxy address %s", tiger);
        address stakeholder = Upgrades.deployUUPSProxy(
            "AnimalSocialClubERC721.sol",
            abi.encodeCall(
                AnimalSocialClubERC721.initialize,
                (
                    "Animal Social Club Stakeholder Membership",
                    "ASC.Stakeholder",
                    250,
                    0.5 ether,
                    ADMIN_ADDRESS,
                    TREASURY_ADDRESS,
                    asc,
                    0,
                    ETH_FEE_PROXY_ADDRESS,
                    STAKEHOLDER_ID,
                    BASE_URI,
                    false
                )
            )
        );
        console.log("stakeholder proxy address %s", stakeholder);

        asc.assignContracts(
            payable(elephantAddress), payable(tiger), payable(sharkAddress), payable(eagle), payable(stakeholder)
        );

        require(asc.owner() == address(ADMIN_ADDRESS));
        AnimalSocialClubERC721[5] memory contracts = [
            AnimalSocialClubERC721(payable(elephantAddress)),
            AnimalSocialClubERC721(payable(tiger)),
            AnimalSocialClubERC721(payable(sharkAddress)),
            AnimalSocialClubERC721(payable(eagle)),
            AnimalSocialClubERC721(payable(stakeholder))
        ];
        for (uint256 i = 0; i < contracts.length; i++) {
            require(contracts[i].owner() == address(ADMIN_ADDRESS));
        }

        asc.setSaleActive(true);

        // add addresses to waitlist
        asc.addToWaitlist(TIGER_ID, 1 ether, 0x724158b824225051935f37984CE0f907f8d451a9);
        asc.addToWaitlist(ELEPHANT_ID, 0.05 ether, 0xE6c30AD5AeE7AD22e9F39D51d67667587cdD05A1);

        // terminate the waitlist period
        asc.setLaunchStatus(true);

        asc.grantRole(asc.OPERATOR_ROLE(), OPERATOR_ADDRESS);

        vm.stopBroadcast();

        console.log("Done. Animal Social Club Manager address: ", asc_address);
    }
}
