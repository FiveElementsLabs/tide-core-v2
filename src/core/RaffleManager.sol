//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "lib/airnode/packages/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import {IWaveFactory} from "../interfaces/IWaveFactory.sol";
import {IWaveContract} from "../interfaces/IWaveContract.sol";
import {IRaffleManager} from "../interfaces/IRaffleManager.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract RaffleManager is RrpRequesterV0, Ownable, IRaffleManager {
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);

    address public airnode;
    bytes32 public endpointIdUint256Array;
    address public sponsor;
    address public sponsorWallet;

    IWaveFactory public waveFactory;

    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;
    mapping(bytes32 => address) public requestToRequester;

    error OnlyRaffleWave();

    modifier onlyRaffleWave() {
        if (!waveFactory.isRaffleWave(msg.sender)) revert OnlyRaffleWave();
        _;
    }

    /// @dev RrpRequester sponsors itself, meaning that it can make requests
    /// that will be fulfilled by its sponsor wallet. See the Airnode protocol
    /// docs about sponsorship for more information.
    /// @param _airnodeRrp Airnode RRP contract address
    constructor(address _airnodeRrp, IWaveFactory _waveFactory) RrpRequesterV0(_airnodeRrp) Ownable() {
        waveFactory = _waveFactory;
    }

    /// @notice Sets parameters used in requesting QRNG services
    /// @param _airnode Airnode address
    /// @param _endpointIdUint256Array Endpoint ID used to request a `uint256[]`
    /// @param _sponsor address used to sponsor this requester
    /// @param _sponsorWallet Sponsor wallet address, used for gas by Airnode
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256Array,
        address _sponsor,
        address _sponsorWallet
    ) external onlyOwner {
        airnode = _airnode;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsor = _sponsor;
        sponsorWallet = _sponsorWallet;
    }

    /// @inheritdoc IRaffleManager
    function makeRequestUint256() external onlyRaffleWave returns (bytes32 requestId) {
        requestId = airnodeRrp.makeFullRequest(
            airnode, endpointIdUint256Array, sponsor, sponsorWallet, address(this), this.fulfillUint256.selector, ""
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        requestToRequester[requestId] = msg.sender;
        emit RequestedUint256(requestId);
    }

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @param requestId Request ID
    /// @param data ABI-encoded response
    function fulfillUint256(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp {
        require(expectingRequestWithIdToBeFulfilled[requestId], "Request ID not known");
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 qrngUint256 = abi.decode(data, (uint256));
        emit ReceivedUint256(requestId, qrngUint256);

        IWaveContract(requestToRequester[requestId]).fulfillRaffle(qrngUint256);
    }
}
