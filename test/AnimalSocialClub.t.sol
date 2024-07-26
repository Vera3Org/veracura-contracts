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

    address ambassador;
    address advocate;
    address evangelist;
    address buyer;

    function setUp() public {
        vm.startPrank(owner);
        asc = new AnimalSocialClub("ipfs://baseURI/", vera3Address, ascAddress);
        ambassador = vm.addr(1);
        advocate = vm.addr(2);
        evangelist = vm.addr(3);
        buyer = vm.addr(4);

        // Assign roles
        asc.assignRole(
            address(0),
            AnimalSocialClub.Role.Ambassador,
            ambassador
        );
        asc.assignRole(ambassador, AnimalSocialClub.Role.Advocate, advocate);
        asc.assignRole(advocate, AnimalSocialClub.Role.Evangelist, evangelist);

        // Set commissions
        asc.setAmbassadorToAdvocateCommission(ambassador, 50); // 50% for this Ambassador
        asc.setAdvocateToEvangelistCommission(advocate, 50); // 50% for this Advocate

        asc.setSaleActive(true);
        vm.stopPrank();
    }

    function testReservedTokens() public view {
        assertEq(asc.uri(asc.ID_RESERVED()), "ipfs://baseURI/5.json");
        assertEq(asc.tokenSupply(asc.ID_RESERVED()), asc.TOTAL_RESERVED()); // 250 reserved tokens
    }

    function testMintElephant(uint howMany) public {
        vm.assume(howMany < 10+asc.TOTAL_ELEPHANT());
        uint256 ambassadorInitialBalance = ambassador.balance;
        uint256 initialSupply = asc.tokenSupply(asc.ID_ELEPHANT());

        vm.prank(owner);
        asc.setSaleActive(true);
        vm.deal(user, 2000000000000 ether);
        vm.startPrank(user);
        for (uint i = 0; i < howMany; i++) {
            if (i >= asc.TOTAL_ELEPHANT()) {
                emit log("i is greater than TOTAL_ELEPHANT");
                vm.expectRevert();
            }
            asc.mintElephant{value: 0.1 ether}(1, ambassador);
        }
        vm.stopPrank();

        howMany = howMany >= asc.TOTAL_ELEPHANT() ? asc.TOTAL_ELEPHANT() : howMany;

        assertEq(
            asc.balanceOf(user, asc.ID_ELEPHANT()),
            howMany,
            "Balance of user doesnt match expectation"
        );
        assertEq(
            asc.tokenSupply(asc.ID_ELEPHANT()),
            initialSupply + howMany,
            "Token supply doesnt match expectation"
        );
        assertEq(
            ambassador.balance,
            ambassadorInitialBalance + (howMany * 0.01 ether),
            "Ambassador did not get proper commission"
        );
    }

    function testWithdrawFunds() public {
        console.log("owner.balance initial: ", owner.balance);
        // Owner opens sale
        vm.prank(owner);
        asc.setSaleActive(true);

        // user mints elephant
        vm.prank(user);
        vm.deal(user, 2 ether);
        asc.mintElephant{value: 0.1 ether}(1, ambassador);

        uint256 initialOwnerBalance = owner.balance;
        uint256 initialASCBalance = ascAddress.balance;

        uint256 ambassadorCommission = 0.1 ether / 10;
        uint256 contractPredictedBalance = (0.1 ether) - ambassadorCommission;

        // owner withdraws funds
        vm.prank(owner);
        asc.withdrawFunds();

        console.log("owner.balance: ", owner.balance);
        console.log("ambassador balance: ", ambassador.balance);
        console.log("ambassador commission: ", ambassadorCommission);
        assertEq(
            owner.balance,
            initialOwnerBalance + (contractPredictedBalance * 30) / 100
        );
        assertEq(
            ascAddress.balance,
            initialASCBalance + (contractPredictedBalance * 70) / 100
        );
    }

    function testAmbassadorReferrer() public {
        // Buyer mints an Elephant with Ambassador as referrer
        vm.deal(buyer, 1 ether);
        vm.startPrank(buyer);
        asc.mintElephant{value: asc.ELEPHANT_PRICE()}(1, ambassador);
        vm.stopPrank();

        uint256 ambassadorBalance = ambassador.balance;
        uint256 expectedCommission = (asc.ELEPHANT_PRICE() * 10) / 100;

        assertEq(
            ambassadorBalance,
            expectedCommission,
            "Ambassador commission is incorrect when they are referrer"
        );
    }

    function testAdvocateReferrer() public {
        // Buyer mints an Elephant with Advocate as referrer
        vm.deal(buyer, 1 ether);
        vm.startPrank(buyer);
        asc.mintElephant{value: asc.ELEPHANT_PRICE()}(1, advocate);
        vm.stopPrank();

        uint256 totalCommission = (asc.ELEPHANT_PRICE() * 10) / 100;
        uint256 expectedAmbassadorCommission = (totalCommission * 50) / 100;
        uint256 expectedAdvocateCommission = totalCommission -
            expectedAmbassadorCommission;

        assertEq(
            ambassador.balance,
            expectedAmbassadorCommission,
            "Ambassador commission is incorrect when Advocate is referrer"
        );
        assertEq(
            advocate.balance,
            expectedAdvocateCommission,
            "Advocate commission is incorrect when they are referrer"
        );
    }

    function testEvangelistReferrer() public {
        // Buyer mints an Elephant with Advocate as referrer
        vm.deal(buyer, 1 ether);
        vm.startPrank(buyer);
        asc.mintElephant{value: asc.ELEPHANT_PRICE()}(1, evangelist);
        vm.stopPrank();

        uint256 totalCommission = (asc.ELEPHANT_PRICE() * 10) / 100;
        uint256 expectedAmbassadorCommission = (totalCommission * 50) / 100;
        uint256 expectedAdvocateCommission = totalCommission -
            expectedAmbassadorCommission;
        uint256 expectedEvangelistCommission = (expectedAdvocateCommission *
            50) / 100;
        expectedAdvocateCommission -= expectedEvangelistCommission;

        assertEq(
            ambassador.balance,
            expectedAmbassadorCommission,
            "Ambassador commission is incorrect when Evangelist is referrer"
        );
        assertEq(
            advocate.balance,
            expectedAdvocateCommission,
            "Advocate commission is incorrect when Evangelist is referrer"
        );
        assertEq(
            evangelist.balance,
            expectedEvangelistCommission,
            "Evangelist commission is incorrect when they are referrer"
        );
    }
}
