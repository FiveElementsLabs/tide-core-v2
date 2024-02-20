// SPDX-License-Identifier:MIT
pragma solidity 0.8.21;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Forwarder {
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        uint256 deadline;
        bytes data;
    }

    using ECDSA for bytes32;

    string public constant GENERIC_PARAMS =
        "address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data";
    string public constant ERC712_VERSION = "1";
    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));
    string public constant CONTRACT_NAME = "TideForwarder";
    
    bytes32 public domainSeparator;

    mapping(bytes32 => bool) public typeHashes;

    // Nonces of senders, used to prevent replay attacks
    mapping(address => uint256) private _nonces;

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function getNonce(address from) public view returns (uint256) {
        return _nonces[from];
    }

    constructor() public {
        string memory requestType = string(
            abi.encodePacked("ForwardRequest(", GENERIC_PARAMS, ")")
        );
        _registerRequestTypeInternal(requestType);
        _initializeDomainSeparator();
    }

    function verify(
        ForwardRequest memory req,
        bytes32 reqDomainSeparator,
        bytes32 requestTypeHash,
        bytes calldata suffixData,
        bytes calldata sig
    ) public view {
        _verifyGas(req);
        _verifyNonce(req);
        _verifyDeadline(req);
        _verifySig(req, reqDomainSeparator, requestTypeHash, suffixData, sig);
    }

    function execute(
        ForwardRequest memory req,
        bytes32 reqDomainSeparator,
        bytes32 requestTypeHash,
        bytes calldata suffixData,
        bytes calldata sig
    ) public payable returns (bool success, bytes memory ret) {
        _verifyGas(req);
        _verifyNonce(req);
        _verifyDeadline(req);
        _verifySig(req, reqDomainSeparator, requestTypeHash, suffixData, sig);
        _updateNonce(req);

        // solhint-disable-next-line avoid-low-level-calls
        (success, ret) = req.to.call{gas: req.gas, value: req.value}(
            abi.encodePacked(req.data, req.from)
        );
        if (address(this).balance > 0) {
            //can't fail: req.from signed (off-chain) the request, so it must be an EOA...
            payable(req.from).transfer(address(this).balance);
        }
        return (success, ret);
    }

    function _verifyNonce(ForwardRequest memory req) internal view {
        require(_nonces[req.from] == req.nonce, "nonce mismatch");
    }

    function _updateNonce(ForwardRequest memory req) internal {
        _nonces[req.from]++;
    }

    function _verifyGas(ForwardRequest memory req) internal view {
        uint gasForTransfer = 0;
        if (req.value != 0) {
            gasForTransfer = 40000;
        }
        require(gasleft() * 63 / 64 >= req.gas + gasForTransfer, "insufficient gas");
    }

    function _verifyDeadline(ForwardRequest memory req) internal view {
        require(block.timestamp <= req.deadline, "Expired deadline"); 
    }

    function registerRequestType(
        string calldata typeName,
        string calldata typeSuffix
    ) external {
        for (uint256 i = 0; i < bytes(typeName).length; i++) {
            bytes1 c = bytes(typeName)[i];
            require(c != "(" && c != ")", "invalid typename");
        }

        string memory requestType = string(
            abi.encodePacked(typeName, "(", GENERIC_PARAMS, ",", typeSuffix)
        );
        _registerRequestTypeInternal(requestType);
    }

    function _registerRequestTypeInternal(string memory requestType) internal {
        bytes32 requestTypehash = keccak256(bytes(requestType));
        typeHashes[requestTypehash] = true;
        emit RequestTypeRegistered(requestTypehash, string(requestType));
    }

    event RequestTypeRegistered(bytes32 indexed typeHash, string typeStr);

    function _verifySig(
        ForwardRequest memory req,
        bytes32 reqDomainSeparator,
        bytes32 requestTypeHash,
        bytes memory suffixData,
        bytes memory sig
    ) internal view {
        require(typeHashes[requestTypeHash], "invalid request typehash");
        require(reqDomainSeparator == domainSeparator, "invalid domain separator");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                reqDomainSeparator,
                keccak256(_getEncoded(req, requestTypeHash, suffixData))
            )
        );
        require(digest.recover(sig) == req.from, "signature mismatch");
    }

    function _getEncoded(
        ForwardRequest memory req,
        bytes32 requestTypeHash,
        bytes memory suffixData
    ) private pure returns (bytes memory) {
        return
            abi.encodePacked(
                requestTypeHash,
                abi.encode(
                    req.from,
                    req.to,
                    req.value,
                    req.gas,
                    req.nonce,
                    keccak256(req.data)
                ),
                suffixData
            );
    }

    function _initializeDomainSeparator() internal {
        domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(CONTRACT_NAME)),
                keccak256(bytes(ERC712_VERSION)),
                _getChainId(),
                address(this)
            )
        );
    }

    function _getChainId() internal view returns (uint256 id) {
        assembly {
            id := chainid()
        }
        return id;
    }
}
