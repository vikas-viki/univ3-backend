// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

library TestUtils{
    function encodeError(string memory _error) internal pure returns(bytes memory){
        return abi.encodeWithSignature(_error);
    }
}