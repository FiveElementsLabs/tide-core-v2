// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

interface IWaveContract {
    struct TokenReward {
        uint256 count;
        uint256 amount;
        address token;
        bool isRaffle;
    }

    /// @notice Allows the governance to set metadata base URI for all tokens
    /// @param _uri The base URI to set
    /// @param _customMetadata Whether the metadata is encoded with tokenId
    function changeBaseURI(string memory _uri, bool _customMetadata) external;

    /// @notice Allows the owner to end the campaign early
    /// and withdraw remaining funds
    function endCampaign() external;

    /// @notice Allows the owner to withdraw remaining funds after the campaign has ended
    function withdrawRemainingFunds() external;

    /// @notice Execute the mint with permit by verifying the off-chain verifier signature
    /// @param deadline The deadline for the permit
    /// @param v The v component of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    function claim(uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function startRaffle() external;

    function fulfillRaffle(uint256[] memory randomNumbers) external;
}
