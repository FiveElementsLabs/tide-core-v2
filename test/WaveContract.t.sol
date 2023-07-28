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

    function setUp() public {
        _factory = new WaveFactory(address(this), address(this), address(this));
        DAI = new MockedERC20("DAI", "DAI");
        DAI.mint(address(this), 1000000000000000000000000000);
    }

    function test_Uno() public {
        IWaveFactory.TokenReward[] memory tokenRewards;
        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, tokenRewards
        );
        _wave = WaveContract(_factory.waves(0));
    }

    function test_InitiateRewards() public {
        IWaveFactory.TokenReward[] memory tokenRewards = new IWaveFactory.TokenReward[](1);
        uint256 rewardsCount = 10;
        uint256 amount = 20;
        tokenRewards[0] = IWaveFactory.TokenReward(rewardsCount, amount, address(DAI), false);
        DAI.approve(address(_factory), 1000000000000000000000000000);

        _factory.deployWave(
            "test", "T", "https://test.com", block.timestamp, block.timestamp + 100, false, tokenRewards
        );
        _wave = WaveContract(_factory.waves(0));
        assertEq(DAI.balanceOf(address(_wave)), amount);
    }
}
