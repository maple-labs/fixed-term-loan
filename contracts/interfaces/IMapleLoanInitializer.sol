// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleLoanEvents } from "./IMapleLoanEvents.sol";

interface IMapleLoanInitializer is IMapleLoanEvents {

    // TODO: Add natspec

    function encodeArguments(
        address globals_,
        address borrower_,
        address feeManager_,
        uint256 originationFee_,
        address[2] memory assets_,
        uint256[3] memory termDetails_,
        uint256[3] memory amounts_,
        uint256[5] memory rates_
    ) external pure returns (bytes memory encodedArguments_);

    function decodeArguments(bytes calldata encodedArguments_) external pure
        returns (
            address globals_,
            address borrower_,
            address feeManager_,
            uint256 originationFee_,
            address[2] memory assets_,
            uint256[3] memory termDetails_,
            uint256[3] memory amounts_,
            uint256[5] memory rates_
        );

}
