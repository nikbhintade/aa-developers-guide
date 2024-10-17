// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {SimpleAccount} from "src/SimpleAccount.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SimpleAccountIntegrationTest is Test {
    SimpleAccount private simpleAccount;
    EntryPoint private entryPoint;

    Account private owner;
    Account private bundler;

    function setUp() external {
        // set Owner
        owner = makeAccount("owner");
        bundler = makeAccount("bundler");
        // set EntryPoint
        entryPoint = new EntryPoint();
        // set SimpleAccount
        simpleAccount = new SimpleAccount(address(entryPoint), owner.addr);
    }

    function testSimpleAccountViaEntryPoint() public {
        // ARRANGE

        // 1. Add ether to the account contract
        uint256 initialBalance = 10 ether;
        vm.deal(address(simpleAccount), initialBalance);

        // 2. Construct calldata
        bytes memory callData = abi.encodeWithSelector(SimpleAccount.execute.selector, address(0), 1 ether, "");

        // 3. Set gas variables
        uint256 gasLimit = type(uint24).max;
        uint256 verificationGasLimit = type(uint24).max;

        uint256 preVerificationGas = type(uint24).max;

        uint256 maxFeePerGas = type(uint8).max;
        uint256 maxPriorityFeePerGas = type(uint8).max;

        // 4. Concatenate gas variables
        bytes32 accountGasLimits = bytes32(verificationGasLimit << 128 | gasLimit);

        bytes32 gasFees = bytes32(maxPriorityFeePerGas << 128 | maxFeePerGas);

        // 5. Generate user operation
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(simpleAccount),
            nonce: 0,
            initCode: hex"",
            callData: callData,
            accountGasLimits: accountGasLimits,
            preVerificationGas: preVerificationGas,
            gasFees: gasFees,
            paymasterAndData: hex"",
            signature: hex""
        });

        // 6. get user operation hash from entry point
        // 6. Retrieve the user operation hash from the entry point
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        // 7. Create the signature and add it to the signature field of userOp

        bytes32 formattedUserOpHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, formattedUserOpHash);

        userOp.signature = abi.encodePacked(r, s, v);

        // 8. Generate the user operations array to pass to the handleOps function

        PackedUserOperation[] memory userOperationArray = new PackedUserOperation[](1);
        userOperationArray[0] = userOp;

        // ACT

        // 9. Send operations to entry point & check if the event is emitted
        vm.prank(bundler.addr);
        vm.expectEmit(true, true, true, false, address(entryPoint));
        emit IEntryPoint.UserOperationEvent(userOpHash, address(simpleAccount), address(0), 0, false, 0, 0);
        vm.recordLogs();

        // Send it to entry point
        entryPoint.handleOps(userOperationArray, payable(bundler.addr));

        // ASSERT

        // 10. Check if the user operation was successful.
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Decode the data to retrieve the non-indexed values
        (uint256 decodedNonce, bool decodedSuccess) = abi.decode(logs[2].data, (uint256, bool));

        // Assert that the success value matches what was emitted
        assertEq(decodedNonce, 0); // Ensure the nonce matches
        assertEq(decodedSuccess, true); // Ensure the success value matches
    }
}
