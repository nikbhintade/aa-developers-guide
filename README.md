## Simple Account Tutorial - Account Abstraction - [WIP]

# Developer’s Guide to ERC-4337

Lately, I’ve been exploring ERC-4337, which introduces account abstraction with an alternative mempool. It’s a really exciting topic because it lets developers hide much of the complexity behind using crypto apps, making the user experience more seamless.

I’m creating this series for developers who want to get hands-on with ERC-4337. This isn’t a series to learn about pros and cons of account abstraction. Instead, this series will focus on the ERC-4337 specification and walk through building a smart contract using it.

Since we’ll be working with ERC-4337, I originally planned to explain concepts as we needed. But I realized it’s more helpful to start with an overview so you can understand the bigger picture upfront. So, let’s dive in and get familiar with ERC-4337!

## Understanding ERC-4337: What It Is and How It Works

ERC-4337 defines how account abstraction should work on Ethereum or any EVM-compatible chain without changing the consensus layer. It introduces two key ideas: the **UserOperation** and the **Alt Mempool**, which are higher-layer components that rely on existing blockchain infrastructure.

A **UserOperation** is a high-level, pseudo-transaction object that holds both intent and verification data. Unlike regular transactions that are sent to validators, UserOperations are sent to **bundlers** through public or private alt mempools. These bundlers collect multiple UserOperations, bundle them together into a single transaction, and submit them for inclusion in the network.

When bundlers send these UserOperations, they interact with a special contract called **EntryPoint**. The EntryPoint contract is responsible for validating and executing UserOperations. However, it doesn’t handle verification itself. Instead, the verification logic is stored in the **Account Contract**, which is the user’s smart contract wallet.

The **Account Contract** contains both the validation and execution logic for UserOperations. The ERC-4337 specification defines a standard interface for these contracts, ensuring they follow a consistent structure. Here's the `IAccount` interface from the spec:

```solidity
interface IAccount {
  function validateUserOp
      (PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
      external returns (uint256 validationData);
}
```

When a bundler submits a UserOperation to the EntryPoint contract, the EntryPoint first calls the `validateUserOp` function on the user’s account contract. If the UserOperation is valid, the function returns `SIG_VALIDATION_SUCCESS` (which is 0). After validation, the EntryPoint proceeds to execute the UserOperation's calldata on the account contract.

![Account Abstraction Flow](/assets/account-abstraction-flow.png)

That’s a high-level overview of account abstraction with ERC-4337. Next, we’ll dive into the code and break down the key components of ERC-4337 starting with account contract in more detail. Let’s get started!

## Setting Up Project

We will be using Foundry to write our smart contract and test them. If you are not familiar with Foundry, check out Foundry documentation.

To create new, foundry project run following command:

```bash
# creates new folder/directory called simple-account
mkdir simple-account
# changes directory to simple-account
cd simple-account
# initializes new foundry project
forge init
```

We also need to install some dependencies which will help us with developing our account contract. `eth-infinitism` team has created an implementation of ERC-4337 that we will be using let’s install it:

```bash
forge install eth-infinitism/account-abstraction@v0.7.0 --no-commit
```

We need to remove all files from `src`, `script`, & `test` folders and create `SimpleAccount.sol` in `src` folder. With that our setup for this project is done. Now we can start with development.

## BaseAccount.Sol

Similar to an ERC20 token, we don’t have to create whole thing from scratch we can use `BaseAccount.sol` from the `eth-infinitism/account-abstraction`. Here is `BaseAccount.sol` code:

```solidity
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-empty-blocks */

import "../interfaces/IAccount.sol";
import "../interfaces/IEntryPoint.sol";
import "./UserOperationLib.sol";

abstract contract BaseAccount is IAccount {
    using UserOperationLib for PackedUserOperation;

    function getNonce() public view virtual returns (uint256) {
        return entryPoint().getNonce(address(this), 0);
    }

    function entryPoint() public view virtual returns (IEntryPoint);

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external virtual override returns (uint256 validationData) {
        _requireFromEntryPoint();
        validationData = _validateSignature(userOp, userOpHash);
        _validateNonce(userOp.nonce);
        _payPrefund(missingAccountFunds);
    }

    function _requireFromEntryPoint() internal view virtual {
        require(
            msg.sender == address(entryPoint()),
            "account: not from EntryPoint"
        );
    }

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual returns (uint256 validationData);

    function _validateNonce(uint256 nonce) internal view virtual {
    }

    function _payPrefund(uint256 missingAccountFunds) internal virtual {
        if (missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            (success);
            //ignore failure (its EntryPoint's job to verify, not account.)
        }
    }
}
```

