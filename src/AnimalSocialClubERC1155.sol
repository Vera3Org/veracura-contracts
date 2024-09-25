// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/Vera3DistributionModel.sol";

// import "forge-std/console.sol";
// import "forge-std/console2.sol";

contract AnimalSocialClubERC1155 is
    ERC1155,
    Ownable,
    ReentrancyGuard,
    Vera3DistributionModel
{
    using Strings for uint256;

    // Token ID constants
    uint256 public constant ID_ELEPHANT = 1;
    uint256 public constant ID_SHARK = 2;
    uint256 public constant ID_EAGLE = 3;
    uint256 public constant ID_TIGER = 4;
    uint256 public constant ID_RESERVED = 5;

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
    mapping(uint256 => uint256) public currentSupply;

    // Events
    event SaleStateChanged(bool active);

    // Constructor initializing the ERC-1155 contract with a base URI and beneficiary addresses
    constructor(
        string memory baseURI,
        address _vera3Address,
        address _ascAddress
    ) Ownable(_vera3Address) ERC1155(baseURI) {
        require(msg.sender == _vera3Address, "sender must be admin");
        require(
            _vera3Address != address(0) && _ascAddress != address(0),
            "One or more invalid addresses"
        );
        // Set the beneficiary addresses
        vera3Address = _vera3Address;
        ascAddress = _ascAddress;

        // Mint reserved tokens for the team
        _mint(msg.sender, ID_RESERVED, TOTAL_RESERVED, "");
        currentSupply[ID_RESERVED] = TOTAL_RESERVED;
    }

    // Modifier to check if sale is active
    modifier isSaleActive() {
        require(saleActive, "Sale is not active");
        _;
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
        } else if (tokenId == ID_RESERVED) {
            return TOTAL_RESERVED;
        } else {
            revert("tokenId not valid");
        }
    }

    // Function to set the base URI for the metadata
    function setBaseURI(string memory baseURI) external nonReentrant onlyOwner {
        _setURI(baseURI);
    }

    // Function to start or stop the sale
    function setSaleActive(bool _saleActive) external onlyOwner {
        saleActive = _saleActive;
        emit SaleStateChanged(_saleActive);
    }

    // Function to mint Elephant NFTs
    function mintElephant(
        uint256 amount,
        address referrer
    ) external payable nonReentrant isSaleActive {
        super.checkReferrer(referrer);
        require(
            amount > 0 && amount <= MAXIMUM_MINTABLE,
            "Cannot mint more than MAXIMUM_MINTABLE at a time"
        );
        require(
            currentSupply[ID_ELEPHANT] + amount <= TOTAL_ELEPHANT,
            "Exceeds total supply of Elephant tokens"
        );
        require(
            msg.value == amount * ELEPHANT_PRICE,
            "Incorrect ETH amount sent"
        );

        // Update token supply
        currentSupply[ID_ELEPHANT] += amount;

        // Mint the NFTs to the buyer
        _mint(msg.sender, ID_ELEPHANT, amount, "");

        sendCommission(referrer);
    }

    function mintShark(
        uint256 amount,
        address referrer
    ) external payable nonReentrant isSaleActive {
        super.checkReferrer(referrer);
        require(
            amount > 0 && amount <= MAXIMUM_MINTABLE,
            "Cannot mint more than MAXIMUM_MINTABLE at a time"
        );
        require(
            currentSupply[ID_SHARK] + amount <= TOTAL_SHARK,
            "Exceeds total supply of Shark tokens"
        );
        require(msg.value == amount * SHARK_PRICE, "Incorrect ETH amount sent");

        currentSupply[ID_SHARK] += amount;
        _mint(msg.sender, ID_SHARK, amount, "");

        sendCommission(referrer);
    }

    // Function to mint EAGLE NFTs
    function mintEagle(
        uint256 amount,
        address referrer
    ) external payable nonReentrant isSaleActive {
        super.checkReferrer(referrer);
        require(
            amount > 0 && amount <= MAXIMUM_MINTABLE,
            "Cannot mint more than MAXIMUM_MINTABLE at a time"
        );
        require(
            currentSupply[ID_EAGLE] + amount <= TOTAL_EAGLE,
            "Exceeds total supply of EAGLE tokens"
        );
        require(msg.value == amount * EAGLE_PRICE, "Incorrect ETH amount sent");

        currentSupply[ID_EAGLE] += amount;
        _mint(msg.sender, ID_EAGLE, amount, "");

        sendCommission(referrer);
    }

    // Function to withdraw funds to respective beneficiaries
    function withdrawFunds() external nonReentrant onlyOwner {
        // console2.log("Hello");
        uint256 balance = address(this).balance;
        // console2.log("got balance");
        require(balance > 0, "No funds to withdraw");

        uint256 vera3Share = (balance * 30) / 100;
        uint256 ascShare = (balance * 70) / 100;
        // console2.log("Vera3share: ", vera3Share);
        // console2.log("Asc3share: ", ascShare);

        payable(vera3Address).transfer(vera3Share);
        // console2.log("transfered veraShare %d to vera3", vera3Share);
        payable(ascAddress).transfer(ascShare);
        // console2.log("transfered ascShare %d to asc", ascShare);
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
    uint256 public constant startingPrice = 2 ether;
    uint256 public constant minBidIncrement = 0.1 ether;

    function startAuction() external onlyOwner {
        require(!auctionStarted, "Auction already started");
        require(
            !auctionEnded && block.timestamp <= auctionEndTime,
            "Auction already ended"
        );
        auctionEndTime = block.timestamp + 7 days; // Auction duration is 7 days
        auctionStarted = true;
    }

    function placeBid(uint256 i) external payable nonReentrant {
        require(i < TOTAL_TIGER, "Invalid card ID");
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

        highestBidder[i] = msg.sender;
        highestBid[i] = msg.value;

        if (highestBidder[i] != address(0)) {
            // Refund the previous highest bidder
            payable(highestBidder[i]).transfer(highestBid[i]);
        }
    }

    function endAuction(uint256 i) external nonReentrant onlyOwner {
        require(i < TOTAL_TIGER, "Invalid card ID");
        require(auctionStarted, "Auction not yet started");
        require(!auctionEnded, "Auction already ended");
        require(
            block.timestamp >= auctionEndTime,
            "Auction end time not reached yet"
        );
        // Mark auction as ended
        auctionEnded = true;

        // Mint Super VIP NFTs to the highest bidder
        _mint(highestBidder[i], ID_TIGER, 1, "");
    }

    // Allow the contract owner to withdraw the highest bid after the auction ends
    function withdrawHighestBid(uint256 i) external nonReentrant onlyOwner {
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

    function tokenSalePrice(uint256 tokenId) public pure returns (uint256) {
        if (tokenId == ID_EAGLE) {
            return EAGLE_PRICE;
        } else if (tokenId == ID_SHARK) {
            return SHARK_PRICE;
        } else if (tokenId == ID_ELEPHANT) {
            return ELEPHANT_PRICE;
        } else {
            revert("Invalid token ID");
        }
    }

    //////////////////////////////////////////////////////////////
    /////// WAITLIST
    //////////////////////////////////////////////////////////////
    uint256 public constant WAITLIST_DISCOUNT_PCT = 5;
    bool public isLaunched = false;

    mapping(address => mapping(uint256 => bool)) public waitlist;
    mapping(address => mapping(uint256 => bool)) public waitlistClaimed;

    event WaitlistJoined(address indexed user, uint256 tokenId);
    event WaitlistClaimed(address indexed user, uint256 tokenId);

    /**
     * Returns how much the user has to deposit in order to reserve a place in the waitlist.
     * @param tokenId the token ID for which to get the necessary deposit amount for waitlist
     */
    function getWaitlistDepositAmount(
        uint256 tokenId
    ) public pure returns (uint256) {
        uint256 waitlist_deposit = 0;
        if (tokenId == ID_EAGLE) {
            waitlist_deposit = EAGLE_PRICE;
        } else if (tokenId == ID_SHARK) {
            waitlist_deposit = SHARK_PRICE;
        } else if (tokenId == ID_ELEPHANT) {
            waitlist_deposit = ELEPHANT_PRICE;
        } else {
            revert("Invalid token ID");
        }
        return waitlist_deposit / 2;
    }

    function joinWaitlist(uint256 tokenId) external payable {
        require(!isLaunched, "Sale has already launched");
        require(tokenId < 4, "Invalid token ID"); // RESERVED and TIGER are excluded from waitlist
        uint256 waitlist_deposit = getWaitlistDepositAmount(tokenId);
        require(msg.value == waitlist_deposit, "Incorrect deposit amount");
        require(
            !waitlist[msg.sender][tokenId],
            "Already on waitlist for this token"
        );

        waitlist[msg.sender][tokenId] = true;
        emit WaitlistJoined(msg.sender, tokenId);
    }

    function claimWaitlist(uint256 tokenId) external payable nonReentrant {
        require(isLaunched, "Sale has not launched yet");
        require(
            waitlist[msg.sender][tokenId],
            "Not on waitlist for this token"
        );
        require(
            !waitlistClaimed[msg.sender][tokenId],
            "Waitlist already claimed"
        );

        uint256 waitlist_deposit = getWaitlistDepositAmount(tokenId);

        uint256 remainingPrice = tokenSalePrice(tokenId) - waitlist_deposit;
        uint256 discount = (remainingPrice * WAITLIST_DISCOUNT_PCT) / 100;
        uint256 finalPrice = remainingPrice - discount;

        require(msg.value == finalPrice, "Incorrect payment amount");

        waitlistClaimed[msg.sender][tokenId] = true;
        _mint(msg.sender, tokenId, 1, "");
        emit WaitlistClaimed(msg.sender, tokenId);
    }

    function launch() external onlyOwner {
        isLaunched = true;
    }

    /**
        LOTTERY
        Requirement: 
         - there is a list `lotteryParticipants`, which is 
           made up of all owners of standard & premium tiers.
         - enough random bytes to choose 9 VIP and 1 Super VIP winners
         - Use Chainlink VRF "Direct Funding" method since this is a sporadic req
     */
}
