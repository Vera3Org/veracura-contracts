// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AnimalSocialClubERC721} from "src/AnimalSocialClubERC721.sol";
import {Vera3DistributionModel} from "src/Vera3DistributionModel.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract ASCLottery is VRFV2PlusWrapperConsumerBase, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords, uint256 payment);

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

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

    address public tigerWinner;
    address[] public eagleWinners;

    // address[] private lotteryParticipants;

    /**
     * @dev addresses which are eligible to receive a membership
     * using the lottery membership.
     * An address is added to this set when they receive a membership.
     */
    EnumerableSet.AddressSet private lotteryParticipants;

    address public immutable treasuryAddress;

    constructor(address _linkAddress, address _VrfWrapperAddress, address _treasuryAddress)
        VRFV2PlusWrapperConsumerBase(_VrfWrapperAddress)
        Ownable(msg.sender)
    {
        // require(_grantRole(OPERATOR_ROLE, msg.sender), "could not grant role");
        // require(_grantRole(ADMIN_ROLE, msg.sender), "could not grant role");

        linkAddress = _linkAddress;
        wrapperAddress = _VrfWrapperAddress;
        treasuryAddress = _treasuryAddress;
    }

    function addToParticipants(address it) external onlyOwner {
        console.log("ASCLottery msg.sender: ", msg.sender);
        lotteryParticipants.add(it);
    }

    function requestRandomWords(bool enableNativePayment) external payable onlyOwner returns (uint256) {
        bytes memory extraArgs =
            VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment}));
        uint256 requestId;
        uint256 reqPrice;
        if (enableNativePayment) {
            (requestId, reqPrice) =
                requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, numWords, extraArgs);
        } else {
            (requestId, reqPrice) = requestRandomness(callbackGasLimit, requestConfirmations, numWords, extraArgs);
        }
        s_requests[requestId] = RequestStatus({paid: reqPrice, randomWords: new uint256[](0), fulfilled: false});
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        require(_randomWords.length >= 10, "Need enough randomness to choose 10 winners");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords, s_requests[_requestId].paid);
        uint16[] memory randomNumbers = splitUint256ToUint16(_randomWords);
        // First thing: extract the one tiger NFT winner
        {
            uint256 winnerIdx = randomNumbers[0] % lotteryParticipants.length();
            address winner = lotteryParticipants.at(winnerIdx);
            tigerWinner = winner;
        }
        // then the 9 eagles
        for (uint256 i = 1; i < randomNumbers.length; i++) {
            uint256 winnerIdx = randomNumbers[i] % lotteryParticipants.length();
            address winner = lotteryParticipants.at(winnerIdx);
            eagleWinners.push(winner);
        }
    }

    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].paid > 0, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }

    /**
     * Allow withdraw of Link tokens from the contract to msg.sender
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }

    /// @notice withdrawNative withdraws the amount specified in amount to the treasury
    /// @param amount the amount to withdraw, in wei
    function withdrawNative(uint256 amount) external onlyOwner {
        (bool success,) = payable(treasuryAddress).call{value: amount}("");
        // solhint-disable-next-line gas-custom-errors
        require(success, "withdrawNative failed");
    }

    function splitUint256ToUint16(uint256[] memory input) public pure returns (uint16[] memory) {
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
}
