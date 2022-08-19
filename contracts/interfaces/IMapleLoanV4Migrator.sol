// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IMapleLoanV4Migrator {

    function encodeArguments(address feeManager_) external returns (bytes memory encodedArguments_);

    function decodeArguments(bytes calldata encodedArguments_) external returns (address feeManager_);

}
