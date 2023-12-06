//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Dynamic721} from "./Dynamic721.sol";

contract Factory is Ownable {
    address[] public nfts;
    address public trustedForwarder;

    event Created(address nft, address deployer, string name);

    constructor(address _trustedForwarder) Ownable() {
        trustedForwarder = _trustedForwarder;
    }

    function setTrustedForwarder(address _trustedForwarder) public onlyOwner {
        trustedForwarder = _trustedForwarder;
    }

    function create(string memory _name, string memory _symbol, string memory _baseURI) public returns (address) {
        Dynamic721 nft = new Dynamic721(_name, _symbol, _baseURI, trustedForwarder);

        address deploymentAddress = address(nft);
        nfts.push(deploymentAddress);
        emit Created(deploymentAddress, _msgSender(), _name);
        return deploymentAddress;
    }
}
