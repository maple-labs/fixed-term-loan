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

    function borrower() external view override returns (address) {
        return _borrower;
    }

    function lender() external view override returns (address) {
        return _lender;
    }

    function collateralAsset() external view override returns (address) {
        return _collateralAsset;
    }

    function fundsAsset() external view override returns (address) {
        return _fundsAsset;
    }

    function endingPrincipal() external view override returns (uint256) {
        return _endingPrincipal;
    }

    function gracePeriod() external view override returns (uint256) {
        return _gracePeriod;
    }

    function interestRate() external view override returns (uint256) {
        return _interestRate;
    }

    function lateFeeRate() external view override returns (uint256) {
        return _lateFeeRate;
    }

    function paymentInterval() external view override returns (uint256) {
        return _paymentInterval;
    }

    function collateralRequired() external view override returns (uint256) {
        return _collateralRequired;
    }

    function principalRequested() external view override returns (uint256) {
        return _principalRequested;
    }

    function drawableFunds() external view override returns (uint256) {
        return _drawableFunds;
    }

    function claimableFunds() external view override returns (uint256) {
        return _claimableFunds;
    }

    function collateral() external view override returns (uint256) {
        return _collateral;
    }

    function nextPaymentDueDate() external view override returns (uint256) {
        return _nextPaymentDueDate;
    }

    function paymentsRemaining() external view override returns (uint256) {
        return _paymentsRemaining;
    }

    function principal() external view override returns (uint256) {
        return _principal;
    }

    function drawdownFunds(uint256 amount, address destination) external override {
        require(msg.sender == _borrower,             "L:DF:NOT_BORROWER");
        require(_drawdownFunds(amount, destination), "L:DF:FAILED");
        emit FundsDrawnDown(amount);
    }

    function makePayment()
        external override
        returns (
            uint256 totalPrincipalAmount,
            uint256 totalInterestFees,
            uint256 totalLateFees
        )
    {
        (totalPrincipalAmount, totalInterestFees, totalLateFees) = _makePayments(uint256(1));
        emit PaymentsMade(uint256(1), totalPrincipalAmount, totalInterestFees, totalLateFees);
    }

    function makePayments(uint256 numberOfPayments)
        external override
        returns (
            uint256 totalPrincipalAmount,
            uint256 totalInterestFees,
            uint256 totalLateFees
        )
    {
        (totalPrincipalAmount, totalInterestFees, totalLateFees) = _makePayments(numberOfPayments);
        emit PaymentsMade(numberOfPayments, totalPrincipalAmount, totalInterestFees, totalLateFees);
    }

    function postCollateral() external override returns (uint256 amount) {
        emit CollateralPosted(amount = _postCollateral());
    }

    function removeCollateral(uint256 amount, address destination) external override {
        require(msg.sender == _borrower,                "L:RC:NOT_BORROWER");
        require(_removeCollateral(amount, destination), "L:RC:FAILED");
        emit CollateralRemoved(amount);
    }

    function returnFunds() external override returns (uint256 amount) {
        emit FundsReturned(amount = _returnFunds());
    }

    function claimFunds(uint256 amount, address destination) external override {
        require(msg.sender == _lender,            "L:CF:NOT_LENDER");
        require(_claimFunds(amount, destination), "L:CF:FAILED");
        emit FundsClaimed(amount);
    }

    function lend(address lender_) external override returns (uint256 amount) {
        bool success;
        (success, amount) = _lend(lender_);
        require(success, "L:L:FAILED");
        emit Funded(lender_, _nextPaymentDueDate);
    }

    function repossess(address collateralAssetDestination, address fundsAssetDestination)
        external override
        returns (uint256 collateralAssetAmount, uint256 fundsAssetAmount)
    {
        require(msg.sender == _lender, "L:R:NOT_LENDER");
        require(_repossess(),          "L:R:FAILED");

        (, collateralAssetAmount) = _skim(_collateralAsset, collateralAssetDestination);
        (, fundsAssetAmount) =      _skim(_fundsAsset, fundsAssetDestination);

        emit Repossessed(collateralAssetAmount, fundsAssetAmount);
    }

    function skim(address asset, address destination) external override returns (uint256 amount) {
        bool success;
        (success, amount) = _skim(asset, destination);
        require(success, "L:S:FAILED");
        emit Skimmed(asset, destination, amount);
    }

    function getNextPaymentsBreakDown(uint256 numberOfPayments)
        external view override
        returns (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees)
    {
        return _getPaymentsBreakdown(
            numberOfPayments,
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
