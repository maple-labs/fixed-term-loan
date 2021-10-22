// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { MapleBorrowerInternals } from "./MapleBorrowerInternals.sol";

/// @title MapleBorrowerInitializer is intended to initialize the storage of a MapleBorrower proxy.
contract MapleBorrowerInitializer is MapleBorrowerInternals {

    function encodeArguments(address owner_) external pure returns (bytes memory encodedArguments_) {
        return abi.encode(owner_);
    }

    function decodeArguments(bytes calldata encodedArguments_) public pure returns (address owner_) {
        ( owner_ ) = abi.decode(encodedArguments_, (address));
    }

    fallback() external {
        ( _owner ) = decodeArguments(msg.data);
    }

}
