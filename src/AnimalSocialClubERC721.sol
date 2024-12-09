// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "@requestnetwork/advanced-logic/src/contracts/interfaces/EthereumFeeProxy.sol";

import "src/Vera3DistributionModel.sol";
import "src/ASC721Manager.sol";

// import "forge-std/console.sol";
// import "forge-std/console2.sol";

/**
 * @dev Contract which represents ASC membership of a certain tier.
 *
 * @dev Has a capped supply, and tokens are minted by either end-users or an
 * admin EOA. A certain number of tokens may be "reserved", either for
 * the auction or for the lottery.
 *
 * @dev Minters must be actual humans and must be verified via a off-chain
 * methods: either a decentralized KYC solution is adopted, or the
 * administrator has verified it, an entity with the `OPERATOR_ROLE` role
 * must register that a certain address has KYC and is thus enabled to mint.
 *
 * @dev When an end-user mints a membership, the donation must be tracked using
 * Request Network. Because of this, a reference to their `EthereumFeeProxy`
 * contract address must be provided at initialization time.
 *
 * @dev When the membership is minted because of off-chain donations, this
 * contract's administrator (with ADMIN_ROLE) is able to mint it to
 * members which have been registered as having performed KYC.
 *
 * @dev When a membership is minted by any means, the membership owner must be
 * added to the list of lottery participants, located in the storage of the
 * `manager`'s contract.
 *
 * @dev Tiger memberships have an auction feature, with a 2 ETH starting price,
 * and minimum bid increment of 0.1 ether. When the auction ends, the
 * highest bidder can withdraw a Tiger NFT.
 *
 * @dev There is a waitlist feature: users who were part of the waitlist and
 * deposited a certain amount are able to claim their membership, by
 * paying the difference between their price and the mint price discounted
 * by 5%.
 *
 * @dev Contract uses OpenZeppelin's Upgrades features, so it inherits from Upgradeable
 * contracts, and is a UUPS proxy.
 */
