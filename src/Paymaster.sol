// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/core/Helpers.sol";

import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract Paymaster is BasePaymaster {
    // mapping to address for whom the paymaster is willing to pay
    mapping(address => bool) private whitelist;

    // constructor takes entrypoint as an argument
    constructor(IEntryPoint entryPoint) BasePaymaster(entryPoint) {}

    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32, /*userOpHash*/ uint256 /*maxCost*/ )
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        address user = userOp.sender;

        context = hex"";

        if (whitelist[user]) {
            validationData = SIG_VALIDATION_SUCCESS;
            return (context, validationData);
        } else {
            validationData = SIG_VALIDATION_FAILED;
            return (context, validationData);
        }
    }

    // allows owner to add address to whitelist
    function addAddress(address user) external onlyOwner {
        whitelist[user] = true;
    }

    // allows owner to remove address to whitelist
    function removeAddress(address user) external onlyOwner {
        whitelist[user] = false;
    }

    // allows anyone to see if address is whitelisted or not
    function checkWhitelist(address user) external view returns (bool) {
        return whitelist[user];
    }
}
