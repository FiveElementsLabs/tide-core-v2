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
    address immutable verifier = vm.addr(VERIFIER_PRIVATE_KEY);
    address immutable alice = vm.addr(1);
    address immutable bob = vm.addr(2);
    address immutable charlie = vm.addr(3);
    address immutable dave = vm.addr(4);

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
    }

    function test_WithoutErc20Rewards() public {
        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, claimRewards, raffleRewards
        );
        _FCFSWave = WaveContract(_factory.waves(0));
    }

    function test_InitiateClaimRewards() public {
        claimRewards.push(IWaveFactory.TokenRewards(REWARDS_COUNT, REWARD_AMOUNT_PER_USER, address(DAI)));
        DAI.approve(address(_factory), 1 ether);
        WETH.approve(address(_factory), 1 ether);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, claimRewards, raffleRewards
        );
        _FCFSWave = WaveContract(_factory.waves(0));
        assertEq(DAI.balanceOf(address(_FCFSWave)), REWARDS_COUNT * REWARD_AMOUNT_PER_USER);
    }

    function test_InitiateRaffleRewards() public {
        raffleRewards.push(IWaveFactory.TokenRewards(REWARDS_COUNT, REWARD_AMOUNT_PER_USER, address(DAI)));
        DAI.approve(address(_factory), 1 ether);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, claimRewards, raffleRewards
        );
        _raffleWave = WaveContract(_factory.waves(0));
        assertEq(DAI.balanceOf(address(_raffleWave)), REWARDS_COUNT * REWARD_AMOUNT_PER_USER);
    }

    function test_claimWithReward() public {
        test_InitiateClaimRewards();

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
        test_InitiateRaffleRewards();

        _claim(alice, _raffleWave, bytes4(0));
        _claim(bob, _raffleWave, bytes4(0));
        _claim(charlie, _raffleWave, bytes4(0));
        _claim(dave, _raffleWave, bytes4(0));

        vm.expectRevert(CampaignNotEnded.selector);
        _raffleWave.startRaffle();

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _raffleWave.startRaffle();

        _mockedAirnodeRNG.fulfillRequest();

        assertEq(
            DAI.balanceOf(alice) + DAI.balanceOf(bob) + DAI.balanceOf(charlie) + DAI.balanceOf(dave),
            REWARD_AMOUNT_PER_USER * REWARDS_COUNT
        );
    }

    function test_EndCampaignNoMints() public {
        test_InitiateClaimRewards();
        assertEq(_FCFSWave.owner(), address(this));
        _FCFSWave.endCampaign();
        assertEq(DAI.balanceOf(address(_FCFSWave)), 0);
        assertEq(DAI.balanceOf(_FCFSWave.owner()), 1 ether);
    }

    function test_WithdrawOnlyAfterCampaignEnd() public {
        test_InitiateClaimRewards();

        vm.expectRevert(CampaignNotEnded.selector);
        _FCFSWave.withdrawRemainingFunds();

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _FCFSWave.withdrawRemainingFunds();
        assertEq(DAI.balanceOf(address(_FCFSWave)), 0);
        assertEq(DAI.balanceOf(_FCFSWave.owner()), 1 ether);
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
