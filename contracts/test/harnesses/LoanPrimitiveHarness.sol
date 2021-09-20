// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { LoanPrimitive } from "../../LoanPrimitive.sol";

contract LoanPrimitiveHarness is LoanPrimitive {

    /**************************/
    /*** Mutating Functions ***/
    /**************************/

    function initialize(address borrower_, address[2] memory assets_, uint256[6] memory parameters_, uint256[2] memory requests_) external {
        _initialize(borrower_, assets_, parameters_, requests_) ;
    }

    function lend(address lender_) external returns (bool success, uint256 amount_) {
        return _lend(lender_);
    }

    function claimFunds(uint256 amount_, address destination_) external returns (bool success_) {
        return _claimFunds(amount_, destination_);
    }

    function postCollateral() external returns (uint256 amount_) {
        return _postCollateral();
    }

    function removeCollateral(uint256 amount_, address destination_) external returns (bool success_) {
        return _removeCollateral(amount_, destination_);
    }

    function skim(address asset_, address destination_) external returns (bool success_, uint256 amount_) {
        return _skim(asset_, destination_);
    }

    /***********************/
    /*** View Functions ****/
    /***********************/

    function collateral() external view returns (uint256 collateral_) {
        return _collateral;
    }

    function getUnaccountedAmount(address asset_) external view returns (uint256 amount_) {
        return _getUnaccountedAmount(asset_);
    }

    function collateralRequired() external view returns (uint256 collateralRequired_) {
        return _collateralRequired;
    }

    function getFee(uint256 amount_, uint256 feeRate_, uint256 interval_) external pure returns (uint256 fee_) {
        return _getFee(amount_, feeRate_, interval_);
    }

    function lender() external view returns (address lender_) {
        return _lender;
    }

    function drawableFunds() external view returns (uint256 drawableFunds_) {
        return _drawableFunds;
    }

    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate_) {
        return _nextPaymentDueDate;
    }

    function paymentInterval() external view returns (uint256 paymentInterval_) {
        return _paymentInterval;
    }

    function principal() external view returns (uint256 principal_) {
        return _principal;
    }

    function principalRequested() external view returns (uint256 principalRequested_) {
        return _principalRequested;
    }

    function getInstallment(
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 totalPayments_
    )
        external pure returns (uint256 principalAmount_, uint256 interestAmount_)
    {
        return _getInstallment(principal_, endingPrincipal_, interestRate_, paymentInterval_, totalPayments_);
    }

    function getPaymentBreakdown(
        uint256 paymentDate_,
        uint256 nextPaymentDueDate_,
        uint256 paymentInterval_,
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 interestRate_,
        uint256 paymentsRemaining_,
        uint256 lateFeeRate_
    )
        external pure returns (uint256 totalPrincipalAmount_, uint256 totalInterestFees_, uint256 totalLateFees_)
    {
        return _getPaymentBreakdown(
            paymentDate_,
            nextPaymentDueDate_,
            paymentInterval_,
            principal_,
            endingPrincipal_,
            interestRate_,
            paymentsRemaining_,
            lateFeeRate_
        );
    }

    function getPaymentsBreakdown(
        uint256 numberOfPayments_,
        uint256 currentTime_,
        uint256 nextPaymentDueDate_,
        uint256 paymentInterval_,
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 interestRate_,
        uint256 paymentsRemaining_,
        uint256 lateFeeRate_
    )
        external pure
        returns (
            uint256 totalPrincipalAmount_,
            uint256 totalInterestFees_,
            uint256 totalLateFees_
        )
    {
        return _getPaymentsBreakdown(
            numberOfPayments_,
            currentTime_,
            nextPaymentDueDate_,
            paymentInterval_,
            principal_,
            endingPrincipal_,
            interestRate_,
            paymentsRemaining_,
            lateFeeRate_
        );
    }

    function getPeriodicFeeRate(uint256 feeRate_, uint256 interval_) external pure returns (uint256 periodicFeeRate_) {
        return _getPeriodicFeeRate(feeRate_, interval_);
    }

    function scaledExponent(uint256 base_, uint256 exponent_, uint256 one_) external pure returns (uint256 scaledExponent_) {
        return _scaledExponent(base_, exponent_, one_);
    }

    function drawdownFunds(uint256 amount_, address destination_) external returns (bool success_) {
        return _drawdownFunds(amount_, destination_);
    }

}
