// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { LoanPrimitive } from "./LoanPrimitive.sol";

import { IMapleLoanEvents } from "./interfaces/IMapleLoan.sol";

/// @title MapleLoanInitializer is intended to initialize the storage of a MapleLoan proxy.
contract MapleLoanInitializer is IMapleLoanEvents, LoanPrimitive {

    function encodeArguments(
        address borrower_,
        address[2] memory assets_,
        uint256[6] memory parameters_,
        uint256[2] memory amounts_
    ) external pure returns (bytes memory encodedArguments_) {
        return abi.encode(borrower_, assets_, parameters_, amounts_);
    }

    function decodeArguments(bytes calldata encodedArguments_)
        external pure returns (
            address borrower_,
            address[2] memory assets_,
            uint256[6] memory parameters_,
            uint256[2] memory amounts_
        )
    {
        ( borrower_, assets_, parameters_, amounts_ ) = _decodeArguments(encodedArguments_);
    }

    function _decodeArguments(bytes calldata encodedArguments_)
        internal pure returns (
            address borrower_,
            address[2] memory assets_,
            uint256[6] memory parameters_,
            uint256[2] memory amounts_
        )
    {
        ( borrower_, assets_, parameters_, amounts_ ) = abi.decode(encodedArguments_, (address, address[2], uint256[6], uint256[2]));
    }

    fallback() external {
        ( address borrower_, address[2] memory assets_, uint256[6] memory parameters_, uint256[2] memory amounts_ ) = _decodeArguments(msg.data);
        _initialize(borrower_, assets_, parameters_, amounts_);

        emit Initialized(borrower_, assets_, parameters_, amounts_);
    }

}
