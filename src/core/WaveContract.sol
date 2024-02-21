// SPDX-License-Identifier: GPL-2.0
pragma solidity 0.8.21;
pragma abicoder v2;

import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {ERC2771Context, Context} from "lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {IWaveFactory} from "../interfaces/IWaveFactory.sol";
import {IWaveContract} from "../interfaces/IWaveContract.sol";
import {IRaffleManager} from "../interfaces/IRaffleManager.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {SignatureVerifier} from "../helpers/SignatureVerifier.sol";


contract WaveContract is ERC2771Context, Ownable2Step, ERC721, SignatureVerifier, ReentrancyGuard, IWaveContract {
    using SafeERC20 for IERC20;
    
    IWaveFactory public factory;

    struct TokenRewardInfo {
        bool hasWon;
        bool hasAlreadyClaimed;
        bool isDisqualified;
    }

    uint256 public lastId;
    uint256 public startTimestamp;
    uint256 public endTimestamp;
    uint256 public deployedTimestamp;
    uint256 public mintsPerClaim = 1;
    uint256 public randomNumber;

    string _metadataBaseURI;

    bool public customMetadata;
    bool public isSoulbound;
    bool public isERC20Campaign;
    bool public raffleCompleted;
    bool public shouldVerifySignature = true;

    mapping(address => bool) _claimed;
    mapping(uint256 => TokenRewardInfo) public tokenIdToTokenRewardInfo;
    uint256 public disqualifiedTokenIdsCount;

    IWaveFactory.TokenRewards public tokenRewards;

    error OnlyRaffleFulfillers();
    error OnlyAuthorized();
    error OnlyGovernance();
    error InvalidTimings();
    error CampaignNotActive();
    error CampaignNotEnded();
    error RewardAlreadyClaimed();
    error PermitDeadlineExpired();
    error NotTransferrable();

    event Claimed(address indexed user, uint256 indexed tokenId);
    event FCFSAwarded(address indexed user, address indexed token, uint256 amount);
    event RaffleWon(address indexed user, address indexed token, uint256 amount);
    event RaffleWithdrawn(address indexed user, address indexed token, uint256 amount);
    event RaffleStarted(address indexed user);
    event RaffleCompleted();
    event CampaignForceEnded();
    event FundsWithdrawn(address indexed token, uint256 indexed amount);

    modifier onlyGovernance() {
        if (_msgSender() != factory.keeper()) {
            revert OnlyGovernance();
        }
        _;
    }

    modifier onlyAuthorized() {
        if (_msgSender() != factory.keeper() && _msgSender() != owner()) {
            revert OnlyAuthorized();
        }
        _;
    }

    modifier onlyRaffleFulfillers() {
        if (_msgSender() != factory.raffleManager() && _msgSender() != factory.keeper() && _msgSender() != owner()) {
            revert OnlyRaffleFulfillers();
        }
        _;
    }

    modifier onlyActive() {
        if (block.timestamp < startTimestamp || block.timestamp > endTimestamp) {
            revert CampaignNotActive();
        }
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
        IWaveFactory.TokenRewards memory _tokenRewards
    ) ERC2771Context(_trustedForwarder) Ownable2Step() ERC721(_name, _symbol) SignatureVerifier(_name) {
        if (_startTimestamp > _endTimestamp || _endTimestamp < block.timestamp) {
            revert InvalidTimings();
        }

        factory = IWaveFactory(_msgSender());
        _metadataBaseURI = _uri;

        if (_startTimestamp < block.timestamp) {
            startTimestamp = block.timestamp;
        } else { 
            startTimestamp = _startTimestamp;
        }
        endTimestamp = _endTimestamp;
        deployedTimestamp = block.timestamp;
        isSoulbound = _isSoulbound;
        tokenRewards = _tokenRewards;

        if (_tokenRewards.token != address(0)) isERC20Campaign = true;
    }

    /// @inheritdoc IWaveContract
    function changeBaseURI(string calldata _uri, bool _customMetadata) public onlyAuthorized {
        _metadataBaseURI = _uri;
        customMetadata = _customMetadata;
    }

    /// @inheritdoc IWaveContract
    function setStartTimestamp(uint256 _startTimestamp) public onlyAuthorized {
        require(block.timestamp < _startTimestamp && _startTimestamp < endTimestamp, "Invalid start timestamp");
        startTimestamp = _startTimestamp;
    }

    /// @inheritdoc IWaveContract
    function setEndTimestamp(uint256 _endTimestamp) public onlyAuthorized {
        /// @dev the wave should end before the contract deployment + 1 year and after the start timestamp
        require(_endTimestamp > block.timestamp && _endTimestamp > startTimestamp 
        && _endTimestamp < deployedTimestamp + 31536000, "Invalid end timestamp");
        endTimestamp = _endTimestamp;
    }

    /// @dev set the `shouldVerifySignature` boolean
    function setVerifySignature(bool _shouldVerifySignature) public onlyGovernance {
        shouldVerifySignature = _shouldVerifySignature;
    }

    /// @dev change the number of mints per claim with the specified number
    function setMintsPerClaim(uint256 _mintsPerClaim) public onlyGovernance {
        mintsPerClaim = _mintsPerClaim;
    }

    /// @inheritdoc IWaveContract
    function endCampaign() public onlyActive onlyAuthorized {
        endTimestamp = block.timestamp;
        emit CampaignForceEnded();
    }

    /// @inheritdoc IWaveContract
    function withdrawFunds() public onlyEnded {
        if (tokenRewards.isRaffle) {
            require(
                !raffleCompleted || _isGovernance(),
                "Can withdraw raffle funds only if raffle is not completed or governance requested it"
            );
        }
        _returnTokenToOwner(IERC20(tokenRewards.token));
    }

    /// @notice allow to disqualify or requalify the `tokenIds` to win raffle rewards
    /// @param tokenIds the token ids to disqualify or requalify
    /// @param areDisqualified whether `tokenIds` should be disqualified or requalified
    function qualifyTokenIds(uint256[] calldata tokenIds, bool areDisqualified) public onlyAuthorized {
        require(tokenRewards.isRaffle, "Can qualify token ids only if raffle wave");
        uint256 changedUsersCount;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenId != 0 && tokenId <= lastId, "Invalid tokenId to qualify");
            // @dev increment the counter only if
            // the tokenId is not alredy set with the right qualification
            if (tokenIdToTokenRewardInfo[tokenId].isDisqualified != areDisqualified) {
                tokenIdToTokenRewardInfo[tokenId].isDisqualified = areDisqualified;
                changedUsersCount++;
            }
        }

        disqualifiedTokenIdsCount = areDisqualified
            ? disqualifiedTokenIdsCount + changedUsersCount
            : disqualifiedTokenIdsCount - changedUsersCount;
    }

    /// @inheritdoc IWaveContract
    function claim(uint256 deadline, uint8 v, bytes32 r, bytes32 s) public virtual onlyActive {
        if (_claimed[_msgSender()]) {
            revert RewardAlreadyClaimed();
        }
        if (block.timestamp > deadline) revert PermitDeadlineExpired();

        if (shouldVerifySignature) {
            _verifySignature(_msgSender(), deadline, v, r, s, factory.verifier());
        }

        for (uint256 i = 0; i < mintsPerClaim; i++) {
            _mintBadge(_msgSender());
        }

        if (isERC20Campaign && !tokenRewards.isRaffle) {
            _emitERC20Rewards(_msgSender());
        }
    }

    /// @inheritdoc IWaveContract
    function startRaffle() public onlyEnded {
        require(!raffleCompleted, "Raffle already done");
        require(tokenRewards.isRaffle, "Not a raffle wave");

        emit RaffleStarted(_msgSender());
        address raffleManager = factory.raffleManager();
        IRaffleManager(raffleManager).makeRequestUint256();
    }

    /// @inheritdoc IWaveContract
    function fulfillRaffle(uint256 _randomNumber) public onlyEnded onlyRaffleFulfillers {
        require(randomNumber == 0, "Random number has already been extracted");
        require(_randomNumber != 0, "Random number extracted cant be 0");
        randomNumber = _randomNumber;
    }

    /// @inheritdoc IWaveContract
    function executeRaffle() public onlyEnded {
        require(!raffleCompleted, "Raffle already done");
        require(randomNumber != 0, "Random number was not extracted yet");

        uint256 rewardsLeft = tokenRewards.rewardsLeft;

        uint256 eligibleTokenIdsCount = lastId - disqualifiedTokenIdsCount;
        uint256 rewardsToAssign = eligibleTokenIdsCount < rewardsLeft ? eligibleTokenIdsCount : rewardsLeft;

        uint256 counter = 0;

        for (uint256 assigned = 0; assigned < rewardsToAssign; assigned++) {
            uint256 tokenId;
            do {
                tokenId = (uint256(keccak256(abi.encodePacked(randomNumber, counter))) % lastId) + 1;
                counter++;
                // @dev skip disqualified users
                if (tokenIdToTokenRewardInfo[tokenId].isDisqualified) continue;
            } while (tokenIdToTokenRewardInfo[tokenId].hasWon);

            emit RaffleWon(ownerOf(tokenId), tokenRewards.token, tokenRewards.amountPerUser);
            tokenIdToTokenRewardInfo[tokenId].hasWon = true;
        }

        raffleCompleted = true;
        emit RaffleCompleted();
    }

    /// @inheritdoc IWaveContract
    function withdrawTokenReward(uint256 tokenId) public onlyEnded nonReentrant { 
        require(isERC20Campaign, "Not an ERC20 campaign");
        require(raffleCompleted, "Raffle not completed yet");
        require(tokenRewards.isRaffle, "Not a raffle wave");
        require(tokenId != 0 && tokenId <= lastId, "Invalid tokenId to withdraw");
        address winner = ownerOf(tokenId);
        require(_msgSender() == winner, "Only token owner can withdraw the reward");
        require(tokenIdToTokenRewardInfo[tokenId].hasWon, "Token has not won the raffle");
        require(tokenIdToTokenRewardInfo[tokenId].hasAlreadyClaimed == false, "Token has already claimed the reward");

        address tokenAddress = tokenRewards.token;
        uint256 amountPerUser = tokenRewards.amountPerUser;
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(winner, amountPerUser);

        tokenIdToTokenRewardInfo[tokenId].hasAlreadyClaimed = true;
        emit RaffleWithdrawn(winner, tokenAddress, amountPerUser);
    }

    /// @notice returns the URI for a given token ID
    /// @param tokenId The token ID to get the URI for
    /// @return string The URI for the given token ID
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        return customMetadata
            ? string(abi.encodePacked(_metadataBaseURI, "/", Strings.toString(tokenId), ".json"))
            : string(abi.encodePacked(_metadataBaseURI, "/metadata.json"));
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
    function _mintBadge(address user) internal {
        _claimed[user] = true;
        _safeMint(user, ++lastId);
        emit Claimed(user, lastId);
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
        IERC20 token = IERC20(tokenRewards.token);
        uint256 amountPerUser = tokenRewards.amountPerUser;
        bool enoughBalance = amountPerUser <= token.balanceOf(address(this));

        if (tokenRewards.rewardsLeft != 0 && enoughBalance) {
            token.safeTransfer(claimer, amountPerUser);
            emit FCFSAwarded(claimer, tokenRewards.token, amountPerUser);
            tokenRewards.rewardsLeft--;
        }
    }

    /// @dev internal function to call when withdrawing funds after campaign is ended
    /// @param token the token address of which balance has to be returned to the owner
    function _returnTokenToOwner(IERC20 token) internal {
        uint256 balance = token.balanceOf(address(this));
        if (balance != 0) {
            token.safeTransfer(owner(), balance);
        }

        emit FundsWithdrawn(address(token), balance);
    }

    function _isGovernance() internal view returns (bool) {
        return _msgSender() == factory.keeper();
    }
}
