// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/AnimalSocialClubERC721.sol";
import "src/Vera3DistributionModel.sol";

contract ASC721Manager is AccessControl, ReentrancyGuard {
    using Strings for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    error CallerNotAdmin(address caller);
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    error CallerNotOperator(address caller);

    // Addresses for funds allocation
    address public immutable adminAddress;
    address public immutable treasuryAddress;

    AnimalSocialClubERC721 public immutable elephant;
    AnimalSocialClubERC721 public immutable tiger;
    AnimalSocialClubERC721 public immutable shark;
    AnimalSocialClubERC721 public immutable eagle;

    uint public constant ELEPHANT_ID = 0;
    uint public constant TIGER_ID = 1;
    uint public constant SHARK_ID = 2;
    uint public constant EAGLE_ID = 3;
    // uint public constant RESERVED_ID = 0;

    mapping(address => bool) private _hasKYC;

    AnimalSocialClubERC721[] public contracts;

    mapping(address => bool) isEarlyBacker;

    constructor(
        address _adminAddress,
        address _treasuryAddress,
        address ethFeeProxy
    ) AccessControl() {
        require(msg.sender == _adminAddress, "sender must be admin");
        require(
            _adminAddress != address(0) && _treasuryAddress != address(0),
            "One or more invalid addresses"
        );

        require(
            _grantRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "could not grant role"
        );
        require(_grantRole(OPERATOR_ROLE, msg.sender), "could not grant role");
        require(_grantRole(ADMIN_ROLE, msg.sender), "could not grant role");

        // Set the beneficiary addresses
        adminAddress = _adminAddress;
        treasuryAddress = _treasuryAddress;

        elephant = AnimalSocialClubERC721(
            payable(
                Upgrades.deployUUPSProxy(
                    "AnimalSocialClubERC721.sol",
                    abi.encodeCall(
                        AnimalSocialClubERC721.initialize,
                        (
                            "Animal Social Club Elephant Membership",
                            "ASC.Elephant",
                            9000,
                            0.1 ether,
                            address(this),
                            treasuryAddress,
                            this,
                            0,
                            ethFeeProxy
                        )
                    )
                )
            )
        );
        contracts.push(elephant);
        shark = AnimalSocialClubERC721(
            payable(
                Upgrades.deployUUPSProxy(
                    "AnimalSocialClubERC721.sol",
                    abi.encodeCall(
                        AnimalSocialClubERC721.initialize,
                        (
                            "Animal Social Club Shark Membership",
                            "ASC.Shark",
                            520,
                            0.5 ether,
                            address(this),
                            treasuryAddress,
                            this,
                            0,
                            ethFeeProxy
                        )
                    )
                )
            )
        );
        contracts.push(shark);
        eagle = AnimalSocialClubERC721(
            payable(
                Upgrades.deployUUPSProxy(
                    "AnimalSocialClubERC721.sol",
                    abi.encodeCall(
                        AnimalSocialClubERC721.initialize,
                        (
                            "Animal Social Club Eagle Membership",
                            "ASC.Eagle",
                            200,
                            1 ether,
                            address(this),
                            treasuryAddress,
                            this,
                            9, // 9 eagle reserved for lottery
                            ethFeeProxy
                        )
                    )
                )
            )
        );
        contracts.push(eagle);
        tiger = AnimalSocialClubERC721(
            payable(
                Upgrades.deployUUPSProxy(
                    "AnimalSocialClubERC721.sol",
                    abi.encodeCall(
                        AnimalSocialClubERC721.initialize,
                        (
                            "Animal Social Club Tiger Membership",
                            "ASC.Tiger",
                            30,
                            2 ether,
                            address(this),
                            treasuryAddress,
                            this,
                            1, // 1 tiger reserved for lottery
                            ethFeeProxy
                        )
                    )
                )
            )
        );
        contracts.push(tiger);
    }

    function setEarlyBacker(
        address it,
        bool _is
    ) external onlyRole(ADMIN_ROLE) {
        isEarlyBacker[it] = _is;
    }

    function adminPackFrenFrog(address dest) external onlyRole(ADMIN_ROLE) {
        require(
            isEarlyBacker[dest],
            "destination address is not registered as a early backer."
        );
        // 10 elephants, 2 sharks
        for (uint i = 0; i < 10; i++) {
            elephant.adminMint(dest);
        }

        shark.adminMint(dest);
        shark.adminMint(dest);
    }

    function adminPackCryptoTucan(address dest) external onlyRole(ADMIN_ROLE) {
        require(
            isEarlyBacker[dest],
            "destination address is not registered as a early backer."
        );
        // 25 elephants, 2 sharks, 1 eagle
        for (uint i = 0; i < 25; i++) {
            elephant.adminMint(dest);
        }

        shark.adminMint(dest);
        shark.adminMint(dest);

        eagle.adminMint(dest);
    }

    function adminPackJaguareth(address dest) external onlyRole(ADMIN_ROLE) {
        require(
            isEarlyBacker[dest],
            "destination address is not registered as a early backer."
        );
        // 75 elephants, 9 sharks, 3 eagle
        for (uint i = 0; i < 75; i++) {
            elephant.adminMint(dest);
        }
        for (uint i = 0; i < 9; i++) {
            shark.adminMint(dest);
        }
        eagle.adminMint(dest);
        eagle.adminMint(dest);
        eagle.adminMint(dest);
    }

    function adminPackWhale(address dest) external onlyRole(ADMIN_ROLE) {
        require(
            isEarlyBacker[dest],
            "destination address is not registered as a early backer."
        );
        // 150 elephants, 16 sharks, 7 eagle
        for (uint i = 0; i < 150; i++) {
            elephant.adminMint(dest);
        }
        for (uint i = 0; i < 16; i++) {
            shark.adminMint(dest);
        }
        for (uint i = 0; i < 7; i++) {
            eagle.adminMint(dest);
        }
    }

    function setOperator(address a) public onlyRole(ADMIN_ROLE) {
        require(_grantRole(OPERATOR_ROLE, a), "role not granted");
    }

    function hasKYC(address a) public view returns (bool) {
        return _hasKYC[a];
    }

    function setKYC(address a, bool val) public onlyRole(OPERATOR_ROLE) {
        _hasKYC[a] = val;
    }

    function isMember(address a) public view returns (bool) {
        uint len = contracts.length; // gas optimization
        for (uint i = 0; i < len; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            if (tier.balanceOf(a) != 0) {
                return true;
            }
        }
        return false;
    }

    // Function to withdraw funds to respective beneficiaries
    function withdrawFunds() external nonReentrant onlyRole(ADMIN_ROLE) {
        // console2.log("Hello");
        for (uint i = 0; i < contracts.length; i++) {
            // slither-disable-next-line calls-loop
            contracts[i].withdrawFunds();
        }

        uint256 balance = address(this).balance;
        // console2.log("got balance");

        if (balance > 0) {
            payable(treasuryAddress).transfer(balance);
        }
    }

    function adminMint(
        address to,
        uint tier
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(tier < contracts.length);
        AnimalSocialClubERC721(contracts[tier]).adminMint(to);
    }

    // each of these methods will call the corresponding one on each erc721 contract

    function assignRole(
        address upper,
        Vera3DistributionModel.Role role,
        address delegate
    ) external {
        console.log(
            "ASC721Manager.assignRole msg.sender: ",
            msg.sender,
            " tx.origin: ",
            tx.origin
        );
        for (uint i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            Vera3DistributionModel(tier).assignRole(upper, role, delegate);
        }
    }

    function setAmbassadorToAdvocateCommission(
        address delegate,
        uint percentage
    ) external {
        for (uint i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            Vera3DistributionModel(tier).setAmbassadorToAdvocateCommission(
                delegate,
                percentage
            );
        }
    }

    function setAdvocateToEvangelistCommission(
        address delegate,
        uint percentage
    ) external {
        for (uint i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            Vera3DistributionModel(tier).setAdvocateToEvangelistCommission(
                delegate,
                percentage
            );
        }
    }

    function setSaleActive(bool isSaleActive) external onlyRole(ADMIN_ROLE) {
        for (uint i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            tier.setSaleActive(isSaleActive);
        }
    }

    function addToWaitlist(
        uint tier,
        uint tokenId,
        uint waitlist_deposit,
        address user
    ) external payable onlyRole(ADMIN_ROLE) nonReentrant {
        require(
            tier < contracts.length,
            "Invalid tier: can be Elephant (1), Shark (2), Eagle (3), Tiger (4)"
        );
        contracts[tier].addToWaitlist(tokenId, waitlist_deposit, user);
    }

    // Function to ensure contract can receive Ether
    receive() external payable {}
}
