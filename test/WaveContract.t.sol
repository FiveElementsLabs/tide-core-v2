// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../lib/forge-std/src/StdUtils.sol";
import "../src/WaveContract.sol";
import "../src/WaveFactory.sol";
import "../src/interfaces/IWaveFactory.sol";
import "./mocked/MockedERC20.sol";
import "../src/helpers/SignatureVerifier.sol";
import "./Helpers.sol";

contract WaveTest is Test, Helpers {
    WaveFactory _factory;
    WaveContract _wave;
    MockedERC20 DAI;

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
        _factory = new WaveFactory(address(this), address(0), verifier, address(0));
        DAI = new MockedERC20("DAI", "DAI");
        DAI.mint(address(this), 1 ether);
    }

    function test_WithoutErc20Rewards() public {
        IWaveFactory.TokenRewards[] memory tokenRewards;
        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, tokenRewards
        );
        _wave = WaveContract(_factory.waves(0));
    }

    function test_InitiateRewards() public {
        IWaveFactory.TokenRewards[] memory tokenRewards = new IWaveFactory.TokenRewards[](1);
        tokenRewards[0] = IWaveFactory.TokenRewards(REWARDS_COUNT, REWARD_AMOUNT_PER_USER, address(DAI), false);
        DAI.approve(address(_factory), 1 ether);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, tokenRewards
        );
        _wave = WaveContract(_factory.waves(0));
        assertEq(DAI.balanceOf(address(_wave)), REWARDS_COUNT * REWARD_AMOUNT_PER_USER);
    }

    function test_claimWithReward() public {
        test_InitiateRewards();

        _claim(alice, bytes4(0));
        assertEq(DAI.balanceOf(alice), REWARD_AMOUNT_PER_USER);

        _claim(alice, RewardAlreadyClaimed.selector);

        _claim(bob, bytes4(0));
        assertEq(DAI.balanceOf(bob), REWARD_AMOUNT_PER_USER);

        _claim(charlie, bytes4(0));
        assertEq(DAI.balanceOf(charlie), 0);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _claim(charlie, CampaignNotActive.selector);
    }

    function test_EndCampaignNoMints() public {
        test_InitiateRewards();
        assertEq(_wave.owner(), address(this));
        _wave.endCampaign();
        assertEq(DAI.balanceOf(address(_wave)), 0);
        assertEq(DAI.balanceOf(_wave.owner()), 1 ether);
    }

    function test_WithdrawOnlyAfterCampaignEnd() public {
        test_InitiateRewards();

        vm.expectRevert(CampaignNotEnded.selector);
        _wave.withdrawRemainingFunds();

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        _wave.withdrawRemainingFunds();
        assertEq(DAI.balanceOf(address(_wave)), 0);
        assertEq(DAI.balanceOf(_wave.owner()), 1 ether);
    }

    function _claim(address user, bytes4 errorMessage) internal {
        uint256 balance = _wave.balanceOf(user);
        uint256 deadline = _wave.endTimestamp();
        bytes32 digest = _wave.getTypedDataHash(SignatureVerifier.Permit(user, REWARD_ID, deadline));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VERIFIER_PRIVATE_KEY, _prefixed(digest));

        vm.prank(user);
        if (errorMessage != bytes4(0)) {
            vm.expectRevert(errorMessage);
        }

        _wave.claim(REWARD_ID, deadline, v, r, s);

        if (errorMessage == bytes4(0)) {
            assertEq(_wave.balanceOf(user), balance + 1);
        }
    }
}
