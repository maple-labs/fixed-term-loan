// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IMapleLoanV4Migrator {

    function encodeArguments(address feeManager_) external returns (bytes memory encodedArguments_);

    function decodeArguments(bytes calldata encodedArguments_) external returns (address feeManager_);

}
