// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AnimalSocialClubERC721.sol";
import "forge-std/console.sol";
import "src/ASC721Manager.sol";

contract AnimalSocialClubTest is Test {
    ASC721Manager public asc;
    address public adminAddress = address(0xd3d3d3d3d3); // Dummy admin address
    address public treasuryAddress = address(0xa1a1a1a1a1); // Dummy treasury address

    address public user = address(0x5678);

    address ambassador;
    address advocate;
    address evangelist;
    address buyer;

    address[] public waitlistedAddresses = [
        address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f),
        address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720)
    ];
    uint256[] public waitlistedIDs = [1, 2];

    function setUp() public {
        vm.startPrank(adminAddress);
        asc = new ASC721Manager(
            adminAddress,
            treasuryAddress
            // waitlistedAddresses,
            // waitlistedIDs
        );
        vm.stopPrank();
        ambassador = vm.addr(1);
        advocate = vm.addr(2);
        evangelist = vm.addr(3);
        buyer = vm.addr(4);

        console.log("asc.adminAddress: ", asc.adminAddress());
        console.log(
            "asc.elephant.adminAddress(): ",
            asc.elephant().adminAddress()
        );
        console.log("asc.adminAddress(): ", asc.adminAddress());

        // Assign roles
        vm.startPrank(adminAddress);
        asc.assignRole(
            address(0),
            Vera3DistributionModel.Role.Ambassador,
            ambassador
        );
        asc.assignRole(
            ambassador,
            Vera3DistributionModel.Role.Advocate,
            advocate
        );
        asc.assignRole(
            advocate,
            Vera3DistributionModel.Role.Evangelist,
            evangelist
        );

        // Set commissions
        asc.setAmbassadorToAdvocateCommission(ambassador, 50); // 50% for this Ambassador
        asc.setAdvocateToEvangelistCommission(advocate, 50); // 50% for this Advocate

        asc.setSaleActive(true);
        vm.stopPrank();
    }

    // function testReservedTokens() public view {
    //     assertEq(asc.uri(asc.ID_RESERVED()), "ipfs://baseURI/5.json");
    //     assertEq(asc.currentSupply(asc.ID_RESERVED()), asc.TOTAL_RESERVED()); // 250 reserved tokens
    // }

    function testMintElephant(uint howMany) public {
        AnimalSocialClubERC721 elephant = asc.elephant();
        vm.assume(howMany < 10);
        uint256 ambassadorInitialBalance = ambassador.balance;
        uint256 initialSupply = asc.elephant().currentSupply();

        vm.prank(adminAddress);
        asc.setSaleActive(true);
        vm.deal(user, 2000000000000 ether);
        vm.startPrank(user);
        for (uint i = 0; i < howMany; i++) {
            if (i > 0) {
                emit log("must have only one membership per address");
                vm.expectRevert();
            }
            elephant.mint{value: 0.1 ether}(user, ambassador);
            if (i > 0) {
                return;
            }
        }
        vm.stopPrank();

        howMany = howMany >= elephant.TOTAL_SUPPLY()
            ? elephant.TOTAL_SUPPLY()
            : howMany;

        assertEq(
            elephant.balanceOf(user),
            howMany,
            "Balance of user doesnt match expectation"
        );
        assertEq(
            elephant.currentSupply(),
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
        console.log("adminAddress.balance initial: ", adminAddress.balance);
        // Owner opens sale
        vm.prank(adminAddress);
        asc.setSaleActive(true);

        // user mints elephant
        vm.prank(user);
        vm.deal(user, 2 ether);
        asc.elephant().mint{value: 0.1 ether}(user, ambassador);

        uint256 initialTreasuryBalance = treasuryAddress.balance;

        uint256 ambassadorCommission = 0.1 ether / 10;
        uint256 contractPredictedBalance = (0.1 ether) - ambassadorCommission;

        // adminAddress withdraws funds
        vm.prank(adminAddress);
        asc.withdrawFunds();

        console.log("adminAddress.balance: ", adminAddress.balance);
        console.log("ambassador balance: ", ambassador.balance);
        console.log("ambassador commission: ", ambassadorCommission);
        assertEq(
            treasuryAddress.balance,
            initialTreasuryBalance + contractPredictedBalance
        );
    }

    function testAmbassadorReferrer() public {
        // Buyer mints an Elephant with Ambassador as referrer
        vm.deal(buyer, 1 ether);
        vm.startPrank(buyer);
        asc.elephant().mint{value: asc.elephant().PRICE()}(buyer, ambassador);
        vm.stopPrank();

        uint256 ambassadorBalance = ambassador.balance;
        uint256 expectedCommission = (asc.elephant().PRICE() * 10) / 100;

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
        asc.elephant().mint{value: asc.elephant().PRICE()}(buyer, advocate);
        vm.stopPrank();

        uint256 totalCommission = (asc.elephant().PRICE() * 10) / 100;
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
        asc.elephant().mint{value: asc.elephant().PRICE()}(buyer, evangelist);
        vm.stopPrank();

        uint256 totalCommission = (asc.elephant().PRICE() * 10) / 100;
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
