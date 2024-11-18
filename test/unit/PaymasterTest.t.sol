// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/core/Helpers.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
        address testUser = makeAddr("testUser");

        vm.prank(owner);
        paymaster.addAddress(testUser);
        assertEq(true, paymaster.checkWhitelist(testUser));

        vm.prank(owner);
        paymaster.removeAddress(testUser);
        assertEq(false, paymaster.checkWhitelist(testUser));
    }

    function testAddAddressThrowErrorWhenCalledByNonOwner() public {
        address testUser = makeAddr("testUser");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        paymaster.addAddress(testUser);
    }

    function testRemoveAddressThrowErrorWhenCalledByNonOwner() public {
        address testUser = makeAddr("testUser");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        paymaster.removeAddress(testUser);
    }

    function testValidatePaymasterUserOp() public {
        address testUser = makeAddr("testUser");

        vm.prank(owner);
        paymaster.addAddress(testUser);

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: testUser,
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
        (bytes memory context, uint256 validationData) = paymaster.exposeValidatePaymasterUserOp(userOp, hex"", 0);

        assertEq(validationData, SIG_VALIDATION_SUCCESS);
        assertEq(context, hex"");

        vm.prank(owner);
        paymaster.removeAddress(testUser);

        (context, validationData) = paymaster.exposeValidatePaymasterUserOp(userOp, hex"", 0);

        assertEq(validationData, SIG_VALIDATION_FAILED);
        assertEq(context, hex"");
    }
}
