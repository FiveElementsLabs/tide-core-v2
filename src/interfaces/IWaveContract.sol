// SPDX-License-Identifier: GPL-2.0
pragma solidity 0.8.21;
pragma abicoder v2;

interface IWaveContract {
    /// @notice Allows the governance to set metadata base URI for all tokens
    /// @param _uri The base URI to set
    /// @param _customMetadata Whether the metadata is encoded with tokenId
    function changeBaseURI(string memory _uri, bool _customMetadata) external;

    /// @notice Allows the owner to set the campaign start timestamp
    function setStartTimestamp(uint256 _startTimestamp) external;

    /// @notice Allows the governance to set the campaign end timestamp
    function setEndTimestamp(uint256 _endTimestamp) external;

    /// @notice Allows the owner to end the campaign early
    function endCampaign() external;

    /// @notice Allows to withdraw funds if certain conditions are met
    function withdrawFunds() external;

    /// @notice Execute the mint with permit by verifying the off-chain verifier signature
    /// @param deadline The deadline for the permit
    /// @param v The v component of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    function claim(uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /// @notice sends a request for random numbers to the raffle manager
    function startRaffle() external;

    /// @notice saves the random number in the contract storage
    /// @param randomNumber the random number to use for the raffle
    function fulfillRaffle(uint256 randomNumber) external;

    /// @notice execute the raffle using the saved random number
    /// and emitting the tokens. Then, returns the remaining funds for raffle rewards
    /// to the owner
    /// @dev the set of winning token ids per reward is generated by the single
    /// random number previously provided by the raffle manager
    function executeRaffle() external;
}
