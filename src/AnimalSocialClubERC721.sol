// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/Vera3DistributionModel.sol";

// import "forge-std/console.sol";
// import "forge-std/console2.sol";

contract AnimalSocialClubERC721 is
    ERC721,
    Ownable,
    ReentrancyGuard,
    Vera3DistributionModel
{
    using Strings for uint256;

    uint256 public immutable TOTAL_SUPPLY;
    uint256 public immutable PRICE;

    // can mint 1 at a time
    uint256 public constant MAXIMUM_MINTABLE = 1;

    // Addresses for funds allocation
    address public vera3Address;
    address public ascAddress;

    // Sale status
    bool public saleActive = false;

    // Tracking token supply
    uint public currentSupply;

    // Events
    event SaleStateChanged(bool active);

    // Constructor initializing the ERC-1155 contract with a base URI and beneficiary addresses
    constructor(
        string memory name,
        string memory symbol,
        uint _totalSupply,
        uint _mint_price,
        address _vera3Address,
        address _ascAddress
    ) Ownable(_vera3Address) ERC721(name, symbol) {
        require(msg.sender == _vera3Address, "sender must be admin");
        require(
            _vera3Address != address(0) && _ascAddress != address(0),
            "One or more invalid addresses"
        );
        // Set the beneficiary addresses
        vera3Address = _vera3Address;
        ascAddress = _ascAddress;
        TOTAL_SUPPLY = _totalSupply;
        PRICE = _mint_price;
    }

    // Modifier to check if sale is active
    modifier isSaleActive() {
        require(saleActive, "Sale is not active");
        _;
    }

    // Function to start or stop the sale
    function setSaleActive(bool _saleActive) external onlyOwner {
        saleActive = _saleActive;
        emit SaleStateChanged(_saleActive);
    }

    // Function to mint Elephant NFTs
    function mint(address referrer) external payable nonReentrant isSaleActive {
        super.checkReferrer(referrer);
        require(
            currentSupply + 1 <= TOTAL_SUPPLY,
            "Exceeds total supply of Elephant tokens"
        );
        require(msg.value == PRICE, "Incorrect ETH amount sent");

        // Update token supply
        currentSupply += 1;

        // Mint the NFTs to the buyer
        _safeMint(msg.sender, currentSupply);

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
        require(i < TOTAL_SUPPLY, "Invalid card ID");
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
        require(i < TOTAL_SUPPLY, "Invalid card ID");
        require(auctionStarted, "Auction not yet started");
        require(!auctionEnded, "Auction already ended");
        require(
            block.timestamp >= auctionEndTime,
            "Auction end time not reached yet"
        );
        // Mark auction as ended
        auctionEnded = true;

        // Mint Super VIP NFTs to the highest bidder
        _safeMint(highestBidder[i], 1);
    }

    // Allow the contract owner to withdraw the highest bid after the auction ends
    function withdrawHighestBid(uint256 i) external nonReentrant onlyOwner {
        require(i < TOTAL_SUPPLY, "Invalid i");
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

    //////////////////////////////////////////////////////////////
    /////// WAITLIST
    //////////////////////////////////////////////////////////////
    uint256 public constant WAITLIST_DISCOUNT_PCT = 5;
    bool public isLaunched = false;

    // keep track of who's on waitlist
    mapping(address => bool) public waitlist;
    // keep track of which specific tokenId the address is waitlisted for
    mapping(address => uint) public waitlistId;
    // keep track of who's claimed their waitlisted item
    mapping(address => bool) public waitlistClaimed;

    event WaitlistJoined(address indexed user);
    event WaitlistClaimed(address indexed user);

    /**
     * Returns how much the user has to deposit in order to reserve a place in the waitlist.
     */
    function getWaitlistDepositAmount() public view returns (uint256) {
        uint256 waitlist_deposit = PRICE;
        return waitlist_deposit / 2;
    }

    function joinWaitlist(uint tokenId) external payable {
        require(!isLaunched, "Sale has already launched");
        uint256 waitlist_deposit = getWaitlistDepositAmount();
        require(msg.value == waitlist_deposit, "Incorrect deposit amount");
        require(!waitlist[msg.sender], "Already on waitlist for this token");

        waitlist[msg.sender] = true;
        waitlistId[msg.sender] = tokenId;
        emit WaitlistJoined(msg.sender);
    }

    function claimWaitlist() external payable nonReentrant {
        require(isLaunched, "Sale has not launched yet");
        require(waitlist[msg.sender], "Not on waitlist for this token");
        require(!waitlistClaimed[msg.sender], "Waitlist already claimed");

        uint256 waitlist_deposit = getWaitlistDepositAmount();

        uint256 remainingPrice = PRICE - waitlist_deposit;
        uint256 discount = (remainingPrice * WAITLIST_DISCOUNT_PCT) / 100;
        uint256 finalPrice = remainingPrice - discount;

        require(msg.value == finalPrice, "Incorrect payment amount");

        waitlistClaimed[msg.sender] = true;
        uint256 tokenId = waitlistId[msg.sender];
        _safeMint(msg.sender, tokenId);
        emit WaitlistClaimed(msg.sender);
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
