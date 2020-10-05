// SPDX-License-Identifier: MIT
// started from https://solidity-by-example.org/0.6/app/multi-sig-wallet/ and cleaned out a bunch of stuff
// grabbed recover stuff from bouncer-proxy: https://github.com/austintgriffith/bouncer-proxy/blob/master/BouncerProxy/BouncerProxy.sol
pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

contract MetaMultiSigWallet {
    event Deposit(address indexed sender, uint amount, uint balance);
    event ExecuteTransaction( address indexed owner, address payable to, uint256 value, bytes data, bytes result);
    event Owner( address indexed owner, bool added);

    mapping(address => bool) public isOwner;
    uint public signaturesRequired;
    uint public nonce;

    constructor(address[] memory _owners, uint _signaturesRequired) public {
        signaturesRequired = _signaturesRequired;
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner!=address(0), "constructor: zero address");
            require(!isOwner[owner], "constructor: owner not unique");
            isOwner[owner] = true;
            emit Owner(owner,isOwner[owner]);
        }
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Not Self");
        _;
    }

    function addSigner(address newSigner, uint256 newSignaturesRequired) public onlySelf {
        require(newSigner!=address(0), "addSigner: zero address");
        require(!isOwner[newSigner], "addSigner: owner not unique");
        isOwner[newSigner] = true;
        signaturesRequired = newSignaturesRequired;
        emit Owner(newSigner,isOwner[newSigner]);
    }

    function removeSigner(address oldSigner, uint256 newSignaturesRequired) public onlySelf {
        require(isOwner[oldSigner], "addSigner: not owner");
        isOwner[oldSigner] = false;
        signaturesRequired = newSignaturesRequired;
        emit Owner(oldSigner,isOwner[oldSigner]);
    }

    function updateSignaturesRequired(uint256 newSignaturesRequired) public onlySelf {
        signaturesRequired = newSignaturesRequired;
    }

    function getTransactionHash( address to, uint256 value, bytes memory data ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this),nonce,to,value,data));
    }

    function executeTransaction( address payable to, uint256 value, bytes memory data, bytes[] memory signatures)
        public
    {
        bytes32 _hash =  getTransactionHash(to, value, data);
        uint256 validSignatures;
        for (uint i = 0; i < signatures.length; i++) {
            if(isOwner[recover(_hash,signatures[i])]){
              validSignatures++;
            }
        }

        require(validSignatures>=signaturesRequired, "executeTransaction: not enough valid signatures");        

        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, "executeTransaction: tx failed");

        emit ExecuteTransaction(msg.sender, to, value, data, result);
    }

    function recover(bytes32 _hash, bytes memory _signature) public pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        // Divide the signature in r, s and v variables (spends extra gas, you could split off-chain)
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
        return ecrecover(keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)
        ), v, r, s);
    }

    receive() payable external {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

}