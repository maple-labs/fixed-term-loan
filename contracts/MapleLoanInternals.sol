// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";
import { Proxied }     from "../modules/proxy-factory/contracts/Proxied.sol";

import { ILenderLike } from "./interfaces/Interfaces.sol";

import { LoanPrimitive } from "./LoanPrimitive.sol";

/// @title TODO
contract MapleLoanInternals is Proxied, LoanPrimitive {

    // Fees
    uint256 internal _earlyFee;
    uint256 internal _earlyFeeRate;
    uint256 internal _lateFee;
    uint256 internal _lateFeeRate;

    bytes32 internal _refinanceCommitment;

    /**********************************/
    /*** Internal General Functions ***/
    /**********************************/

    /**
     *  @dev   Initializes the loan.
     *  @param borrower_   The address of the borrower.
     *  @param assets_     Array of asset addresses.
     *                         [0]: collateralAsset,
     *                         [1]: fundsAsset.
     *  @param parameters_ Array of loan parameters:
     *                         [0]: gracePeriod,
     *                         [1]: paymentInterval,
     *                         [2]: payments,
     *                         [3]: interestRate,
     *                         [4]: earlyInterestRateDiscount,
     *                         [5]: lateInterestRatePremium.
     *  @param amounts_   Requested amounts:
     *                         [0]: collateralRequired,
     *                         [1]: principalRequested,
     *                         [2]: endingPrincipal.
     *  @param fees_      Fee parameters:
     *                         [0]: earlyFee,
     *                         [1]: earlyFeeRate,
     *                         [2]: lateFee,
     *                         [3]: lateFeeRate.
     */
    function _initializeLoan(
        address borrower_,
        address[2] memory assets_,
        uint256[6] memory parameters_,
        uint256[3] memory amounts_,
        uint256[4] memory fees_
    )
        internal
    {
        require(_initialize(borrower_, assets_, parameters_, amounts_), "ML_IL:FAILED");

        _earlyFee     = fees_[0];
        _earlyFeeRate = fees_[1];
        _lateFee      = fees_[2];
        _lateFeeRate  = fees_[3];
    }

    /************************/
    /*** Borrow Functions ***/
    /************************/

    function _makePaymentsWithFees(uint256 numberOfPayments_) internal returns (uint256 principalPortion_, uint256 interestPortion_, uint256 feePortion_) {
        // Get principal and interest amounts, including discounted/premium rates for early/late payments.
        ( principalPortion_, interestPortion_ ) = _getCurrentPaymentsBreakdown(numberOfPayments_);

        // Calculate flat rate and flat fee amounts for early/late payments.
        ( uint256 adminFee, uint256 serviceCharge ) = _getPaymentFees(
            _principal,                            // Use current principal balance.
            numberOfPayments_,                     // Number of payments being made.
            _getEarlyPayments(numberOfPayments_),  // Get number of payments made early.
            _getLatePayments(numberOfPayments_)    // Get number of payments made late.
        );

        feePortion_ = adminFee + serviceCharge;

        // Update Loan accounting, with `totalPaid_` being principal, interest, and fees.
        require(_accountForPayments(numberOfPayments_, principalPortion_ + interestPortion_ + feePortion_ , principalPortion_), "ML:MPWF:ACCOUNTING");

        // Transfer admin fees, if any, to pool delegate, and decrement claimable funds.
        require(ERC20Helper.transfer(_fundsAsset, ILenderLike(_lender).poolDelegate(), adminFee), "ML:MPWF:PD_TRANSER");
        _claimableFunds -= adminFee;
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function _getEarlyPayments(uint256 numberOfPayments_) internal view returns (uint256 earlyPayments_) {
        // Timestamp after which a payment is not early.
        uint256 cutoff = _nextPaymentDueDate - _paymentInterval;

        // If the current timestamp is after the cutoff, there are no early payments here.
        if (block.timestamp > cutoff) return uint256(0);

        // Get the number of early payments and "round up".
        earlyPayments_ = uint256(1) + ((cutoff - block.timestamp) / _paymentInterval);

        // Number of early payments being made is fewer of earlyPayments_ or numberOfPayments_.
        earlyPayments_ = numberOfPayments_ < earlyPayments_ ? numberOfPayments_ : earlyPayments_;
    }

    function _getLatePayments(uint256 numberOfPayments_) internal view returns (uint256 latePayments_) {
        // Timestamp after which a payment is late.
        uint256 cutoff = _nextPaymentDueDate + _gracePeriod;

        // If the current timestamp is before or on the cutoff, there are no late payments here.
        if (block.timestamp <= cutoff) return uint256(0);

        // Get the number of late payments and "round up".
        latePayments_ = uint256(1) + ((block.timestamp - cutoff) / _paymentInterval);

        // Number of late payments being made is fewer of latePayments_ or numberOfPayments_.
        latePayments_ = numberOfPayments_ < latePayments_ ? numberOfPayments_ : latePayments_;
    }

    function _getPaymentFees(
        uint256 payment_,
        uint256 numberOfPayments_,
        uint256 earlyPayments_,
        uint256 latePayments_
    )
        internal view
        returns (
            uint256 adminFee_,
            uint256 serviceCharge_
        )
    {
        if (earlyPayments_ > uint256(0) && _paymentsRemaining == uint256(0)) {
            adminFee_      += _earlyFee;
            serviceCharge_ += _earlyFeeRate * payment_;
        }

        if (latePayments_ > uint256(0)) {
            adminFee_      += _lateFee * latePayments_;
            serviceCharge_ += (_lateFeeRate * payment_ * latePayments_) / numberOfPayments_;
        }
    }

}
