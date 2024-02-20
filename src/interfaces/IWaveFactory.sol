// SPDX-License-Identifier: GPL-2.0
pragma solidity 0.8.21;
pragma abicoder v2;

interface IWaveFactory {
    struct TokenRewards {
        uint256 rewardsLeft;
        uint256 amountPerUser;
        address token;
        bool isRaffle;
    }

    /// @notice deploys a new campaign
    /// @param _name name of the campaign
    /// @param _symbol symbol of the campaign
    /// @param _baseURI base URI of the ERC-721 metadata
    /// @param _startTimestamp start timestamp of the campaign
    /// @param _endTimestamp end timestamp of the campaign
    /// @param _isSoulbound whether the wave badges will be soulbound
    /// @param _tokenRewards rewards in ERC20 tokens
    function deployWave(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        bool _isSoulbound,
        IWaveFactory.TokenRewards memory _tokenRewards
    ) external;

    function keeper() external view returns (address);

    function verifier() external view returns (address);

    function raffleManager() external view returns (address);

    function isRaffleWave(address) external view returns (bool);
}
