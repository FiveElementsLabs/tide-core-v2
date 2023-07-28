// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

interface IWaveFactory {
    struct TokenRewards {
        uint256 rewardsLeft;
        uint256 amountPerUser;
        address token;
        bool isRaffle;
    }

    function deployWave(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        bool _isSoulbound,
        TokenRewards[] memory _tokenRewards
    ) external;

    function keeper() external view returns (address);

    function verifier() external view returns (address);
}
