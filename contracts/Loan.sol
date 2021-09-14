// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ILoan } from "./interfaces/ILoan.sol";

import { LoanPrimitive } from "./LoanPrimitive.sol";

// TODO: Move to mocks as MockLoanPrimitive when Loan becomes Maple-specific.

contract Loan is ILoan, LoanPrimitive {

    constructor(address borrower_, address[2] memory assets_, uint256[6] memory parameters_, uint256[2] memory amounts_) {
        _initialize(borrower_, assets_, parameters_, amounts_);
        emit Initialized(borrower_, assets_, parameters_, amounts_);
    }

    function borrower() external view override returns (address borrower_) {
        return _borrower;
    }

    function lender() external view override returns (address lender_) {
        return _lender;
    }

    function collateralAsset() external view override returns (address collateralAsset_) {
        return _collateralAsset;
    }

    function fundsAsset() external view override returns (address fundsAsset_) {
        return _fundsAsset;
    }

    function endingPrincipal() external view override returns (uint256 endingPrincipal_) {
        return _endingPrincipal;
    }

    function gracePeriod() external view override returns (uint256 gracePeriod_) {
        return _gracePeriod;
    }

    function interestRate() external view override returns (uint256 interestRate_) {
        return _interestRate;
    }

    function lateFeeRate() external view override returns (uint256 lateFeeRate_) {
        return _lateFeeRate;
    }

    function paymentInterval() external view override returns (uint256 paymentInterval_) {
        return _paymentInterval;
    }

    function collateralRequired() external view override returns (uint256 collateralRequired_) {
        return _collateralRequired;
    }

    function principalRequested() external view override returns (uint256 principalRequested_) {
        return _principalRequested;
    }

    function drawableFunds() external view override returns (uint256 drawableFunds_) {
        return _drawableFunds;
    }

    function claimableFunds() external view override returns (uint256 claimableFunds_) {
        return _claimableFunds;
    }

    function collateral() external view override returns (uint256 collateral_) {
        return _collateral;
    }

    function nextPaymentDueDate() external view override returns (uint256 nextPaymentDueDate_) {
        return _nextPaymentDueDate;
    }

    function paymentsRemaining() external view override returns (uint256 paymentsRemaining_) {
        return _paymentsRemaining;
    }

    function principal() external view override returns (uint256 principal_) {
        return _principal;
    }

    function drawdownFunds(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower,               "L:DF:NOT_BORROWER");
        require(_drawdownFunds(amount_, destination_), "L:DF:FAILED");
        emit FundsDrawnDown(amount_);
    }

    function makePayment()
        external override
        returns (
            uint256 totalPrincipalAmount_,
            uint256 totalInterestFees_,
            uint256 totalLateFees_
        )
    {
        (totalPrincipalAmount_, totalInterestFees_, totalLateFees_) = _makePayments(uint256(1));
        emit PaymentsMade(uint256(1), totalPrincipalAmount_, totalInterestFees_, totalLateFees_);
    }

    function makePayments(uint256 numberOfPayments_)
        external override
        returns (
            uint256 totalPrincipalAmount_,
            uint256 totalInterestFees_,
            uint256 totalLateFees_
        )
    {
        (totalPrincipalAmount_, totalInterestFees_, totalLateFees_) = _makePayments(numberOfPayments_);
        emit PaymentsMade(numberOfPayments_, totalPrincipalAmount_, totalInterestFees_, totalLateFees_);
    }

    function postCollateral() external override returns (uint256 amount_) {
        emit CollateralPosted(amount_ = _postCollateral());
    }

    function removeCollateral(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower,                  "L:RC:NOT_BORROWER");
        require(_removeCollateral(amount_, destination_), "L:RC:FAILED");
        emit CollateralRemoved(amount_);
    }

    function returnFunds() external override returns (uint256 amount_) {
        emit FundsReturned(amount_ = _returnFunds());
    }

    function claimFunds(uint256 amount_, address destination_) external override {
        require(msg.sender == _lender,              "L:CF:NOT_LENDER");
        require(_claimFunds(amount_, destination_), "L:CF:FAILED");
        emit FundsClaimed(amount_);
    }

    function lend(address lender_) external override returns (uint256 amount_) {
        bool success;
        (success, amount_) = _lend(lender_);
        require(success, "L:L:FAILED");
        emit Funded(lender_, _nextPaymentDueDate);
    }

    function repossess(address collateralAssetDestination_, address fundsAssetDestination_)
        external override
        returns (uint256 collateralAssetAmount_, uint256 fundsAssetAmount_)
    {
        require(msg.sender == _lender, "L:R:NOT_LENDER");
        require(_repossess(),          "L:R:FAILED");

        (, collateralAssetAmount_) = _skim(_collateralAsset, collateralAssetDestination_);
        (, fundsAssetAmount_) =      _skim(_fundsAsset, fundsAssetDestination_);

        emit Repossessed(collateralAssetAmount_, fundsAssetAmount_);
    }

    function skim(address asset_, address destination_) external override returns (uint256 amount_) {
        bool success;
        (success, amount_) = _skim(asset_, destination_);
        require(success, "L:S:FAILED");
        emit Skimmed(asset_, destination_, amount_);
    }

    function getNextPaymentsBreakDown(uint256 numberOfPayments_)
        external view override
        returns (uint256 totalPrincipalAmount_, uint256 totalInterestFees_, uint256 totalLateFees_)
    {
        return _getPaymentsBreakdown(
            numberOfPayments_,
            block.timestamp,
            _nextPaymentDueDate,
            _paymentInterval,
            _principal,
            _endingPrincipal,
            _interestRate,
            _paymentsRemaining,
            _lateFeeRate
        );
    }

}
