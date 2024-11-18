// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/core/Helpers.sol";

/// @title Paymaster Contract
/// @notice This contract extends BasePaymaster and is responsible for validating user operations based on a whitelist.
contract Paymaster is BasePaymaster {
    /// @dev Stores the whitelist status of each address.
    /// Only whitelisted addresses can successfully validate operations.
    mapping(address => bool) private whitelist;

    /// @notice Initializes the Paymaster with a specified EntryPoint.
    /// @param entryPoint The EntryPoint contract address for managing user operations.
    constructor(IEntryPoint entryPoint) BasePaymaster(entryPoint) {}

    /// @inheritdoc BasePaymaster
    /// @notice Validates the user operation if the sender is whitelisted, as per ERC-4337.
    /// @param userOp The user operation that needs validation.
    /// @param userOpHash Hash of the user operation, required by ERC-4337.
    /// @param maxCost The maximum gas cost for the operation.
    /// @return context An empty bytes context as no post-operation action is needed.
    /// @return validationData The validation result, indicating success or failure based on the whitelist.
    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        (userOpHash, maxCost);
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

    /// @notice Adds a specified address to the whitelist.
    /// @dev This function can only be called by the owner.
    /// @param user The address to be added to the whitelist.
    function addAddress(address user) external onlyOwner {
        whitelist[user] = true;
    }

    /// @notice Removes a specified address from the whitelist.
    /// @dev This function can only be called by the owner.
    /// @param user The address to be removed from the whitelist.
    function removeAddress(address user) external onlyOwner {
        whitelist[user] = false;
    }

    /// @notice Checks if a specified address is whitelisted.
    /// @param user The address to check.
    /// @return True if the address is whitelisted, false otherwise.
    function checkWhitelist(address user) external view returns (bool) {
        return whitelist[user];
    }
}
