// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/AnimalSocialClubERC721.sol";
import "src/Vera3DistributionModel.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

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
     * Needed for addToLotteryParticipants, since lotteryParticipants
     * needs access control and cannot be public.
     */
    bytes32 public constant NFT_ROLE = keccak256("NFT_ROLE");
    error CallerNotNFT(address caller);

    // Addresses for funds allocation
    address public immutable treasuryAddress;

    // references to managed contracts
    AnimalSocialClubERC721 public elephant;
    AnimalSocialClubERC721 public tiger;
    AnimalSocialClubERC721 public shark;
    AnimalSocialClubERC721 public eagle;
    AnimalSocialClubERC721 public stakeholder;

    uint public constant ELEPHANT_ID = 0;
    uint public constant TIGER_ID = 1;
    uint public constant SHARK_ID = 2;
    uint public constant EAGLE_ID = 3;
    uint public constant STAKEHOLDER_ID = 4;

    mapping(address => bool) private _hasKYC;

    AnimalSocialClubERC721[] public contracts;

    /**
     * @dev keeps track of early backers.
     * Early backers can only be registered by the admin, and they
     * donated using means outside of the smart contract.
     * This means they are eligible to receive membership packages,
     * like adminPackFrenFrog.
     */
    mapping(address => bool) isEarlyBacker;
    /**
     * @dev used to enumerate the isEarlyBacker mapping.
     */
    address[] public earlyBackers;

    /**
     * @dev addresses which are eligible to receive a membership
     * using the lottery membership.
     * An address is added to this set when they receive a membership.
     */
    EnumerableSet.AddressSet private lotteryParticipants;

    constructor(
        address _treasuryAddress,
        address _linkAddress,
        address _VrfWrapperAddress
    ) AccessControlDefaultAdminRules(3 hours, msg.sender) {
        require(
            _treasuryAddress != address(0),
            "One or more invalid addresses"
        );

        require(_grantRole(OPERATOR_ROLE, msg.sender), "could not grant role");
        require(_grantRole(ADMIN_ROLE, msg.sender), "could not grant role");

        // Set the beneficiary addresses
        treasuryAddress = _treasuryAddress;

        linkAddress = _linkAddress;
        wrapperAddress = _VrfWrapperAddress;
    }

    /**
     * Only used during deployment. Registers each NFT tier into this contract.
     * Deployment of these
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

    function addToLotteryParticipants(address it) public onlyRole(NFT_ROLE) {
        lotteryParticipants.add(it);
    }

    /**
     * @dev adds an address to the isEarlyBacker and earlyBackers variables.
     * Admin only.
     */
    function setEarlyBacker(
        address it,
        bool _is
    ) external onlyRole(ADMIN_ROLE) {
        isEarlyBacker[it] = _is;
        earlyBackers.push(it);
    }

    /**
     * @dev mints 10 elephants and 2 sharks to an early backer.
     * Payment is made outside of contract.
     */
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

    /**
     * @dev mints 25 elephants, 2 sharks, 1 eagle to early backer.
     * Payment is made outside of contract.
     */
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

    /**
     * @dev mints 75 elephants, 9 sharks, 3 eagle to early backer.
     * Payment is made outside of contract.
     */
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

    /**
     * @dev mints 150 elephants, 16 sharks, 7 eagle to early backer.
     * Payment is made outside of contract.
     */
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

    /**
     * @dev grants the OPERATOR role to an address.
     */
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
        address payable upper,
        Vera3DistributionModel.Role role,
        address payable delegate
    ) external {
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

    /**
     * Register someone on the waitlist for a certain token tier with ID tokenId.
     * Assume they deposited `waitlist_deposit` amount of ETH.
     * Only admin can do this.
     */
    function addToWaitlist(
        uint tier,
        uint waitlist_deposit,
        address user
    ) external payable onlyRole(ADMIN_ROLE) nonReentrant {
        require(
            tier < contracts.length,
            "Invalid tier: can be Elephant (1), Shark (2), Eagle (3), Tiger (4)"
        );
        contracts[tier].addToWaitlist(waitlist_deposit, user);
    }

    ////////////////////////////////////////////////////////////////////////
    ///////// LOTTERY THINGS
    ////////////////////////////////////////////////////////////////////////
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 public callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
    uint32 public numWords = 2;

    // Address LINK - hardcoded for Sepolia
    address immutable linkAddress;

    // address WRAPPER - hardcoded for Sepolia
    address immutable wrapperAddress;

    function requestRandomWords(
        bool enableNativePayment
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment})
        );
        uint256 requestId;
        uint256 reqPrice;
        // if (enableNativePayment) {
        //     (requestId, reqPrice) = requestRandomnessPayInNative(
        //         callbackGasLimit,
        //         requestConfirmations,
        //         numWords,
        //         extraArgs
        //     );
        // } else {
        //     (requestId, reqPrice) = requestRandomness(
        //         callbackGasLimit,
        //         requestConfirmations,
        //         numWords,
        //         extraArgs
        //     );
        // }
        s_requests[requestId] = RequestStatus({
            paid: reqPrice,
            randomWords: new uint256[](0),
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords // ) internal override {
    ) internal {
        require(s_requests[_requestId].paid > 0, "request not found");
        require(
            _randomWords.length >= 10,
            "Need enough randomness to choose 10 winners"
        );
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].paid
        );
        uint16[] memory randomNumbers = splitUint256ToUint16(_randomWords);
        // First thing: extract the one tiger NFT winner
        {
            uint winnerIdx = randomNumbers[0] % lotteryParticipants.length();
            address winner = lotteryParticipants.at(winnerIdx);
            tiger.adminMint(winner);
        }
        // then the 9 eagles
        for (uint i = 1; i < randomNumbers.length; i++) {
            uint winnerIdx = randomNumbers[i] % lotteryParticipants.length();
            address winner = lotteryParticipants.at(winnerIdx);
            eagle.adminMint(winner);
        }
    }

    function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].paid > 0, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyRole(ADMIN_ROLE) {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    /// @notice withdrawNative withdraws the amount specified in amount to the owner
    /// @param amount the amount to withdraw, in wei
    function withdrawNative(uint256 amount) external onlyRole(ADMIN_ROLE) {
        (bool success, ) = payable(treasuryAddress).call{value: amount}("");
        // solhint-disable-next-line gas-custom-errors
        require(success, "withdrawNative failed");
    }

    function splitUint256ToUint16(
        uint256[] memory input
    ) public pure returns (uint16[] memory) {
        uint16[] memory output = new uint16[](input.length * 16);
        for (uint256 i = 0; i < input.length; i++) {
            uint256 value = input[i];
            for (uint256 j = 0; j < 16; j++) {
                output[i * 16 + j] = uint16(value & 0xFFFF);
                value >>= 16;
            }
        }
        return output;
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
