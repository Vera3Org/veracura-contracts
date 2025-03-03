// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IVera3DistributionModel, Vera3DistributionModel} from "interfaces/IVera3DistributionModel.sol";

interface IAnimalSocialClubERC721 is IVera3DistributionModel {
    error AddressEmptyCode(address target);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);
    error ERC721InsufficientApproval(address operator, uint256 tokenId);
    error ERC721InvalidApprover(address approver);
    error ERC721InvalidOperator(address operator);
    error ERC721InvalidOwner(address owner);
    error ERC721InvalidReceiver(address receiver);
    error ERC721InvalidSender(address sender);
    error ERC721NonexistentToken(uint256 tokenId);
    error FailedCall();
    error ReentrancyGuardReentrantCall();
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    event AdminMinted(address to, uint256 tokenId);
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event Initialized(
        uint256 tier_id,
        uint256 _totalSupply,
        uint256 _mint_price,
        address _adminAddress,
        address _treasuryAddress,
        address _manager,
        uint256 num_reserved,
        address ethFeeProxy,
        bool strongKycRequired
    );
    event MintedWithDonation(
        uint256 token_id,
        address to,
        address referrer,
        address donor
    );
    event SaleStateChanged(bool active);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event TreasuryAddressChanged(address old_address, address new_address);
    event Upgraded(address indexed implementation);
    event WaitlistClaimed(address indexed user, uint256 indexed tokenId);
    event WaitlistJoined(address indexed user, uint256 indexed tokenId);

    receive() external payable;

    function BASE_URI() external view returns (string memory);
    function ETHEREUM_FEE_PROXY() external view returns (address);
    function MAXIMUM_MINTABLE() external view returns (uint256);
    function MAX_TOKEN_SUPPLY() external view returns (uint256);
    function NUMBER_RESERVED() external view returns (uint256);
    function PRICE() external view returns (uint256);
    function TIER_ID() external view returns (uint256);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function addToWaitlist(
        uint256 waitlist_deposit,
        address user
    ) external payable;
    function adminAddress() external view returns (address);
    function adminMint(address to) external;
    function advocateToAmbassador(
        address
    ) external view returns (address payable);
    function advocateToEvangelistCommission() external view returns (uint256);
    function advocateToEvangelists(
        address,
        uint256
    ) external view returns (address payable);
    function ambassadorToAdvocateCommission() external view returns (uint256);
    function ambassadorToAdvocates(
        address,
        uint256
    ) external view returns (address payable);
    function approve(address to, uint256 tokenId) external;
    function assignRole(
        address payable delegator,
        Vera3DistributionModel.Role role,
        address payable delegate,
        address _msgSender
    ) external;
    function balanceOf(address owner) external view returns (uint256);
    function claimWaitlist() external payable;
    function evangelistToAdvocate(
        address
    ) external view returns (address payable);
    function getApproved(uint256 tokenId) external view returns (address);
    function getPromoterCommissions(
        address referrer,
        uint256 total_value
    )
        external
        view
        returns (address, uint256, address, uint256, address, uint256);
    function initialize(
        string memory name,
        string memory symbol,
        uint256 _totalSupply,
        uint256 _mint_price,
        address _adminAddress,
        address _treasuryAddress,
        address _manager,
        uint256 num_reserved,
        address ethFeeProxy,
        uint256 tier_id,
        string memory _initialBaseURI,
        bool _strongKycRequired
    ) external;
    function isASCMember(address a) external view returns (bool);
    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
    function isLaunched() external view returns (bool);
    function isReferrer(address referrer) external view returns (bool);
    function manager() external view returns (address);
    function mintWithDonationRequestNetwork(
        address to,
        address referrer,
        bytes memory donorReference,
        bytes memory ambassadorReference,
        bytes memory advocateReference,
        bytes memory evangelistReference
    ) external payable;
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function ownerOf(uint256 tokenId) external view returns (address);
    function proxiableUUID() external view returns (bytes32);
    function renounceOwnership() external;
    function requireReferrer(address referrer) external view;
    function roles(address) external view returns (Vera3DistributionModel.Role);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) external;
    function saleActive() external view returns (bool);
    function setApprovalForAll(address operator, bool approved) external;
    function setBaseURI(string memory newUri) external;
    function setLaunchStatus(bool status) external;
    function setSaleActive(bool _saleActive) external;
    function setTreasuryAddress(address new_address) external;
    function strongKycRequired() external view returns (bool);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function transferOwnership(address newOwner) external;
    function treasuryAddress() external view returns (address);
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) external payable;
    function waitlist(address) external view returns (bool);
    function waitlistClaimed(address) external view returns (bool);
    function waitlistDeposited(address) external view returns (uint256);
    function waitlistId(address) external view returns (uint256);
    function waitlisted(uint256) external view returns (address);
    function withdrawFunds() external;
}
