// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {Paymaster} from "src/Paymaster.sol";
import {SimpleAccount} from "src/SimpleAccount.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract PaymasterIntegrationTest is Test {
    Paymaster private paymaster;
    SimpleAccount private simpleAccount;
    EntryPoint private entryPoint;

    Account private owner;
    address private paymasterOwner;

    function setUp() external {
        owner = makeAccount("owner");
        paymasterOwner = makeAddr("paymasterOwner");

        entryPoint = new EntryPoint();

        simpleAccount = new SimpleAccount(address(entryPoint), owner.addr);

        vm.prank(paymasterOwner);
        paymaster = new Paymaster(entryPoint);
    }

    function testSimpleAccountInteractionWithEntryPointUsingPaymaster() external {
        vm.prank(paymasterOwner);
        paymaster.addAddress(address(simpleAccount));

        // create receiver and bundler
        address receiver = makeAddr("receiver");
        address bundler = makeAddr("bundler");

        // increase balance of simpleAccount & bundler
        vm.deal(address(simpleAccount), 10 ether);
        vm.deal(bundler, 10 ether);

        // increase paymaster deposit
        entryPoint.depositTo{value: 1 ether}(address(paymaster));

        // create paymaster data & calldata
        bytes memory paymasterAndData =
            abi.encodePacked(address(paymaster), uint128(10000000), uint128(10000000), hex"");

        bytes memory callData = abi.encodeWithSelector(SimpleAccount.execute.selector, receiver, 1 ether, "");

        // create userOp
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(simpleAccount),
            nonce: 0,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(10000000) << 128 | uint256(10000000)),
            preVerificationGas: 10000000,
            gasFees: bytes32(uint256(10000000) << 128 | uint256(10000000)),
            paymasterAndData: paymasterAndData,
            signature: hex""
        });

        // sign userOp
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes32 formattedUserOpHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, formattedUserOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        // creaet PackedUserOperation Array for handleOps function
        PackedUserOperation[] memory userOpArray = new PackedUserOperation[](1);
        userOpArray[0] = userOp;

        // call handleOps
        vm.prank(bundler);
        vm.recordLogs();
        vm.expectEmit(true, true, true, false, address(entryPoint));
        emit IEntryPoint.UserOperationEvent(userOpHash, address(simpleAccount), address(paymaster), 0, false, 0, 0);
        entryPoint.handleOps(userOpArray, payable(bundler));

        // check success and nonce value
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Decode the data to retrieve the non-indexed values
        (uint256 decodedNonce, bool decodedSuccess, uint256 actualGasCost) =
            abi.decode(logs[2].data, (uint256, bool, uint256));

        assertEq(decodedNonce, 0);
        assertEq(decodedSuccess, true);

        // check receiver and simpleAccount balance is as expected along with deposit of paymaster
        assertEq(receiver.balance, 1 ether);
        assertEq(address(simpleAccount).balance, 9 ether);
        assertEq(1 ether - entryPoint.balanceOf(address(paymaster)), actualGasCost);
    }

    function testFailedPaymasterInteraction() external {
        address receiver = makeAddr("receiver");
        address bundler = makeAddr("bundler");

        vm.deal(address(simpleAccount), 10 ether);
        vm.deal(bundler, 10 ether);
        // vm.deal(address(entryPoint), 10 ether);

        entryPoint.depositTo{value: 1 ether}(address(paymaster));

        // create paymaster data
        bytes memory paymasterAndData =
            abi.encodePacked(address(paymaster), uint128(10000000), uint128(10000000), hex"");
        // create userOp

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(simpleAccount),
            nonce: 0,
            initCode: hex"",
            callData: abi.encodeWithSelector(SimpleAccount.execute.selector, receiver, 1 ether, ""),
            accountGasLimits: bytes32(uint256(10000000) << 128 | uint256(10000000)),
            preVerificationGas: 10000000,
            gasFees: bytes32(uint256(30) << 128 | uint256(30)),
            paymasterAndData: paymasterAndData,
            signature: hex""
        });

        // sign userOp
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes32 formattedUserOpHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, formattedUserOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        // send userOp to entryPoint
        PackedUserOperation[] memory userOpArray = new PackedUserOperation[](1);
        userOpArray[0] = userOp;

        // vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA34 signature error"));
        try entryPoint.handleOps(userOpArray, payable(bundler)) {}
        catch (bytes memory reason) {
            assertEq(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA34 signature error"), reason);
        }
    }
}
