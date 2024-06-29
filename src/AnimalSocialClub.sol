// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "forge-std/console.sol";
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

    // Roles mapping
    enum Role {
        None,
        Ambassador,
        Advocate,
        Evangelist
    }
    mapping(address => Role) public roles;

    // Mapping to track Promoter Ambassador, Advocates, Evangelists and their commissions
    mapping(address => uint256) public ambassadorToAdvocateCommission; // Commission % set by Promoter Ambassador
    mapping(address => mapping(address => uint256)) public advocateCommission; // Commission % delegated by Advocates to Evangelists

    // Mappings to keep track of hierarchical relationships
    mapping(address => address[]) public ambassadorToAdvocates;
    mapping(address => address[]) public advocateToEvangelists;
    mapping(address => address) public advocateToAmbassador;
    mapping(address => address) public evangelistToAdvocate;

    // Events for role assignment and commission updates
    event RoleAssigned(address indexed user, Role role);
    event PromoterCommissionSet(address indexed promoter, uint256 commission);
    event AdvocateCommissionDelegated(
        address indexed advocate,
        address indexed evangelist,
        uint256 commission
    );

    // Function to mint Elephant NFTs
    function mintElephant(
        uint256 amount,
        address referrer
    ) external payable isSaleActive {
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

        sendCommission(referrer);

        // Mint the NFTs to the buyer
        _mint(msg.sender, ID_ELEPHANT, amount, "");

        // Update token supply
        tokenSupply[ID_ELEPHANT] += amount;
    }

    function sendCommission(address referrer) internal {
        // Ensure referrer is registered as Ambassador, Advocate, or Evangelist
        require(
            roles[referrer] == Role.Ambassador ||
                roles[referrer] == Role.Advocate ||
                roles[referrer] == Role.Evangelist,
            "Referrer is not registered as Ambassador, Advocate, or Evangelist"
        );

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
        } else if (roles[referrer] == Role.Advocate) {
            // Referrer is an Advocate delegated by an Ambassador
            advocate = referrer;
            ambassador = advocateToAmbassador[advocate];
            uint256 ambassadorCommissionPercentage = ambassadorToAdvocateCommission[
                    ambassador
                ];
            uint256 ambassadorShare = (totalCommission *
                ambassadorCommissionPercentage) / 100;
            uint256 advocateShare = totalCommission - ambassadorShare;
            require(
                totalCommission == (ambassadorShare + advocateShare),
                "Error in calculation"
            );
            payable(ambassador).transfer(ambassadorShare);
            payable(advocate).transfer(advocateShare);
        } else if (roles[referrer] == Role.Evangelist) {
            // Referrer is an Evangelist delegated by an Advocate
            evangelist = referrer;
            advocate = evangelistToAdvocate[evangelist];
            ambassador = advocateToAmbassador[advocate];
            uint256 ambassadorCommissionPercentage = ambassadorToAdvocateCommission[
                    ambassador
                ];
            console.log("mintElephant totalCommission: ", totalCommission);
            uint256 ambassadorShare = (totalCommission *
                ambassadorCommissionPercentage) / 100;
            console.log("mintElephant ambassadorShare: ", ambassadorShare);
            uint256 advocateCommissionPercentage = advocateCommission[
                ambassador
            ][advocate];
            console.log(
                "mintElephant advocateCommissionPercentage: ",
                advocateCommissionPercentage
            );
            uint256 advocateShare = ((totalCommission - ambassadorShare) *
                advocateCommissionPercentage) / 100;
            console.log("mintElephant advocateShare: ", advocateShare);
            uint256 evangelistShare = totalCommission -
                ambassadorShare -
                advocateShare;
            console.log("mintElephant evangelistShare: ", evangelistShare);
            require(
                totalCommission ==
                    (ambassadorShare + advocateShare + evangelistShare),
                "Error in calculation"
            );
            payable(ambassador).transfer(ambassadorShare);
            payable(advocate).transfer(advocateShare);
            payable(evangelist).transfer(evangelistShare);
        } else {
            revert("referrer role is None!!");
        }
    }

    // Function to assign roles (Ambassador, Advocate, Evangelist)
    function assignRole(address user, Role role, address delegate) external {
        roles[user] = role;
        if (role == Role.Advocate) {
            ambassadorToAdvocates[delegate].push(user);
            advocateToAmbassador[user] = delegate;
        } else if (role == Role.Evangelist) {
            advocateToEvangelists[delegate].push(user);
            evangelistToAdvocate[user] = delegate;
        }
        emit RoleAssigned(user, role);
    }

    // Function to set commission percentage for Promoter Ambassadors
    function setAmbassadorToAdvocateCommission(
        address promoter,
        uint256 commissionPercentage
    ) external {
        require(
            commissionPercentage <= 100,
            "Commission percentage must be <= 100"
        );
        ambassadorToAdvocateCommission[promoter] = commissionPercentage;
        emit PromoterCommissionSet(promoter, commissionPercentage);
    }

    // Function to delegate commission from Advocates to Evangelists
    function delegateCommission(
        address advocate,
        address evangelist,
        uint256 commissionPercentage
    ) external {
        require(
            commissionPercentage <= 100 && commissionPercentage > 0,
            "Commission percentage must be <= 100 and > 0"
        );
        advocateCommission[advocate][evangelist] = commissionPercentage;
        emit AdvocateCommissionDelegated(
            advocate,
            evangelist,
            commissionPercentage
        );
    }

    // Function to get assigned Ambassador for an Advocate
    function getAssignedAmbassador(
        address advocate
    ) internal view returns (address) {
        return advocateToAmbassador[advocate];
    }

    // Function to get assigned Advocate for an Evangelist
    function getAssignedAdvocate(
        address evangelist
    ) internal view returns (address) {
        return evangelistToAdvocate[evangelist];
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
