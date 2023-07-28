// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {WaveContract} from "./WaveContract.sol";
import {IWaveFactory} from "./interfaces/IWaveFactory.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract WaveFactory is Ownable, IWaveFactory {
    address[] public waves;
    address public keeper;
    address public trustedForwarder;
    address public verifier;

    error TooManyRewards();

    event WaveCreated(address indexed wave, address indexed owner);

    constructor(address _keeper, address _trustedForwarder, address _verifier) Ownable() {
        keeper = _keeper;
        trustedForwarder = _trustedForwarder;
        verifier = _verifier;
    }

    /// @dev changes the keeper associated with the factory
    /// @param _keeper address of the new keeper
    function changeKeeper(address _keeper) public onlyOwner {
        keeper = _keeper;
    }

    /// @dev changes the trusted forwarder for EIP-2771 meta transactions
    /// @param _trustedForwarder address of the new trusted forwarder
    function changeTrustedForwarder(address _trustedForwarder) public onlyOwner {
        trustedForwarder = _trustedForwarder;
    }

    /// @dev changes the verifier for EIP-712 signatures
    /// @param _verifier address of the new verifier
    function changeVerifier(address _verifier) public onlyOwner {
        verifier = _verifier;
    }

    /// @notice deploys a new campaign
    /// @param _name name of the campaign
    /// @param _symbol symbol of the campaign
    /// @param _baseURI base URI of the ERC-721 metadata
    /// @param _startTimestamp start timestamp of the campaign
    /// @param _endTimestamp end timestamp of the campaign
    /// @param _isSoulbound whether the wave badges will be soulbound
    /// @param _tokenRewards array of token rewards
    function deployWave(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        bool _isSoulbound,
        IWaveFactory.TokenRewards[] memory _tokenRewards
    ) public override {
        WaveContract wave = new WaveContract(
            _name,
            _symbol,
            _baseURI,
            _startTimestamp,
            _endTimestamp,
            _isSoulbound,
            trustedForwarder,
            _tokenRewards
        );

        waves.push(address(wave));
        wave.transferOwnership(msg.sender);

        _initiateRewards(_tokenRewards, address(wave));

        emit WaveCreated(address(wave), msg.sender);
    }

    /// @notice funds the campaign with the specified token rewards
    /// @param _tokenRewards array of token rewards
    /// @param wave address of the campaign
    function _initiateRewards(IWaveFactory.TokenRewards[] memory _tokenRewards, address wave) internal {
        uint8 len = uint8(_tokenRewards.length);

        if (len >= 2 ** 8) {
            revert TooManyRewards();
        }

        for (uint8 i = 0; i < len; ++i) {
            IERC20(_tokenRewards[i].token).transferFrom(
                msg.sender, wave, _tokenRewards[i].amountPerUser * _tokenRewards[i].rewardsLeft
            );
        }
    }
}
