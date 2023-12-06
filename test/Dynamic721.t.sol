// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.21;
pragma abicoder v2;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../lib/forge-std/src/StdUtils.sol";
import "../src/dNft/Dynamic721.sol";

contract Dynamic721Test is Test {
    Dynamic721 nft;
    string baseUri = "https://myUrl.com/api";

    error AlreadyClaimed();
    error OnlyGovernance();

    function setUp() public {
        nft = new Dynamic721("name", "SMB", baseUri, vm.addr(3), vm.addr(4));
    }

    function test_CheckUri() public {
        vm.prank(vm.addr(1001));
        nft.claim();

        uint256 tokenId = nft.lastId();
        console.logString(nft.tokenURI(tokenId));
    }

    function test_multipleClaims() public {
        vm.startPrank(vm.addr(1002));
        nft.claim();

        vm.expectRevert(AlreadyClaimed.selector);
        nft.claim();
        vm.stopPrank();
    }

    function test_baseUriUpdate() public {
        vm.prank(vm.addr(1003));
        vm.expectRevert("Ownable: caller is not the owner");
        nft.setBaseURI("https://scam.it");

        address owner = nft.owner();
        vm.prank(owner);
        nft.setBaseURI("https://mynewsite.com/api");
    }
}
