// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console2.sol";
import "lib/forge-std/src/StdUtils.sol";
import "src/WaveContract.sol";
import "src/WaveFactory.sol";
import "src/interfaces/IWaveFactory.sol";
import "./mocked/MockedERC20.sol";

contract WaveTest is Test {
    WaveFactory _factory;
    WaveContract _wave;
    MockedERC20 DAI;

    uint256 constant CAMPAIGN_DURATION = 100;

    error CampaignNotEnded();

    function setUp() public {
        _factory = new WaveFactory(address(this), address(0), address(this));
        DAI = new MockedERC20("DAI", "DAI");
        DAI.mint(address(this), 1 ether);
    }

    function test_WithoutErc20Rewards() public {
        IWaveFactory.TokenReward[] memory tokenRewards;
        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + CAMPAIGN_DURATION, false, tokenRewards
        );
        _wave = WaveContract(_factory.waves(0));
    }

    function test_InitiateRewards() public {
        IWaveFactory.TokenReward[] memory tokenRewards = new IWaveFactory.TokenReward[](1);
        uint256 rewardsCount = 10;
        uint256 amount = 20;
        tokenRewards[0] = IWaveFactory.TokenReward(rewardsCount, amount, address(DAI), false);
        DAI.approve(address(_factory), 1 ether);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + CAMPAIGN_DURATION, false, tokenRewards
        );
        _wave = WaveContract(_factory.waves(0));
        assertEq(DAI.balanceOf(address(_wave)), amount);
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
}
