// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { MapleLoanInternals } from "../../MapleLoanInternals.sol";

contract MapleLoanInternalsHarness is MapleLoanInternals {

    /**************************/
    /*** Mutating Functions ***/
    /**************************/

    function acceptNewTerms(address refinancer_, bytes[] calldata calls_) external returns (bytes32 refinanceCommitment_) {
        return _acceptNewTerms(refinancer_, calls_);
    }

    function claimFunds(uint256 amount_, address destination_) external {
        _claimFunds(amount_, destination_);
    }

    function drawdownFunds(uint256 amount_, address destination_) external {
        _drawdownFunds(amount_, destination_);
    }

    function initialize(
        address borrower_,
        address[2] memory assets_,
        uint256[6] memory parameters_,
        uint256[3] memory requests_,
        uint256[4] memory fees_
    ) external {
        return _initialize(borrower_, assets_, parameters_, requests_, fees_) ;
    }

    function fundLoan(address lender_) external returns (uint256 amount_) {
        return _fundLoan(lender_);
    }

    function makePayment() external returns (uint256 principal_, uint256 interest_) {
        return _makePayment();
    }

    function postCollateral() external returns (uint256 amount_) {
        return _postCollateral();
    }

    function proposeNewTerms(address refinancer_, bytes[] calldata calls_) external returns (bytes32 refinanceCommitment_) {
        return _proposeNewTerms(refinancer_, calls_);
    }

    function removeCollateral(uint256 amount_, address destination_) external {
        _removeCollateral(amount_, destination_);
    }

    function repossess(address destination_) external returns (uint256 collateralAssetAmount_, uint256 fundsAssetAmount_) {
        return _repossess(destination_);
    }

    function returnFunds() external returns (uint256 amount_) {
        return _returnFunds();
    }

    /***********************/
    /*** View Functions ****/
    /***********************/

    function generateRefinanceCommitment(address refinancer_, bytes[] calldata calls_) external pure returns (bytes32 refinanceCommitment_) {
        return _generateRefinanceCommitment(refinancer_, calls_);
    }

    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_) {
        return _getNextPaymentBreakdown();
    }

    function getUnaccountedAmount(address asset_) external view returns (uint256 amount_) {
        return _getUnaccountedAmount(asset_);
    }

    function isCollateralMaintained() external view returns (bool isMaintained_) {
        return _isCollateralMaintained();
    }

    /**********************/
    /*** State Getters ****/
    /**********************/

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

    function earlyFee() external view returns (uint256 earlyFee_) {
        return _earlyFee;
    }

    function earlyFeeRate() external view returns (uint256 earlyFeeRate_) {
        return _earlyFeeRate;
    }

    function gracePeriod() external view returns (uint256 gracePeriod_) {
        return _gracePeriod;
    }

    function interestRate() external view returns (uint256 interestRate_) {
        return _interestRate;
    }

    function lateFee() external view returns (uint256 lateFee_) {
        return _lateFee;
    }

    function lateFeeRate() external view returns (uint256 lateFeeRate_) {
        return _lateFeeRate;
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

    /**********************/
    /*** State Setters ****/
    /**********************/

    function setBorrower(address borrower_) external {
        _borrower = borrower_;
    }

    function setClaimableFunds(uint256 claimableFunds_) external {
        _claimableFunds = claimableFunds_;
    }

    function setCollateral(uint256 collateral_) external {
        _collateral = collateral_;
    }

    function setCollateralAsset(address collateralAsset_) external {
        _collateralAsset = collateralAsset_;
    }

    function setCollateralRequired(uint256 collateralRequired_) external {
        _collateralRequired = collateralRequired_;
    }

    function setDrawableFunds(uint256 drawableFunds_) external {
        _drawableFunds = drawableFunds_;
    }

    function setEarlyInterestRateDiscount(uint256 earlyInterestRateDiscount_) external {
        _earlyInterestRateDiscount = earlyInterestRateDiscount_;
    }

    function setEndingPrincipal(uint256 endingPrincipal_) external {
        _endingPrincipal = endingPrincipal_;
    }

    function setFundsAsset(address fundsAsset_) external {
        _fundsAsset = fundsAsset_;
    }

    function setEarlyFee(uint256 earlyFee_) external {
        _earlyFee = earlyFee_;
    }

    function setEarlyFeeRate(uint256 earlyFeeRate_) external {
        _earlyFeeRate = earlyFeeRate_;
    }

    function setGracePeriod(uint256 gracePeriod_) external {
        _gracePeriod = gracePeriod_;
    }

    function setInterestRate(uint256 interestRate_) external {
        _interestRate = interestRate_;
    }

    function setLateFee(uint256 lateFee_) external {
        _lateFee = lateFee_;
    }

    function setLateFeeRate(uint256 lateFeeRate_) external {
        _lateFeeRate = lateFeeRate_;
    }

    function setLateInterestRatePremium(uint256 lateInterestRatePremium_) external {
        _lateInterestRatePremium = lateInterestRatePremium_;
    }

    function setLender(address lender_) external {
        _lender = lender_;
    }

    function setNextPaymentDueDate(uint256 nextPaymentDueDate_) external {
        _nextPaymentDueDate = nextPaymentDueDate_;
    }

    function setPaymentInterval(uint256 paymentInterval_) external {
        _paymentInterval = paymentInterval_;
    }

    function setPaymentsRemaining(uint256 paymentsRemaining_) external {
        _paymentsRemaining = paymentsRemaining_;
    }

    function setPrincipal(uint256 principal_) external {
        _principal = principal_;
    }

    function setPrincipalRequested(uint256 principalRequested_) external {
        _principalRequested = principalRequested_;
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

    function getInterest(uint256 principal_, uint256 interestRate_, uint256 interval_) external pure returns (uint256 interest_) {
        return _getInterest(principal_, interestRate_, interval_);
    }

    function getPaymentBreakdown(
        uint256 currentTime_,
        uint256 nextPaymentDueDate_,
        uint256 paymentInterval_,
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 lateInterestRatePremium_
    )
        external pure
        returns (
            uint256 principalAmount_,
            uint256 interestAmount_
        )
    {
        return _getPaymentBreakdown(
            currentTime_,
            nextPaymentDueDate_,
            paymentInterval_,
            principal_,
            endingPrincipal_,
            paymentsRemaining_,
            interestRate_,
            lateFeeRate_,
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
