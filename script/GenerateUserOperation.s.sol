// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {SimpleAccount} from "src/SimpleAccount.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GenerateUserOperation is Script {
    function run() external {}

    function generateUserOperation(Account calldata user, address simpleAccount, EntryPoint entryPoint, uint256 nonce)
        public
        view
        returns (PackedUserOperation memory, bytes32)
    {
        // generate calldata
        bytes memory callData = abi.encodeWithSelector(SimpleAccount.execute.selector, address(0), 1 ether, "");

        // gas variables
        uint256 gasLimit = type(uint24).max;
        uint256 verificationGasLimit = type(uint24).max;

        bytes32 accountGasLimits = bytes32(verificationGasLimit << 128 | gasLimit);

        uint256 preVerificationGas = type(uint24).max;

        uint256 maxFeePerGas = type(uint8).max;
        uint256 maxPriorityFeePerGas = type(uint8).max;

        bytes32 gasFees = bytes32(maxPriorityFeePerGas << 128 | maxFeePerGas);

        // generate user operation
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: simpleAccount,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: accountGasLimits,
            preVerificationGas: preVerificationGas,
            gasFees: gasFees,
            paymasterAndData: hex"",
            signature: hex""
        });

        // get user operation hash
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        // sign user operation
        bytes32 formattedUserOpHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.key, formattedUserOpHash);

        // signed user operation
        userOp.signature = abi.encodePacked(r, s, v);

        return (userOp, userOpHash);
    }
}
