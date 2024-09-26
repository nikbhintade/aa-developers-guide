// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseAccount} from "account-abstraction/core/BaseAccount.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract SimpleAccount is BaseAccount {
    IEntryPoint private immutable i_entryPoint;
    address private immutable i_owner;

    constructor(address entryPointAddress, address owner) {
        i_entryPoint = IEntryPoint(entryPointAddress);
        i_owner = owner;
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return i_entryPoint;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
}
