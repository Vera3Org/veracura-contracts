// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// import {console} from "forge-std/console.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AnimalSocialClubERC721} from "src/AnimalSocialClubERC721.sol";


contract ASCAuction is Ownable, IERC721Receiver, ReentrancyGuard {
    AnimalSocialClubERC721 public immutable tiger;
    uint256 public tokenId = uint256.max;

    constructor(address _treasuryAddress, address payable _tigerAddress)
        Ownable(msg.sender)
    {
        tiger = AnimalSocialClubERC721(_tigerAddress);
        auctionEndTime = type(uint256).max;
    }

    /////////////////////////////////////////////////////////////////
    ///////// TIGER Auction things
    /////////////////////////////////////////////////////////////////

    // /// @dev keys are token IDs, values are address & amount of current highest bidder
    // address[] public highestBidder;

    struct Bid {
        address _address;
        uint256 amount;
    }
    /// @dev keys are token IDs, values are the current highest bidder and bid value.

    mapping(uint256 => Bid) public highestBid;

    // track auction start & end
    bool public auctionStarted;
    bool public auctionEnded;
    uint256 public auctionEndTime;

    uint256 public constant startingPrice = 2 ether;
    // minimum step to increment highest bid
    uint256 public constant minBidIncrement = 0.1 ether;

    /**
     * @dev function used by admin to start the auction for this contract's reserved tokens.
     */
    function startAuction() external onlyOwner {
        require(!auctionStarted, "Auction already started");
        require(!auctionEnded && block.timestamp <= auctionEndTime, "Auction already ended");
        auctionEndTime = block.timestamp + 7 days; // Auction duration is 7 days
        auctionStarted = true;
    }

    /**
     * @dev Place bid on a certain reserved token.
     * Bid is included in `msg.value`.
     * If higher than current highest bid + `minbidIncrement`,
     * then `msg.sender` becomes the new highest bidder, and the previous
     * bid value is transfered back to the previous user.
     */
    function placeBid() external payable nonReentrant {
        require(this.tokenId < tiger.MAX_TOKEN_SUPPLY(), "this.tokenId is too high");
        require(this.tokenId > tiger.MAX_TOKEN_SUPPLY() - tiger.NUMBER_RESERVED(), "this.tokenId is too low");
        require(auctionStarted, "Auction not yet started");
        require(!auctionEnded && block.timestamp <= auctionEndTime, "Auction already ended");
        require(msg.value > highestBid[this.tokenId].amount + minBidIncrement, "Bid must be higher than current highest bid");
        require(msg.value >= startingPrice, "Bid must be at least the starting price");
        Bid memory oldBid = highestBid[this.tokenId];
        // address oldHighestBidder = highestBidder[this.tokenId];
        // uint256 oldHighestBid = highestBid[this.tokenId];
        bool shouldRefund = oldBid._address != address(0);

        // highestBidder[this.tokenId] = msg.sender;
        {
            Bid memory newBid;
            newBid._address = msg.sender;
            newBid.amount = msg.value;
            highestBid[this.tokenId] = newBid;
        }

        if (shouldRefund) {
            // Refund the previous highest bidder
            payable(oldBid._address).transfer(oldBid.amount);
        }
    }

    function endAuction(uint256 i) external nonReentrant onlyOwner{
        require(i < tiger.MAX_TOKEN_SUPPLY(), "Invalid card ID");
        require(auctionStarted, "Auction not yet started");
        require(!auctionEnded, "Auction already ended");
        require(block.timestamp >= auctionEndTime, "Auction end time not reached yet");
        // Mark auction as ended
        auctionEnded = true;

        // Mint Super VIP NFTs to the highest bidder
        tiger.safeTransfer(highestBid[i]._address, i);
    }

    // Allow the contract owner to withdraw the highest bid after the auction ends
    function withdrawHighestBid(uint256 i) external nonReentrant onlyOwner{
        require(i < tiger.MAX_TOKEN_SUPPLY(), "Invalid i");
        require(auctionStarted, "Auction not yet started");
        require(auctionEnded, "Auction has not ended yet");
        require(block.timestamp >= auctionEndTime, "Auction end time not reached yet");
        require(highestBid[i]._address != address(0), "No bids received");

        uint256 amount = highestBid[i].amount;
        highestBid[i].amount = 0;
        highestBid[i]._address = address(0);
        payable(owner()).transfer(amount);
    }

    function onERC721Received(address operator, address from, uint256 _tokenId, bytes calldata data) external returns (bytes4) {
        // this contract will receive the tiger to be auctioned, and nothing more.
        if (msg.sender == address(tiger)) {
            require(this.tokenId == uint256.max, "contract can receive at most one ASC tiger NFT");
            this.tokenId = _tokenId;
        } else {
            revert("cannot receive anything but tiger nfts");
        }
        return this.onERC721Received.selector;
    }

}