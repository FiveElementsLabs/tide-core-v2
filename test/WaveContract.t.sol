// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../lib/forge-std/src/StdUtils.sol";
import "../src/WaveContract.sol";
import "../src/WaveFactory.sol";
import "../src/RaffleManager.sol";
import "../src/interfaces/IWaveFactory.sol";
import "./mocked/MockedERC20.sol";
import "../src/helpers/SignatureVerifier.sol";
import "./Helpers.sol";
import "./mocked/MockedAirnodeRNG.sol";

contract WaveTest is Test, Helpers {
    WaveFactory _factory;
    RaffleManager _raffleManager;
    WaveContract _FCFSWave;
    WaveContract _raffleWave;
    MockedAirnodeRNG _mockedAirnodeRNG;
    MockedERC20 DAI;
    MockedERC20 WETH;
    IWaveFactory.TokenRewards[] claimRewards;
    IWaveFactory.TokenRewards[] raffleRewards;
    mapping(bytes32 => bool) tokenIdAndRewardIdxToHasWon;

    uint256 constant CAMPAIGN_DURATION = 100;
    uint256 constant VERIFIER_PRIVATE_KEY = 69420;
    uint256 constant REWARD_ID = 17;
    uint256 constant REWARD_AMOUNT_PER_USER = 20;
    uint256 constant REWARDS_COUNT = 2;
    uint256 constant USERS_COUNT = 100;
    address immutable verifier = vm.addr(VERIFIER_PRIVATE_KEY);
    address immutable alice = vm.addr(1000);
    address immutable bob = vm.addr(1001);
    address immutable charlie = vm.addr(1002);
    address immutable dave = vm.addr(1003);
    address[] addresses;

    error CampaignNotActive();
    error CampaignNotEnded();
    error RewardAlreadyClaimed();

    function setUp() public {
        _mockedAirnodeRNG = new MockedAirnodeRNG();
        _factory = new WaveFactory(
            address(this),
            address(0),
            verifier,
            address(0)
        );
        _raffleManager = new RaffleManager(address(_mockedAirnodeRNG), _factory);
        _factory.changeRaffleManager(address(_raffleManager));
        DAI = new MockedERC20("DAI", "DAI");
        WETH = new MockedERC20("WETH", "WETH");
        DAI.mint(address(this), 1 ether);
        WETH.mint(address(this), 1 ether);
        for (uint256 i = 1; i <= USERS_COUNT; i++) {
            addresses.push(vm.addr(i));
        }
    }

    function test_WithoutErc20Rewards() public {
        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, claimRewards, raffleRewards
        );
        _FCFSWave = WaveContract(_factory.waves(0));
    }

    function test_claimWithReward() public {
        _initiateClaimRewards(REWARDS_COUNT, REWARD_AMOUNT_PER_USER);

        _claim(alice, _FCFSWave, bytes4(0));
        assertEq(DAI.balanceOf(alice), REWARD_AMOUNT_PER_USER);

        _claim(alice, _FCFSWave, RewardAlreadyClaimed.selector);

        _claim(bob, _FCFSWave, bytes4(0));
        assertEq(DAI.balanceOf(bob), REWARD_AMOUNT_PER_USER);

        _claim(charlie, _FCFSWave, bytes4(0));
        assertEq(DAI.balanceOf(charlie), 0);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _claim(charlie, _FCFSWave, CampaignNotActive.selector);
    }

    function test_raffleWithReward() public {
        uint256 rewardsCount = 55;
        _initiateRaffleRewards(rewardsCount, REWARD_AMOUNT_PER_USER);

        vm.expectRevert(CampaignNotEnded.selector);
        _raffleWave.startRaffle();

        for (uint256 i = 0; i < addresses.length; i++) {
            _claim(addresses[i], _raffleWave, bytes4(0));
        }

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _raffleWave.startRaffle();

        _mockedAirnodeRNG.fulfillRequest();

        uint256 totalBalanceRaffled = 0;
        uint256 totalWinners = 0;

        for (uint256 i = 0; i < addresses.length; i++) {
            uint256 balance = DAI.balanceOf(addresses[i]);
            if (balance > 0) {
                totalWinners++;
                assertEq(balance, REWARD_AMOUNT_PER_USER);
                totalBalanceRaffled += balance;
            }
        }

        assertEq(totalWinners, rewardsCount);
        assertEq(totalBalanceRaffled, REWARD_AMOUNT_PER_USER * rewardsCount);
    }

    function test_EndCampaignNoMints() public {
        _initiateClaimRewards(REWARDS_COUNT, REWARD_AMOUNT_PER_USER);
        assertEq(_FCFSWave.owner(), address(this));
        _FCFSWave.endCampaign();
        assertEq(DAI.balanceOf(address(_FCFSWave)), 0);
        assertEq(DAI.balanceOf(_FCFSWave.owner()), 1 ether);
    }

    function test_WithdrawOnlyAfterCampaignEnd() public {
        _initiateClaimRewards(REWARDS_COUNT, REWARD_AMOUNT_PER_USER);

        vm.expectRevert(CampaignNotEnded.selector);
        _FCFSWave.withdrawRemainingFunds();

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _FCFSWave.withdrawRemainingFunds();
        assertEq(DAI.balanceOf(address(_FCFSWave)), 0);
        assertEq(DAI.balanceOf(_FCFSWave.owner()), 1 ether);
    }

    function _initiateClaimRewards(uint256 rewardsCount, uint256 rewardAmountPerUser) internal {
        claimRewards.push(IWaveFactory.TokenRewards(rewardsCount, rewardAmountPerUser, address(DAI)));
        DAI.approve(address(_factory), 1 ether);
        WETH.approve(address(_factory), 1 ether);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, claimRewards, raffleRewards
        );

        _FCFSWave = WaveContract(_factory.waves(0));

        assertEq(DAI.balanceOf(address(_FCFSWave)), rewardsCount * rewardAmountPerUser);
    }

    function _initiateRaffleRewards(uint256 rewardsCount, uint256 rewardAmountPerUser) internal {
        raffleRewards.push(IWaveFactory.TokenRewards(rewardsCount, rewardAmountPerUser, address(DAI)));
        DAI.approve(address(_factory), 1 ether);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, claimRewards, raffleRewards
        );
        _raffleWave = WaveContract(_factory.waves(0));
        assertEq(DAI.balanceOf(address(_raffleWave)), rewardsCount * rewardAmountPerUser);
    }

    function _claim(address user, WaveContract wave, bytes4 errorMessage) internal {
        uint256 balance = wave.balanceOf(user);
        uint256 deadline = wave.endTimestamp();
        bytes32 digest = wave.getTypedDataHash(SignatureVerifier.Permit(user, REWARD_ID, deadline));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VERIFIER_PRIVATE_KEY, _prefixed(digest));

        vm.prank(user);
        if (errorMessage != bytes4(0)) {
            vm.expectRevert(errorMessage);
        }

        wave.claim(REWARD_ID, deadline, v, r, s);

        if (errorMessage == bytes4(0)) {
            assertEq(wave.balanceOf(user), balance + 1);
        }
    }
}
