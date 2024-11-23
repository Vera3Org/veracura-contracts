// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "@requestnetwork/advanced-logic/src/contracts/interfaces/EthereumFeeProxy.sol";

import "src/Vera3DistributionModel.sol";
import "src/ASC721Manager.sol";

// import "forge-std/console.sol";
// import "forge-std/console2.sol";

contract AnimalSocialClubERC721 is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    Vera3DistributionModel
{
    using Strings for uint256;

    uint256 public TOTAL_SUPPLY;
    uint256 public PRICE;
    uint256 public NUMBER_RESERVED;

    // can mint 1 at a time
    uint256 public constant MAXIMUM_MINTABLE = 1;

    // Addresses for funds allocation
    address public adminAddress;
    address public treasuryAddress;
    ASC721Manager public manager;

    // Sale status
    bool public saleActive;

    // Tracking token supply
    uint public currentSupply;

    // Events
    event SaleStateChanged(bool active);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint _totalSupply,
        uint _mint_price,
        address _adminAddress,
        address _treasuryAddress,
        ASC721Manager _manager,
        uint num_reserved,
        address ethFeeProxy
    ) public initializer {
        __Ownable_init(_adminAddress);
        __ERC721_init(name, symbol);
        __ReentrancyGuard_init();
        __Vera3DistributionModel_init(ethFeeProxy);
        // require(msg.sender == _adminAddress, "sender must be admin");
        require(
            _adminAddress != address(0) && _treasuryAddress != address(0),
            "One or more invalid addresses"
        );
        // Set the beneficiary addresses
        adminAddress = _adminAddress;
        treasuryAddress = _treasuryAddress;
        TOTAL_SUPPLY = _totalSupply;
        PRICE = _mint_price;
        manager = ASC721Manager(_manager);
        NUMBER_RESERVED = num_reserved;
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

    function isASCMember(address a) public view returns (bool) {
        return manager.isMember(a);
    }

    // Function to mint NFTs. `referrer` is optional.
    function adminMint(
        address to
    ) external payable nonReentrant isSaleActive onlyOwner {
        // it's on the admin to add kyc or kyb
        require(manager.hasKYC(to), "Destination address without KYC!");
        require(
            currentSupply + 1 <= TOTAL_SUPPLY,
            "Exceeds total supply of tokens"
        );
        require(
            currentSupply + 1 <= (TOTAL_SUPPLY - NUMBER_RESERVED),
            "No more tokens: the remainder is reserved"
        );

        // Update token supply
        currentSupply += 1;

        // Mint the NFTs to the buyer
        _safeMint(to, currentSupply);
    }

    // Function to mint NFTs. `referrer` is optional.
    function mintWithDonationRequestNetwork(
        address to,
        address referrer,
        bytes calldata donorReference,
        bytes calldata ambassadorReference,
        bytes calldata advocateReference,
        bytes calldata evangelistReference
    ) external payable nonReentrant isSaleActive {
        // require(!isASCMember(to), "Only one membership per address");
        require(manager.hasKYC(to), "Destination address without KYC!");
        super.requireReferrer(referrer);
        require(
            currentSupply + 1 <= TOTAL_SUPPLY,
            "Exceeds total supply of tokens"
        );
        require(
            currentSupply + 1 <= (TOTAL_SUPPLY - NUMBER_RESERVED),
            "No more tokens: the remainder is reserved for lottery"
        );
        require(msg.value == PRICE, "Incorrect ETH amount sent");

        // Update token supply
        currentSupply += 1;

        console.log("minting");
        // Mint the NFTs to the buyer
        _safeMint(to, currentSupply);
        console.log("minted");

        ETHEREUM_FEE_PROXY.transferWithReferenceAndFee(
            payable(manager.treasuryAddress()),
            donorReference,
            0,
            payable(address(0))
        );
        sendCommission(
            referrer,
            ambassadorReference,
            advocateReference,
            evangelistReference
        );
        console.log("commission sent");
    }

    // Function to withdraw funds to respective beneficiaries
    function withdrawFunds() external nonReentrant onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0, "No funds to withdraw");

        if (balance > 0) {
            payable(treasuryAddress).transfer(balance);
        }
    }

    // Function to ensure contract can receive Ether
    receive() external payable {}

    /////////////////////////////////////////////////////////////////
    ///////// TIGER Auction things
    /////////////////////////////////////////////////////////////////

    // address & amount of current highest bid
    address[] public highestBidder;
    uint256[] public highestBid;

    // track auction start & end
    bool public auctionStarted;
    bool public auctionEnded;
    uint256 public auctionEndTime;

    uint256 public constant startingPrice = 2 ether;
    // minimum step to increment highest bid
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

    /**
     * Place bid on a certain reserved token.
     * Bid is included in msg.value.
     * If higher than highest bid + minimum increment,
     * this bid becomes the new highest bid, and the previous one
     * gets transfered back to the previous user.
     */
    function placeBid(uint256 tokenId) external payable nonReentrant {
        require(tokenId < TOTAL_SUPPLY, "tokenId is too high");
        require(tokenId > TOTAL_SUPPLY - NUMBER_RESERVED, "tokenId is too low");
        require(auctionStarted, "Auction not yet started");
        require(
            !auctionEnded && block.timestamp <= auctionEndTime,
            "Auction already ended"
        );
        require(
            msg.value > highestBid[tokenId] + minBidIncrement,
            "Bid must be higher than current highest bid"
        );
        require(
            msg.value >= startingPrice,
            "Bid must be at least the starting price"
        );

        highestBidder[tokenId] = msg.sender;
        highestBid[tokenId] = msg.value;

        if (highestBidder[tokenId] != address(0)) {
            // Refund the previous highest bidder
            payable(highestBidder[tokenId]).transfer(highestBid[tokenId]);
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
        _safeMint(highestBidder[i], i);
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
    bool public isLaunched;

    // keep track of who's on waitlist
    mapping(address => bool) public waitlist;
    // keep track of which specific tokenId the address is waitlisted for
    mapping(address => uint) public waitlistId;
    // keep track of how much deposit was made for waitlist
    mapping(address => uint) public waitlistDeposited;
    // keep track of who's claimed their waitlisted item
    mapping(address => bool) public waitlistClaimed;

    event WaitlistJoined(address indexed user);
    event WaitlistClaimed(address indexed user);

    /**
     * Register someone on the waitlist for the tokenId.
     * Assume they deposited `waitlist_deposit` amount of ETH.
     * Only admin can do this.
     */
    function addToWaitlist(
        uint waitlist_deposit,
        address user
    ) external payable onlyOwner nonReentrant {
        require(!isLaunched, "Sale has already launched");

        uint tokenId = currentSupply;
        require(_ownerOf(tokenId) == address(0), "tokenId is already owned");
        require(
            tokenId < TOTAL_SUPPLY,
            "Total supply exhausted for this token"
        );
        require(!waitlist[user], "Already on waitlist for this token");
        require(waitlist_deposit <= PRICE, "deposit amount is more than price");

        waitlistDeposited[user] += waitlist_deposit;

        waitlist[user] = true;
        waitlistId[user] = tokenId;

        currentSupply += 1;

        emit WaitlistJoined(user);
    }

    /**
     * Called by a user to claim their waitlisted token.
     * User must pay what's left to pay minus a discount.
     * After payment, the token is minted to them just like the normal case.
     * currentSupply is not incremented here because it already was in addToWaitlist.
     */
    function claimWaitlist() external payable nonReentrant {
        require(isLaunched, "Sale has not launched yet");
        require(waitlist[msg.sender], "Not on waitlist for this token");
        require(!waitlistClaimed[msg.sender], "Waitlist already claimed");

        uint256 waitlist_deposit = waitlistDeposited[msg.sender];

        uint256 remainingPrice = PRICE - waitlist_deposit;
        uint256 discount = (remainingPrice * WAITLIST_DISCOUNT_PCT) / 100;
        uint256 finalPrice = remainingPrice - discount;

        require(msg.value == finalPrice, "Incorrect payment amount");

        waitlistClaimed[msg.sender] = true;
        uint256 tokenId = waitlistId[msg.sender];
        _safeMint(msg.sender, tokenId);
        emit WaitlistClaimed(msg.sender);
    }

    function launch() external onlyOwner nonReentrant {
        isLaunched = true;
    }
}
