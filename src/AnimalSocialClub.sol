// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "forge-std/console2.sol";

contract AnimalSocialClub is ERC1155, Ownable {
    using Strings for uint256;

    // Token ID constants
    uint256 public constant ID_RESERVED = 0;
    uint256 public constant ID_ELEPHANT = 1;
    uint256 public constant ID_SHARK = 2;
    uint256 public constant ID_EAGLE = 3;
    uint256 public constant ID_TIGER = 4;

    // Token Prices
    uint256 public constant ELEPHANT_PRICE = 0.1 ether;
    uint256 public constant SHARK_PRICE = 0.5 ether;
    uint256 public constant EAGLE_PRICE = 1 ether;

    // Token supply
    uint256 public constant TOTAL_RESERVED = 250;
    uint256 public constant TOTAL_ELEPHANT = 9000;
    uint256 public constant TOTAL_SHARK = 520;
    uint256 public constant TOTAL_EAGLE = 200;
    uint256 public constant TOTAL_TIGER = 30;

    // can mint 1 at a time
    uint256 public constant MAXIMUM_MINTABLE = 1;

    // Addresses for funds allocation
    address public vera3Address;
    address public ascAddress;

    // Sale status
    bool public saleActive = false;

    // Tracking token supply
    mapping(uint256 => uint256) public tokenSupply;

    // Events
    event SaleStateChanged(bool active);

    // Constructor initializing the ERC-1155 contract with a base URI and beneficiary addresses
    constructor(
        string memory baseURI,
        address _vera3Address,
        address _ascAddress
    ) Ownable(_vera3Address) ERC1155(baseURI) {
        // Set the beneficiary addresses
        vera3Address = _vera3Address;
        ascAddress = _ascAddress;

        // Mint reserved tokens for the team
        _mint(msg.sender, ID_RESERVED, TOTAL_RESERVED, "");
        tokenSupply[ID_RESERVED] = TOTAL_RESERVED;
    }

    // Modifier to check if sale is active
    modifier isSaleActive() {
        require(saleActive, "Sale is not active");
        _;
    }

    // Function to set the base URI for the metadata
    function setBaseURI(string memory baseURI) external onlyOwner {
        _setURI(baseURI);
    }

    // Function to start or stop the sale
    function setSaleActive(bool _saleActive) external onlyOwner {
        saleActive = _saleActive;
        emit SaleStateChanged(_saleActive);
    }

    // Function to mint Elephant NFTs
    function mintElephant(uint256 amount) external payable isSaleActive {
        require(
            amount > 0 && amount <= MAXIMUM_MINTABLE,
            "Cannot mint more than MAXIMUM_MINTABLE at a time"
        );
        require(
            tokenSupply[ID_ELEPHANT] + amount <= TOTAL_ELEPHANT,
            "Exceeds total supply of Elephant tokens"
        );
        require(
            msg.value == amount * ELEPHANT_PRICE,
            "Incorrect ETH amount sent"
        );

        _mint(msg.sender, ID_ELEPHANT, amount, "");
        tokenSupply[ID_ELEPHANT] += amount;
    }

    // Function to mint Shark NFTs
    function mintShark(uint256 amount) external payable isSaleActive {
        require(
            amount > 0 && amount <= MAXIMUM_MINTABLE,
            "Cannot mint more than MAXIMUM_MINTABLE at a time"
        );
        require(
            tokenSupply[ID_SHARK] + amount <= TOTAL_SHARK,
            "Exceeds total supply of Shark tokens"
        );
        require(msg.value == amount * SHARK_PRICE, "Incorrect ETH amount sent");

        _mint(msg.sender, ID_SHARK, amount, "");
        tokenSupply[ID_SHARK] += amount;
    }

    // Function to mint EAGLE NFTs
    function mintEagle(uint256 amount) external payable isSaleActive {
        require(
            amount > 0 && amount <= MAXIMUM_MINTABLE,
            "Cannot mint more than MAXIMUM_MINTABLE at a time"
        );
        require(
            tokenSupply[ID_EAGLE] + amount <= TOTAL_EAGLE,
            "Exceeds total supply of EAGLE tokens"
        );
        require(msg.value == amount * EAGLE_PRICE, "Incorrect ETH amount sent");

        _mint(msg.sender, ID_EAGLE, amount, "");
        tokenSupply[ID_EAGLE] += amount;
    }

    // Function to withdraw funds to respective beneficiaries
    function withdrawFunds() external onlyOwner {
        console2.log("Hello");
        uint256 balance = address(this).balance;
        console2.log("got balance");
        require(balance > 0, "No funds to withdraw");

        uint256 vera3Share = (balance * 30) / 100;
        uint256 ascShare = (balance * 70) / 100;
        console2.log("Vera3share: ", vera3Share);
        console2.log("Asc3share: ", ascShare);

        payable(vera3Address).transfer(vera3Share);
        console2.log("transfered to vera3");
        payable(ascAddress).transfer(ascShare);
        console2.log("transfered to asc");
    }

    // Override URI function to return token-specific metadata
    function uri(uint256 tokenId) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    super.uri(tokenId),
                    tokenId.toString(),
                    ".json"
                )
            );
    }

    // Function to ensure contract can receive Ether
    receive() external payable {}

    /////////////////////////////////////////////////////////////////
    ///////// TIGER Auction things
    /////////////////////////////////////////////////////////////////
    address[] public highestBidder;
    uint256[] public highestBid;
    bool public auctionStarted = false;
    bool public auctionEnded = false;
    uint256 public auctionEndTime;
    uint256 public startingPrice = 2 ether;
    uint256 public minBidIncrement = 0.1 ether;

    function startAuction() external onlyOwner {
        require(!auctionStarted, "Auction already started");
        require(
            !auctionEnded && block.timestamp <= auctionEndTime,
            "Auction already ended"
        );
        auctionEndTime = block.timestamp + 7 days; // Auction duration is 7 days
        auctionStarted = true;
    }

    function placeBid(uint256 i) external payable {
        require(i < TOTAL_TIGER, "Invalid i");
        require(auctionStarted, "Auction not yet started");
        require(
            !auctionEnded && block.timestamp <= auctionEndTime,
            "Auction already ended"
        );
        require(
            msg.value > highestBid[i],
            "Bid must be higher than current highest bid"
        );
        require(
            msg.value >= startingPrice,
            "Bid must be at least the starting price"
        );

        if (highestBidder[i] != address(0)) {
            // Refund the previous highest bidder
            payable(highestBidder[i]).transfer(highestBid[i]);
        }

        highestBidder[i] = msg.sender;
        highestBid[i] = msg.value;
    }

    function endAuction(uint256 i) external onlyOwner {
        require(i < TOTAL_TIGER, "Invalid i");
        require(auctionStarted, "Auction not yet started");
        require(!auctionEnded, "Auction already ended");
        require(
            block.timestamp >= auctionEndTime,
            "Auction end time not reached yet"
        );

        // Mint Super VIP NFTs to the highest bidder
        _mint(highestBidder[i], ID_TIGER, 1, "");

        // Mark auction as ended
        auctionEnded = true;
    }

    // Allow the contract owner to withdraw the highest bid after the auction ends
    function withdrawHighestBid(uint256 i) external onlyOwner {
        require(i < TOTAL_TIGER, "Invalid i");
        require(auctionStarted, "Auction not yet started");
        require(auctionEnded, "Auction has not ended yet");
        require(
            block.timestamp >= auctionEndTime,
            "Auction end time not reached yet"
        );
        require(highestBidder[i] != address(0), "No bids received");

        uint256 amount = highestBid[i];
        highestBid[i] = 0;
        highestBidder[i] = address(0);
        payable(owner()).transfer(amount);
    }
}
