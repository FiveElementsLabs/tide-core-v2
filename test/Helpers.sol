// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

contract Helpers {
    /// @dev Builds a prefixed hash to mimic the behavior of eth_sign.
    /// @param hash The hash to prefix
    /// @return bytes32 The prefixed hash
    function _prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