contract AnimalSocialClubERC721 is
    Initializable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    Vera3DistributionModel
{
    using Strings for uint256;

    uint256 public MAX_TOKEN_SUPPLY;
    uint256 public PRICE;
    uint256 public NUMBER_RESERVED;
    uint256 public TIER_ID;

    // can mint 1 at a time
    uint256 public constant MAXIMUM_MINTABLE = 1;

    /// Address of admin contract. Is the
    address public adminAddress;
    address public treasuryAddress;
    ASC721Manager public manager;

    /**
     * @dev sale status: when false, no memberships can be minted.
     */
    bool public saleActive;

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
        address ethFeeProxy,
        uint tier_id
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
        MAX_TOKEN_SUPPLY = _totalSupply;
        PRICE = _mint_price;
        manager = ASC721Manager(_manager);
        NUMBER_RESERVED = num_reserved;
        TIER_ID = tier_id;
        auctionEndTime = type(uint256).max;
        saleActive = true;
    }

    /**
     * @dev modifier which reverts if the sale is not active.
     */
    modifier isSaleActive() {
        require(saleActive, "Sale is not active");
        _;
    }

    /**
     * @dev function to start or stop the sale. can only be called by owner.
     * @param _saleActive the state of the sale. `true` to enable, `false` to disable.
     */
    function setSaleActive(bool _saleActive) external onlyOwner {
        saleActive = _saleActive;
        emit SaleStateChanged(_saleActive);
    }

    /**
     * @dev verifies whether an address is part of ASC. Calls the manager contract
     * to see if the address owns any ASC NFT.
     * @param a the address to check.
     */
    function isASCMember(address a) public view returns (bool) {
        return manager.isMember(a);
    }

    /**
     * @dev function for the admin to mint a membership to `to`.
     * Payment is made off-chain.
     * @dev requires that `saleActive` is true. See `setSaleActive`.
     * @param to the destination address
     */
    function adminMint(
        address to
    ) external nonReentrant isSaleActive onlyOwner {
        // it's on the admin to add kyc or kyb
        require(manager.hasKYC(to), "Destination address without KYC!");
        require(
            totalSupply() + 1 < MAX_TOKEN_SUPPLY,
            "Exceeds total supply of tokens"
        );
        require(
            totalSupply() + 1 < (MAX_TOKEN_SUPPLY - NUMBER_RESERVED),
            "No more tokens: the remainder is reserved"
        );

        manager.addToLotteryParticipants(to);

        // Mint the NFTs to the buyer
        _safeMint(to, totalSupply());
    }

    /**
     * @dev Main function to mint a membership NFT to a KYC'd address.
     * @dev Payment must be made via RequestNetwork.
     * @dev Requires that saleActive is true.
     * @param to detination address. `manager.hasKYC(to)` must return true.
     * @param referrer address of referring promoter, or address(0) if none
     * @param donorReference payment reference of `to`, the donor.
     * @param ambassadorReference payment reference of the ambassador. Empty if none.
     * @param advocateReference payment reference of the ambassador. Empty if none.
     * @param evangelistReference payment reference of the ambassador. Empty if none.
     */
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
        require(
            TIER_ID != manager.STAKEHOLDER_ID(),
            "Stakeholder memberships not minted with donation"
        );
        super.requireReferrer(referrer);
        require(
            totalSupply() + 1 < MAX_TOKEN_SUPPLY - waitlisted.length,
            "Exceeds total supply of tokens"
        );
        require(
            totalSupply() + 1 <
                (MAX_TOKEN_SUPPLY - NUMBER_RESERVED - waitlisted.length),
            "No more tokens: the remainder is reserved for lottery"
        );
        require(msg.value == PRICE, "Incorrect ETH amount sent");

        manager.addToLotteryParticipants(to);

        // Mint the NFTs to the buyer
        _safeMint(to, totalSupply());

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
    }

    /**
     * @dev withdraws ether funds to `treasuryAddress`.
     * @dev Only admin.
     */
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

    modifier onlyTiger() {
        require(TIER_ID == manager.TIGER_ID(), "Only tiger supports this");
        _;
    }

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

    /**
     * @dev function used by admin to start the auction for this contract's reserved tokens.
     */
    function startAuction() external onlyOwner onlyTiger {
        require(!auctionStarted, "Auction already started");
        require(
            !auctionEnded && block.timestamp <= auctionEndTime,
            "Auction already ended"
        );
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
    function placeBid(uint256 tokenId) external payable nonReentrant onlyTiger {
        require(tokenId < MAX_TOKEN_SUPPLY, "tokenId is too high");
        require(
            tokenId > MAX_TOKEN_SUPPLY - NUMBER_RESERVED,
            "tokenId is too low"
        );
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
        address oldHighestBidder = highestBidder[tokenId];
        uint256 oldHighestBid = highestBid[tokenId];
        bool shouldRefund = oldHighestBidder != address(0);

        highestBidder[tokenId] = msg.sender;
        highestBid[tokenId] = msg.value;

        if (shouldRefund) {
            // Refund the previous highest bidder
            payable(oldHighestBidder).transfer(oldHighestBid);
        }
    }

    function endAuction(uint256 i) external nonReentrant onlyOwner onlyTiger {
        require(i < MAX_TOKEN_SUPPLY, "Invalid card ID");
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
    function withdrawHighestBid(
        uint256 i
    ) external nonReentrant onlyOwner onlyTiger {
        require(i < MAX_TOKEN_SUPPLY, "Invalid i");
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

    // pair (array, address) to keep track of who's on waitlist
    address[] public waitlisted;
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
     * @dev Register someone on the waitlist for the tokenId.
     * @dev Assume they deposited `waitlist_deposit` amount of ETH.
     * @dev Only admin can do this.
     * @param waitlist_deposit the initial deposit amount
     * @param user the waitilisted address.
     */
    function addToWaitlist(
        uint waitlist_deposit,
        address user
    ) external payable onlyOwner nonReentrant {
        require(!isLaunched, "Sale has already launched");
        uint tokenId = totalSupply() + waitlisted.length;
        require(_ownerOf(tokenId) == address(0), "tokenId is already owned");
        require(
            tokenId < MAX_TOKEN_SUPPLY,
            "Total supply exhausted for this token"
        );
        require(!waitlist[user], "Already on waitlist for this token");
        require(waitlist_deposit <= PRICE, "deposit amount is more than price");

        waitlistDeposited[user] += waitlist_deposit;

        waitlist[user] = true;
        waitlistId[user] = tokenId;
        waitlisted.push(user);

        emit WaitlistJoined(user);
    }

    /**
     * @dev Called by a user to claim their waitlisted token.
     * @dev User must pay what's left to pay minus a discount.
     * @dev After payment, the token is minted to them (`msg.sender`) just like the normal case.
     * @dev currentSupply is not incremented here because it already was in addToWaitlist.
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

        // remove person from waitlist
        for (uint i = 0; i < waitlisted.length; i++) {
            if (msg.sender == waitlisted[i]) {
                waitlisted[i] = waitlisted[waitlisted.length];
                waitlisted.pop();
            }
        }

        _safeMint(msg.sender, tokenId);
        emit WaitlistClaimed(msg.sender);
    }

    function launch() external onlyOwner nonReentrant {
        isLaunched = true;
    }
}
