// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IMapleProxyFactory } from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { ILenderLike } from "./interfaces/Interfaces.sol";
import { IMapleLoan }  from "./interfaces/IMapleLoan.sol";

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

        IMapleProxyFactory(_factory()).upgradeInstance(toVersion_, arguments_);

        emit Upgraded(toVersion_, arguments_);
    }

    /************************/
    /*** Borrow Functions ***/
    /************************/

    function postCollateral(uint256 amount_) external override returns (uint256 postedAmount_) {
        if (amount_ > uint256(0)) ERC20Helper.transferFrom(_collateralAsset, msg.sender, address(this), amount_);

        emit CollateralPosted(postedAmount_ = _postCollateral());
    }

    function drawdownFunds(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower, "ML:DF:NOT_BORROWER");

        _drawdownFunds(amount_, destination_);

        emit FundsDrawnDown(amount_, destination_);
    }

    function makePayments(uint256 numberOfPayments_, uint256 amount_)
        external
        override
        returns (
            uint256 principal_,
            uint256 interest_,
            uint256 fees_
        )
    {
        if (amount_ > uint256(0)) ERC20Helper.transferFrom(_fundsAsset, msg.sender, address(this), amount_);

        ( principal_, interest_, fees_ ) = _makePayments(numberOfPayments_);

        emit PaymentsMade(numberOfPayments_, principal_, interest_, fees_);
    }

    function removeCollateral(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower, "ML:RC:NOT_BORROWER");

        _removeCollateral(amount_, destination_);

        emit CollateralRemoved(amount_, destination_);
    }

    function returnFunds(uint256 amount_) external override returns (uint256 returnedAmount_) {
        if (amount_ > uint256(0)) ERC20Helper.transferFrom(_fundsAsset, msg.sender, address(this), amount_);

        emit FundsReturned(returnedAmount_ = _returnFunds());
    }

    function setBorrower(address borrower_) external override {
        require(msg.sender == _borrower, "ML:TB:NOT_BORROWER");

        emit BorrowerSet(_borrower = borrower_);
    }

    /**********************/
    /*** Lend Functions ***/
    /**********************/

    function fundLoan(address lender_, uint256 amount_) external override returns (uint256 amountFunded_) {
        if (amount_ > uint256(0)) ERC20Helper.transferFrom(_fundsAsset, msg.sender, address(this), amount_);

        emit Funded(lender_, amountFunded_ = _fundLoan(lender_), _nextPaymentDueDate);
    }

    function claimFunds(uint256 amount_, address destination_) external override {
        require(msg.sender == _lender, "ML:CF:NOT_LENDER");

        _claimFunds(amount_, destination_);

        emit FundsClaimed(amount_, destination_);
    }

    function repossess(address destination_) external override returns (uint256 collateralAssetAmount_, uint256 fundsAssetAmount_) {
        require(msg.sender == _lender, "ML:R:NOT_LENDER");

        ( collateralAssetAmount_, fundsAssetAmount_ ) = _repossess(destination_);

        emit Repossessed(collateralAssetAmount_, fundsAssetAmount_, destination_);
    }

    function setLender(address lender_) external override {
        require(msg.sender == _lender, "ML:TL:NOT_LENDER");

        emit LenderSet(_lender = lender_);
    }

    /***************************/
    /*** Refinance Functions ***/
    /***************************/

    function proposeNewTerms(address refinancer_, bytes[] calldata calls_) external override {
        require(msg.sender == _borrower, "ML:PNT:NOT_BORROWER");

        emit NewTermsProposed(_proposeNewTerms(refinancer_, calls_), refinancer_, calls_);
    }

    function acceptNewTerms(address refinancer_, bytes[] calldata calls_, uint256 amount_) external override {
        require(msg.sender == _lender, "ML:ANT:NOT_LENDER");

        if (amount_ > uint256(0)) ERC20Helper.transferFrom(_fundsAsset, msg.sender, address(this), amount_);

        emit NewTermsAccepted(_acceptNewTerms(refinancer_, calls_), refinancer_, calls_);
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function factory() external view override returns (address factory_) {
        return _factory();
    }

    function getAdditionalCollateralRequiredFor(uint256 drawdownAmount_) external view override returns (uint256 collateral_) {
        uint256 collateralNeeded = _getCollateralRequiredFor(_principal, _drawableFunds - drawdownAmount_, _principalRequested, _collateralRequired);

        return collateralNeeded > _collateral ? collateralNeeded - _collateral : uint256(0);
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
        uint256 collateralNeeded = _getCollateralRequiredFor(_principal, _drawableFunds, _principalRequested, _collateralRequired);

        return _collateral > collateralNeeded ? _collateral - collateralNeeded : uint256(0);
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
