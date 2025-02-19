// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "@requestnetwork/advanced-logic/src/contracts/interfaces/EthereumFeeProxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Vera3DistributionModel} from "src/Vera3DistributionModel.sol";
import {ASC721Manager} from "src/ASC721Manager.sol";

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
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    Vera3DistributionModel
{
    using Strings for uint256;

    uint256 public MAX_TOKEN_SUPPLY;
    uint256 public PRICE;
    uint256 public NUMBER_RESERVED;
    uint256 public TIER_ID;

    // can mint 1 at a time
    uint256 public constant MAXIMUM_MINTABLE = 1;

    /// @dev Address of contract admin.
    address public adminAddress;
    /// @dev Address of treasury where funds are withdraw.
    address public treasuryAddress;
    ASC721Manager public manager;

    string public BASE_URI;

    /**
     * @dev sale status: when false, no memberships can be minted.
     */
    bool public saleActive;

    /**
     * @dev whether the sale is open to strong KYC'd addresses only.
     */
    bool public strongKycRequired;

    uint256 public totalSupply;

    // Events
    event SaleStateChanged(bool active);

    event Initialized(
        uint256 tier_id,
        uint256 _totalSupply,
        uint256 _mint_price,
        address _adminAddress,
        address _treasuryAddress,
        ASC721Manager _manager,
        uint256 num_reserved,
        address ethFeeProxy,
        bool strongKycRequired
    );

    event TreasuryAddressChanged(address old_address, address new_address);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        string memory name,
        string memory symbol,
        uint256 _totalSupply,
        uint256 _mint_price,
        address _adminAddress,
        address _treasuryAddress,
        ASC721Manager _manager,
        uint256 num_reserved,
        address ethFeeProxy,
        uint256 tier_id,
        string memory _initialBaseURI,
        bool _strongKycRequired
    ) public initializer {
        __ERC721_init(name, symbol);
        __ReentrancyGuard_init();
        __Vera3DistributionModel_init(ethFeeProxy);
        __UUPSUpgradeable_init();
        __Ownable_init(_adminAddress);
        // require(msg.sender == _adminAddress, "sender must be admin");
        require(_adminAddress != address(0) && _treasuryAddress != address(0), "One or more invalid addresses");
        // Set the beneficiary addresses
        adminAddress = _adminAddress;
        treasuryAddress = _treasuryAddress;
        MAX_TOKEN_SUPPLY = _totalSupply;
        PRICE = _mint_price;
        manager = ASC721Manager(_manager);
        NUMBER_RESERVED = num_reserved;
        TIER_ID = tier_id;
        // auctionEndTime = type(uint256).max;
        saleActive = true;
        BASE_URI = _initialBaseURI;
        strongKycRequired = _strongKycRequired;
    }

    /**
     * @dev modifier which reverts if the sale is not active.
     */
    modifier isSaleActive() {
        require(saleActive, "Sale is not active");
        _;
    }

    /**
     * @dev modifier which reverts if the sale is not active.
     */
    modifier onlyOwnerAndManager() {
        require(
            msg.sender == owner() || msg.sender == address(manager),
            "Caller must be either owner or manager for this function"
        );
        _;
    }

    /**
     * @dev function to start or stop the sale. can only be called by owner.
     * @param _saleActive the state of the sale. `true` to enable, `false` to disable.
     */
    function setSaleActive(bool _saleActive) external onlyOwnerAndManager {
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

    event AdminMinted(address to, uint256 tokenId);
    /**
     * @dev function for the admin to mint a membership to `to`.
     * Payment is made off-chain.
     * @dev requires that `saleActive` is true. See `setSaleActive`.
     * @param to the destination address
     */

    function adminMint(address to) external nonReentrant isSaleActive onlyOwnerAndManager {
        // it's on the admin to add kyc or kyb
        require(strongKycRequired ? manager.hasStrongKYC(to) : manager.hasKYC(to), "Destination address without KYC!");
        require(totalSupply + 1 < MAX_TOKEN_SUPPLY, "Exceeds total supply of tokens");
        require(totalSupply + 1 < (MAX_TOKEN_SUPPLY - NUMBER_RESERVED), "No more tokens: the remainder is reserved");

        manager.addToLotteryParticipants(to);

        // Mint the NFTs to the buyer
        uint256 tokenId = ++totalSupply;
        _safeMint(to, tokenId);
        emit AdminMinted(to, tokenId);
    }

    event MintedWithDonation(uint256 token_id, address to, address referrer, address donor);

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
        require(strongKycRequired ? manager.hasStrongKYC(to) : manager.hasKYC(to), "Destination address without KYC!");
        require(TIER_ID != manager.STAKEHOLDER_ID(), "Stakeholder memberships not minted with donation");
        require(referrer == address(0) || isReferrer((referrer)));
        require(totalSupply < MAX_TOKEN_SUPPLY - waitlisted.length, "Exceeds total supply of tokens");
        require(
            totalSupply < (MAX_TOKEN_SUPPLY - NUMBER_RESERVED - waitlisted.length),
            "No more tokens: the remainder is reserved for lottery"
        );
        require(msg.value == PRICE, "Incorrect ETH amount sent");

        manager.addToLotteryParticipants(to);

        // Mint the NFTs to the buyer
        uint256 tokenId = ++totalSupply;
        _safeMint(to, tokenId);

        ETHEREUM_FEE_PROXY.transferWithReferenceAndFee(
            payable(manager.treasuryAddress()), donorReference, 0, payable(address(0))
        );
        sendCommission(referrer, ambassadorReference, advocateReference, evangelistReference);
        emit MintedWithDonation(tokenId, to, referrer, msg.sender);
    }

    /**
     * @dev withdraws ether funds to `treasuryAddress`.
     * @dev Only admin.
     */
    function withdrawFunds() external nonReentrant onlyOwnerAndManager {
        uint256 balance = address(this).balance;

        require(balance > 0, "No funds to withdraw");

        if (balance > 0) {
            payable(treasuryAddress).transfer(balance);
        }
    }

    // Function to ensure contract can receive Ether
    receive() external payable {}

    //////////////////////////////////////////////////////////////
    /////// WAITLIST
    //////////////////////////////////////////////////////////////
    uint256 public constant WAITLIST_DISCOUNT_PCT = 5;
    bool public isLaunched;

    // pair (array, address) to keep track of who's on waitlist
    address[] public waitlisted;
    mapping(address => bool) public waitlist;

    // keep track of which specific tokenId the address is waitlisted for
    mapping(address => uint256) public waitlistId;
    // keep track of how much deposit was made for waitlist
    mapping(address => uint256) public waitlistDeposited;
    // keep track of who's claimed their waitlisted item
    mapping(address => bool) public waitlistClaimed;

    event WaitlistJoined(address indexed user);
    event WaitlistClaimed(address indexed user, uint256 indexed tokenId);

    /**
     * @dev Register someone on the waitlist for the tokenId.
     * @dev Assume they deposited `waitlist_deposit` amount of ETH.
     * @dev Only admin can do this.
     * @param waitlist_deposit the initial deposit amount
     * @param user the waitilisted address.
     */
    function addToWaitlist(uint256 waitlist_deposit, address user) external payable nonReentrant onlyOwnerAndManager {
        require(!isLaunched, "Sale has already launched");
        require(!waitlist[user], "Already on waitlist for this token");
        require(waitlist_deposit <= PRICE, "deposit amount is more than price");

        uint256 tokenId = ++totalSupply;
        require(_ownerOf(tokenId) == address(0), "tokenId is already owned");
        require(tokenId < MAX_TOKEN_SUPPLY, "Total supply exhausted for this token");

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
        for (uint256 i = 0; i < waitlisted.length; i++) {
            if (msg.sender == waitlisted[i]) {
                waitlisted[i] = waitlisted[waitlisted.length];
                waitlisted.pop();
            }
        }

        _safeMint(msg.sender, tokenId);
        emit WaitlistClaimed(msg.sender, tokenId);
    }

    function launch() external nonReentrant onlyOwnerAndManager {
        isLaunched = true;
    }

    /**
     * @dev Updates the hierarchy of roles.
     * @dev E.g. an Ambassador `delegator` adds a `delegate` with `role` Advocate to his/her group.
     * @param delegator the upper level in the hierarchy. address(0) when contract owner assigns an Ambassador role.
     * @param role the role which the `delegate` will have.
     * @param delegate the lower level in the hierarchy.
     */
    function assignRole(address payable delegator, Role role, address payable delegate, address _msgSender)
        external
        override
    {
        bool isAuthorized = msg.sender == owner() || msg.sender == address(manager);

        if (role == Role.Ambassador) {
            // here `user` is the owner, and `delegate` is the advocate
            // only the owner can set an ambassador
            require(delegator == address(0));
        } else if (role == Role.Advocate) {
            require(roles[delegator] == Role.Ambassador, "user is not an Ambassador and cannot delegate an Advocate");
            require(advocateToAmbassador[delegate] == address(0), "delegate is already an ambassador for someone else");
            // One advocate can add an ambassador only for themselves, not others.
            // Only admin is allowed to everything
            isAuthorized = isAuthorized || delegator == _msgSender;
            // add advocate to the list of the corresponding ambassador
            ambassadorToAdvocates[delegator].push(delegate);
            // reverse the many-to-one mapping
            advocateToAmbassador[delegate] = delegator;
        } else if (role == Role.Evangelist) {
            require(roles[delegator] == Role.Advocate, "user is not an Advocate and cannot delegate an Evangelist");
            require(evangelistToAdvocate[delegate] == address(0), "delegate is already an advocate for someone else");
            isAuthorized = isAuthorized || delegator == _msgSender;
            advocateToEvangelists[delegator].push(delegate);
            evangelistToAdvocate[delegate] = delegator;
        } else if (role == Role.None) {
            // TODO discuss whether ambassador/advocate can remove ppl below them
            require(_msgSender == owner(), "only the owner can assign arbitrary roles");
        }
        require(isAuthorized, "user not authorized");
        roles[delegate] = role;
        emit RoleAssigned(delegator, role, delegate, _msgSender);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return string.concat(super.tokenURI(tokenId), ".json");
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return string.concat(BASE_URI, tierIdString());
    }

    function setBaseURI(string memory newUri) external onlyOwnerAndManager {
        BASE_URI = newUri;
    }

    function tierIdString() internal view virtual returns (string memory) {
        if (TIER_ID == manager.ELEPHANT_ID()) {
            return "elephant/";
        } else if (TIER_ID == manager.TIGER_ID()) {
            return "tiger/";
        } else if (TIER_ID == manager.SHARK_ID()) {
            return "shark/";
        } else if (TIER_ID == manager.EAGLE_ID()) {
            return "eagle/";
        } else if (TIER_ID == manager.STAKEHOLDER_ID()) {
            return "stakeholder/";
        }
        return "";
    }

    function setTreasuryAddress(address new_address) external onlyOwnerAndManager {
        require(new_address != address(0), "treasury cant be 0x0");
        address old_address = treasuryAddress;
        treasuryAddress = new_address;
        emit TreasuryAddressChanged(old_address, new_address);
    }
}
