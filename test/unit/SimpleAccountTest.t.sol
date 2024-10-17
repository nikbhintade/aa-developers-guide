// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.24;

// import {Test} from "forge-std/Test.sol";

// import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
// import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
// import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/core/Helpers.sol";

// import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// import {SimpleAccount} from "src/SimpleAccount.sol";

// contract SimpleAccountHarness is SimpleAccount {
//     constructor(address entryPoint, address owner) SimpleAccount(entryPoint, owner) {}

//     // exposes `_validateSignature` for testing
//     function validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
//         external
//         view
//         returns (uint256)
//     {
//         return _validateSignature(userOp, userOpHash);
//     }
// }

// contract RevertsOnEthTransfer {
//     fallback() external {
//         revert("");
//     }
// }

// contract SimpleAccountTest is Test {
//     SimpleAccount private simpleAccount;
//     SimpleAccountHarness private simpleAccountHarness;
//     EntryPoint private entryPoint;

//     uint256 private constant AMOUNT_TO_DEAL = 10 ether;
//     Account owner;
//     Account randomUser;

//     function setUp() external {
//         owner = makeAccount("owner");
//         randomUser = makeAccount("randomUser");
        
//         entryPoint = new EntryPoint();
//         simpleAccountHarness = new SimpleAccountHarness(address(entryPoint), owner.addr);
//         vm.deal(address(simpleAccountHarness), AMOUNT_TO_DEAL);
//     }

//     function test_StateVariable() public view {
//         address contractOwner = simpleAccountHarness.getOwner();
//         address contractEntryPoint = address(simpleAccountHarness.entryPoint());

//         vm.assertEq(owner.addr, contractOwner);
//         vm.assertEq(address(entryPoint), contractEntryPoint);
//     }

//     function generateSigAndSignedUserOp(Account memory user)
//         public
//         view
//         returns (PackedUserOperation memory, bytes32)
//     {
        
//         PackedUserOperation memory userOp = PackedUserOperation({
//             sender: user.addr,
//             nonce: 1,
//             initCode: hex"",
//             callData: hex"",
//             accountGasLimits: hex"",
//             preVerificationGas: type(uint64).max,
//             gasFees: hex"",
//             paymasterAndData: hex"",
//             signature: hex""
//         });

//         bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
//         bytes32 formattedUserOpHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);

//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.key, formattedUserOpHash);

//         userOp.signature = abi.encodePacked(r, s, v);

//         return (userOp, userOpHash);
//     }

//     function test_vaildateSignatureReturnsSuccessCode() public view {
//         (PackedUserOperation memory userOp, bytes32 userOpHash) = generateSigAndSignedUserOp(owner);

//         uint256 result = simpleAccountHarness.validateSignature(userOp, userOpHash);

//         vm.assertEq(result, SIG_VALIDATION_SUCCESS);
//     }

//     function test_validateSignatureReturnsFailCode() public view {
//         (PackedUserOperation memory userOp, bytes32 userOpHash) = generateSigAndSignedUserOp(randomUser);

//         uint256 result = simpleAccountHarness.validateSignature(userOp, userOpHash);

//         vm.assertEq(result, SIG_VALIDATION_FAILED);
//     }

//     function test_executeCanBeCalledByEntryPointOnly() public {
//         uint256 valueToSend = 1 ether;
//         vm.assertEq(randomUser.addr.balance, 0);

//         vm.prank(address(entryPoint));
//         simpleAccountHarness.execute(randomUser.addr, valueToSend, "");

//         vm.assertEq(randomUser.addr.balance, valueToSend);
//         vm.assertEq(address(simpleAccountHarness).balance, AMOUNT_TO_DEAL - valueToSend);
//     }

//     function test_executeFailsOnCalledOtherThanEntryPoint() public {
//         uint256 valueToSend = 1 ether;
//         vm.deal(randomUser.addr, AMOUNT_TO_DEAL);

//         vm.prank(randomUser.addr);
//         vm.expectRevert(bytes("account: not from EntryPoint"));
//         simpleAccountHarness.execute(randomUser.addr, valueToSend, "");
//     }

//     function test_executeRevertOnFailedCall() public {
//         RevertsOnEthTransfer revertsOnEthTransfer = new RevertsOnEthTransfer();
//         uint256 valueToSend = 1 ether;

//         vm.prank(address(entryPoint));
//         vm.expectRevert(SimpleAccount.SimpleAccount__CallFailed.selector);

//         simpleAccountHarness.execute(address(revertsOnEthTransfer), valueToSend, "");
//     }
// }