Before understanding above implementation, we need to understand some specs ERC-4337 has define for account contract. Here are some of those which we need to understand for this part of the series:

-   MUST validate the caller is a trusted EntryPoint
-   If the account does not support signature aggregation, it MUST validate that the signature is a valid signature of the `userOpHash`, and SHOULD return `SIG_VALIDATION_FAILED` (and not revert) on signature mismatch. Any other error MUST revert.
-   MUST pay the entryPoint (caller) at least the `missingAccountFunds` (which might be zero, in case the current account’s deposit is high enough)

Above implementation satisfies all those requirements in `validateUserOp` .

```solidity
function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external virtual override returns (uint256 validationData) {
        _requireFromEntryPoint();
        validationData = _validateSignature(userOp, userOpHash);
        _validateNonce(userOp.nonce);
        _payPrefund(missingAccountFunds);
    }
```

First with `_requireFromEntryPoint` it checks if trusted EntryPoint is calling the account contract. Then it invokes `_validateSignature` which will contains validation logic and we need to write that in our contract. Last but not the least we pay `missingAccountFunds` via `_payPrefund` function. This way it satisfies all the requirements from the spec.

There is one more function in `validateUserOp` which is `_validateNonce`. Why nonce is here? Doesn’t EOA has those? why a smart contract has one now?

Main reason EOA have nonce is to stop replay attacks and now that our wallet is smart contract we need nonce to stop the same attacks. We can define the validation logic for nonce but EntryPoint does something similar and so we don’t really have to think about it for now. So all the requirements mentioned above are satisfied.

## SimpleAccount.sol

If all the requirements are satisfied what else remaining? From the above contract we can see we need to implement 2 functions to satisfy basic requirement when we will inherit `BaseAccount` which are: `_validateSignature` & `entryPoint`. Along with these two functions, we need one more function to interact with other account and contracts. In the ERC-4337, it doesn’t specifies what name this function should have and it doesn’t really matter as `EntryPoint` contract will execute the calldata directly on account contract.

`entryPoint` function is simplest to implement so let’s try to implement it. Our requirements for this is define the trusted `entryPoint` and return it when someone calls this function.

### EntryPoint Function

Let’s start our development of `SimpleAccount.sol`, we can start with first creating `SimpleAccount` contract and importing `BaseAccount` from `BaseAccount.sol`. This contract will inherit `BaseAccount`.

```
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseAccount} from "account-abstraction/core/BaseAccount.sol";

contract SimpleAccount is BaseAccount {
    constructor() {}
}

```

First, we want define the entry point that we can trust so we will get `EntryPoint` address in constructor. This will be stored in an immutable variable called `_entryPoint`. of type I

```solidity
contract SimpleAccount is BaseAccount {
    IEntryPoint private immutable i_entryPoint;

    constructor(address entryPointAddress) {
        i_entryPoint = IEntryPoint(entryPointAddress);
    }
}
```

We also need to import `IEntryPoint` from `account-abstraction` module.

```solidity
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
```

Finally, we will return `_entryPoint` from `entryPoint` function. This will be a view function and we are overriding the inherited function we will add `override` to this function.

```solidity
    function entryPoint() public view override returns(IEntryPoint) {
        return i_entryPoint;
    }
```

At the end of this step the contract should look a follows:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseAccount} from "account-abstraction/core/BaseAccount.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract SimpleAccount is BaseAccount {
    IEntryPoint private immutable i_entryPoint;

    constructor(address entryPointAddress) {
        i_entryPoint = IEntryPoint(entryPointAddress);
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return i_entryPoint;
    }
}
```

### Account Contract Owner

Developers any method they want to validate the UserOperation but for this series. We will use ECDSA signature to validate the UserOperation. For validation, we want to know who is the owner of the account contract. We can set the contract owner in the constructor and then set `_owner` global variable.

```solidity
      // variable to store owner address
      address private immutable i_owner;

    constructor(address entryPointAddress, address owner) {
        i_entryPoint = IEntryPoint(entryPointAddress);
        // set i_owner;
        i_owner = owner;
    }
```

Let’s write a getter function, that returns address of the owner called `getOwner`.

```solidity
    function getOwner() public view returns (address) {
        return i_owner;
    }
