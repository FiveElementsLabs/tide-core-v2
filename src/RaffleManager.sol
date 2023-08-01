//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../lib/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import {IWaveFactory} from "./interfaces/IWaveFactory.sol";

contract RaffleManager is RrpRequesterV0 {
    event RequestedUint256Array(bytes32 indexed requestId, uint256 size);
    event ReceivedUint256Array(bytes32 indexed requestId, uint256[] response);

    // These variables can also be declared as `constant`/`immutable`.
    // However, this would mean that they would not be updatable.
    // Since it is impossible to ensure that a particular Airnode will be
    // indefinitely available, you are recommended to always implement a way
    // to update these parameters.
    address public airnode = 0x6238772544f029ecaBfDED4300f13A3c4FE84E1D;
    bytes32 public endpointIdUint256Array = 0x27cc2713e7f968e4e86ed274a051a5c8aaee9cca66946f23af6f29ecea9704c3;
    address public sponsorWallet;
    uint256[] public qrngUint256Array;

    IWaveFactory public waveFactory;

    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;

    modifier onlyGovernance() {
        require(msg.sender == waveFactory.keeper(), "Only governance can call this function.");
        _;
    }

    /// @dev RrpRequester sponsors itself, meaning that it can make requests
    /// that will be fulfilled by its sponsor wallet. See the Airnode protocol
    /// docs about sponsorship for more information.
    /// @param _airnodeRrp Airnode RRP contract address
    constructor(address _airnodeRrp, IWaveFactory _waveFactory) RrpRequesterV0(_airnodeRrp) {
        waveFactory = _waveFactory;
    }

    /// @notice Sets parameters used in requesting QRNG services
    /// @param _airnode Airnode address
    /// @param _endpointIdUint256Array Endpoint ID used to request a `uint256[]`
    /// @param _sponsorWallet Sponsor wallet address
    function setRequestParameters(address _airnode, bytes32 _endpointIdUint256Array, address _sponsorWallet)
        external
        onlyGovernance
    {
        airnode = _airnode;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    /// @notice Requests a `uint256[]`
    /// @param size Size of the requested array
    function makeRequestUint256Array(uint256 size) external {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
            // Using Airnode ABI to encode the parameters
            abi.encode(bytes32("1u"), bytes32("size"), size)
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedUint256Array(requestId, size);
    }

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @param requestId Request ID
    /// @param data ABI-encoded response
    function fulfillUint256Array(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp {
        require(expectingRequestWithIdToBeFulfilled[requestId], "Request ID not known");
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256[] memory _qrngUint256Array = abi.decode(data, (uint256[]));
        // Do what you want with `qrngUint256Array` here...
        qrngUint256Array = _qrngUint256Array;
        emit ReceivedUint256Array(requestId, qrngUint256Array);
    }

    function getRandomNumberArray() public view returns (uint256[] memory) {
        return qrngUint256Array;
    }
}
