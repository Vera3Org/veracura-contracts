// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {console} from "forge-std/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {AnimalSocialClubERC721} from "src/AnimalSocialClubERC721.sol";
import {ASCLottery} from "src/ASCLottery.sol";
import {Vera3DistributionModel} from "src/Vera3DistributionModel.sol";

/**
 * @dev Contract which coordinates the Animal Social Club NFT memberships.

 * @dev Holds references to each of the membership contracts, and provides
 * functions which need information to flow between contracts.
 *
 * @dev Roles:
 * - ADMIN_ROLE: a human administrator which can mint membership packs,
 *   as well as altering certain internal state variables: the early backer
 *   list, the saleActive variable, the waitlist, as well as
 *   the other roles OPERATOR_ROLE and NFT_ROLE
 * - OPERATOR_ROLE: can modify the `_hasKYC` list.
 * - NFT_ROLE: is an AnimalSocialClubERC721 contract address, and is the only
 *   role which can interact with the `lottery` contract.
 */
contract ASC721Manager is AccessControlDefaultAdminRules, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    /**
     * @dev role for a (EOA) admin. Admin role is allowed to adminMint,
     * and add the Operator Role to an address. TODO look into role admins
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    error CallerNotAdmin(address caller);
    /**
     * @dev Role for EOAs that need to invoke addToKYC
     * when a user completes KYC.
     */

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error CallerNotOperator(address caller);

    /**
     * @dev Role for the smart contracts that are managed by this one.
     * Needed for addToLotteryParticipants.
     */
    bytes32 public constant NFT_ROLE = keccak256("NFT_ROLE");

    /// Address of Animal Social Club treasury.
    address public immutable treasuryAddress;

    /// references to Elephant contract
    AnimalSocialClubERC721 public elephant;
    /// references to Tiger contract
    AnimalSocialClubERC721 public tiger;
    /// references to Shark contract
    AnimalSocialClubERC721 public shark;
    /// references to Eagle contract
    AnimalSocialClubERC721 public eagle;
    /// references to Stakeholder contract
    AnimalSocialClubERC721 public stakeholder;

    /// index of Elephant contract in the `contracts` array
    uint256 public constant ELEPHANT_ID = 0;
    /// index of Tiger contract in the `contracts` array
    uint256 public constant TIGER_ID = 1;
    /// index of Shark contract in the `contracts` array
    uint256 public constant SHARK_ID = 2;
    /// index of Eagle contract in the `contracts` array
    uint256 public constant EAGLE_ID = 3;
    /// index of Stakeholder contract in the `contracts` array
    uint256 public constant STAKEHOLDER_ID = 4;

    /**
     * @dev referenctes to [elephant, tiger, shark, eagle, stakeholder].
     */
    AnimalSocialClubERC721[] public contracts;

    /**
     * @notice Mapping to keep track of who has completed KYC verification
     * and thus can mint memberships.
     * @dev Only addresses `a` for which `_hasKYC[a]` is true can mint memberships.
     */
    mapping(address => bool) private _hasKYC;

    /**
     * @dev reference to lottery contract.
     */
    ASCLottery public lottery;

    /**
     * @dev keeps track of early backers.
     * @dev Early backers can only be registered by the admin, and they
     * donated using means outside of the smart contract.
     * This means they are eligible to receive membership packages,
     * like adminPackFrenFrog.
     */
    mapping(address => bool) isEarlyBacker;

    /**
     * @dev used to enumerate the isEarlyBacker mapping.
     */
    address[] public earlyBackers;

    constructor(
        address _treasuryAddress,
        address _lotteryAddress
    ) AccessControlDefaultAdminRules(3 hours, msg.sender) {
        require(
            _treasuryAddress != address(0) && _lotteryAddress != address(0),
            "One or more invalid addresses"
        );

        require(_grantRole(OPERATOR_ROLE, msg.sender), "could not grant role");
        require(_grantRole(ADMIN_ROLE, msg.sender), "could not grant role");

        // Set the beneficiary addresses
        treasuryAddress = _treasuryAddress;
        lottery = ASCLottery(_lotteryAddress);
    }

    /**
     * @dev Only used during deployment. Registers each NFT tier into this contract.
     * @dev Requires that all the argument are addresses of AnimalSocialClubERC721 proxy contracts
     *
     * @param _elephant address of a deployed AnimalSocialClubERC721 contract
     * @param _tiger address of a deployed AnimalSocialClubERC721 contract
     * @param _shark address of a deployed AnimalSocialClubERC721 contract
     * @param _eagle address of a deployed AnimalSocialClubERC721 contract
     * @param _stakeholder address of a deployed AnimalSocialClubERC721 contract
     */
    function assignContracts(
        address payable _elephant,
        address payable _tiger,
        address payable _shark,
        address payable _eagle,
        address payable _stakeholder
    ) external onlyRole(ADMIN_ROLE) {
        // no clearing the array bc we only use it at contract creation time
        // for (uint i = 0; i < contracts.length; i++) {
        //     contracts.pop();
        // }
        require(contracts.length == 0, "Can't initialize twice");

        elephant = AnimalSocialClubERC721(_elephant);
        contracts.push(AnimalSocialClubERC721(_elephant));
        require(_grantRole(NFT_ROLE, _elephant), "could not grant role");

        tiger = AnimalSocialClubERC721(_tiger);
        contracts.push(AnimalSocialClubERC721(_tiger));
        require(_grantRole(NFT_ROLE, _tiger), "could not grant role");

        shark = AnimalSocialClubERC721(_shark);
        contracts.push(AnimalSocialClubERC721(_shark));
        require(_grantRole(NFT_ROLE, _shark), "could not grant role");

        eagle = AnimalSocialClubERC721(_eagle);
        contracts.push(AnimalSocialClubERC721(_eagle));
        require(_grantRole(NFT_ROLE, _eagle), "could not grant role");

        stakeholder = AnimalSocialClubERC721(_stakeholder);
        contracts.push(AnimalSocialClubERC721(_stakeholder));
        require(_grantRole(NFT_ROLE, _stakeholder), "could not grant role");
    }

    /**
     * @dev can only be called by a contract in `contracts`. Adds the address
     * `it` to the list of participants.
     */
    function addToLotteryParticipants(address it) public onlyRole(NFT_ROLE) {
        lottery.addToParticipants(it);
    }

    /**
     * @dev adds or removes an address to the isEarlyBacker and earlyBackers variables.
     * Admin only.
     * @param it The address to be altered
     * @param _is true means that the user is added, false means the user is removed
     */
    function setEarlyBacker(
        address it,
        bool _is
    ) external onlyRole(ADMIN_ROLE) {
        isEarlyBacker[it] = _is;
        if (_is) {
            earlyBackers.push(it);
        } else {
            // remove `it` from the list
            for (uint256 i = 0; i < earlyBackers.length; i++) {
                if (earlyBackers[i] == it) {
                    earlyBackers[i] = earlyBackers[earlyBackers.length];
                    earlyBackers.pop();
                }
            }
        }
    }

    /**
     * @dev mints 10 elephants and 2 sharks to an early backer.
     * Payment is made outside of contract.
     * Admin only.
     * @param dest the receiving address of NFTs
     */
    function adminPackFrenFrog(address dest) external onlyRole(ADMIN_ROLE) {
        require(
            isEarlyBacker[dest],
            "destination address is not registered as a early backer."
        );
        // 10 elephants, 2 sharks
        for (uint256 i = 0; i < 10; i++) {
            elephant.adminMint(dest);
        }

        shark.adminMint(dest);
        shark.adminMint(dest);
    }

    /**
     * @dev mints 25 elephants, 2 sharks, 1 eagle to early backer.
     * Payment is made outside of contract.
     * Admin only.
     * @param dest the receiving address of NFTs
     */
    function adminPackCryptoTucan(address dest) external onlyRole(ADMIN_ROLE) {
        require(
            isEarlyBacker[dest],
            "destination address is not registered as a early backer."
        );
        // 25 elephants, 2 sharks, 1 eagle
        for (uint256 i = 0; i < 25; i++) {
            elephant.adminMint(dest);
        }

        shark.adminMint(dest);
        shark.adminMint(dest);

        eagle.adminMint(dest);
    }

    /**
     * @dev mints 75 elephants, 9 sharks, 3 eagle to early backer.
     * Payment is made outside of contract.
     * Admin only.
     * @param dest the receiving address of NFTs
     */
    function adminPackJaguareth(address dest) external onlyRole(ADMIN_ROLE) {
        require(
            isEarlyBacker[dest],
            "destination address is not registered as a early backer."
        );
        // 75 elephants, 9 sharks, 3 eagle
        for (uint256 i = 0; i < 75; i++) {
            elephant.adminMint(dest);
        }
        for (uint256 i = 0; i < 9; i++) {
            shark.adminMint(dest);
        }
        eagle.adminMint(dest);
        eagle.adminMint(dest);
        eagle.adminMint(dest);
    }

    /**
     * @dev mints 150 elephants, 16 sharks, 7 eagle to early backer.
     * Payment is made outside of contract.
     * Admin only.
     * @param dest the receiving address of NFTs
     */
    function adminPackWhale(address dest) external onlyRole(ADMIN_ROLE) {
        require(
            isEarlyBacker[dest],
            "destination address is not registered as a early backer."
        );
        // 150 elephants, 16 sharks, 7 eagle
        for (uint256 i = 0; i < 150; i++) {
            elephant.adminMint(dest);
        }
        for (uint256 i = 0; i < 16; i++) {
            shark.adminMint(dest);
        }
        for (uint256 i = 0; i < 7; i++) {
            eagle.adminMint(dest);
        }
    }

    /**
     * @dev grants the OPERATOR role to an address.
     */
    function setOperator(address a) public onlyRole(ADMIN_ROLE) {
        require(_grantRole(OPERATOR_ROLE, a), "role not granted");
    }

    /**
     * @dev removes the OPERATOR role from an address.
     */
    function removeOperator(address a) public onlyRole(ADMIN_ROLE) {
        revokeRole(OPERATOR_ROLE, a);
    }

    /**
     * @dev check whether an address is registered has having
     * completed the KYC procedure.
     * @param a the address to check
     */
    function hasKYC(address a) public view returns (bool) {
        return _hasKYC[a];
    }

    /**
     * @dev marks an address as having completed the KYC procedure.
     * @param a the address to alter
     * @param val true indicates the user has KYC, false the opposite.
     */
    function setKYC(address a, bool val) public onlyRole(OPERATOR_ROLE) {
        _hasKYC[a] = val;
    }

    /**
     * @dev returns `true` when the input address has at least one ASC NFT membership,
     * any tier.
     * @param a the address of the queried user.
     */
    function isMember(address a) public view returns (bool) {
        uint256 len = contracts.length; // gas optimization
        for (uint256 i = 0; i < len; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            if (tier.balanceOf(a) != 0) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev withdraw ether from each sub-contract and this contract to the treasury.
     * Only admin.
     * @dev funds are withdrawn to `treasuryAddress`.
     */
    function withdrawFunds() external nonReentrant onlyRole(ADMIN_ROLE) {
        // console2.log("Hello");
        for (uint256 i = 0; i < contracts.length; i++) {
            // slither-disable-next-line calls-loop
            contracts[i].withdrawFunds();
        }

        uint256 balance = address(this).balance;
        // console2.log("got balance");

        if (balance > 0) {
            payable(treasuryAddress).transfer(balance);
        }
    }

    /**
     * @dev function for the admin to call a sub-contract's `adminMint`
     * function. See `AnimalSocialClubERC721.adminMint`.
     * Only admin.
     * @param to the receiving address
     * @param tier the membership tier. Must be between `ELEPHANT_ID` and `EAGLE_ID`
     */
    function adminMint(
        address to,
        uint256 tier
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(tier < contracts.length);
        AnimalSocialClubERC721(contracts[tier]).adminMint(to);
    }

    // each of these methods will call the corresponding one on each erc721 contract

    /**
     * @dev calls  `AnimalSocialClubERC721.assignRole` on each sub-contract.
     * See that function.
     */
    function assignRole(
        address payable upper,
        Vera3DistributionModel.Role role,
        address payable delegate
    ) external {
        for (uint256 i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            Vera3DistributionModel(tier).assignRole(
                upper,
                role,
                delegate,
                msg.sender
            );
        }
    }

    /**
     * @dev calls  `AnimalSocialClubERC721.setAmbassadorToAdvocateCommission`
     * on each sub-contract.
     */
    function setAmbassadorToAdvocateCommission(uint256 percentage) external {
        for (uint256 i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            Vera3DistributionModel(tier).setAmbassadorToAdvocateCommission(
                percentage
            );
        }
    }

    /**
     * @dev calls  `AnimalSocialClubERC721.setAdvocateToEvangelistCommission`
     * on each sub-contract.
     */
    function setAdvocateToEvangelistCommission(uint256 percentage) external {
        for (uint256 i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            Vera3DistributionModel(tier).setAdvocateToEvangelistCommission(
                percentage
            );
        }
    }

    /**
     * @dev calls  `AnimalSocialClubERC721.setSaleActive`  on each sub-contract.
     */
    function setSaleActive(bool isSaleActive) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            // slither-disable-next-line calls-loop
            tier.setSaleActive(isSaleActive);
        }
    }

    /**
     * @dev Register someone on the waitlist for a certain token
     * tier with ID tokenId.
     * @dev Assume they deposited `waitlist_deposit` amount of ETH.
     * @dev Only admin can do this.
     * @param tier the membership tier. Must be between `ELEPHANT_ID` and `EAGLE_ID`
     * @param waitlist_deposit how much the user deposited.
     *        will be deducted from final payment
     * @param user address of the user to register
     */
    function addToWaitlist(
        uint256 tier,
        uint256 waitlist_deposit,
        address user
    ) external payable onlyRole(ADMIN_ROLE) nonReentrant {
        require(
            tier < contracts.length,
            "Invalid tier: can be Elephant (0), Shark (1), Eagle (2), Tiger (3), Stakeholder (4)"
        );
        // TODO check KYC member?
        contracts[tier].addToWaitlist(waitlist_deposit, user);
    }

    /**
     * @dev TODO verify if this is the only thing to do.
     */
    function startLottery() external onlyRole(ADMIN_ROLE) {
        lottery.requestRandomWords(true);
    }

    function startTigerAuction() external onlyRole(ADMIN_ROLE) {
        tiger.startAuction();
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
