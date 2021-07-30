// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Test {
    
    mapping(address => bool) public signers; //adresses that can call sign functions
    
    modifier factoryIndexCheck(uint8 _index){
        require(_index == 0 || _index == 1, "Invalid index");
        _;
    }

    function getEncoded(address token, address sender, uint256 amount, uint256 timestamp) external returns (bytes memory) {
        bytes memory encoded = abi.encodePacked(
                    token,
                    sender,
                    amount,
                    timestamp
                );

        return encoded;
    }
    
    function _verifySigner(bytes32 data, bytes memory signature, uint8 _index)
        public
        view
        factoryIndexCheck(_index)
        returns (bool)
    {
        address messageSigner =
            ECDSA.recover(data, signature);
        require(
            isSigner(messageSigner),
            "Unauthorised signer"
        );
        return true;
    }
    
    function addOrRemoveSigner(address _address, bool _canSign) external {
        signers[_address] = _canSign;
    }
    
    function isSigner(address _address) public view returns (bool) {
        return signers[_address];
    }
}