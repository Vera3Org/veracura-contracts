// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "forge-std/Test.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import {console} from "forge-std/console.sol";

import {ASC721Manager} from "src/ASC721Manager.sol";
import {ASCLottery} from "src/ASCLottery.sol";
import {AnimalSocialClubERC721} from "src/AnimalSocialClubERC721.sol";
import {Vera3DistributionModel} from "src/Vera3DistributionModel.sol";
import "src/DummyEthFeeProxy.sol";

contract AnimalSocialClubTest is Test {
    ASC721Manager public asc;
    ASCLottery lottery;
    address public adminAddress = address(0xd3d3d3d3d3); // Dummy admin address
    address public treasuryAddress = address(0xa1a1a1a1a1); // Dummy treasury address

    address public user = address(0x5678);

    address ambassador;
    address advocate;
    address evangelist;
    address buyer;
    EthereumFeeProxy ethFeeProxy;

    address[] public waitlistedAddresses =
        [address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f), address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720)];

    // address public constant LINK_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // eth sepolia
    // address public constant VRF_WRAPPER_ADDRESS = 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1; // eth sepolia
    // address public constant ETH_FEE_PROXY_ADDRESS = 0xe11BF2fDA23bF0A98365e1A4c04A87C9339e8687; // eth sepolia
    address public constant LINK_ADDRESS = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196; // base mainnet
    address public constant VRF_WRAPPER_ADDRESS = 0xb0407dbe851f8318bd31404A49e658143C982F23; // base mainnet
    address public constant ETH_FEE_PROXY_ADDRESS = 0xd9C3889eB8DA6ce449bfFE3cd194d08A436e96f2; // base mainnet

    string public constant DUMMY_BASE_URI = "ipfs://ciao/";

    function setUp() public {
        ambassador = vm.addr(1);
        advocate = vm.addr(2);
        evangelist = vm.addr(3);
        buyer = vm.addr(4);
        // ethFeeProxy = address(0xA52672A2aC57263d599284a75585Cc7771363A05); // base sepolia testnet address
        ethFeeProxy = EthereumFeeProxy(payable(ETH_FEE_PROXY_ADDRESS)); // eth sepolia testnet address
        console.log("ethfeeproxy deployed.");

        vm.startPrank(adminAddress);
        lottery = new ASCLottery(LINK_ADDRESS, VRF_WRAPPER_ADDRESS, treasuryAddress);
        console.log("lottery deployed.");

        address payable asc_address = payable(
            Upgrades.deployUUPSProxy(
                "ASC721Manager.sol", abi.encodeCall(ASC721Manager.initialize, (treasuryAddress, address(lottery)))
            )
        );
        console.log("manager deployed.");
        asc = ASC721Manager(asc_address);
        lottery.transferOwnership(address(asc));
        console.log("ownership transfered");
        {
            address elephant = Upgrades.deployUUPSProxy(
                "AnimalSocialClubERC721.sol",
                abi.encodeCall(
                    AnimalSocialClubERC721.initialize,
                    (
                        "Animal Social Club Elephant Membership",
                        "ASC.Elephant",
                        9000,
                        0.1 ether,
                        adminAddress,
                        treasuryAddress,
                        asc,
                        0,
                        address(ethFeeProxy),
                        asc.ELEPHANT_ID(),
                        DUMMY_BASE_URI,
                        false
                    )
                )
            );

            address shark = Upgrades.deployUUPSProxy(
                "AnimalSocialClubERC721.sol",
                abi.encodeCall(
                    AnimalSocialClubERC721.initialize,
                    (
                        "Animal Social Club Shark Membership",
                        "ASC.Shark",
                        520,
                        0.5 ether,
                        adminAddress,
                        treasuryAddress,
                        asc,
                        0,
                        address(ethFeeProxy),
                        asc.SHARK_ID(),
                        DUMMY_BASE_URI,
                        false
                    )
                )
            );

            address eagle = Upgrades.deployUUPSProxy(
                "AnimalSocialClubERC721.sol",
                abi.encodeCall(
                    AnimalSocialClubERC721.initialize,
                    (
                        "Animal Social Club Eagle Membership",
                        "ASC.Eagle",
                        200,
                        1 ether,
                        adminAddress,
                        treasuryAddress,
                        asc,
                        9, // 9 eagle reserved for lottery
                        address(ethFeeProxy),
                        asc.EAGLE_ID(),
                        DUMMY_BASE_URI,
                        false
                    )
                )
            );

            address tiger = Upgrades.deployUUPSProxy(
                "AnimalSocialClubERC721.sol",
                abi.encodeCall(
                    AnimalSocialClubERC721.initialize,
                    (
                        "Animal Social Club Tiger Membership",
                        "ASC.Tiger",
                        30,
                        2 ether,
                        adminAddress,
                        treasuryAddress,
                        asc,
                        11, // 1 tiger reserved for lottery, 10 tigers in auction
                        address(ethFeeProxy),
                        asc.TIGER_ID(),
                        DUMMY_BASE_URI,
                        true
                    )
                )
            );
            address stakeholder = Upgrades.deployUUPSProxy(
                "AnimalSocialClubERC721.sol",
                abi.encodeCall(
                    AnimalSocialClubERC721.initialize,
                    (
                        "Animal Social Club Stakeholder Membership",
                        "ASC.Stakeholder",
                        250,
                        0.5 ether,
                        adminAddress,
                        treasuryAddress,
                        asc,
                        0,
                        address(ethFeeProxy),
                        asc.STAKEHOLDER_ID(),
                        DUMMY_BASE_URI,
                        false
                    )
                )
            );

            asc.assignContracts(payable(elephant), payable(tiger), payable(shark), payable(eagle), payable(stakeholder));
            AnimalSocialClubERC721[5] memory contracts = [
                AnimalSocialClubERC721(payable(elephant)),
                AnimalSocialClubERC721(payable(tiger)),
                AnimalSocialClubERC721(payable(shark)),
                AnimalSocialClubERC721(payable(eagle)),
                AnimalSocialClubERC721(payable(stakeholder))
            ];
            for (uint256 i = 0; i < contracts.length; i++) {
                require(contracts[i].owner() == address(adminAddress));
            }
        }
        for (uint256 i = 0; i < waitlistedAddresses.length; i++) {
            console.log("adding address in the elephant waitlist: ", waitlistedAddresses[i]);
            asc.addToWaitlist(asc.ELEPHANT_ID(), 0.01 ether, waitlistedAddresses[i]);
        }
        asc.setSoftKYC(buyer, true);
        asc.setSoftKYC(user, true);
        asc.setStrongKYC(buyer, true);
        asc.setStrongKYC(user, true);

        vm.stopPrank();

        console.log("asc.elephant.owner(): ", asc.elephant().owner());
        // Assign roles
        vm.startPrank(adminAddress);
        asc.assignRole(payable(address(0)), Vera3DistributionModel.Role.Ambassador, payable(ambassador));
        asc.assignRole(payable(ambassador), Vera3DistributionModel.Role.Advocate, payable(advocate));
        asc.assignRole(payable(advocate), Vera3DistributionModel.Role.Evangelist, payable(evangelist));

        // Set commissions
        // asc.setAmbassadorToAdvocateCommission(ambassador, 50); // 50% for this Ambassador
        // asc.setAdvocateToEvangelistCommission(advocate, 50); // 50% for this Advocate

        asc.setSaleActive(true);
        vm.stopPrank();
    }

    /// tests that a random user cannot claim the waitlist for another one
    function testCannotStealWaitlist() public {
        vm.prank(adminAddress);
        asc.setLaunchStatus(true);

        // create a random user and set all the correct params for claiming
        address non_waitlisted_user = address(0x123);
        AnimalSocialClubERC721 elephant = asc.elephant();
        vm.deal(non_waitlisted_user, 2000000000000 ether);
        vm.startPrank(non_waitlisted_user);
        uint256 amt_to_pay = elephant.PRICE() - elephant.waitlistDeposited(non_waitlisted_user);
        vm.expectRevert();
        elephant.claimWaitlist{value: amt_to_pay}();
        vm.stopPrank();
    }

    function testClaimWaitlist() public {
        vm.prank(adminAddress);
        asc.setLaunchStatus(true);

        // check that it's ok to non-waitlist mint before ppl claim
        testAdminMint(0, 1);
        testMintWithDonation(0, 1);
        testAdminMint(0, 1);
        testMintWithDonation(0, 1);

        AnimalSocialClubERC721 elephant = asc.elephant();
        for (uint256 i = 0; i < waitlistedAddresses.length; i++) {
            address waitlisted_user = waitlistedAddresses[i];
            vm.deal(waitlisted_user, 2000000000000 ether);
            vm.startPrank(waitlisted_user);
            uint256 amt_to_pay = elephant.PRICE() - elephant.waitlistDeposited(waitlisted_user);
            console.log("amount to pay: ", amt_to_pay);
            elephant.claimWaitlist{value: amt_to_pay}();
            vm.expectRevert();
            elephant.claimWaitlist{value: amt_to_pay}();
            vm.stopPrank();
            // check that non-waitlist mints work fine after ppl claim
            testAdminMint(0, 1);
            testMintWithDonation(0, 1);
            testAdminMint(0, 1);
            testMintWithDonation(0, 1);
        }
    }

    function testTreasuryChange() public {
        vm.startPrank(adminAddress);
        address new_treasury = address(0x123123);

        asc.setTreasuryAddress(new_treasury);
        assertEq(new_treasury, asc.treasuryAddress());
        for (uint256 i = 0; i < 5; i++) {
            assertEq(new_treasury, asc.contracts(i).treasuryAddress());
        }
    }

    function testAdminMint(uint8 _tier, uint8 _howMany) public {
        vm.assume(_howMany > 0 && _howMany < 3 && _tier <= asc.STAKEHOLDER_ID());
        uint256 tier = bound(_tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        uint256 howMany = _howMany;

        AnimalSocialClubERC721 membership = asc.contracts(tier);
        uint256 inital_membership_balance = membership.balanceOf(user);
        uint256 initialSupply = membership.totalSupply();

        vm.deal(user, 2000000000000 ether);
        vm.startPrank(adminAddress);

        asc.setSaleActive(true);
        for (uint256 i = 0; i < howMany; i++) {
            // mint using both methods
            console.log("before 1: %s", membership.totalSupply());
            asc.adminMint(user, tier);
            console.log("after 1: %s", membership.totalSupply());
            console.log("uri for tier %s: %s", tier, membership.totalSupply() - 1);

            console.log("before 2: %s", membership.totalSupply());
            AnimalSocialClubERC721(asc.contracts(tier)).adminMint(user);
            console.log("after 2: %s", membership.totalSupply());
            console.log("uri for tier %s: %s", tier, membership.totalSupply() - 1);
        }
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        howMany = howMany >= membership.MAX_TOKEN_SUPPLY() ? membership.MAX_TOKEN_SUPPLY() : howMany;

        assertEq(
            membership.balanceOf(user),
            inital_membership_balance + howMany * 2,
            "Balance of user doesnt match expectation"
        );
        assertEq(membership.totalSupply(), initialSupply + (howMany * 2), "Token supply doesnt match expectation");
    }

    function testMintWithDonation(uint8 _tier, uint8 _howMany) public {
        vm.assume(_howMany < 3 && _tier < asc.STAKEHOLDER_ID());
        uint256 tier = bound(_tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        uint256 howMany = _howMany;

        AnimalSocialClubERC721 membership = asc.contracts(tier);
        uint256 inital_membership_balance = membership.balanceOf(user);
        uint256 ambassadorInitialBalance = ambassador.balance;
        uint256 initialSupply = membership.totalSupply();

        vm.prank(adminAddress);
        asc.setSaleActive(true);
        vm.deal(user, 2000000000000 ether);
        vm.startPrank(user);
        for (uint256 i = 0; i < howMany; i++) {
            uint256 price = membership.PRICE();
            // test that it does not work without the right amount
            if (tier == asc.STAKEHOLDER_ID()) {
                vm.expectRevert();
            }
            membership.mintWithDonationRequestNetwork{value: price}(
                user, ambassador, new bytes(1), new bytes(1), new bytes(2), new bytes(3)
            );
            // test that it does not work without the right amount
            vm.expectRevert();
            membership.mintWithDonationRequestNetwork{value: 1}(
                user, ambassador, new bytes(1), new bytes(1), new bytes(2), new bytes(3)
            );
        }
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        howMany = howMany >= membership.MAX_TOKEN_SUPPLY() ? membership.MAX_TOKEN_SUPPLY() : howMany;

        assertEq(
            membership.balanceOf(user), inital_membership_balance + howMany, "Balance of user doesnt match expectation"
        );
        assertEq(membership.totalSupply(), initialSupply + howMany, "Token supply doesnt match expectation");
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

    function testNoReferrer(uint8 _tier) public {
        vm.assume(_tier < asc.STAKEHOLDER_ID());
        uint256 tier = bound(_tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        AnimalSocialClubERC721 membership = asc.contracts(tier);
        // Buyer mints an Elephant with Ambassador as referrer
        vm.deal(buyer, 1000 ether);
        vm.startPrank(buyer);
        uint256 price = membership.PRICE();
        if (tier == asc.STAKEHOLDER_ID()) {
            vm.expectRevert();
        }
        membership.mintWithDonationRequestNetwork{value: price}(
            buyer, address(0), new bytes(1), new bytes(1), new bytes(2), new bytes(3)
        );
        // test it does not work without right amount
        vm.expectRevert();
        membership.mintWithDonationRequestNetwork{value: 1}(
            buyer, address(0), new bytes(1), new bytes(1), new bytes(2), new bytes(3)
        );
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();
    }

    function testAmbassadorReferrer(uint8 _tier) public {
        vm.assume(_tier < asc.STAKEHOLDER_ID());
        uint256 tier = bound(_tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        AnimalSocialClubERC721 membership = asc.contracts(tier);
        // Buyer mints an Elephant with Ambassador as referrer
        vm.deal(buyer, 1000 ether);
        vm.startPrank(buyer);
        uint256 price = membership.PRICE();
        if (tier == asc.STAKEHOLDER_ID()) {
            vm.expectRevert();
        }
        membership.mintWithDonationRequestNetwork{value: price}(
            buyer, ambassador, new bytes(1), new bytes(1), new bytes(2), new bytes(3)
        );
        // test it does not work without right amount
        vm.expectRevert();
        membership.mintWithDonationRequestNetwork{value: 1}(
            buyer, ambassador, new bytes(1), new bytes(1), new bytes(2), new bytes(3)
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

    function testAdvocateReferrer(uint8 _tier) public {
        vm.assume(_tier < asc.STAKEHOLDER_ID());
        uint256 tier = bound(_tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        AnimalSocialClubERC721 membership = asc.contracts(tier);
        // Buyer mints an Elephant with Advocate as referrer
        vm.deal(buyer, 1000 ether);
        vm.startPrank(buyer);
        uint256 price = membership.PRICE();
        if (tier == asc.STAKEHOLDER_ID()) {
            vm.expectRevert();
        }
        membership.mintWithDonationRequestNetwork{value: price}(
            buyer, advocate, new bytes(1), new bytes(1), new bytes(2), new bytes(3)
        );
        // test it does not work without right amount
        vm.expectRevert();
        membership.mintWithDonationRequestNetwork{value: 1}(
            buyer, advocate, new bytes(1), new bytes(1), new bytes(2), new bytes(3)
        );
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        uint256 totalCommission = (membership.PRICE() * 10) / 100;
        uint256 expectedAmbassadorCommission = (totalCommission * 40) / 100;
        uint256 expectedAdvocateCommission = (totalCommission * 60) / 100;

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

    function testEvangelistReferrer(uint8 _tier) public {
        vm.assume(_tier < asc.STAKEHOLDER_ID());
        uint256 tier = bound(_tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        AnimalSocialClubERC721 membership = asc.contracts(tier);
        // Buyer mints an Elephant with Advocate as referrer
        vm.deal(buyer, 1000 ether);
        vm.startPrank(buyer);
        uint256 price = membership.PRICE();
        if (tier == asc.STAKEHOLDER_ID()) {
            vm.expectRevert();
        }
        membership.mintWithDonationRequestNetwork{value: price}(
            buyer, evangelist, new bytes(1), new bytes(1), new bytes(2), new bytes(3)
        );
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        uint256 totalCommission = (membership.PRICE() * 10) / 100;
        uint256 expectedAmbassadorCommission = (totalCommission * 40) / 100;
        uint256 expectedAdvocateCommission = (totalCommission * 30) / 100;
        uint256 expectedEvangelistCommission = (totalCommission * 30) / 100;

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

    function testLottery() public {
        vm.deal(adminAddress, 100 ether);
        vm.startPrank(adminAddress);
        uint256 requestId = asc.startLottery{value: 1 ether}();
        console.log("lottery started");
        vm.stopPrank();
    }
}
