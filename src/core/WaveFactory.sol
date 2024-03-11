// SPDX-License-Identifier: GPL-2.0
pragma solidity 0.8.21;
pragma abicoder v2;

import {Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {WaveContract} from "./WaveContract.sol";
import {IWaveFactory} from "../interfaces/IWaveFactory.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract WaveFactory is Ownable2Step, IWaveFactory {
    address[] public waves;
    address public keeper;
    address public trustedForwarder;
    address public verifier;
    address public raffleManager;
    mapping(address => bool) public isRaffleWave;

    error TooManyRewards();

    event WaveCreated(address indexed wave, address indexed owner);

    constructor(address _keeper, address _trustedForwarder, address _verifier, address _raffleManager) Ownable2Step() {
        keeper = _keeper;
        trustedForwarder = _trustedForwarder;
        verifier = _verifier;
        raffleManager = _raffleManager;
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

    /// @dev changes the raffle manager for the factory
    /// @param _raffleManager address of the new raffle manager
    function changeRaffleManager(address _raffleManager) public onlyOwner {
        raffleManager = _raffleManager;
    }

    /// @inheritdoc IWaveFactory
    function deployWave(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        bool _isSoulbound,
        IWaveFactory.TokenRewards memory _tokenRewards
    ) public {
        WaveContract wave = new WaveContract(
            _name, _symbol, _baseURI, _startTimestamp, _endTimestamp, _isSoulbound, trustedForwarder, _tokenRewards
        );

        waves.push(address(wave));
        wave.transferOwnership(msg.sender);

        if (_tokenRewards.isRaffle) {
            isRaffleWave[address(wave)] = true;
        }

        if (_tokenRewards.token != address(0)) {
            _initiateRewards(_tokenRewards, address(wave));
        }

        emit WaveCreated(address(wave), msg.sender);
    }

    /// @notice funds the campaign with the specified token rewards
    /// @param _tokenRewards array of token rewards
    /// @param wave address of the campaign
    function _initiateRewards(IWaveFactory.TokenRewards memory _tokenRewards, address wave) internal {
        IERC20(_tokenRewards.token).transferFrom(
            msg.sender, wave, _tokenRewards.amountPerUser * _tokenRewards.rewardsLeft
        );
    }
}
