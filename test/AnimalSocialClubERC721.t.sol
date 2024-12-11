// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AnimalSocialClubERC721.sol";
import "forge-std/console.sol";
import "src/ASC721Manager.sol";
import "src/ASCLottery.sol";
import "../src/DummyEthFeeProxy.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";

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
        lottery = new ASCLottery(
            LINK_BASE_SEPOLIA,
            VRF_WRAPPER_BASE_SEPOLIA,
            treasuryAddress
        );
        asc = new ASC721Manager(treasuryAddress, address(lottery));
        lottery.transferOwnership(address(asc));
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
                        asc.ELEPHANT_ID()
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
                        asc.SHARK_ID()
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
                        asc.EAGLE_ID()
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
                        asc.TIGER_ID()
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
                        asc.STAKEHOLDER_ID()
                    )
                )
            );

            asc.assignContracts(
                payable(elephant),
                payable(tiger),
                payable(shark),
                payable(eagle),
                payable(stakeholder)
            );
        }
        for (uint256 i = 0; i < waitlistedAddresses.length; i++) {
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
        // asc.setAmbassadorToAdvocateCommission(ambassador, 50); // 50% for this Ambassador
        // asc.setAdvocateToEvangelistCommission(advocate, 50); // 50% for this Advocate

        asc.setSaleActive(true);
        vm.stopPrank();
    }

    // function testReservedTokens() public view {
    //     assertEq(asc.uri(asc.ID_RESERVED()), "ipfs://baseURI/5.json");
    //     assertEq(asc.totalSupply(asc.ID_RESERVED()), asc.TOTAL_RESERVED()); // 250 reserved tokens
    // }

    function testAdminMint(uint8 _tier, uint8 _howMany) public {
        vm.assume(_howMany < 3 && _tier < asc.STAKEHOLDER_ID());
        uint256 tier = bound(_tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        uint256 howMany = _howMany;

        AnimalSocialClubERC721 membership = asc.contracts(tier);
        uint256 initialSupply = membership.totalSupply();

        vm.deal(user, 2000000000000 ether);
        vm.startPrank(adminAddress);

        asc.setSaleActive(true);
        for (uint256 i = 0; i < howMany; i++) {
            // mint using both methods
            asc.adminMint(user, tier);
            AnimalSocialClubERC721(asc.contracts(tier)).adminMint(user);
        }
        if (tier == asc.STAKEHOLDER_ID()) {
            return;
        }
        vm.stopPrank();

        howMany = howMany >= membership.MAX_TOKEN_SUPPLY()
            ? membership.MAX_TOKEN_SUPPLY()
            : howMany;

        assertEq(
            membership.balanceOf(user),
            howMany * 2,
            "Balance of user doesnt match expectation"
        );
        assertEq(
            membership.totalSupply(),
            initialSupply + (howMany * 2),
            "Token supply doesnt match expectation"
        );
    }

    function testMintWithDonation(uint8 _tier, uint8 _howMany) public {
        vm.assume(_howMany < 3 && _tier < asc.STAKEHOLDER_ID());
        uint256 tier = bound(_tier, asc.ELEPHANT_ID(), asc.STAKEHOLDER_ID());
        uint256 howMany = _howMany;

        AnimalSocialClubERC721 membership = asc.contracts(tier);
        uint256 ambassadorInitialBalance = ambassador.balance;
        uint256 initialSupply = membership.totalSupply();

        vm.prank(adminAddress);
        asc.setSaleActive(true);
        vm.deal(user, 2000000000000 ether);
        vm.startPrank(user);
        for (uint256 i = 0; i < howMany; i++) {
            uint256 price = membership.PRICE();
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

        howMany = howMany >= membership.MAX_TOKEN_SUPPLY()
            ? membership.MAX_TOKEN_SUPPLY()
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

    function testAuction() public {
        AnimalSocialClubERC721 tiger = asc.tiger();
        vm.prank(adminAddress);
        asc.startTigerAuction();
        vm.deal(user, 2000000000000 ether);
        vm.startPrank(user);
        tiger.placeBid{value: 3 ether}(21);
        vm.stopPrank();
    }

    // function testLottery() public {
    //     vm.startPrank(adminAddress);
    //     asc.startLottery();
    //     vm.stopPrank();
    // }
}
