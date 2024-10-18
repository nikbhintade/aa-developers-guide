// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {SimpleAccountFactory} from "src/SimpleAccountFactory.sol";
import {SimpleAccount} from "src/SimpleAccount.sol";

contract SimpleAccountFactoryTest is Test {
    SimpleAccountFactory private simpleAccountFactory;

    address private entryPoint;
    address private owner;

    function setUp() external {
        simpleAccountFactory = new SimpleAccountFactory();

        entryPoint = makeAddr("entryPoint");
        owner = makeAddr("owner");
    }

    function testComputedAddressIsSameAsDeployedAddress() public {
        bytes32 salt = keccak256("CreateASaltForFactory");

        bytes memory creationCode = type(SimpleAccount).creationCode;
        bytes memory constructorArgs = abi.encode(entryPoint, owner);

        bytes memory byteCodeWithArgs = abi.encodePacked(creationCode, constructorArgs);

        bytes32 byteCodeHash = keccak256(byteCodeWithArgs);

        address computedAddress = simpleAccountFactory.getAccountAddress(salt, byteCodeHash);

        address deployedAddress = simpleAccountFactory.createAccount(entryPoint, owner, salt);

        SimpleAccount simpleAccount = SimpleAccount(deployedAddress);

        assertEq(computedAddress, deployedAddress);
        assertEq(entryPoint, address(simpleAccount.entryPoint()));
        assertEq(owner, simpleAccount.getOwner());
    }
}
