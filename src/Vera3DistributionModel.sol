// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@requestnetwork/advanced-logic/src/contracts/interfaces/EthereumFeeProxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "forge-std/console.sol";

/**
 * @dev Abstract contract which implements the Vera3 distribution model.

 * @dev There are 3 promoter roles in the hierarchy, from highest to lowest
 * Ambassador, Advocate and Evangelist.

 * @dev Each level in the hierarchy can specify one or more promoters of the
 * lower level, and when a mint of AnimalSocialClubERC721 happens, and
 * the `referrer` argument is a promoter, a 10% mint fee is take from the
 * donation and distributed as follows:
 * - If `referrer` is an Ambassador, they keep the fee.
 * - If `referrer` is an Advocate, they and their Ambassador share the fee.
 * - If `referrer` is an Evangelist, all the upper levels (the Evangelist's
 *   Advocate, and that Advocate's Ambassador) share the fee.
 */
abstract contract Vera3DistributionModel is OwnableUpgradeable {
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

    ///////////////////////////////////////////////////////////
    // Mappings to keep track of hierarchical relationships
    ///////////////////////////////////////////////////////////

    /**
     * @dev keys are Ambassador address, values are list of their Advocates.
     * One-to-many mapping.
     */
    mapping(address => address payable[]) public ambassadorToAdvocates;

    /**
     * @dev inverse of ambassadorToAdvocates mapping: given a value in the list,
     * returns the corresponding key.
     * One-to-one mapping.
     */
    mapping(address => address payable) public advocateToAmbassador;

    /**
     * @dev keys are Advocate address, values are list of their Evangelists.
     * One-to-many mapping.
     */
    mapping(address => address payable[]) public advocateToEvangelists;

    /**
     * @dev inverse of advocateToEvangelists mapping: given a value,
     * returns the corresponding key.
     * One-to-one mapping.
     */
    mapping(address => address payable) public evangelistToAdvocate;

    ///////////////////////////////////////////////////////////////////////////////
    // Mappings to track Promoter Ambassador, Advocates, and their commissions
    ///////////////////////////////////////////////////////////////////////////////

    /**
     * @dev
     * commission that one ambassador gives to their advocates.
     * 60 means 60% to advocate, rest 40% to ambassador
     */
    uint256 public ambassadorToAdvocateCommission;
    /**
     * @dev
     * commission that one advocate gives to their evangelists.
     * 50 means 50% to evangelist, 50% advocate.
     */
    uint256 public advocateToEvangelistCommission;

    // mapping(address => uint256) public ambassadorToAdvocateCommission;
    // // commission that one advocate gives to their evangelists.
    // mapping(address => uint256) public advocateToEvangelistCommission;

    /**
     * @dev reference to Request Network's Ethereum Fee Proxy.
     */
    IEthereumFeeProxy public ETHEREUM_FEE_PROXY;

    // Events for role assignment and commission updates
    event RoleAssigned(address indexed user, Role role);
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

    function __Vera3DistributionModel_init(
        address ethFeeProxy
    ) internal onlyInitializing {
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

    function isReferrer(address referrer) public view returns (bool) {
        return
            roles[referrer] == Role.Ambassador ||
            roles[referrer] == Role.Advocate ||
            roles[referrer] == Role.Evangelist;
    }

    // Ensure referrer is registered as Ambassador, Advocate
    function requireReferrer(address referrer) public view {
        require(
            isReferrer(referrer),
            "referrer must be a valid Ambassador, Advocate or Evangelist"
        );
    }

    function calculateCommission(uint256 amt) internal pure returns (uint256) {
        return amt / 10;
    }

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
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{
                value: calculateCommission(msg.value)
            }(payable(ambassador), ambassadorReference, 0, payable(address(0)));

            return;
        } else if (roles[referrer] == Role.Advocate) {
            // Referrer is an Advocate delegated by an Ambassador
            address advocate = referrer;
            (
                address ambassador,
                uint256 ambassadorShare,
                uint256 advocateShare
            ) = getAdvocateShare(advocate, calculateCommission(msg.value));
            // ambassador = ambassador_;
            // payable(ambassador).transfer(ambassadorShare);
            console.log("Using Ethereum fee proxy");
            // transfer to ambassador
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{
                value: ambassadorShare
            }(payable(ambassador), ambassadorReference, 0, payable(address(0)));
            // transfer to advocate
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{
                value: advocateShare
            }(payable(advocate), advocateReference, 0, payable(address(0)));
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

            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{
                value: ambassadorShare
            }(payable(ambassador), ambassadorReference, 0, payable(address(0)));
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{
                value: advocateShare
            }(payable(advocate), advocateReference, 0, payable(address(0)));
            ETHEREUM_FEE_PROXY.transferWithReferenceAndFee{
                value: evangelistShare
            }(payable(evangelist), evangelistReference, 0, payable(address(0)));
            return;
        } else {
            revert("referrer role is None!!");
        }
    }

    // Function to set commission percentage for Promoter Ambassadors
    function setAmbassadorToAdvocateCommission(
        // address ambassador,
        uint256 commissionPercentage
    ) external onlyOwner {
        require(
            roles[msg.sender] == Role.Ambassador || msg.sender == owner(),
            "Not authorized!"
        );
        require(
            commissionPercentage <= 100,
            "Commission percentage must be <= 100"
        );
        // ambassadorToAdvocateCommission[ambassador] = commissionPercentage;
        // emit AmbassadorCommissionSet(ambassador, commissionPercentage);
        ambassadorToAdvocateCommission = commissionPercentage;
        emit AmbassadorCommissionSet(commissionPercentage);
    }

    // Function to set commission percentage for Promoter Ambassadors
    function setAdvocateToEvangelistCommission(
        uint256 commissionPercentage
    ) external onlyOwner {
        require(
            roles[msg.sender] == Role.Advocate || msg.sender == owner(),
            "Not authorized!"
        );
        require(
            commissionPercentage <= 100,
            "Commission percentage must be <= 100"
        );
        // advocateToEvangelistCommission[advocate] = commissionPercentage;
        // emit AdvocateCommissionSet(advocate, commissionPercentage);
        advocateToEvangelistCommission = commissionPercentage;
        emit AdvocateCommissionSet(commissionPercentage);
    }

    function getAdvocateShare(
        address advocate,
        uint256 totalCommission
    ) internal view returns (address, uint256, uint256) {
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

    function getEvangelistShare(
        address evangelist,
        uint256 totalCommission
    )
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
        uint256 evangelistShare = (advocateShare100 * evangelistCommissionPct) /
            10000;
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

    /**
     * Updates the hierarchy of roles.
     * E.g. an Ambassador `user` adds a `delegate` with `role` Advocate to his/her group.
     * args:
     *   - user: the upper level in the hierarchy. Unused when contract owner assigns an Ambassador role.
     *   - role: the role which the `delegate` will have.
     *   - delegate: the lower level in the hierarchy.
     */
    function assignRole(
        address payable user,
        Role role,
        address payable delegate
    ) external {
        bool isAuthorized = msg.sender == owner();

        if (role == Role.Ambassador) {
            // here `user` is the owner, and `delegate` is the advocate
            // only the owner can set an advocate
        } else if (role == Role.Advocate) {
            require(
                roles[user] == Role.Ambassador,
                "user is not an Ambassador and cannot delegate an Advocate"
            );
            require(
                advocateToAmbassador[delegate] == address(0),
                "delegate is already an ambassador for someone else"
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
            require(
                evangelistToAdvocate[delegate] == address(0),
                "delegate is already an advocate for someone else"
            );
            isAuthorized = isAuthorized || user == msg.sender;
            advocateToEvangelists[user].push(delegate);
            evangelistToAdvocate[delegate] = user;
        } else if (role == Role.None) {
            // TODO discuss whether ambassador/advocate can remove ppl below them
            require(
                msg.sender == owner(),
                "only the owner can assign arbitrary roles"
            );
        }
        require(isAuthorized, "user not authorized");
        roles[delegate] = role;
        emit RoleAssigned(user, role);
    }
}
