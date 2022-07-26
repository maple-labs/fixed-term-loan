// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleLoanInitializer } from "./interfaces/IMapleLoanInitializer.sol";
import { IMapleLoanFeeManager }  from "./interfaces/IMapleLoanFeeManager.sol";
import { IGlobalsLike }          from "./interfaces/Interfaces.sol";

import { MapleLoanStorage } from "./MapleLoanStorage.sol";

contract MapleLoanInitializer is IMapleLoanInitializer, MapleLoanStorage {

    // TODO: Ask offchain if structs are worth using.
    function encodeArguments(
        address globals_,
        address borrower_,
        address feeManager_,
        uint256 originationFee_,
        address[2] memory assets_,
        uint256[3] memory termDetails_,
        uint256[3] memory amounts_,
        uint256[5] memory rates_
    ) external pure override returns (bytes memory encodedArguments_) {
        return abi.encode(globals_, borrower_, feeManager_, originationFee_, assets_, termDetails_, amounts_, rates_);
    }

    function decodeArguments(bytes calldata encodedArguments_)
        public pure override returns (
            address globals_,
            address borrower_,
            address feeManager_,
            uint256 originationFee_,
            address[2] memory assets_,
            uint256[3] memory termDetails_,
            uint256[3] memory amounts_,
            uint256[5] memory rates_
        )
    {
        (
            globals_,
            borrower_,
            feeManager_,
            originationFee_,
            assets_,
            termDetails_,
            amounts_,
            rates_
        ) = abi.decode(encodedArguments_, (address, address, address, uint256, address[2], uint256[3], uint256[3], uint256[5]));
    }

    fallback() external {
        (
            address globals_,
            address borrower_,
            address feeManager_,
            uint256 originationFee_,
            address[2] memory assets_,
            uint256[3] memory termDetails_,
            uint256[3] memory amounts_,
            uint256[5] memory rates_
        ) = decodeArguments(msg.data);

        _initialize(globals_, borrower_, feeManager_, originationFee_, assets_, termDetails_, amounts_, rates_);

        emit Initialized(globals_, borrower_, feeManager_, originationFee_, assets_, termDetails_, amounts_, rates_);
    }

    /**
     *  @dev   Initializes the loan.
     *  @param borrower_       The address of the borrower.
     *  @param feeManager_     The address of the entity responsible for calculating fees
     *  @param originationFee_ The fee paid by the borrower on loan origination.
     *  @param assets_         Array of asset addresses.
     *                          [0]: collateralAsset,
     *                          [1]: fundsAsset.
     *  @param termDetails_    Array of loan parameters:
     *                          [0]: gracePeriod,
     *                          [1]: paymentInterval,
     *                          [2]: payments,
     *  @param amounts_        Requested amounts:
     *                          [0]: collateralRequired,
     *                          [1]: principalRequested,
     *                          [2]: endingPrincipal.
     *  @param rates_          Fee parameters:
     *                          [0]: interestRate,
     *                          [1]: closingFeeRate,
     *                          [2]: lateFeeRate,
     *                          [3]: lateInterestPremium.
     *                          [4]: adminFeeRate
     */
    function _initialize(
        address globals_,
        address borrower_,
        address feeManager_,
        uint256 originationFee_,
        address[2] memory assets_,
        uint256[3] memory termDetails_,
        uint256[3] memory amounts_,
        uint256[5] memory rates_
    )
        internal
    {
        // Principal requested needs to be non-zero (see `_getCollateralRequiredFor` math).
	    require(amounts_[1] > uint256(0), "MLI:I:INVALID_PRINCIPAL");

        // Ending principal needs to be less than or equal to principal requested.
        require(amounts_[2] <= amounts_[1], "MLI:I:INVALID_ENDING_PRINCIPAL");

        require((_borrower = borrower_) != address(0),        "MLI:I:ZERO_BORROWER");
        require(IGlobalsLike(globals_).isBorrower(borrower_), "MLI:I:INVALID_BORROWER");

        require((_feeManager = feeManager_) != address(0), "MLI:I:INVALID_MANAGER");

        _collateralAsset = assets_[0];
        _fundsAsset      = assets_[1];

        _gracePeriod       = termDetails_[0];
        _paymentInterval   = termDetails_[1];
        _paymentsRemaining = termDetails_[2];

        _collateralRequired = amounts_[0];
        _principalRequested = amounts_[1];
        _endingPrincipal    = amounts_[2];

        _interestRate        = rates_[0];
        _closingRate         = rates_[1];
        _lateFeeRate         = rates_[2];
        _lateInterestPremium = rates_[3];

        // Set fees for the loan.
        IMapleLoanFeeManager(feeManager_).updateFeeTerms(originationFee_, rates_[4]);
    }

}
