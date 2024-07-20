// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// import "forge-std/console.sol";
// import "forge-std/console2.sol";

contract AnimalSocialClub is ERC1155, Ownable, ReentrancyGuard {
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
    mapping(uint256 => uint256) public tokenSupply;

    // Events
    event SaleStateChanged(bool active);

    // Errors
    error NotAnAmbassador(address account);
    error NotAnAdvocate(address account);
    error NotAnEvangelist(address account);

    // Roles mapping
    enum Role {
        None,
        Ambassador,
        Advocate,
        Evangelist
    }

    mapping(address => Role) public roles;

    // Mappings to keep track of hierarchical relationships
    /**
     *  CAUTION: one advocate must be only associated to a single ambassador.
     *  adding to ambassadorToAdvocates must check the user is not already an advocate
     */
    // each key is an ambassador's address, and the value is the list of its advocates
    mapping(address => address[]) public ambassadorToAdvocates;
    // inverted ambassadorToAdvocates: given an advocate, obtain its corresponing advocate
    mapping(address => address) public advocateToAmbassador;

    mapping(address => address[]) public advocateToEvangelists;
    mapping(address => address) public evangelistToAdvocate;

    // Mapping to track Promoter Ambassador, Advocates, and their commissions
    // commission that one ambassador gives to their advocates. 10 means 10% to advocate, rest to ambassador
    mapping(address => uint256) public ambassadorToAdvocateCommission;
    // commission that one advocate gives to their evangelists.
    mapping(address => uint256) public advocateToEvangelistCommission;

    // Events for role assignment and commission updates
    event RoleAssigned(address indexed user, Role role);
    event AmbassadorCommissionSet(
        address indexed ambassador,
        uint256 commission_pct
    );
    event AdvocateCommissionSet(
        address indexed advocate,
        uint256 commission_pct
    );

    // Constructor initializing the ERC-1155 contract with a base URI and beneficiary addresses
    constructor(
        string memory baseURI,
        address _vera3Address,
        address _ascAddress
    ) Ownable(_vera3Address) ERC1155(baseURI) {
        require(
            _vera3Address != address(0) && _ascAddress != address(0),
            "One or more invalid addresses"
        );
        // Set the beneficiary addresses
        vera3Address = _vera3Address;
        ascAddress = _ascAddress;

        // Mint reserved tokens for the team
        _mint(msg.sender, ID_RESERVED, TOTAL_RESERVED, "");
        tokenSupply[ID_RESERVED] = TOTAL_RESERVED;
    }

    modifier onlyAmbassador() {
        if (roles[msg.sender] != Role.Ambassador) {
            revert NotAnAmbassador(msg.sender);
        }
        _;
    }

    modifier onlyAdvocate() {
        if (roles[msg.sender] != Role.Advocate) {
            revert NotAnAdvocate(msg.sender);
        }
        _;
    }

    modifier onlyEvangelist() {
        if (roles[msg.sender] != Role.Evangelist) {
            revert NotAnEvangelist(msg.sender);
        }
        _;
    }

    // Modifier to check if sale is active
    modifier isSaleActive() {
        require(saleActive, "Sale is not active");
        _;
    }

    /**
     * Updates the hierarchy of roles.
     * E.g. an Ambassador `user` adds a `delegate` with `role` Advocate to his/her group.
     * args:
     *   - user: the upper level in the hierarchy. Unused when contract owner assigns an Ambassador role.
     *   - role: the role which the `delegate` will have.
     *   - delegate: the lower level in the hierarchy.
     */
    function assignRole(address user, Role role, address delegate) external {
        bool isAuthorized = msg.sender == owner();

        if (role == Role.Ambassador) {
            // here `user` is the owner, and `delegate` is the advocate
            // only the owner can set an advocate
            isAuthorized = true;
        } else if (role == Role.Advocate) {
            require(
                roles[user] == Role.Ambassador,
                "user is not an Ambassador and cannot delegate an Advocate"
            );
            // One advocate can add an ambassador only for themselves, not others. Only admin is allowed to everything
            isAuthorized = isAuthorized || user == msg.sender;
            // add advocate to the list of the corresponding ambassador
            ambassadorToAdvocates[user].push(delegate);
            // reverse the many-to-one mapping
            advocateToAmbassador[delegate] = user;
        } else if (role == Role.Evangelist) {
            require(
                roles[user] == Role.Advocate,
                "user is not an Advocate and cannot delegate an Evangelist"
            );
            isAuthorized = isAuthorized || user == msg.sender;
            advocateToEvangelists[user].push(delegate);
            evangelistToAdvocate[delegate] = user;
        } else if (role == Role.None) {
            require(
                msg.sender == owner(),
                "only the owner can assign arbitrary roles"
            );
        }
        require(isAuthorized, "user not authorized");
        roles[delegate] = role;
        emit RoleAssigned(user, role);
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

    // Ensure referrer is registered as Ambassador, Advocate
    function checkReferrer(address referrer) internal view {
        require(
            roles[referrer] == Role.Ambassador ||
                roles[referrer] == Role.Advocate ||
                roles[referrer] == Role.Evangelist,
            "referrer must be a valid Ambassador, Advocate or Evangelist"
        );
    }

    // Function to mint Elephant NFTs
    function mintElephant(
        uint256 amount,
        address referrer
    ) external payable nonReentrant isSaleActive {
        checkReferrer(referrer);
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

        // Update token supply
        tokenSupply[ID_ELEPHANT] += amount;

        // Mint the NFTs to the buyer
        _mint(msg.sender, ID_ELEPHANT, amount, "");

        sendCommission(referrer);
    }

    function mintShark(
        uint256 amount,
        address referrer
    ) external payable nonReentrant isSaleActive {
        checkReferrer(referrer);
        require(
            amount > 0 && amount <= MAXIMUM_MINTABLE,
            "Cannot mint more than MAXIMUM_MINTABLE at a time"
        );
        require(
            tokenSupply[ID_SHARK] + amount <= TOTAL_SHARK,
            "Exceeds total supply of Shark tokens"
        );
        require(msg.value == amount * SHARK_PRICE, "Incorrect ETH amount sent");

        tokenSupply[ID_SHARK] += amount;
        _mint(msg.sender, ID_SHARK, amount, "");

        sendCommission(referrer);
    }

    // Function to mint EAGLE NFTs
    function mintEagle(
        uint256 amount,
        address referrer
    ) external payable nonReentrant isSaleActive {
        checkReferrer(referrer);
        require(
            amount > 0 && amount <= MAXIMUM_MINTABLE,
            "Cannot mint more than MAXIMUM_MINTABLE at a time"
        );
        require(
            tokenSupply[ID_EAGLE] + amount <= TOTAL_EAGLE,
            "Exceeds total supply of EAGLE tokens"
        );
        require(msg.value == amount * EAGLE_PRICE, "Incorrect ETH amount sent");

        tokenSupply[ID_EAGLE] += amount;
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

    function sendCommission(address referrer) internal {
        checkReferrer(referrer);

        // Calculate commissions
        uint256 totalCommission = msg.value / 10; // 10% commission to Promoter

        // Track commission delegation
        address ambassador = address(0);
        address advocate = address(0);
        address evangelist = address(0);

        if (roles[referrer] == Role.Ambassador) {
            // Referrer is an Ambassador, all commission goes to them
            ambassador = referrer;
            payable(ambassador).transfer(totalCommission);
            return;
        } else if (roles[referrer] == Role.Advocate) {
            // Referrer is an Advocate delegated by an Ambassador
            advocate = referrer;
            (
                address ambassador_,
                uint ambassadorShare,
                uint advocateShare
            ) = getAdvocateShare(advocate, totalCommission);
            ambassador = ambassador_;
            payable(ambassador).transfer(ambassadorShare);
            payable(advocate).transfer(advocateShare);
            return;
        } else if (roles[referrer] == Role.Evangelist) {
            evangelist = referrer;
            (
                address ambassador_,
                address advocate_,
                uint ambassadorShare,
                uint advocateShare,
                uint evangelistShare
            ) = getEvangelistShare(evangelist, totalCommission);

            ambassador = ambassador_;
            advocate = advocate_;
            payable(ambassador).transfer(ambassadorShare);
            payable(advocate).transfer(advocateShare);
            payable(evangelist).transfer(evangelistShare);
            return;
        } else {
            revert("referrer role is None!!");
        }
    }

    // Function to set commission percentage for Promoter Ambassadors
    function setAmbassadorToAdvocateCommission(
        address ambassador,
        uint256 commissionPercentage
    ) external {
        require(
            roles[msg.sender] == Role.Ambassador || msg.sender == owner(),
            "Not authorized!"
        );
        require(
            commissionPercentage <= 100,
            "Commission percentage must be <= 100"
        );
        ambassadorToAdvocateCommission[ambassador] = commissionPercentage;
        emit AmbassadorCommissionSet(ambassador, commissionPercentage);
    }

    // Function to set commission percentage for Promoter Ambassadors
    function setAdvocateToEvangelistCommission(
        address advocate,
        uint256 commissionPercentage
    ) external {
        require(
            roles[msg.sender] == Role.Advocate || msg.sender == owner(),
            "Not authorized!"
        );
        require(
            commissionPercentage <= 100,
            "Commission percentage must be <= 100"
        );
        advocateToEvangelistCommission[advocate] = commissionPercentage;
        emit AdvocateCommissionSet(advocate, commissionPercentage);
    }

    function getAdvocateShare(
        address advocate,
        uint256 totalCommission
    ) internal view returns (address, uint256, uint256) {
        address ambassador = advocateToAmbassador[advocate];
        uint256 advocateCommissionPct = ambassadorToAdvocateCommission[
            ambassador
        ];
        uint256 advocateShare = (totalCommission * advocateCommissionPct) / 100;
        uint256 ambassadorShare = totalCommission - advocateShare;
        require(
            totalCommission == (ambassadorShare + advocateShare),
            "Error in calculation for advocate: shares don't add up"
        );
        return (ambassador, ambassadorShare, advocateShare);
    }

    function getEvangelistShare(
        address evangelist,
        uint256 totalCommission
    ) internal view returns (address, address, uint256, uint256, uint256) {
        address advocate = evangelistToAdvocate[evangelist];
        address ambassador = advocateToAmbassador[advocate];
        // get share % for advocate & evangelist
        uint256 advocateCommissionPct = ambassadorToAdvocateCommission[
            ambassador
        ];
        uint256 evangelistCommissionPct = advocateToEvangelistCommission[
            advocate
        ];

        // calculate advocate & evangelist share in coins
        uint256 advocateShare = (totalCommission * advocateCommissionPct) / 100;
        uint256 ambassadorShare = totalCommission - advocateShare;

        // the evangelist takes a piece of the advocate's share
        uint256 evangelistShare = (advocateShare * evangelistCommissionPct) /
            100;
        advocateShare -= evangelistShare;

        require(
            totalCommission ==
                (ambassadorShare + advocateShare + evangelistShare),
            "Error in calculation for evangelist: shares don't add up"
        );
        return (
            ambassador,
            advocate,
            ambassadorShare,
            advocateShare,
            evangelistShare
        );
    }

    // Override URI function to return token-specific metadata
    function uri(uint256 tokenId) public view override returns (string memory) {
        return
            string(abi.encode(super.uri(tokenId), tokenId.toString(), ".json"));
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

        if (highestBidder[i] != address(0)) {
            // Refund the previous highest bidder
            payable(highestBidder[i]).transfer(highestBid[i]);
        }

        highestBidder[i] = msg.sender;
        highestBid[i] = msg.value;
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
}
