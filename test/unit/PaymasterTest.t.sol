// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/core/Helpers.sol";

import {Paymaster} from "src/Paymaster.sol";

contract PaymasterHarness is Paymaster {
    constructor(EntryPoint entryPoint) Paymaster(entryPoint) {}

    function exposeValidatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        external
        view
        returns (bytes memory context, uint256 validationData)
    {
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }
}

contract PaymasterTest is Test {
    EntryPoint private entryPoint;
    PaymasterHarness private paymaster;

    address private owner;

    function setUp() external {
        owner = makeAddr("owner");

        vm.startPrank(owner);

        entryPoint = new EntryPoint();
        paymaster = new PaymasterHarness(entryPoint);

        vm.stopPrank();
    }

    function testOwnerCanAddAndRemoveAddressesFromWhitelist() public {
        address testUserOne = makeAddr("testUserOne");

        vm.prank(owner);
        paymaster.addAddress(testUserOne);
        assertEq(true, paymaster.checkWhitelist(testUserOne));

        vm.prank(owner);
        paymaster.removeAddress(testUserOne);
        assertEq(false, paymaster.checkWhitelist(testUserOne));
    }

    function testValidationWorkForWhitelistedAddresses() public {
        address testUserOne = makeAddr("testUserOne");

        vm.prank(owner);
        paymaster.addAddress(testUserOne);

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: testUserOne,
            nonce: 1,
            initCode: hex"",
            callData: hex"",
            accountGasLimits: hex"",
            preVerificationGas: type(uint64).max,
            gasFees: hex"",
            paymasterAndData: hex"",
            signature: hex""
        });

        vm.prank(address(entryPoint));
        (, uint256 validationData) = paymaster.exposeValidatePaymasterUserOp(userOp, hex"", 0);

        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }

    function testPaymasterValidationFailsForNonWhitelistAddress() public {
        address testUserOne = makeAddr("testUserOne");

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: testUserOne,
            nonce: 1,
            initCode: hex"",
            callData: hex"",
            accountGasLimits: hex"",
            preVerificationGas: type(uint64).max,
            gasFees: hex"",
            paymasterAndData: hex"",
            signature: hex""
        });

        vm.prank(address(entryPoint));
        (, uint256 validationData) = paymaster.exposeValidatePaymasterUserOp(userOp, hex"", 0);

        assertEq(validationData, SIG_VALIDATION_FAILED);
    }
}
