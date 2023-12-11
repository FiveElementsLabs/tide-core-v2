//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ERC2771Context, Context} from "lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";

interface IFactory {
    function owner() external view returns (address);
}

contract Dynamic721 is ERC2771Context, ERC721 {
    using Strings for uint256;
    using Strings for address;

    uint256 public lastId;
    string baseURI;
    mapping(address => bool) claimed;
    IFactory factory;

    event Claimed(address user, uint256 tokenId);

    error AlreadyClaimed();
    error EmptyBaseUri();
    error NotTransferrable();
    error OnlyGovernance();

    constructor(string memory _name, string memory _symbol, string memory _baseURI, address _trustedForwarder)
        ERC2771Context(_trustedForwarder)
        ERC721(_name, _symbol)
    {
        if (bytes(_baseURI).length == 0) revert EmptyBaseUri();
        baseURI = _baseURI;
        factory = IFactory(_msgSender());
    }

    modifier onlyGovernance() {
        if (_msgSender() != factory.owner()) revert OnlyGovernance();
        _;
    }

    function setBaseURI(string memory _baseURI) public onlyGovernance {
        if (bytes(_baseURI).length == 0) revert EmptyBaseUri();
        baseURI = _baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        return string(
            abi.encodePacked(
                baseURI,
                "/",
                uint256(block.chainid).toString(),
                "/",
                address(this).toHexString(),
                "/",
                ownerOf(tokenId).toHexString()
            )
        );
    }

    function claim() public {
        address msgSender = _msgSender();
        if (claimed[msgSender] == true) revert AlreadyClaimed();

        lastId++;
        _safeMint(msgSender, lastId);
        claimed[msgSender] = true;

        emit Claimed(msgSender, lastId);
    }

    /// @dev override the transfer function to allow transfers only if not soulbound
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param tokenId The token ID to transfer
    function _transfer(address from, address to, uint256 tokenId) internal pure override {
        revert NotTransferrable();
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
