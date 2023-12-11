//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IRaffleManager {
    /// @notice Sets parameters used in requesting QRNG services
    /// @param _airnode Airnode address
    /// @param _endpointIdUint256Array Endpoint ID used to request a `uint256[]`
    /// @param _sponsor address used to sponsor this requester
    /// @param _sponsorWallet Sponsor wallet address
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256Array,
        address _sponsor,
        address _sponsorWallet
    ) external;

    /// @notice Requests a `uint256`
    function makeRequestUint256() external returns (bytes32 requestId);

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @param requestId Request ID
    /// @param data ABI-encoded response
    function fulfillUint256(bytes32 requestId, bytes calldata data) external;
}
