// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../lib/forge-std/src/StdUtils.sol";
import "../src/core/WaveContract.sol";
import "../src/core/WaveFactory.sol";
import "../src/gasless/Forwarder.sol";
import "../src/core/RaffleManager.sol";
import "../src/interfaces/IWaveFactory.sol";
import "./mocked/MockedERC20.sol";
import "../src/helpers/SignatureVerifier.sol";
import "./Helpers.sol";
import "./mocked/MockedAirnodeRNG.sol";

contract WaveTest is Test, Helpers {
    WaveFactory _factory;
    RaffleManager _raffleManager;
    WaveContract _wave;
    MockedAirnodeRNG _mockedAirnodeRNG;
    MockedERC20 DAI;
    MockedERC20 WETH;
    IWaveFactory.TokenRewards tokenRewards;
    mapping(bytes32 => bool) tokenIdToHasWon;

    IWaveFactory.TokenRewards EMPTY_TOKEN_REWARDS = IWaveFactory.TokenRewards(0, 0, address(0), false);

    uint256 constant CAMPAIGN_DURATION = 100;
    uint256 constant VERIFIER_PRIVATE_KEY = 69420;
    uint256 constant REWARD_AMOUNT_PER_USER = 20;
    uint256 constant REWARDS_COUNT = 2;
    address immutable verifier = vm.addr(VERIFIER_PRIVATE_KEY);
    address immutable project = vm.addr(999);
    address immutable alice = vm.addr(1000);
    address immutable bob = vm.addr(1001);
    address immutable charlie = vm.addr(1002);
    address immutable dave = vm.addr(1003);
    bytes32 immutable raffleWonTopic0 = keccak256("RaffleWon(indexed uint256,indexed address,uint256)");

    error CampaignNotActive();
    error CampaignNotEnded();
    error RewardAlreadyClaimed();

    function setUp() public {
        _mockedAirnodeRNG = new MockedAirnodeRNG();
        _factory = new WaveFactory(address(this), address(0), verifier, address(0));
        _raffleManager = new RaffleManager(address(_mockedAirnodeRNG), _factory);
        _factory.changeRaffleManager(address(_raffleManager));
        DAI = new MockedERC20("DAI", "DAI");
        WETH = new MockedERC20("WETH", "WETH");
        DAI.mint(project, 1 ether);
        WETH.mint(project, 1 ether);
    }

    function test_ClaimNoRewards() public {
        _initiateBasicWave();
        _claim(alice, _wave, bytes4(0));
    }

    function test_EndCampaign() public {
        _initiateBasicWave();
        uint256 endTimestamp = block.timestamp + CAMPAIGN_DURATION / 2;
        vm.warp(endTimestamp);

        _wave.endCampaign();
        vm.stopPrank();
        assertEq(_wave.endTimestamp(), endTimestamp);
    }

    function test_claimWithReward() public {
        _initiateFCFSWave(REWARDS_COUNT, REWARD_AMOUNT_PER_USER);

        _claim(alice, _wave, bytes4(0));
        assertEq(DAI.balanceOf(alice), REWARD_AMOUNT_PER_USER);

        _claim(alice, _wave, RewardAlreadyClaimed.selector);

        _claim(bob, _wave, bytes4(0));
        assertEq(DAI.balanceOf(bob), REWARD_AMOUNT_PER_USER);

        _claim(charlie, _wave, bytes4(0));
        assertEq(DAI.balanceOf(charlie), 0);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _claim(charlie, _wave, CampaignNotActive.selector);
    }

    function test_qualifyTokenIds_1() public {
        uint256 rewardsCount = 4;
        _initiateRaffleWave(rewardsCount, REWARD_AMOUNT_PER_USER);

        assertEq(_wave.disqualifiedTokenIdsCount(), 0);

        address[] memory addresses = new address[](20);
        for (uint256 i = 0; i < addresses.length; i++) {
            addresses[i] = vm.addr(i + 1);
            _claim(addresses[i], _wave, bytes4(0));
        }

        // disqualify address[0], address[1]
        uint256[] memory disqualifiedIds = new uint256[](2);
        disqualifiedIds[0] = 1;
        disqualifiedIds[1] = 2;
        bool areDisqualified = true;
        _wave.qualifyTokenIds(disqualifiedIds, areDisqualified);
        assertEq(_wave.disqualifiedTokenIdsCount(), 2);

        // requalify tokenId 1
        uint256[] memory requalifiedIds = new uint256[](1);
        requalifiedIds[0] = 1;
        areDisqualified = false;
        _wave.qualifyTokenIds(requalifiedIds, areDisqualified);
        assertEq(_wave.disqualifiedTokenIdsCount(), 1);

        // fulfill raffle and verify
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _wave.fulfillRaffle(1);
        assertEq(_wave.randomNumber(), 1);

        _wave.executeRaffle();
    }

    /// @dev number of claims <= number of rewards
    function test_RaffleWithRewards_1() public {
        uint256 rewardsCount = 2;
        uint256 usersCount = 1;
        _raffle(rewardsCount, usersCount);
    }

    /// @dev number of claims > number of rewards
    function test_RaffleWithRewards_2() public {
        uint256 rewardsCount = 300;
        uint256 usersCount = 10000;
        _raffle(rewardsCount, usersCount);
    }

    function test_EndCampaignNoMints() public {
        _initiateFCFSWave(REWARDS_COUNT, REWARD_AMOUNT_PER_USER);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        uint256 balance = DAI.balanceOf(_wave.owner());
        _wave.withdrawFunds();
        assertEq(DAI.balanceOf(address(_wave)), 0);
        assertEq(DAI.balanceOf(_wave.owner()) - balance, REWARDS_COUNT * REWARD_AMOUNT_PER_USER);
    }

    function test_WithdrawClaimRewardsFunds() public {
        _initiateFCFSWave(REWARDS_COUNT, REWARD_AMOUNT_PER_USER);

        vm.expectRevert(CampaignNotEnded.selector);
        _wave.withdrawFunds();

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        uint256 balance = DAI.balanceOf(_wave.owner());
        _wave.withdrawFunds();
        assertEq(DAI.balanceOf(address(_wave)), 0);
        assertEq(DAI.balanceOf(_wave.owner()) - balance, REWARDS_COUNT * REWARD_AMOUNT_PER_USER);
    }

    function test_WithdrawOnlyAfterCampaignEnd() public {
        _initiateFCFSWave(REWARDS_COUNT, REWARD_AMOUNT_PER_USER);

        vm.expectRevert(CampaignNotEnded.selector);
        _wave.withdrawFunds();

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 balance = DAI.balanceOf(_wave.owner());
        _wave.withdrawFunds();
        assertEq(DAI.balanceOf(address(_wave)), 0);
        assertEq(DAI.balanceOf(_wave.owner()) - balance, REWARDS_COUNT * REWARD_AMOUNT_PER_USER);
    }

    function test_RaffleNoMints() public {
        _initiateRaffleWave(REWARDS_COUNT, REWARD_AMOUNT_PER_USER);
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        _wave.startRaffle();
        _mockedAirnodeRNG.fulfillRequest();
        assert(_wave.randomNumber() > 0);
        _wave.executeRaffle();

        uint256 balance = DAI.balanceOf(_wave.owner());
        _wave.withdrawFunds();
        assertEq(DAI.balanceOf(address(_wave)), 0);
        assertEq(DAI.balanceOf(_wave.owner()) - balance, REWARDS_COUNT * REWARD_AMOUNT_PER_USER);
    }

    function _initiateBasicWave() internal {
        vm.startPrank(project);
        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, EMPTY_TOKEN_REWARDS
        );

        _wave = WaveContract(_factory.waves(0));
        vm.stopPrank();
    }

    function _initiateFCFSWave(uint256 rewardsCount, uint256 rewardAmountPerUser) internal {
        vm.startPrank(project);
        tokenRewards = IWaveFactory.TokenRewards(rewardsCount, rewardAmountPerUser, address(DAI), false);
        DAI.approve(address(_factory), 1 ether);
        WETH.approve(address(_factory), 1 ether);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, tokenRewards
        );

        _wave = WaveContract(_factory.waves(0));
        vm.stopPrank();

        assertEq(DAI.balanceOf(address(_wave)), rewardsCount * rewardAmountPerUser);
    }

    function _initiateRaffleWave(uint256 rewardsCount, uint256 rewardAmountPerUser) internal {
        vm.startPrank(project);
        tokenRewards = IWaveFactory.TokenRewards(rewardsCount, rewardAmountPerUser, address(DAI), true);
        DAI.approve(address(_factory), 1 ether);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, tokenRewards
        );
        _wave = WaveContract(_factory.waves(0));
        vm.stopPrank();
        assertEq(DAI.balanceOf(address(_wave)), rewardsCount * rewardAmountPerUser);
    }

    function _claim(address user, WaveContract wave, bytes4 errorMessage) internal {
        uint256 balance = wave.balanceOf(user);
        uint256 deadline = wave.endTimestamp();
        bytes32 digest = wave.getTypedDataHash(SignatureVerifier.Permit(user, deadline, address(wave)));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VERIFIER_PRIVATE_KEY, _prefixed(digest));

        vm.prank(user);
        if (errorMessage != bytes4(0)) {
            vm.expectRevert(errorMessage);
        }

        wave.claim(deadline, v, r, s);

        if (errorMessage == bytes4(0)) {
            assertEq(wave.balanceOf(user), balance + 1);
        }
    }

    function _raffle(uint256 rewardsCount, uint256 usersCount) internal {
        address[] memory addresses = new address[](usersCount);
        for (uint256 i = 0; i < usersCount; i++) {
            addresses[i] = vm.addr(i + 1);
        }

        _initiateRaffleWave(rewardsCount, REWARD_AMOUNT_PER_USER);

        vm.expectRevert(CampaignNotEnded.selector);
        _wave.startRaffle();

        for (uint256 i = 0; i < addresses.length; i++) {
            _claim(addresses[i], _wave, bytes4(0));
        }

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _wave.startRaffle();

        _mockedAirnodeRNG.fulfillRequest();
        assert(_wave.randomNumber() > 0);

        vm.recordLogs();
        _wave.executeRaffle();
        Vm.Log[] memory entries = vm.getRecordedLogs();

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] != raffleWonTopic0) continue;
            uint256 winningToken = (uint256(entries[i].topics[1]));
            address winner = _wave.ownerOf(winningToken);

            uint256 balance = DAI.balanceOf(winner);

            vm.prank(_wave.ownerOf(winningToken));
            _wave.withdrawTokenReward(winningToken);
            assertEq(DAI.balanceOf(winner), balance + REWARD_AMOUNT_PER_USER);
        }
    }
}
