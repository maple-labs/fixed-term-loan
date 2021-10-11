// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";
import { Proxied }     from "../modules/proxy-factory/contracts/Proxied.sol";

import { IDebtLockerLike } from "./interfaces/Interfaces.sol";

import { LoanPrimitive } from "./LoanPrimitive.sol";

/// @title TODO
contract MapleLoanInternals is Proxied, LoanPrimitive {

    address internal _debtLocker;

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
     *  @param debtLocker_ The address of the DebtLocker contract.
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
        address debtLocker_,
        address borrower_,
        address[2] memory assets_,
        uint256[6] memory parameters_,
        uint256[3] memory amounts_,
        uint256[4] memory fees_
    )
        internal
    {
        require(_initialize(borrower_, assets_, parameters_, amounts_), "ML_IL:FAILED");

        _debtLocker = debtLocker_;

        _earlyFee     = fees_[0];
        _earlyFeeRate = fees_[1];
        _lateFee      = fees_[2];
        _lateFeeRate  = fees_[3];
    }

    /************************/
    /*** Borrow Functions ***/
    /************************/

    function _makePaymentsWithFees(uint256 numberOfPayments_) internal returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        uint256 earlyPayments = _getEarlyPayments(numberOfPayments_);
        uint256 latePayments  = _getLatePayments(numberOfPayments_);

        (principal_, interest_) = _getCurrentPaymentsBreakdown(numberOfPayments_);

        ( uint256 adminFee, uint256 serviceCharge ) = _getPaymentFees(
            principal_ + interest_,
            numberOfPayments_,
            earlyPayments,
            latePayments
        );

        fees_ = adminFee + serviceCharge;
        
        require(_accountForPayments(numberOfPayments_, principal_ + interest_ + fees_ , principal_), "ML:MPWF:FAILED");

        // Transfer admin fees, if any, to pool delegate, and decrement claimable funds.
        ERC20Helper.transfer(_fundsAsset, IDebtLockerLike(_debtLocker).poolDelegate(), adminFee);
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

        // Number is early payments being made is fewer of earlyPayments_ or numberOfPayments_.
        earlyPayments_ = numberOfPayments_ < earlyPayments_ ? numberOfPayments_ : earlyPayments_;
    }

    function _getLatePayments(uint256 numberOfPayments_) internal view returns (uint256 latePayments_) {
        // Timestamp after which a payment is late.
        uint256 cutoff = _nextPaymentDueDate + _gracePeriod;

        // If the current timestamp is before or on the cutoff, there are no late payments here.
        if (block.timestamp <= cutoff) return uint256(0);

        // Get the number of late payments and "round up".
        latePayments_ = uint256(1) + ((block.timestamp - cutoff) / _paymentInterval);

        // Number is late payments being made is fewer of latePayments_ or numberOfPayments_.
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
