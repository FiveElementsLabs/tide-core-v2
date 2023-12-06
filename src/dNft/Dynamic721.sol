//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ERC2771Context, Context} from "lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Dynamic721 is ERC2771Context, ERC721, Ownable {
    using Strings for uint256;
    using Strings for address;

    uint256 public lastId;
    string baseURI;
    mapping(address => bool) claimed;

    event Claimed(address user, uint256 tokenId);

    error AlreadyClaimed();

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _trustedForwarder,
        address _owner
    ) ERC2771Context(_trustedForwarder) ERC721(_name, _symbol) Ownable() {
        baseURI = _baseURI;
        _transferOwnership(_owner);
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        return bytes(baseURI).length > 0
            ? string(
                abi.encodePacked(
                    baseURI,
                    "/",
                    uint256(block.chainid).toString(),
                    "/",
                    address(this).toHexString(),
                    "/",
                    tokenId.toString()
                )
            )
            : "";
    }

    function claim() public {
        address msgSender = _msgSender();
        if (claimed[msgSender] == true) revert AlreadyClaimed();

        lastId++;
        _safeMint(msgSender, lastId);
        claimed[msgSender] = true;

        emit Claimed(msgSender, lastId);
    }

    ///@dev use ERC2771Context to get msg data
    ///@return bytes calldata
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    ///@dev use ERC2771Context to get msg sender
    ///@return address sender
    function _msgSender() internal view override(ERC2771Context, Context) returns (address) {
        return ERC2771Context._msgSender();
    }
}
