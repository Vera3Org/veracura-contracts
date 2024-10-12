// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/AnimalSocialClubERC721.sol";

contract ASC721Manager is Ownable, ReentrancyGuard {
    using Strings for uint256;

    // Addresses for funds allocation
    address public vera3Address;
    address public ascAddress;

    AnimalSocialClubERC721 public elephant;
    AnimalSocialClubERC721 public tiger;
    AnimalSocialClubERC721 public shark;
    AnimalSocialClubERC721 public eagle;

    AnimalSocialClubERC721[] public contracts;

    constructor(
        address _vera3Address,
        address _ascAddress
    ) Ownable(_vera3Address) {
        require(msg.sender == _vera3Address, "sender must be admin");
        require(
            _vera3Address != address(0) && _ascAddress != address(0),
            "One or more invalid addresses"
        );
        // Set the beneficiary addresses
        vera3Address = _vera3Address;
        ascAddress = _ascAddress;

        elephant = new AnimalSocialClubERC721(
            "Animal Social Club Elephant Membership",
            "ASC.Elephant",
            9000,
            0.1 ether,
            vera3Address,
            ascAddress,
            address(this)
        );
        contracts.push(elephant);
        shark = new AnimalSocialClubERC721(
            "Animal Social Club Shark Membership",
            "ASC.Shark",
            520,
            0.5 ether,
            vera3Address,
            ascAddress,
            address(this)
        );
        contracts.push(shark);
        eagle = new AnimalSocialClubERC721(
            "Animal Social Club Eagle Membership",
            "ASC.Eagle",
            200,
            1 ether,
            vera3Address,
            ascAddress,
            address(this)
        );
        contracts.push(eagle);
        tiger = new AnimalSocialClubERC721(
            "Animal Social Club Tiger Membership",
            "ASC.Tiger",
            30,
            2 ether,
            vera3Address,
            ascAddress,
            address(this)
        );
        contracts.push(tiger);
    }

    function isMember(address a) public view returns (bool) {
        for (uint i = 0; i < contracts.length; i++) {
            AnimalSocialClubERC721 tier = contracts[i];
            if (tier.balanceOf(a) != 0) {
                return true;
            }
        }
        return false;
    }
}
