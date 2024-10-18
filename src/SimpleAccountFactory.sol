// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Create2.sol";
import {SimpleAccount} from "src/SimpleAccount.sol";

contract SimpleAccountFactory {
    function createAccount(address entryPoint, address owner, bytes32 salt)
        public
        returns (address simpleAccountAddress)
    {
        bytes memory creationCode = abi.encodePacked(type(SimpleAccount).creationCode, abi.encode(entryPoint, owner));
        simpleAccountAddress = Create2.deploy(0, salt, creationCode);
    }

    function getAccountAddress(bytes32 salt, bytes32 byteCodeHash) public view returns (address) {
        return Create2.computeAddress(salt, byteCodeHash);
    }
}
