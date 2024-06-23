// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AnimalSocialClub.sol";
import "forge-std/console2.sol";

contract AnimalSocialClubTest is Test {
    AnimalSocialClub public asc;
    address public vera3Address = address(0xd3d3d3d3d3); // Dummy Vera3 address
    address public ascAddress = address(0xa1a1a1a1a1); // Dummy ASC address

    address public user = address(0x5678);
    address public owner = vera3Address;

    function setUp() public {
        vm.startPrank(owner);
        asc = new AnimalSocialClub("ipfs://baseURI/", vera3Address, ascAddress);
        vm.stopPrank();
    }

    function testReservedTokens() public view {
        assertEq(asc.uri(asc.ID_RESERVED()), "ipfs://baseURI/0.json");
        assertEq(asc.tokenSupply(asc.ID_RESERVED()), asc.TOTAL_RESERVED()); // 250 reserved tokens
    }

    function testMintElephant() public {
        vm.prank(owner);
        asc.setSaleActive(true);
        vm.prank(user);
        vm.deal(user, 2 ether);
        asc.mintElephant{value: 0.1 ether}(1);
        vm.prank(user);
        asc.mintElephant{value: 0.1 ether}(1);
        vm.prank(user);
        asc.mintElephant{value: 0.1 ether}(1);

        assertEq(asc.balanceOf(user, asc.ID_ELEPHANT()), 3);
        assertEq(asc.tokenSupply(asc.ID_ELEPHANT()), 3);
    }

    function testWithdrawFunds() public {
        // Owner opens sale
        vm.prank(owner);
        asc.setSaleActive(true);

        // user mints elephant
        vm.prank(user);
        vm.deal(user, 2 ether);
        asc.mintElephant{value: 0.1 ether}(1);

        uint256 initialOwnerBalance = owner.balance;
        uint256 initialASCBalance = ascAddress.balance;

        // owner withdraws funds
        vm.prank(owner);
        asc.withdrawFunds();

        console.log("owner.balance: ", owner.balance);
        assertEq(owner.balance, initialOwnerBalance + (0.1 ether * 30) / 100);
        assertEq(
            ascAddress.balance,
            initialASCBalance + (0.1 ether * 70) / 100
        );
    }
}