```

Next function we are going to work on is validateUserOp but before that we need to understand UserOperation object and what data is passed with it.

### UserOperation

From the start of the article, we talked about `UserOperation` object but what exactly sent with it?

UserOperation contains general fields like sender, nonce, gas-related fields, calldata, etc. which you can find in regular transaction object. Along with those it also has extra fields for account factory, paymaster (don’t worry about what these fields are, we will discuss as we move forward in this series) and a signature field.

When UserOperation is generated by user it is sent to bundler and it packs the UserOperation by consolidate fields and makes it compact. The new type is called `PackedUserOperation` and here it is:

```solidity
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}
```

Right now we only have to think about and know what only 2 fields: calldata, and signature. Calldata is used for execution and signature is used for validation of UserOperation.

### validateUserOp Function

`validateUserOp` function validates the UserOperation and some extra things but as we have seen in `BaseAccount` that is already implemented and part of it which validates the signature i.e. `_validateSignature` function is remaining and expected to be implemented by the developer of the account contract. 

We are going to use ECDSA signature to verify the UserOperation is signed by the owner of the account contract. If signer and owner is same, we return `SIG_VALIDATION_SUCCESS` else `SIG_VALIDATION_FAILED`.

To verify ECDSA signature we can use ecrecover but using library from openzeppelin is better way to do it as it removes lot of extra work that we might had to do when using ecrecover directly. We will install openzeppelin and then start with writing the function.

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
```

You should see following message in the terminal if OpenZeppelin is installed correctly.

```bash
Installed openzeppelin-contracts v5.0.2
```

Now we can write `_validateSignature`, the function signature for this function is already defined let’s take that and override it.

```solidity
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        override
        returns (uint256) {}
```

First step is to create the signed message hash using userOpHash which will be used to get address of signer. To get the address we are going to use recover function which takes signature and hashed message.

```solidity
		    bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address messageSigner = ECDSA.recover(digest, userOp.signature);
```

Now that we have `messageSigner`. We can compare that with `i_owner` if they are same then we will return `SIG_VALIDATION_SUCCESS`, if not then `SIG_VALIDATION_FAILED`.

```solidity
        if (messageSigner == i_owner) {
            return SIG_VALIDATION_SUCCESS;
        } else {
            return SIG_VALIDATION_FAILED;
        }
```

At end the `_validateSignature` function will look like following.

```solidity
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        override
        returns (uint256)
    {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address messageSigner = ECDSA.recover(digest, userOp.signature);

        if (messageSigner == i_owner) {
            return SIG_VALIDATION_SUCCESS;
        } else {
            return SIG_VALIDATION_FAILED;
        }
    }
```

### execute Function

This function will be for account contract to interact with other accounts and contracts. The name of the this function doesn’t matter as the `EntryPoint` contract directly executes calldata. When sending UserOperation, the user or dapp user has been using need to construct that calldata.

For this contract, the function will be called execute and will take address of contract/account to be called, value to be sent with call and calldata for the call as the arguments.

```solidity
function execute(address dest, uint256 value, bytes calldata funcCallData) external {}
```

As this function can sent assets and perform action on behalf of the contract, we need to restrict access to this function. To achieve this we will use function that is available in `BaseAccount`, **`_requireFromEntryPoint`.**

Then just do the call and check if call succeeded, if fails we will revert with a `SimpleAccount__CallFailed` error which we will define at the top of the contract.

```solidity
    error SimpleAccount__CallFailed();
```

Let’s write rest of the function. Here is how it looks like.

```solidity
    function execute(address dest, uint256 value, bytes calldata funcCallData) external {
        _requireFromEntryPoint();
        (bool success, bytes memory result) = dest.call{value: value}(funcCallData);
        if (!success) {
            revert SimpleAccount__CallFailed(result);
        }
    }
```

With this function finished, we have completed our simple account which is ERC-4337 compliant and can be used with `EntryPoint` and any bundler.

## Final Thoughts

We covered some of the concept that we needed to understand to develop a simple account contract that satisfies requirements of ERC-4337. This article also walks through each function in that contract and libraries which we use like account-abstraction from eth-infinitism and ECDSA from OpenZeppelin.

We also covered a bunch of concepts from ERC-4337 like bundlers, entrypoint, etc. We still don’t know a lot about them except for basics but let’s go over them as we need them.

## Next Steps

In the next article, we will test this contract and learn more intersting things about UserOperation like how to generate UserOperation hash via endpoint. If you want you can start writing tests right now and try to see if our contract is working as except. 

I hope you liked this article and will follow the rest of the articles in this series.