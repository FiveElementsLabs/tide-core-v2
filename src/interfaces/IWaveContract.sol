// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC2771Context, Context} from "lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {IWaveFactory} from "./IWaveFactory.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SignatureVerifier} from "../helpers/SignatureVerifier.sol";

interface IWaveContract {
    struct TokenReward {
        uint256 count;
        uint256 amount;
        address token;
        bool isRaffle;
    }

    /// @notice Allows the governance to set metadata base URI for all tokens
    /// @param _uri The base URI to set
    /// @param _customMetadata Whether the metadata is encoded with rewardId or tokenId
    function changeBaseURI(string memory _uri, bool _customMetadata) external;

    /// @notice Allows the owner to end the campaign early
    /// and withdraw remaining funds
    function endCampaign() external;

    /// @notice Allows the owner to withdraw remaining funds after the campaign has ended
    function withdrawRemainingFunds() external;

    /// @notice Execute the mint with permit by verifying the off-chain verifier signature
    /// @dev Also works with gasless EIP-2612 forwarders
    /// @param rewardId The rewardId to mint
    /// @param deadline The deadline for the permit
    /// @param v The v component of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    function claim(uint256 rewardId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function startRaffle() external;

    function fulfillRaffle() external;

    /// @notice returns the URI for a given token ID
    /// @param tokenId The token ID to get the URI for
    /// @return string The URI for the given token ID
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
