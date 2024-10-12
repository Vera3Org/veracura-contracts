// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

abstract contract Vera3DistributionModel is Ownable {
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

    // Ensure referrer is registered as Ambassador, Advocate
    function checkReferrer(address referrer) public view {
        require(
            roles[referrer] == Role.Ambassador ||
                roles[referrer] == Role.Advocate ||
                roles[referrer] == Role.Evangelist,
            "referrer must be a valid Ambassador, Advocate or Evangelist"
        );
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

    /**
     * Updates the hierarchy of roles.
     * E.g. an Ambassador `user` adds a `delegate` with `role` Advocate to his/her group.
     * args:
     *   - user: the upper level in the hierarchy. Unused when contract owner assigns an Ambassador role.
     *   - role: the role which the `delegate` will have.
     *   - delegate: the lower level in the hierarchy.
     */
    function assignRole(address user, Role role, address delegate) external {
        console.log(
            "Vera3DistributionModel.assignRole msg.sender: ",
            msg.sender,
            " tx.origin: ",
            tx.origin
        );
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
