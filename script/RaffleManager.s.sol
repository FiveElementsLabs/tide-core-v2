// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {RaffleManager} from "src/RaffleManager.sol";
import {IWaveFactory} from "src/interfaces/IWaveFactory.sol";

contract RaffleManagerDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new RaffleManager(
            0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd, 
            IWaveFactory(0xc9fd346E93fbE1F3ceeF4eD9EF352420c01e739E)
        );

        vm.stopBroadcast();
    }
}
