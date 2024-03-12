// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {WaveFactory} from "../src/core/WaveFactory.sol";
import {RaffleManager} from "../src/core/RaffleManager.sol";
import {IAirnodeRrpV0} from "../lib/airnode/packages/airnode-protocol/contracts/rrp/interfaces/IAirnodeRrpV0.sol";

contract DeployPipeline is Script {
    address polygonTrustedForwarder = 0xafA1853E44e547F1A9770Fd37c4556b4Faf54674;
    address verifier = 0x75d14F0Ae59003C0806B625B402a40340Ffde634;
    address airnode = 0x224e030f03Cd3440D88BD78C9BF5Ed36458A1A25;
    bytes32 endpointIdUint256 = 0xffd1bbe880e7b2c662f6c8511b15ff22d12a4a35d5c8c17202893a5f10e25284;
    address sponsorWallet = 0x1BE092f422a936319B8FaBc3E5A992ACB79ec495;
    address airnodeRrp = 0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd;
    address arbitrumRrp = 0xb015ACeEdD478fc497A798Ab45fcED8BdEd08924;

    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function run() external {
        // load variables from envinronment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        WaveFactory factory = new WaveFactory(deployerAddress, polygonTrustedForwarder, verifier, address(0));

        address rrpAddress;
        if (getChainID() == 42161) rrpAddress = arbitrumRrp;
        else rrpAddress = airnodeRrp;

        IAirnodeRrpV0 airnodeRrpContract = IAirnodeRrpV0(rrpAddress);
        RaffleManager raffleManager = new RaffleManager(rrpAddress, factory);
        raffleManager.setRequestParameters(airnode, endpointIdUint256, deployerAddress, sponsorWallet);
        airnodeRrpContract.setSponsorshipStatus(address(raffleManager), true);

        factory.changeRaffleManager(address(raffleManager));
        vm.stopBroadcast();
    }
}
