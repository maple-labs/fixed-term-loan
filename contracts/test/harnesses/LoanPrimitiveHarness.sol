// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { LoanPrimitive } from "../../LoanPrimitive.sol";

contract LoanPrimitiveHarness is LoanPrimitive {

    /**************************/
    /*** Mutating Functions ***/
    /**************************/

    function accountForPayments(uint256 numberOfPayments_, uint256 totalPaid_, uint256 principalPaid_) external returns (bool success_) {
        return _accountForPayments(numberOfPayments_, totalPaid_, principalPaid_);
    }

    function claimFunds(uint256 amount_, address destination_) external returns (bool success_) {
        return _claimFunds(amount_, destination_);
    }

    function drawdownFunds(uint256 amount_, address destination_) external returns (bool success_) {
        return _drawdownFunds(amount_, destination_);
    }

    function initialize(
        address borrower_,
        address[2] memory assets_,
        uint256[6] memory parameters_,
        uint256[3] memory requests_
    )
        external returns (bool success_)
    {
        return _initialize(borrower_, assets_, parameters_, requests_) ;
    }

    function lend(address lender_) external returns (bool success, uint256 amount_) {
        return _lend(lender_);
    }

    function postCollateral() external returns (bool success_, uint256 amount_) {
        return _postCollateral();
    }

    function removeCollateral(uint256 amount_, address destination_) external returns (bool success_) {
        return _removeCollateral(amount_, destination_);
    }

    function repossess() external returns (bool success_) {
        return _repossess();
    }

    function returnFunds() external returns (bool success_, uint256 amount_) {
        return _returnFunds();
    }

    function skim(address asset_, address destination_) external returns (bool success_, uint256 amount_) {
        return _skim(asset_, destination_);
    }

    /***********************/
    /*** View Functions ****/
    /***********************/

    function borrower() external view returns (address borrower_) {
        return _borrower;
    }

    function claimableFunds() external view returns (uint256 claimableFunds_) {
        return _claimableFunds;
    }

    function collateral() external view returns (uint256 collateral_) {
        return _collateral;
    }

    function collateralAsset() external view returns (address collateralAsset_) {
        return _collateralAsset;
    }

    function collateralRequired() external view returns (uint256 collateralRequired_) {
        return _collateralRequired;
    }

    function drawableFunds() external view returns (uint256 drawableFunds_) {
        return _drawableFunds;
    }

    function earlyInterestRateDiscount() external view returns (uint256 earlyInterestRateDiscount_) {
        return _earlyInterestRateDiscount;
    }

    function endingPrincipal() external view returns (uint256 endingPrincipal_) {
        return _endingPrincipal;
    }

    function fundsAsset() external view returns (address fundsAsset_) {
        return _fundsAsset;
    }

    function getCurrentPaymentsBreakdown(uint256 numberOfPayments_) external view returns (uint256 principal_, uint256 interest_) {
        return _getCurrentPaymentsBreakdown(numberOfPayments_);
    }

    function getUnaccountedAmount(address asset_) external view returns (uint256 amount_) {
        return _getUnaccountedAmount(asset_);
    }

    function gracePeriod() external view returns (uint256 gracePeriod_) {
        return _gracePeriod;
    }

    function interestRate() external view returns (uint256 interestRate_) {
        return _interestRate;
    }

    function isCollateralMaintained() external view returns (bool isMaintained_) {
        return _isCollateralMaintained();
    }

    function lateInterestRatePremium() external view returns (uint256 lateInterestRatePremium_) {
        return _lateInterestRatePremium;
    }

    function lender() external view returns (address lender_) {
        return _lender;
    }

    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate_) {
        return _nextPaymentDueDate;
    }

    function paymentInterval() external view returns (uint256 paymentInterval_) {
        return _paymentInterval;
    }

    function paymentsRemaining() external view returns (uint256 paymentsRemaining_) {
        return _paymentsRemaining;
    }

    function principal() external view returns (uint256 principal_) {
        return _principal;
    }

    function principalRequested() external view returns (uint256 principalRequested_) {
        return _principalRequested;
    }

    /***********************/
    /*** Pure Functions ****/
    /***********************/

    function getCollateralRequiredFor(
        uint256 principal_,
        uint256 drawableFunds_,
        uint256 principalRequested_,
        uint256 collateralRequired_
    )
        external pure returns (uint256 collateral_)
    {
        return _getCollateralRequiredFor(principal_, drawableFunds_, principalRequested_, collateralRequired_);
    }

    function getInterest(uint256 principal_, uint256 interestRate_, uint256 interval_) external pure returns (uint256 interest_) {
        return _getInterest(principal_, interestRate_, interval_);
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

    function getPaymentsBreakdown(
        uint256 numberOfPayments_,
        uint256 currentTime_,
        uint256 nextPaymentDueDate_,
        uint256 paymentInterval_,
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 lateInterestRatePremium_
    )
        external pure
        returns (
            uint256 principalAmount_,
            uint256 interestAmount_
        )
    {
        return _getPaymentsBreakdown(
            numberOfPayments_,
            currentTime_,
            nextPaymentDueDate_,
            paymentInterval_,
            principal_,
            endingPrincipal_,
            paymentsRemaining_,
            interestRate_,
            lateInterestRatePremium_
        );
    }

    function getPeriodicInterestRate(uint256 interestRate_, uint256 interval_) external pure returns (uint256 periodicInterestRate_) {
        return _getPeriodicInterestRate(interestRate_, interval_);
    }

    function scaledExponent(uint256 base_, uint256 exponent_, uint256 one_) external pure returns (uint256 result_) {
        return _scaledExponent(base_, exponent_, one_);
    }

}
