    // SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleAccount} from "src/SimpleAccount.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "account-abstraction/core/Helpers.sol";

contract SimpleAccountHarness is SimpleAccount {
    constructor(address entryPoint, address owner) SimpleAccount(entryPoint, owner) {}

    // exposes `_validateSignature` for testing
    function validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        view
        returns (uint256)
    {
        return _validateSignature(userOp, userOpHash);
    }
}

contract RevertsOnEthTransfer {
    fallback() external {
        revert("");
    }
}

contract SimpleAccountTest is Test {
    SimpleAccountHarness private simpleAccountHarness;
    EntryPoint private entryPoint;

    Account owner;
    Account randomUser;

    function setUp() external {
        owner = makeAccount("owner");
        randomUser = makeAccount("randomUser");

        entryPoint = new EntryPoint();
        simpleAccountHarness = new SimpleAccountHarness(address(entryPoint), owner.addr);
        vm.deal(address(simpleAccountHarness), 10 ether);
    }

    function testStateVariables() public view {
        // Arrange

        // Act
        address contractOwner = simpleAccountHarness.getOwner();
        address contractEntryPoint = address(simpleAccountHarness.entryPoint());

        // Assert
        vm.assertEq(owner.addr, contractOwner);
        vm.assertEq(address(entryPoint), contractEntryPoint);
    }

    function testExecuteFunction() public {
        // Arrange
        uint256 initalBalanceOfRandomUser = randomUser.addr.balance;
        uint256 initalBalanceOfAccountContract = address(simpleAccountHarness).balance;

        uint256 valueToSend = 1 ether;

        // Act
        vm.prank(address(entryPoint));
        simpleAccountHarness.execute(randomUser.addr, valueToSend, "");

        // Assert
        vm.assertEq(randomUser.addr.balance, initalBalanceOfRandomUser + valueToSend);
        vm.assertEq(address(simpleAccountHarness).balance, initalBalanceOfAccountContract - valueToSend);
    }

    function testExecuteRevertsWithCorrectError() public {
        // Arrange
        uint256 valueToSend = 1 ether;

        // Act + Assert
        vm.prank(randomUser.addr);
        vm.expectRevert(bytes("account: not from EntryPoint"));
        simpleAccountHarness.execute(randomUser.addr, valueToSend, "");
    }

    function testCallFromExecuteFails() public {
        // Arrange
        RevertsOnEthTransfer revertsOnEthTransfer = new RevertsOnEthTransfer();

        uint256 valueToSend = 1 ether;

        // Act + Assert
        vm.prank(address(entryPoint)); // execute function needs to be executes from EntryPoint
        vm.expectRevert(SimpleAccount.SimpleAccount__CallFailed.selector);
        simpleAccountHarness.execute(address(revertsOnEthTransfer), valueToSend, "");
    }

    function generateSigAndSignedUserOp(Account memory user)
        public
        view
        returns (PackedUserOperation memory, bytes32)
    {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(simpleAccountHarness),
            nonce: 1,
            initCode: hex"",
            callData: hex"",
            accountGasLimits: hex"",
            preVerificationGas: type(uint64).max,
            gasFees: hex"",
            paymasterAndData: hex"",
            signature: hex""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes32 formattedUserOpHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.key, formattedUserOpHash);

        userOp.signature = abi.encodePacked(r, s, v);

        return (userOp, userOpHash);
    }

    function testValidateSignature() public view {
        // Arrange
        (PackedUserOperation memory userOp, bytes32 userOpHash) = generateSigAndSignedUserOp(owner);
        // Act
        uint256 result = simpleAccountHarness.validateSignature(userOp, userOpHash);
        // Assert
        vm.assertEq(result, SIG_VALIDATION_SUCCESS);
    }

    function testValidateSignatureWithWrongSignature() public view {
        // Arrange
        (PackedUserOperation memory userOp, bytes32 userOpHash) = generateSigAndSignedUserOp(randomUser);
        // Act
        uint256 result = simpleAccountHarness.validateSignature(userOp, userOpHash);
        // Assert
        vm.assertEq(result, SIG_VALIDATION_FAILED);
    }
}
