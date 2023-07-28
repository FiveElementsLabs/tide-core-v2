// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC2771Context, Context} from "lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {IWaveFactory} from "./interfaces/IWaveFactory.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract WaveContract is ERC2771Context, Ownable, ERC721 {
    IWaveFactory public factory;

    uint256 public lastId;
    uint256 public startTimestamp;
    uint256 public endTimestamp;

    string _metadataBaseURI;
    bool public customMetadata;
    bool public isSoulbound;
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public immutable PERMIT_TYPEHASH;

    mapping(bytes32 => bool) _claimed;
    mapping(uint256 => uint256) public tokenIdToRewardId;
    IWaveFactory.TokenReward[] public tokenRewards;

    struct ClaimParams {
        uint256 rewardId;
        address user;
    }

    struct Permit {
        address spender;
        uint256 rewardId;
        uint256 deadline;
    }

    struct TokenReward {
        uint256 count;
        uint256 amount;
        address token;
        bool isRaffle;
    }

    error OnlyGovernance();
    error InvalidTimings();
    error InvalidSignature();
    error CampaignNotActive();
    error CampaignNotEnded();
    error RewardAlreadyClaimed();
    error PermitDeadlineExpired();
    error NotTransferrable();

    event Claimed(address indexed user, uint256 indexed tokenId, uint256 rewardId);

    // @dev remove this event when done debugging
    event Debug(string message, uint256 param);

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
        IWaveFactory.TokenReward[] memory _tokenRewards
    ) ERC2771Context(_trustedForwarder) Ownable() ERC721(_name, _symbol) {
        if (_startTimestamp > _endTimestamp || _endTimestamp < block.timestamp) {
            revert InvalidTimings();
        }

        factory = IWaveFactory(_msgSender());
        _metadataBaseURI = _uri;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        isSoulbound = _isSoulbound;

        DOMAIN_SEPARATOR = _computeDomainSeparator();
        PERMIT_TYPEHASH = keccak256("Permit(address spender,uint256 rewardId,uint256 deadline)");

        uint8 len = uint8(_tokenRewards.length);
        for (uint8 i = 0; i < len; ++i) {
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
    function endCampaign() public onlyOwner onlyActive {
        endTimestamp = block.timestamp;
        // call raffle function
        withdrawRemainingFunds();
    }

    /// @notice Allows the owner to withdraw remaining funds after the campaign has ended
    function withdrawRemainingFunds() public onlyOwner onlyEnded {
        //check that all rewards have been awarded
        //otherwise, revert

        uint8 len = uint8(tokenRewards.length);

        for (uint8 i = 0; i < len; ++i) {
            IWaveFactory.TokenReward memory tokenReward = tokenRewards[i];
            IERC20 token = IERC20(tokenReward.token);
            uint256 balance = token.balanceOf(address(this));

            if (balance != 0) {
                token.transferFrom(address(this), owner(), balance);
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

        bytes32 typedDataHash = getTypedDataHash(Permit(_msgSender(), rewardId, deadline));
        address recoveredAddress = ecrecover(_prefixed(typedDataHash), v, r, s);

        if (recoveredAddress == address(0) || recoveredAddress != factory.verifier()) revert InvalidSignature();

        _mintReward(_msgSender(), rewardId);
    }

    /// @dev computes the hash of the fully encoded EIP-712 message for the domain,
    /// which can be used to recover the signer
    /// @param _permit The permit struct
    /// @return bytes32 The hash of the fully encoded EIP-712 message for the domain
    function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _getStructHash(_permit)));
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

    /// @dev returns the domain separator for the contract
    /// @return bytes32 The domain separator for the contract
    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @dev computes the hash of a permit struct
    /// @param _permit The permit struct
    /// @return bytes32 The hash of the permit struct
    function _getStructHash(Permit memory _permit) internal view returns (bytes32) {
        return keccak256(abi.encode(PERMIT_TYPEHASH, _permit.spender, _permit.rewardId, _permit.deadline));
    }

    /// @dev Builds a prefixed hash to mimic the behavior of eth_sign.
    /// @param hash The hash to prefix
    /// @return bytes32 The prefixed hash
    function _prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
