// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AnimalSocialClubERC721.sol";
import "forge-std/console.sol";
import "src/ASC721Manager.sol";
import "../src/DummyEthFeeProxy.sol";

contract AnimalSocialClubTest is Test {
    ASC721Manager public asc;
    address public adminAddress = address(0xd3d3d3d3d3); // Dummy admin address
    address public treasuryAddress = address(0xa1a1a1a1a1); // Dummy treasury address

    address public user = address(0x5678);

    address ambassador;
    address advocate;
    address evangelist;
    address buyer;
    EthereumFeeProxy ethFeeProxy;

    address[] public waitlistedAddresses = [
        address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f),
        address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720)
    ];
    uint256[] public waitlistedIDs = [1, 2];

    address public constant LINK_BASE_MAINNET =
        0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
    address public constant VRF_WRAPPER_BASE_MAINNET =
        0xb0407dbe851f8318bd31404A49e658143C982F23;

    address public constant LINK_BASE_SEPOLIA =
        0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    address public constant VRF_WRAPPER_BASE_SEPOLIA =
        0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    function setUp() public {
        ambassador = vm.addr(1);
        advocate = vm.addr(2);
        evangelist = vm.addr(3);
        buyer = vm.addr(4);
        // ethFeeProxy = address(0xA52672A2aC57263d599284a75585Cc7771363A05); // base sepolia testnet address
        ethFeeProxy = new EthereumFeeProxy();

        vm.startPrank(adminAddress);
        asc = new ASC721Manager(
            treasuryAddress,
            address(ethFeeProxy),
            LINK_BASE_SEPOLIA,
            VRF_WRAPPER_BASE_SEPOLIA
            // waitlistedAddresses,
            // waitlistedIDs
        );
        for (uint i = 0; i < waitlistedAddresses.length; i++) {
            asc.addToWaitlist(asc.ELEPHANT_ID(), 0, waitlistedAddresses[i]);
        }
        asc.setKYC(buyer, true);
        asc.setKYC(user, true);
        vm.stopPrank();

        console.log("asc.elephant.owner(): ", asc.elephant().owner());
        // Assign roles
        vm.startPrank(adminAddress);
        asc.assignRole(
            payable(address(0)),
            Vera3DistributionModel.Role.Ambassador,
            payable(ambassador)
        );
        asc.assignRole(
            payable(ambassador),
            Vera3DistributionModel.Role.Advocate,
            payable(advocate)
        );
        asc.assignRole(
            payable(advocate),
            Vera3DistributionModel.Role.Evangelist,
            payable(evangelist)
        );

        // Set commissions
        asc.setAmbassadorToAdvocateCommission(ambassador, 50); // 50% for this Ambassador
        asc.setAdvocateToEvangelistCommission(advocate, 50); // 50% for this Advocate

        asc.setSaleActive(true);
        vm.stopPrank();
    }

    // function testReservedTokens() public view {
    //     assertEq(asc.uri(asc.ID_RESERVED()), "ipfs://baseURI/5.json");
    //     assertEq(asc.totalSupply(asc.ID_RESERVED()), asc.TOTAL_RESERVED()); // 250 reserved tokens
    // }

    function testMintWithDonation(uint tier, uint howMany) public {
        tier = bound(tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());

        AnimalSocialClubERC721 membership = asc.contracts(tier);
        vm.assume(howMany < 3);
        uint256 ambassadorInitialBalance = ambassador.balance;
        uint256 initialSupply = membership.totalSupply();

        vm.prank(adminAddress);
        asc.setSaleActive(true);
        vm.deal(user, 2000000000000 ether);
        vm.startPrank(user);
        for (uint i = 0; i < howMany; i++) {
            uint price = membership.PRICE();
            if (tier == asc.STAKEHOLDER_ID()) {
                vm.expectRevert();
            }
            membership.mintWithDonationRequestNetwork{value: price}(
                user,
                ambassador,
                new bytes(1),
                new bytes(1),
                new bytes(2),
                new bytes(3)
            );
        }
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        howMany = howMany >= membership.TOTAL_SUPPLY()
            ? membership.TOTAL_SUPPLY()
            : howMany;

        assertEq(
            membership.balanceOf(user),
            howMany,
            "Balance of user doesnt match expectation"
        );
        assertEq(
            membership.totalSupply(),
            initialSupply + howMany,
            "Token supply doesnt match expectation"
        );
        assertEq(
            ambassador.balance,
            ambassadorInitialBalance + ((howMany * membership.PRICE()) / 10),
            "Ambassador did not get proper commission"
        );
    }

    // function testWithdrawFunds() public {
    //     console.log("adminAddress.balance initial: ", adminAddress.balance);
    //     // Owner opens sale
    //     vm.prank(adminAddress);
    //     asc.setSaleActive(true);

    //     // user mints elephant
    //     vm.prank(user);
    //     vm.deal(user, 2 ether);
    //     asc.elephant().mintWithDonationRequestNetwork{value: 0.1 ether}(user, ambassador);

    //     uint256 initialTreasuryBalance = treasuryAddress.balance;

    //     uint256 ambassadorCommission = 0.1 ether / 10;
    //     uint256 contractPredictedBalance = (0.1 ether) - ambassadorCommission;

    //     // adminAddress withdraws funds
    //     vm.prank(adminAddress);
    //     asc.withdrawFunds();

    //     console.log("adminAddress.balance: ", adminAddress.balance);
    //     console.log("ambassador balance: ", ambassador.balance);
    //     console.log("ambassador commission: ", ambassadorCommission);
    //     assertEq(
    //         treasuryAddress.balance,
    //         initialTreasuryBalance + contractPredictedBalance
    //     );
    // }

    function testAmbassadorReferrer(uint tier) public {
        tier = bound(tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        AnimalSocialClubERC721 membership = asc.contracts(tier);
        // Buyer mints an Elephant with Ambassador as referrer
        vm.deal(buyer, 1000 ether);
        vm.startPrank(buyer);
        uint price = membership.PRICE();
        if (tier == asc.STAKEHOLDER_ID()) {
            vm.expectRevert();
        }
        membership.mintWithDonationRequestNetwork{value: price}(
            buyer,
            ambassador,
            new bytes(1),
            new bytes(1),
            new bytes(2),
            new bytes(3)
        );
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        uint256 ambassadorBalance = ambassador.balance;
        uint256 expectedCommission = (membership.PRICE() * 10) / 100;

        assertApproxEqRel(
            ambassadorBalance,
            expectedCommission,
            1e15, // 1e18 = 100%, 1e16 = 1%
            "Ambassador commission is incorrect when they are referrer"
        );
    }

    function testAdvocateReferrer(uint tier) public {
        tier = bound(tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        AnimalSocialClubERC721 membership = asc.contracts(tier);
        // Buyer mints an Elephant with Advocate as referrer
        vm.deal(buyer, 1000 ether);
        vm.startPrank(buyer);
        uint price = membership.PRICE();
        if (tier == asc.STAKEHOLDER_ID()) {
            vm.expectRevert();
        }
        membership.mintWithDonationRequestNetwork{value: price}(
            buyer,
            advocate,
            new bytes(1),
            new bytes(1),
            new bytes(2),
            new bytes(3)
        );
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        uint256 totalCommission = (membership.PRICE() * 10) / 100;
        uint256 expectedAmbassadorCommission = (totalCommission * 50) / 100;
        uint256 expectedAdvocateCommission = totalCommission -
            expectedAmbassadorCommission;

        assertApproxEqRel(
            ambassador.balance,
            expectedAmbassadorCommission,
            1e16,
            "Ambassador commission is incorrect when Advocate is referrer"
        );
        assertApproxEqRel(
            advocate.balance,
            expectedAdvocateCommission,
            1e16,
            "Advocate commission is incorrect when they are referrer"
        );
    }

    function testEvangelistReferrer(uint tier) public {
        tier = bound(tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        AnimalSocialClubERC721 membership = asc.contracts(tier);
        // Buyer mints an Elephant with Advocate as referrer
        vm.deal(buyer, 1000 ether);
        vm.startPrank(buyer);
        uint price = membership.PRICE();
        if (tier == asc.STAKEHOLDER_ID()) {
            vm.expectRevert();
        }
        membership.mintWithDonationRequestNetwork{value: price}(
            buyer,
            evangelist,
            new bytes(1),
            new bytes(1),
            new bytes(2),
            new bytes(3)
        );
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        uint256 totalCommission = (membership.PRICE() * 10) / 100;
        uint256 expectedAmbassadorCommission = (totalCommission * 50) / 100;
        uint256 expectedAdvocateCommission = totalCommission -
            expectedAmbassadorCommission;
        uint256 expectedEvangelistCommission = (expectedAdvocateCommission *
            50) / 100;
        expectedAdvocateCommission -= expectedEvangelistCommission;

        assertApproxEqRel(
            ambassador.balance,
            expectedAmbassadorCommission,
            1e16,
            "Ambassador commission is incorrect when Evangelist is referrer"
        );
        assertApproxEqRel(
            advocate.balance,
            expectedAdvocateCommission,
            1e16,
            "Advocate commission is incorrect when Evangelist is referrer"
        );
        assertApproxEqRel(
            evangelist.balance,
            expectedEvangelistCommission,
            1e16,
            "Evangelist commission is incorrect when they are referrer"
        );
    }
}
