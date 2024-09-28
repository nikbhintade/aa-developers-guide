// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseAccount} from "account-abstraction/core/BaseAccount.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/core/Helpers.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SimpleAccount is BaseAccount {
    error SimpleAccount__NotFromEntryPoint();
    error SimpleAccount__CallFailed();

    IEntryPoint private immutable i_entryPoint;
    address private immutable i_owner;

    constructor(address entryPointAddress, address owner) {
        i_entryPoint = IEntryPoint(entryPointAddress);
        i_owner = owner;
    }

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        override
        returns (uint256)
    {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address messageSigner = ECDSA.recover(digest, userOp.signature);

        if (messageSigner == i_owner) {
            return SIG_VALIDATION_SUCCESS;
        } else {
            return SIG_VALIDATION_FAILED;
        }
    }

    function execute(address dest, uint256 value, bytes calldata funcCallData) external {
        _requireFromEntryPoint();
        (bool success,) = dest.call{value: value}(funcCallData);
        if (!success) {
            revert SimpleAccount__CallFailed();
        }
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return i_entryPoint;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
}
