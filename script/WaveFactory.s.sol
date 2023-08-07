// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {WaveFactory} from "src/WaveFactory.sol";

contract WaveScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new WaveFactory(
            vm.addr(deployerPrivateKey),
            0x8f5B08237d9aaf212a6ABeF3379149765dEE9C10,
            0x75d14F0Ae59003C0806B625B402a40340Ffde634,
            address(0)
        );

        vm.stopBroadcast();
    }
}
