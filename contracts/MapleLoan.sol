// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";
import { Proxied }     from "../modules/proxy-factory/contracts/Proxied.sol";

import { ILenderLike }       from "./interfaces/Interfaces.sol";
import { IMapleLoan }        from "./interfaces/IMapleLoan.sol";
import { IMapleLoanFactory } from "./interfaces/IMapleLoanFactory.sol";

import { MapleLoanInternals } from "./MapleLoanInternals.sol";

/// @title MapleLoan implements a primitive loan with additional functionality, and is intended to be proxied.

contract MapleLoan is IMapleLoan, MapleLoanInternals {

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
        bool success;
        ( success, amount_ ) = _postCollateral();
        require(success, "ML:PC:FAILED");

        emit CollateralPosted(amount_);
    }

    function drawdownFunds(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower,               "ML:DF:NOT_BORROWER");
        require(_drawdownFunds(amount_, destination_), "ML:DF:FAILED");

        emit FundsDrawnDown(amount_);
    }

    function makePayment() external override returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        ( principal_, interest_, fees_ ) = _makePaymentsWithFees(uint256(1));

        emit PaymentsMade(uint256(1), principal_, interest_, fees_);
    }

    function makePayments(uint256 numberOfPayments_) external override returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        ( principal_, interest_, fees_ ) = _makePaymentsWithFees(numberOfPayments_);

        emit PaymentsMade(numberOfPayments_, principal_, interest_, fees_);
    }

    function removeCollateral(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower,                  "ML:RC:NOT_BORROWER");
        require(_removeCollateral(amount_, destination_), "ML:RC:FAILED");

        emit CollateralRemoved(amount_);
    }

    function returnFunds() external override returns (uint256 amount_) {
        bool success;
        ( success, amount_ ) = _returnFunds();
        require(success, "ML:RF:FAILED");

        emit FundsReturned(amount_);
    }

    /**********************/
    /*** Lend Functions ***/
    /**********************/

    function fundLoan(address lender_, uint256 amount_) external override returns (uint256 amountFunded_) {
        // If funds were transferred to this contract prior or calling this function, it is acceptable for this `transferFrom` to return false.
        ERC20Helper.transferFrom(_fundsAsset, msg.sender, address(this), amount_);

        bool success;
        ( success, amountFunded_ ) = _lend(lender_);
        require(success, "ML:L:FAILED");

        // Transfer the annualized treasury fee, if any, to the Maple treasury, and decrement drawable funds.
        uint256 treasuryFee = (amountFunded_ * ILenderLike(lender_).treasuryFee() * _paymentInterval * _paymentsRemaining) / (uint256(10_000) * uint256(365 days));
        require(ERC20Helper.transfer(_fundsAsset, ILenderLike(lender_).mapleTreasury(), treasuryFee), "ML:FL:T_TRANSFER");
        _drawableFunds -= treasuryFee;

        // Transfer delegate fee, if any, to the pool delegate, and decrement drawable funds.
        uint256 delegateFee = (amountFunded_ * ILenderLike(lender_).investorFee() * _paymentInterval * _paymentsRemaining) / (uint256(10_000) * uint256(365 days));
        require(ERC20Helper.transfer(_fundsAsset, ILenderLike(lender_).poolDelegate(), delegateFee), "ML:FL:PD_TRANSFER");
        _drawableFunds -= delegateFee;

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
        ( , fundsAssetAmount_ )      = _skim(_fundsAsset,      fundsAssetDestination_);

        _lender = address(0);

        emit Repossessed(collateralAssetAmount_, fundsAssetAmount_);
    }

    /***************************/
    /*** Refinance Functions ***/
    /***************************/

    function proposeNewTerms(address refinancer_, bytes[] calldata calls_) external override {
        require(msg.sender == _borrower, "ML:PNT:NOT_BORROWER");

        _refinanceCommitment = keccak256(abi.encode(refinancer_, calls_));

        emit NewTermsProposed(_refinanceCommitment, refinancer_, calls_);
    }

    function acceptNewTerms(address refinancer_, bytes[] calldata calls_) external override {
        require(msg.sender == _lender, "ML:ANT:NOT_LENDER");

        bytes32 refinanceCommitment = keccak256(abi.encode(refinancer_, calls_));
        require(refinanceCommitment == _refinanceCommitment, "ML:ANT:INVALID_ARGS");

        for (uint256 i; i < calls_.length; ++i) {
            ( bool success, ) = refinancer_.delegatecall(calls_[i]);
            require(success, "ML:ANT:FAILED");
        }

        require(_isCollateralMaintained(), "ML:ANT:COLLATERAL_NOT_MAINTAINED");

        emit NewTermsAccepted(refinanceCommitment, refinancer_, calls_);
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function factory() external view override returns (address factory_) {
        return _factory();
    }

    function getAdditionalRequiredCollateral(uint256 drawdownAmount_) external view override returns (uint256 additionalRequiredCollateral_) {
        uint256 newCollateralRequired = _getCollateralRequiredFor(_principal, _drawableFunds - drawdownAmount_, _principalRequested, _collateralRequired);
        return newCollateralRequired > _collateral ? newCollateralRequired - _collateral : uint256(0);
    }

    function getNextPaymentsBreakDown(uint256 numberOfPayments_)
        external view override
        returns (
            uint256 principal_,
            uint256 interest_,
            uint256 fees_
        )
    {
        uint256 adminFee;
        uint256 serviceFee;

        ( principal_, interest_, adminFee, serviceFee ) = _getNextPaymentsBreakDown(numberOfPayments_);

        fees_ = adminFee + serviceFee;
    }

    function getRemovableCollateral() external view override returns (uint256 removableCollateral_) {
        uint256 currentCollateralRequired = _getCollateralRequiredFor(_principal, _drawableFunds, _principalRequested, _collateralRequired);
        return _collateral > currentCollateralRequired ? _collateral - currentCollateralRequired : uint256(0);
    }

    function implementation() external view override returns (address implementation_) {
        return _implementation();
    }

    /*************************************/
    /*** State Variable View Functions ***/
    /*************************************/

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

    function earlyFee() external view override returns (uint256 earlyFee_) {
        return _earlyFee;
    }

    function earlyFeeRate() external view override returns (uint256 earlyFeeRate_) {
        return _earlyFeeRate;
    }

    function earlyInterestRateDiscount() external view override returns (uint256 earlyInterestRateDiscount_) {
        return _earlyInterestRateDiscount;
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

    function lateFee() external view override returns (uint256 lateFee_) {
        return _lateFee;
    }

    function lateFeeRate() external view override returns (uint256 lateFeeRate_) {
        return _lateFeeRate;
    }

    function lateInterestRatePremium() external view override returns (uint256 lateInterestRatePremium_) {
        return _lateInterestRatePremium;
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
