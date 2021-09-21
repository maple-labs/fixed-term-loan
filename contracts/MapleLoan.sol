// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { Proxied } from "../modules/proxy-factory/contracts/Proxied.sol";

import { IMapleLoan } from "./interfaces/IMapleLoan.sol";
import { IMapleLoanFactory } from "./interfaces/IMapleLoanFactory.sol";

import { LoanPrimitive } from "./LoanPrimitive.sol";

/// @title MapleLoan implements a primitive loan with additional functionality, and is intended to be proxied.
contract MapleLoan is IMapleLoan, Proxied, LoanPrimitive {

    /********************************/
    /*** Administrative Functions ***/
    /********************************/

    function migrate(address migrator_, bytes calldata arguments_) external override {
        require(msg.sender == _factory(),        "ML:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "ML:M:FAILED");
    }

    function setImplementation(address newImplementation_) external override {
        require(msg.sender == _factory(),               "ML:SI:NOT_FACTORY");
        require(_setImplementation(newImplementation_), "ML:SI:FAILED");
    }

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external override {
        require(msg.sender == _borrower, "ML:U:NOT_BORROWER");

        IMapleLoanFactory(_factory()).upgradeLoan(toVersion_, arguments_);
    }

    /************************/
    /*** Borrow Functions ***/
    /************************/

    function postCollateral() external override returns (uint256 amount_) {
        emit CollateralPosted(amount_ = _postCollateral());
    }

    function drawdownFunds(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower,               "ML:DF:NOT_BORROWER");
        require(_drawdownFunds(amount_, destination_), "ML:DF:FAILED");

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
        ( totalPrincipalAmount_, totalInterestFees_, totalLateFees_ ) = _makePayments(uint256(1));
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
        ( totalPrincipalAmount_, totalInterestFees_, totalLateFees_ ) = _makePayments(numberOfPayments_);
        emit PaymentsMade(numberOfPayments_, totalPrincipalAmount_, totalInterestFees_, totalLateFees_);
    }

    function removeCollateral(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower,                  "ML:RC:NOT_BORROWER");
        require(_removeCollateral(amount_, destination_), "ML:RC:FAILED");

        emit CollateralRemoved(amount_);
    }

    function returnFunds() external override returns (uint256 amount_) {
        emit FundsReturned(amount_ = _returnFunds());
    }

    /**********************/
    /*** Lend Functions ***/
    /**********************/

    function lend(address lender_) external override returns (uint256 amount_) {
        bool success;
        ( success, amount_ ) = _lend(lender_);
        require(success, "ML:L:FAILED");

        emit Funded(lender_, _nextPaymentDueDate);
    }

    function claimFunds(uint256 amount_, address destination_) external override {
        require(msg.sender == _lender,              "ML:CF:NOT_LENDER");
        require(_claimFunds(amount_, destination_), "ML:CF:FAILED");

        emit FundsClaimed(amount_);
    }

    function repossess(address collateralAssetDestination_, address fundsAssetDestination_)
        external override
        returns (uint256 collateralAssetAmount_, uint256 fundsAssetAmount_)
    {
        require(msg.sender == _lender, "ML:R:NOT_LENDER");
        require(_repossess(),          "ML:R:FAILED");

        ( , collateralAssetAmount_ ) = _skim(_collateralAsset, collateralAssetDestination_);
        ( , fundsAssetAmount_ ) =      _skim(_fundsAsset, fundsAssetDestination_);

        emit Repossessed(collateralAssetAmount_, fundsAssetAmount_);
    }

    /*************************/
    /*** Utility Functions ***/
    /*************************/

    function skim(address asset_, address destination_) external override returns (uint256 amount_) {
        bool success;
        ( success, amount_ ) = _skim(asset_, destination_);
        require(success, "ML:S:FAILED");

        emit Skimmed(asset_, destination_, amount_);
    }

    /************************/
    /*** Getter Functions ***/
    /************************/

    function factory() public view override returns (address factory_) {
        return _factory();
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

    function implementation() public view override returns (address implementation_) {
        return _implementation();
    }

    /***************************************/
    /*** State Variable Getter Functions ***/
    /***************************************/

    function borrower() external view override returns (address borrower_) {
        return _borrower;
    }

    function claimableFunds() external view override returns (uint256 claimableFunds_) {
        return _claimableFunds;
    }

    function collateral() external view override returns (uint256 collateral_) {
        return _collateral;
    }

    function collateralAsset() external view override returns (address collateralAsset_) {
        return _collateralAsset;
    }

    function collateralRequired() external view override returns (uint256 collateralRequired_) {
        return _collateralRequired;
    }

    function drawableFunds() external view override returns (uint256 drawableFunds_) {
        return _drawableFunds;
    }

    function endingPrincipal() external view override returns (uint256 endingPrincipal_) {
        return _endingPrincipal;
    }

    function fundsAsset() external view override returns (address fundsAsset_) {
        return _fundsAsset;
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

    function lender() external view override returns (address lender_) {
        return _lender;
    }

    function nextPaymentDueDate() external view override returns (uint256 nextPaymentDueDate_) {
        return _nextPaymentDueDate;
    }

    function paymentInterval() external view override returns (uint256 paymentInterval_) {
        return _paymentInterval;
    }

    function paymentsRemaining() external view override returns (uint256 paymentsRemaining_) {
        return _paymentsRemaining;
    }

    function principalRequested() external view override returns (uint256 principalRequested_) {
        return _principalRequested;
    }

    function principal() external view override returns (uint256 principal_) {
        return _principal;
    }

}
