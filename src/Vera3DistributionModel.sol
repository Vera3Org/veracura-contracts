// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@requestnetwork/advanced-logic/src/contracts/interfaces/EthereumFeeProxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "forge-std/console.sol";

/**
 * @dev Abstract contract which implements the Vera3 distribution model.
 *
 * @dev There are 3 promoter roles in the hierarchy, from highest to lowest
 * Ambassador, Advocate and Evangelist.
 *
 * @dev Each level in the hierarchy can specify one or more promoters of the
 * lower level, and when a mint of AnimalSocialClubERC721 happens, and
 * the `referrer` argument is a promoter, a 10% mint fee is take from the
 * donation and distributed as follows:
 * - If `referrer` is an Ambassador, they keep the fee.
 * - If `referrer` is an Advocate, they and their Ambassador share the fee.
 * - If `referrer` is an Evangelist, all the upper levels (the Evangelist's
 *   Advocate, and that Advocate's Ambassador) share the fee.
 */
abstract contract Vera3DistributionModel is Initializable, OwnableUpgradeable {
    // Errors
    error NotAnAmbassador(address account);
    error NotAnAdvocate(address account);
    error NotAnEvangelist(address account);

    // Roles mapping
    /**
     * @dev Promoter role enumeration type.
     */
    enum Role {
        None,
        Ambassador,
        Advocate,
        Evangelist
    }

    mapping(address => Role) public roles;

    ///////////////////////////////////////////////////////////
    // Mappings to keep track of hierarchical relationships
    ///////////////////////////////////////////////////////////

    /**
     * @dev keys are Ambassador address, values are list of their Advocates.
     * @dev One-to-many mapping.
     */
    mapping(address => address payable[]) public ambassadorToAdvocates;

    /**
     * @dev inverse of ambassadorToAdvocates mapping: given a value in the list,
     * returns the corresponding key.
     * @dev One-to-one mapping.
     */
    mapping(address => address payable) public advocateToAmbassador;

    /**
     * @dev keys are Advocate address, values are list of their Evangelists.
     * @dev One-to-many mapping.
     */
    mapping(address => address payable[]) public advocateToEvangelists;

    /**
     * @dev inverse of advocateToEvangelists mapping: given a value,
     * returns the corresponding key.
     * @dev One-to-one mapping.
     */
    mapping(address => address payable) public evangelistToAdvocate;

    ///////////////////////////////////////////////////////////////////////////////
    // Mappings to track Promoter Ambassador, Advocates, and their commissions
    ///////////////////////////////////////////////////////////////////////////////

    /**
     * @dev commission that one ambassador gives to their advocates.
     * @dev 60 means 60% to advocate, rest 40% to ambassador
     */
    uint256 public ambassadorToAdvocateCommission;
    /**
     * @dev commission that one advocate gives to their evangelists.
     * @dev 50 means 50% to evangelist, 50% advocate.
     */
    uint256 public advocateToEvangelistCommission;

    // mapping(address => uint256) public ambassadorToAdvocateCommission;
    // // commission that one advocate gives to their evangelists.
    // mapping(address => uint256) public advocateToEvangelistCommission;

    /**
     * @dev reference to Request Network's Ethereum Fee Proxy.
     */
    IEthereumFeeProxy public ETHEREUM_FEE_PROXY;

    // gap of unused 48 words. can be used to add new storage variables in upgrades
    uint256[48] __gap;

    // Events for role assignment and commission updates
    event RoleAssigned(address indexed user, Role indexed role, address indexed delegate, address _msgSender);
    event AmbassadorCommissionSet(uint256 commission_pct);
    event AdvocateCommissionSet(uint256 commission_pct);

    // event AmbassadorCommissionSet(
    //     address indexed ambassador,
    //     uint256 commission_pct
    // );
    // event AdvocateCommissionSet(
    //     address indexed advocate,
    //     uint256 commission_pct
    // );

    function __Vera3DistributionModel_init(address ethFeeProxy) internal onlyInitializing {
        // __Ownable_init(adminAddress);
        ETHEREUM_FEE_PROXY = IEthereumFeeProxy(ethFeeProxy);
        ambassadorToAdvocateCommission = 60;
        advocateToEvangelistCommission = 50;
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

    /**
     * @dev returns true if user is a registered promoter in any role.
     */
    function isReferrer(address referrer) public view returns (bool) {
        return
            roles[referrer] == Role.Ambassador || roles[referrer] == Role.Advocate || roles[referrer] == Role.Evangelist;
    }

    /**
     * @dev reverts if input address is not a valid Ambassador, Advocate or Evangelist
     * @param referrer address to check.
     */
    function requireReferrer(address referrer) public view {
        require(isReferrer(referrer), "referrer must be a valid Ambassador, Advocate or Evangelist");
    }

    /**
     * @dev calculates how much commission is deducted from each donations and sent to referrer(s)
     */
    function calculateCommission(uint256 amt) internal pure returns (uint256) {
        return amt / 10;
    }

    event CommissionSent(
        address ambassador,
        uint256 ambassadorAmount,
        address advocate,
        uint256 advocateAmount,
        address evangelist,
        uint256 evangelistAmount
    );
    /**
     * @dev given a referrer, calculates how much needs to be sent to promoters, if any, and sends it.
     * @param referrer the referred promoter, or address(0) if none.
     * @param ambassadorReference RequestNetwork payment reference of the referred promoter.
     *        Unused if `referrer` is none.
     * @param advocateReference RequestNetwork payment reference of the referred promoter.
     *        Unused if `referrer` is none or Ambassador
     * @param evangelistReference RequestNetwork payment reference of the referred promoter, or address(0) if none.
     *        Unused if `referrer` is none, Ambassador or Advocate.
     */

    function sendCommission(
        address referrer,
        bytes calldata ambassadorReference,
        bytes calldata advocateReference,
        bytes calldata evangelistReference
    ) internal {
        if (referrer == address(0)) {
            return;
        }
        requireReferrer(referrer);

        if (roles[referrer] == Role.Ambassador) {
            // Referrer is an Ambassador, all commission goes to them
            address ambassador = referrer;
            // payable(ambassador).transfer(totalCommission);
            console.log("Using Ethereum fee proxy");
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{value: calculateCommission(msg.value)}(
                payable(ambassador), ambassadorReference, 0, payable(address(0))
            );
            emit CommissionSent(ambassador, msg.value, address(0), 0, address(0), 0);

            return;
        } else if (roles[referrer] == Role.Advocate) {
            // Referrer is an Advocate delegated by an Ambassador
            address advocate = referrer;
            (address ambassador, uint256 ambassadorShare, uint256 advocateShare) =
                getAdvocateShare(advocate, calculateCommission(msg.value));
            // ambassador = ambassador_;
            // payable(ambassador).transfer(ambassadorShare);
            console.log("Using Ethereum fee proxy");
            // transfer to ambassador
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{value: ambassadorShare}(
                payable(ambassador), ambassadorReference, 0, payable(address(0))
            );
            // transfer to advocate
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{value: advocateShare}(
                payable(advocate), advocateReference, 0, payable(address(0))
            );
            emit CommissionSent(ambassador, ambassadorShare, advocate, advocateShare, address(0), 0);
            return;
        } else if (roles[referrer] == Role.Evangelist) {
            address evangelist = referrer;
            (
                address payable ambassador,
                address payable advocate,
                uint256 ambassadorShare,
                uint256 advocateShare,
                uint256 evangelistShare
            ) = getEvangelistShare(evangelist, calculateCommission(msg.value));

            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{value: ambassadorShare}(
                payable(ambassador), ambassadorReference, 0, payable(address(0))
            );
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{value: advocateShare}(
                payable(advocate), advocateReference, 0, payable(address(0))
            );
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{value: evangelistShare}(
                payable(evangelist), evangelistReference, 0, payable(address(0))
            );
            emit CommissionSent(ambassador, ambassadorShare, advocate, advocateShare, evangelist, evangelistShare);
            return;
        } else {
            revert("referrer role is None!!");
        }
    }

    function getPromoterCommissions(address referrer, uint256 total_value)
        public
        view
        returns (address, uint256, address, uint256, address, uint256)
    {
        if (referrer == address(0) || !isReferrer(referrer)) {
            return (address(0), 0, address(0), 0, address(0), 0);
        }

        if (roles[referrer] == Role.Ambassador) {
            // Referrer is an Ambassador, all commission goes to them
            address ambassador = referrer;
            return (ambassador, total_value, address(0), 0, address(0), 0);
        } else if (roles[referrer] == Role.Advocate) {
            // Referrer is an Advocate delegated by an Ambassador
            address advocate = referrer;
            (address ambassador, uint256 ambassadorShare, uint256 advocateShare) =
                getAdvocateShare(advocate, calculateCommission(total_value));
            return (ambassador, ambassadorShare, advocate, advocateShare, address(0), 0);
        } else if (roles[referrer] == Role.Evangelist) {
            address evangelist = referrer;
            (
                address payable ambassador,
                address payable advocate,
                uint256 ambassadorShare,
                uint256 advocateShare,
                uint256 evangelistShare
            ) = getEvangelistShare(evangelist, calculateCommission(total_value));
            return (ambassador, ambassadorShare, advocate, advocateShare, evangelist, evangelistShare);
        } else {
            revert("referrer role is None!!");
        }
    }

    /**
     * @dev Function to set commission percentage that Advocates share with Ambassadors.
     * @param commissionPercentage the new commission percentage. 10 means 10%, 100 mean 100%
     */
    function setAmbassadorToAdvocateCommission(
        // address ambassador,
        uint256 commissionPercentage
    ) external onlyOwner {
        require(roles[msg.sender] == Role.Ambassador || msg.sender == owner(), "Not authorized!");
        require(commissionPercentage <= 100, "Commission percentage must be <= 100");
        // ambassadorToAdvocateCommission[ambassador] = commissionPercentage;
        // emit AmbassadorCommissionSet(ambassador, commissionPercentage);
        ambassadorToAdvocateCommission = commissionPercentage;
        emit AmbassadorCommissionSet(commissionPercentage);
    }

    /**
     * @dev Function to set commission percentage that Evangelists share with Advocates.
     * @param commissionPercentage the new commission percentage. 10 means 10%, 100 mean 100%
     */
    function setAdvocateToEvangelistCommission(uint256 commissionPercentage) external onlyOwner {
        require(roles[msg.sender] == Role.Advocate || msg.sender == owner(), "Not authorized!");
        require(commissionPercentage <= 100, "Commission percentage must be <= 100");
        // advocateToEvangelistCommission[advocate] = commissionPercentage;
        // emit AdvocateCommissionSet(advocate, commissionPercentage);
        advocateToEvangelistCommission = commissionPercentage;
        emit AdvocateCommissionSet(commissionPercentage);
    }

    /**
     * @dev Calculates how much is the advocate's share for a given commission value.
     * @param advocate the Advocate's address. Will be used to fetch the upper Ambassador.
     * @param totalCommission the commission to share.
     * @return Triple `(ambassador, ambassadorShare, advocateShare)` where: `ambassador` is
     * the address of the upper Ambassador of this `advocate`, `ambassadorShare` is the amount
     * of coins that the Ambassador gets, and `advocateShare` is the number of coins that the
     * Advocate gets.
     */
    function getAdvocateShare(address advocate, uint256 totalCommission)
        internal
        view
        returns (address, uint256, uint256)
    {
        address ambassador = advocateToAmbassador[advocate];
        // uint256 advocateCommissionPct = ambassadorToAdvocateCommission[
        //     ambassador
        // ];
        uint256 advocateCommissionPct = ambassadorToAdvocateCommission;
        uint256 advocateShare = (totalCommission * advocateCommissionPct) / 100;
        uint256 ambassadorShare = totalCommission - advocateShare;
        require(
            totalCommission == (ambassadorShare + advocateShare),
            "Error in calculation for advocate: shares don't add up"
        );
        return (ambassador, ambassadorShare, advocateShare);
    }

    /**
     * @dev Calculates how much is the evangelist's share for a given commission value.
     * @param evangelist the Evangelist's address. Will be used to fetch the upper Advocate.
     * @param totalCommission the commission to share.
     * @return Quintuple `(ambassador, advocate, ambassadorShare, advocateShare, evangelistShare where):
     * `ambassador` is the address of the upper ambassador of this evangelist's
     * advocate, `advocate` is the address of the upper Advocate of this
     * `evangelist`, `ambassadorShare` is the amount of coin the the Ambassador
     * gets, `advocateShare` is the amount of coins that the Advocate gets, and
     * `evangelistShare` is the number of coins that the Evangelist gets.
     */
    function getEvangelistShare(address evangelist, uint256 totalCommission)
        internal
        view
        returns (address payable, address payable, uint256, uint256, uint256)
    {
        address payable advocate = evangelistToAdvocate[evangelist];
        address payable ambassador = advocateToAmbassador[advocate];
        // get share % for advocate & evangelist
        // uint256 advocateCommissionPct = ambassadorToAdvocateCommission[
        //     ambassador
        // ];
        // uint256 evangelistCommissionPct = advocateToEvangelistCommission[
        //     advocate
        // ];
        uint256 advocateCommissionPct = ambassadorToAdvocateCommission;
        uint256 evangelistCommissionPct = advocateToEvangelistCommission;

        // calculate advocate & evangelist share in coins
        uint256 advocateShare100 = (totalCommission * advocateCommissionPct);
        uint256 advocateShare = advocateShare100 / 100;
        uint256 ambassadorShare = totalCommission - advocateShare;

        // the evangelist takes a piece of the advocate's share
        uint256 evangelistShare = (advocateShare100 * evangelistCommissionPct) / 10000;
        advocateShare -= evangelistShare;

        require(
            totalCommission == (ambassadorShare + advocateShare + evangelistShare),
            "Error in calculation for evangelist: shares don't add up"
        );
        return (ambassador, advocate, ambassadorShare, advocateShare, evangelistShare);
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
        virtual
    {
        revert("Not implemented here, you should override this function!");
    }
}
