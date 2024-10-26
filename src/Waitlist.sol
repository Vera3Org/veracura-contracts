// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/Vera3DistributionModel.sol";
import "@requestnetwork/advanced-logic/src/contracts/interfaces/EthereumFeeProxy.sol";
import "src/ASC721Manager.sol";

// import "forge-std/console.sol";
// import "forge-std/console2.sol";

contract ASCWaitlist is Ownable, ReentrancyGuard {
    IEthereumFeeProxy public constant ETHEREUM_FEE_PROXY =
        IEthereumFeeProxy(0xd9C3889eB8DA6ce449bfFE3cd194d08A436e96f2);

    address payable public immutable TREASURY;
    // Token ID constants
    uint256 public constant ID_ELEPHANT = 1;
    uint256 public constant ID_SHARK = 2;
    uint256 public constant ID_EAGLE = 3;
    uint256 public constant ID_TIGER = 4;

    // Token supply
    uint256 public constant ELEPHANT_PRICE = 0.1 ether;
    uint256 public constant SHARK_PRICE = 0.5 ether;
    uint256 public constant EAGLE_PRICE = 1 ether;
    uint256 public constant TIGER_PRICE = 2 ether;

    // Token supply
    uint256 public constant TOTAL_ELEPHANT = 9000;
    uint256 public constant TOTAL_SHARK = 520;
    uint256 public constant TOTAL_EAGLE = 200;
    uint256 public constant TOTAL_TIGER = 30 - 10; // ten for auction

    // Tracking token supply
    mapping(uint256 => uint256) public currentSupply;

    mapping(address => uint256[]) waitlist;
    address[] public waitlistAddresses;

    constructor(address payable treasury) Ownable(msg.sender) {
        TREASURY = treasury;
    }

    function tokenSalePrice(uint256 tokenId) public pure returns (uint256) {
        if (tokenId == ID_ELEPHANT) {
            return ELEPHANT_PRICE;
        } else if (tokenId == ID_SHARK) {
            return SHARK_PRICE;
        } else if (tokenId == ID_EAGLE) {
            return EAGLE_PRICE;
        } else if (tokenId == ID_TIGER) {
            return TIGER_PRICE;
        } else {
            revert("Invalid token ID");
        }
    }

    function totalSupplyOf(uint tokenId) public pure returns (uint) {
        if (tokenId == ID_EAGLE) {
            return TOTAL_EAGLE;
        } else if (tokenId == ID_ELEPHANT) {
            return TOTAL_ELEPHANT;
        } else if (tokenId == ID_SHARK) {
            return TOTAL_SHARK;
        } else if (tokenId == ID_EAGLE) {
            return TOTAL_EAGLE;
        } else if (tokenId == ID_TIGER) {
            return TOTAL_TIGER;
        } else {
            revert("tokenId not valid");
        }
    }

    function addToWaitlist(
        address user,
        uint tokenId,
        bytes calldata _paymentReference
    ) public payable {
        require(tokenId >= ID_ELEPHANT && tokenId <= ID_TIGER);
        uint price = tokenSalePrice(tokenId);
        require(msg.value >= price, "Insufficient msg.value");
        uint totalSupply = totalSupplyOf(tokenId);
        require(
            currentSupply[tokenId] + 1 < totalSupply,
            "Total supply reached for this NFT"
        );

        currentSupply[tokenId] += 1;
        waitlist[user].push(tokenId);
        waitlistAddresses.push(user);

        ETHEREUM_FEE_PROXY.transferWithReferenceAndFee(
            TREASURY,
            _paymentReference,
            0,
            payable(address(0))
        );
    }
}
