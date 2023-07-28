// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import {Strings} from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC2771Context, Context} from "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {IWaveFactory} from "./interfaces/IWaveFactory.sol";
import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SignatureVerifier} from "./helpers/SignatureVerifier.sol";

contract WaveContract is ERC2771Context, Ownable, ERC721, SignatureVerifier {
    IWaveFactory public factory;

    uint256 public lastId;
    uint256 public startTimestamp;
    uint256 public endTimestamp;

    string _metadataBaseURI;
    bool public customMetadata;
    bool public isSoulbound;

    mapping(bytes32 => bool) _claimed;
    mapping(uint256 => uint256) public tokenIdToRewardId;
    IWaveFactory.TokenRewards[] public tokenRewards;
    uint8 public immutable rewardsLength;

    struct ClaimParams {
        uint256 rewardId;
        address user;
    }

    error OnlyGovernance();
    error InvalidTimings();
    error CampaignNotActive();
    error CampaignNotEnded();
    error RewardAlreadyClaimed();
    error PermitDeadlineExpired();
    error NotTransferrable();

    event Claimed(address indexed user, uint256 indexed tokenId, uint256 rewardId);

    modifier onlyGovernance() {
        if (_msgSender() != factory.keeper()) revert OnlyGovernance();
        _;
    }

    modifier onlyActive() {
        if (block.timestamp < startTimestamp || block.timestamp > endTimestamp) revert CampaignNotActive();
        _;
    }

    modifier onlyEnded() {
        if (block.timestamp < endTimestamp) revert CampaignNotEnded();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        bool _isSoulbound,
        address _trustedForwarder,
        IWaveFactory.TokenRewards[] memory _tokenRewards
    ) ERC2771Context(_trustedForwarder) Ownable() ERC721(_name, _symbol) SignatureVerifier(_name) {
        if (_startTimestamp > _endTimestamp || _endTimestamp < block.timestamp) {
            revert InvalidTimings();
        }

        factory = IWaveFactory(_msgSender());
        _metadataBaseURI = _uri;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        isSoulbound = _isSoulbound;

        rewardsLength = uint8(_tokenRewards.length);
        for (uint8 i = 0; i < rewardsLength; ++i) {
            tokenRewards.push(_tokenRewards[i]);
        }
    }

    /// @notice Allows the governance to set metadata base URI for all tokens
    /// @param _uri The base URI to set
    /// @param _customMetadata Whether the metadata is encoded with rewardId or tokenId
    function changeBaseURI(string memory _uri, bool _customMetadata) public onlyGovernance {
        _metadataBaseURI = _uri;
        customMetadata = _customMetadata;
    }

    /// @notice Allows the owner to end the campaign early
    /// and withdraw remaining funds
    function endCampaign() public onlyActive {
        endTimestamp = block.timestamp;
        // call raffle function
        withdrawRemainingFunds();
    }

    /// @notice Allows the owner to withdraw remaining funds after the campaign has ended
    function withdrawRemainingFunds() public onlyOwner onlyEnded {
        //check that all rewards have been awarded
        //otherwise, revert

        for (uint8 i = 0; i < rewardsLength; ++i) {
            IWaveFactory.TokenRewards memory tokenReward = tokenRewards[i];
            IERC20 token = IERC20(tokenReward.token);
            uint256 balance = token.balanceOf(address(this));

            if (balance != 0) {
                token.transfer(owner(), balance);
            }
        }
    }

    /// @notice Execute the mint with permit by verifying the off-chain verifier signature
    /// @dev Also works with gasless EIP-2612 forwarders
    /// @param rewardId The rewardId to mint
    /// @param deadline The deadline for the permit
    /// @param v The v component of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    function claim(uint256 rewardId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public virtual onlyActive {
        if (_claimed[keccak256(abi.encode(_msgSender(), rewardId))]) {
            revert RewardAlreadyClaimed();
        }
        if (block.timestamp > deadline) revert PermitDeadlineExpired();

        _verifySignature(_msgSender(), rewardId, deadline, v, r, s, factory.verifier());

        _mintReward(_msgSender(), rewardId);

        _emitERC20Rewards(_msgSender());
    }

    /// @notice returns the URI for a given token ID
    /// @param tokenId The token ID to get the URI for
    /// @return string The URI for the given token ID
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        return customMetadata
            ? string(abi.encodePacked(_metadataBaseURI, "/", Strings.toString(tokenId), ".json"))
            : string(abi.encodePacked(_metadataBaseURI, "/", Strings.toString(tokenIdToRewardId[tokenId]), ".json"));
    }

    /// @dev override the transfer function to allow transfers only if not soulbound
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param tokenId The token ID to transfer
    function _transfer(address from, address to, uint256 tokenId) internal override {
        if (isSoulbound) revert NotTransferrable();
        super._transfer(from, to, tokenId);
    }

    /// @dev internal function to mint a reward for a user
    /// @param user The user to mint the reward for
    /// @param rewardId The rewardId to mint
    function _mintReward(address user, uint256 rewardId) internal {
        _safeMint(user, ++lastId);
        tokenIdToRewardId[lastId] = rewardId;
        _claimed[keccak256(abi.encode(user, rewardId))] = true;
        emit Claimed(user, lastId, rewardId);
    }

    ///@dev use ERC2771Context to get msg data
    ///@return bytes calldata
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    ///@dev use ERC2771Context to get msg sender
    ///@return address sender
    function _msgSender() internal view override(ERC2771Context, Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    /// @dev internal function to emit the first FCFS ERC20 reward available
    /// @param claimer The address to emit the rewards to
    function _emitERC20Rewards(address claimer) internal {
        for (uint8 i = 0; i < rewardsLength; i++) {
            if (!tokenRewards[i].isRaffle && tokenRewards[i].rewardsLeft != 0) {
                IERC20(tokenRewards[i].token).transfer(claimer, tokenRewards[i].amountPerUser);
                tokenRewards[i].rewardsLeft--;
                break;
            }
        }
    }
}
