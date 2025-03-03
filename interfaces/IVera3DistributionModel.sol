// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library Vera3DistributionModel {
    type Role is uint8;
}

interface IVera3DistributionModel {
    error InvalidInitialization();
    error NotAnAdvocate(address account);
    error NotAnAmbassador(address account);
    error NotAnEvangelist(address account);
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);

    event AdvocateCommissionSet(uint256 commission_pct);
    event AmbassadorCommissionSet(uint256 commission_pct);
    event CommissionSent(
        address ambassador,
        uint256 ambassadorAmount,
        address advocate,
        uint256 advocateAmount,
        address evangelist,
        uint256 evangelistAmount
    );
    event Initialized(uint64 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleAssigned(
        address indexed user, Vera3DistributionModel.Role indexed role, address indexed delegate, address _msgSender
    );

    function ETHEREUM_FEE_PROXY() external view returns (address);
    function advocateToAmbassador(address) external view returns (address payable);
    function advocateToEvangelistCommission() external view returns (uint256);
    function advocateToEvangelists(address, uint256) external view returns (address payable);
    function ambassadorToAdvocateCommission() external view returns (uint256);
    function ambassadorToAdvocates(address, uint256) external view returns (address payable);
    function assignRole(
        address payable delegator,
        Vera3DistributionModel.Role role,
        address payable delegate,
        address _msgSender
    ) external;
    function evangelistToAdvocate(address) external view returns (address payable);
    function getPromoterCommissions(address referrer, uint256 total_value)
        external
        view
        returns (address, uint256, address, uint256, address, uint256);
    function isReferrer(address referrer) external view returns (bool);
    function owner() external view returns (address);
    function renounceOwnership() external;
    function requireReferrer(address referrer) external view;
    function roles(address) external view returns (Vera3DistributionModel.Role);
    function transferOwnership(address newOwner) external;
}
