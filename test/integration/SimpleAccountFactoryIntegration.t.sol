// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {SimpleAccountFactory} from "src/SimpleAccountFactory.sol";
import {SimpleAccount} from "src/SimpleAccount.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SimpleAccountFactoryIntegration is Test {
    SimpleAccountFactory private simpleAccountFactory;

    EntryPoint private entryPoint;
    Account private owner;
    Account private bundler;

    function setUp() external {
        owner = makeAccount("owner");
        bundler = makeAccount("bundler");
        // vm.deal(bundler.addr, 10 ether);

        simpleAccountFactory = new SimpleAccountFactory();

        entryPoint = new EntryPoint();
    }

    function testFactoryWithEntryPoint() public {
        bytes32 salt = keccak256("CreateASaltForFactory");

        address factory = address(simpleAccountFactory);
        bytes memory factoryData =
            abi.encodeWithSelector(SimpleAccountFactory.createAccount.selector, address(entryPoint), owner.addr, salt);

        bytes32 byteCodeHash =
            keccak256(abi.encodePacked(type(SimpleAccount).creationCode, abi.encode(address(entryPoint), owner.addr)));

        address sender = simpleAccountFactory.getAccountAddress(salt, byteCodeHash);

        bytes memory initCode = abi.encodePacked(factory, factoryData);


        bytes32 accountGasLimits = bytes32(uint256(type(uint24).max) << 128 | uint256(type(uint24).max));

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: sender,
            nonce: 0,
            initCode: initCode,
            callData: hex"",
            accountGasLimits: accountGasLimits,
            preVerificationGas: type(uint24).max,
            gasFees: hex"",
            paymasterAndData: hex"",
            signature: hex""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        bytes32 formattedUserOpHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, formattedUserOpHash);

        userOp.signature = abi.encodePacked(r, s, v);

        // 8. Generate the user operations array to pass to the handleOps function

        PackedUserOperation[] memory userOperationArray = new PackedUserOperation[](1);
        userOperationArray[0] = userOp;

        entryPoint.handleOps(userOperationArray, payable(bundler.addr));
    }
}
