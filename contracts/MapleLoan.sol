// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

// TODO: flatten internals into MapleLoan (new PR)
// TODO: custom error messages (later maybe)
// TODO: closeLoan only by borrower and instantly returns funds and collateral to borrower (later maybe)
// TODO: drawdownFunds calls destination_ with data_ before _postCollateral and endsWithCollateralMaintained() check (later maybe)
// TODO: last payment is a loan close (later maybe)
// TODO: removeCollateral calls destination_ with data_ before endsWithCollateralMaintained() check (later maybe)
// TODO: only push pattern (no more transferFrom) (later maybe)
// TODO: only 2 rates (interestRate and closingRate) (later maybe)
// TODO: permits (later maybe)
// TODO: back and forth proposing new terms (later maybe)
// TODO: spawn new loan on partial funds (later maybe)

import { IERC20 }                from "../modules/erc20/contracts/interfaces/IERC20.sol";
import { ERC20Helper }           from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IMapleProxyFactory }    from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { MapleProxiedInternals } from "../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleLoan } from "./interfaces/IMapleLoan.sol";
import { IMapleLoanFactory } from "./interfaces/IMapleLoanFactory.sol";

import { MapleLoanStorage } from "./MapleLoanStorage.sol";

/// @title MapleLoan implements a primitive loan with additional functionality, and is intended to be proxied.
contract MapleLoan is IMapleLoan, MapleProxiedInternals, MapleLoanStorage {

    uint256 private constant SCALED_ONE = uint256(10 ** 18);

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

        emit Upgraded(toVersion_, arguments_);

        IMapleProxyFactory(_factory()).upgradeInstance(toVersion_, arguments_);
    }

    /************************/
    /*** Borrow Functions ***/
    /************************/

    function acceptBorrower() external override {
        require(msg.sender == _pendingBorrower, "ML:AB:NOT_PENDING_BORROWER");

        _pendingBorrower = address(0);

        emit BorrowerAccepted(_borrower = msg.sender);
    }

    function closeLoan(uint256 amount_) external override returns (uint256 principal_, uint256 interest_) {
        uint256 drawableFundsBeforePayment = _drawableFunds;

        // The amount specified is an optional amount to be transfer from the caller, as a convenience for EOAs.
        require(amount_ == uint256(0) || ERC20Helper.transferFrom(_fundsAsset, msg.sender, address(this), amount_), "ML:CL:TRANSFER_FROM_FAILED");

        ( principal_, interest_ ) = _closeLoan();

        // Either the caller is the borrower or `_drawableFunds` has not decreased.
        require(msg.sender == _borrower || _drawableFunds >= drawableFundsBeforePayment, "ML:CL:CANNOT_USE_DRAWABLE");

        emit LoanClosed(principal_, interest_);
    }

    function drawdownFunds(uint256 amount_, address destination_) external override returns (uint256 collateralPosted_) {
        require(msg.sender == _borrower, "ML:DF:NOT_BORROWER");

        emit FundsDrawnDown(amount_, destination_);

        // Post additional collateral required to facilitate this drawdown, if needed.
        uint256 additionalCollateralRequired = getAdditionalCollateralRequiredFor(amount_);

        if (additionalCollateralRequired > uint256(0)) {
            // Determine collateral currently unaccounted for.
            uint256 unaccountedCollateral = _getUnaccountedAmount(_collateralAsset);

            // Post required collateral, specifying then amount lacking as the optional amount to be transferred from.
            collateralPosted_ = postCollateral(
                additionalCollateralRequired > unaccountedCollateral ? additionalCollateralRequired - unaccountedCollateral : uint256(0)
            );
        }

        _drawdownFunds(amount_, destination_);
    }

    function makePayment(uint256 amount_) external override returns (uint256 principal_, uint256 interest_) {
        uint256 drawableFundsBeforePayment = _drawableFunds;

        // The amount specified is an optional amount to be transfer from the caller, as a convenience for EOAs.
        require(amount_ == uint256(0) || ERC20Helper.transferFrom(_fundsAsset, msg.sender, address(this), amount_), "ML:MP:TRANSFER_FROM_FAILED");

        ( principal_, interest_ ) = _makePayment();

        // Either the caller is the borrower or `_drawableFunds` has not decreased.
        require(msg.sender == _borrower || _drawableFunds >= drawableFundsBeforePayment, "ML:MP:CANNOT_USE_DRAWABLE");

        emit PaymentMade(principal_, interest_);
    }

    function postCollateral(uint256 amount_) public override returns (uint256 collateralPosted_) {
        // The amount specified is an optional amount to be transfer from the caller, as a convenience for EOAs.
        require(
            amount_ == uint256(0) || ERC20Helper.transferFrom(_collateralAsset, msg.sender, address(this), amount_),
            "ML:PC:TRANSFER_FROM_FAILED"
        );

        emit CollateralPosted(collateralPosted_ = _postCollateral());
    }

    function proposeNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) external override returns (bytes32 refinanceCommitment_) {
        require(msg.sender == _borrower,      "ML:PNT:NOT_BORROWER");
        require(deadline_ >= block.timestamp, "ML:PNT:INVALID_DEADLINE");

        emit NewTermsProposed(refinanceCommitment_ = _proposeNewTerms(refinancer_, deadline_, calls_), refinancer_, deadline_, calls_);
    }

    function removeCollateral(uint256 amount_, address destination_) external override {
        require(msg.sender == _borrower, "ML:RC:NOT_BORROWER");

        emit CollateralRemoved(amount_, destination_);

        _removeCollateral(amount_, destination_);
    }

    function returnFunds(uint256 amount_) external override returns (uint256 fundsReturned_) {
        // The amount specified is an optional amount to be transfer from the caller, as a convenience for EOAs.
        require(amount_ == uint256(0) || ERC20Helper.transferFrom(_fundsAsset, msg.sender, address(this), amount_), "ML:RF:TRANSFER_FROM_FAILED");

        emit FundsReturned(fundsReturned_ = _returnFunds());
    }

    function setPendingBorrower(address pendingBorrower_) external override {
        require(msg.sender == _borrower, "ML:SPB:NOT_BORROWER");

        emit PendingBorrowerSet(_pendingBorrower = pendingBorrower_);
    }

    /**********************/
    /*** Lend Functions ***/
    /**********************/

    function acceptLender() external override {
        require(msg.sender == _pendingLender, "ML:AL:NOT_PENDING_LENDER");

        _pendingLender = address(0);

        emit LenderAccepted(_lender = msg.sender);
    }

    function acceptNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_, uint256 amount_) external override {
        require(msg.sender == _lender, "ML:ANT:NOT_LENDER");

        address fundsAssetAddress = _fundsAsset;

        // The amount specified is an optional amount to be transfer from the caller, as a convenience for EOAs.
        require(
            amount_ == uint256(0) || ERC20Helper.transferFrom(fundsAssetAddress, msg.sender, address(this), amount_),
            "ML:ANT:TRANSFER_FROM_FAILED"
        );

        emit NewTermsAccepted(_acceptNewTerms(refinancer_, deadline_, calls_), refinancer_, deadline_, calls_);

        uint256 extra = _getUnaccountedAmount(fundsAssetAddress);

        if (extra == uint256(0)) return;

        // NOTE: Ensures unaccounted funds (pre-existing or due to over-funding) is claimable by the lender.
        _claimableFunds += extra;
    }

    function claimFunds(uint256 amount_, address destination_) external override {
        require(msg.sender == _lender, "ML:CF:NOT_LENDER");

        emit FundsClaimed(amount_, destination_);

        _claimFunds(amount_, destination_);
    }

    function fundLoan(address lender_, uint256 amount_) external override returns (uint256 fundsLent_) {
        address fundsAssetAddress = _fundsAsset;

        // The amount specified is an optional amount to be transferred from the caller, as a convenience for EOAs.
        require(amount_ == uint256(0) || ERC20Helper.transferFrom(fundsAssetAddress, msg.sender, address(this), amount_), "ML:FL:TRANSFER_FROM_FAILED");

        // NOTE: `_nextPaymentDueDate` emitted in event is updated by `_fundLoan`.
        emit Funded(lender_, fundsLent_ = _fundLoan(lender_), _nextPaymentDueDate);

        uint256 extra = _getUnaccountedAmount(fundsAssetAddress);

        // NOTE: Ensures unaccounted funds (pre-existing or due to over-funding) is claimable by the lender.
        if (extra > uint256(0)) {
            _claimableFunds = extra;
        }
    }

    function repossess(address destination_) external override returns (uint256 collateralRepossessed_, uint256 fundsRepossessed_) {
        require(msg.sender == _lender, "ML:R:NOT_LENDER");

        ( collateralRepossessed_, fundsRepossessed_ ) = _repossess(destination_);

        emit Repossessed(collateralRepossessed_, fundsRepossessed_, destination_);
    }

    function setPendingLender(address pendingLender_) external override {
        require(msg.sender == _lender, "ML:SPL:NOT_LENDER");

        emit PendingLenderSet(_pendingLender = pendingLender_);
    }

    /*******************************/
    /*** Miscellaneous Functions ***/
    /*******************************/

    function rejectNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) external override {
        require((msg.sender == _borrower) || (msg.sender == _lender), "L:RNT:NO_AUTH");

        emit NewTermsRejected(_rejectNewTerms(refinancer_, deadline_, calls_), refinancer_, deadline_, calls_);
    }

    function skim(address token_, address destination_) external override returns (uint256 skimmed_) {
        require((msg.sender == _borrower) || (msg.sender == _lender),    "L:S:NO_AUTH");
        require((token_ != _fundsAsset) && (token_ != _collateralAsset), "L:S:INVALID_TOKEN");

        emit Skimmed(token_, skimmed_ = IERC20(token_).balanceOf(address(this)), destination_);

        require(ERC20Helper.transfer(token_, destination_, skimmed_), "L:S:TRANSFER_FAILED");
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function getAdditionalCollateralRequiredFor(uint256 drawdown_) public view override returns (uint256 collateral_) {
        // Determine the collateral needed in the contract for a reduced drawable funds amount.
        uint256 collateralNeeded  = _getCollateralRequiredFor(_principal, _drawableFunds - drawdown_, _principalRequested, _collateralRequired);
        uint256 currentCollateral = _collateral;

        return collateralNeeded > currentCollateral ? collateralNeeded - currentCollateral : uint256(0);
    }

    function getClosingPaymentBreakdown() external view override returns (uint256 principal_, uint256 interest_) {
        ( principal_, interest_ ) = _getClosingPaymentBreakdown();
    }

    function getNextPaymentBreakdown() external view override returns (uint256 principal_, uint256 interest_) {
        ( principal_, interest_ ) = _getNextPaymentBreakdown();
    }

    function getRefinanceInterest(uint256 timestamp_) external view override returns (uint256 proRataInterest_) {
        proRataInterest_ = _getRefinanceInterestParams(
            timestamp_,
            _paymentInterval,
            _principal,
            _endingPrincipal,
            _interestRate,
            _paymentsRemaining,
            _nextPaymentDueDate,
            _lateFeeRate,
            _lateInterestPremium
        );
    }

    function getUnaccountedAmount(address asset_) external view override returns (uint256 unaccountedAmount_) {
        return _getUnaccountedAmount(asset_);
    }

    /****************************/
    /*** State View Functions ***/
    /****************************/

    function borrower() external view override returns (address borrower_) {
        return _borrower;
    }

    function claimableFunds() external view override returns (uint256 claimableFunds_) {
        return _claimableFunds;
    }

    function closingRate() external view override returns (uint256 closingRate_) {
        return _closingRate;
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

    function excessCollateral() external view override returns (uint256 excessCollateral_) {
        uint256 collateralNeeded  = _getCollateralRequiredFor(_principal, _drawableFunds, _principalRequested, _collateralRequired);
        uint256 currentCollateral = _collateral;

        return currentCollateral > collateralNeeded ? currentCollateral - collateralNeeded : uint256(0);
    }

    function factory() external view override returns (address factory_) {
        return _factory();
    }

    function fundsAsset() external view override returns (address fundsAsset_) {
        return _fundsAsset;
    }

    function gracePeriod() external view override returns (uint256 gracePeriod_) {
        return _gracePeriod;
    }

    function implementation() external view override returns (address implementation_) {
        return _implementation();
    }

    function interestRate() external view override returns (uint256 interestRate_) {
        return _interestRate;
    }

    function lateFeeRate() external view override returns (uint256 lateFeeRate_) {
        return _lateFeeRate;
    }

    function lateInterestPremium() external view override returns (uint256 lateInterestPremium_) {
        return _lateInterestPremium;
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

    function pendingBorrower() external view override returns (address pendingBorrower_) {
        return _pendingBorrower;
    }

    function pendingLender() external view override returns (address pendingLender_) {
        return _pendingLender;
    }

    function principalRequested() external view override returns (uint256 principalRequested_) {
        return _principalRequested;
    }

    function principal() external view override returns (uint256 principal_) {
        return _principal;
    }

    function refinanceCommitment() external view override returns (bytes32 refinanceCommitment_) {
        return _refinanceCommitment;
    }

    function refinanceInterest() external view override returns (uint256 refinanceInterest_) {
        return _refinanceInterest;
    }

    /**********************************/
    /*** Internal General Functions ***/
    /**********************************/

    /// @dev Clears all state variables to end a loan, but keep borrower and lender withdrawal functionality intact.
    function _clearLoanAccounting() internal {
        _gracePeriod     = uint256(0);
        _paymentInterval = uint256(0);

        _interestRate        = uint256(0);
        _closingRate         = uint256(0);
        _lateFeeRate         = uint256(0);
        _lateInterestPremium = uint256(0);

        _endingPrincipal = uint256(0);

        _nextPaymentDueDate = uint256(0);
        _paymentsRemaining  = uint256(0);
        _principal          = uint256(0);
    }

    /**************************************/
    /*** Internal Borrow-side Functions ***/
    /**************************************/

    /// @dev Prematurely ends a loan by making all remaining payments.
    function _closeLoan() internal returns (uint256 principal_, uint256 interest_) {
        require(block.timestamp <= _nextPaymentDueDate, "MLI:CL:PAYMENT_IS_LATE");

        ( principal_, interest_ ) = _getClosingPaymentBreakdown();

        _refinanceInterest  = uint256(0);

        uint256 principalAndInterest = principal_ + interest_;

        // The drawable funds are increased by the extra funds in the contract, minus the total needed for payment.
        // NOTE: This line will revert if not enough funds were added for the full payment amount.
        _drawableFunds = (_drawableFunds + _getUnaccountedAmount(_fundsAsset)) - principalAndInterest;

        _claimableFunds += principalAndInterest;

        _clearLoanAccounting();
    }

    /// @dev Sends `amount_` of `_drawableFunds` to `destination_`.
    function _drawdownFunds(uint256 amount_, address destination_) internal {
        _drawableFunds -= amount_;

        require(ERC20Helper.transfer(_fundsAsset, destination_, amount_), "MLI:DF:TRANSFER_FAILED");
        require(_isCollateralMaintained(),                                "MLI:DF:INSUFFICIENT_COLLATERAL");
    }

    /// @dev Makes a payment to progress the loan closer to maturity.
    function _makePayment() internal returns (uint256 principal_, uint256 interest_) {
        ( principal_, interest_ ) = _getNextPaymentBreakdown();

        _refinanceInterest = uint256(0);

        uint256 principalAndInterest = principal_ + interest_;

        // The drawable funds are increased by the extra funds in the contract, minus the total needed for payment.
        // NOTE: This line will revert if not enough funds were added for the full payment amount.
        _drawableFunds = (_drawableFunds + _getUnaccountedAmount(_fundsAsset)) - principalAndInterest;

        _claimableFunds += principalAndInterest;

        uint256 paymentsRemaining = _paymentsRemaining;

        if (paymentsRemaining == uint256(1)) {
            _clearLoanAccounting();  // Assumes `_getNextPaymentBreakdown` returns a `principal_` that is `_principal`.
        } else {
            _nextPaymentDueDate += _paymentInterval;
            _principal          -= principal_;
            _paymentsRemaining   = paymentsRemaining - uint256(1);
        }
    }

    /// @dev Registers the delivery of an amount of collateral to be posted.
    function _postCollateral() internal returns (uint256 collateralPosted_) {
        _collateral += (collateralPosted_ = _getUnaccountedAmount(_collateralAsset));
    }

    /// @dev Sets refinance commitment given refinance operations.
    function _proposeNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) internal returns (bytes32 refinanceCommitment_) {
        return _refinanceCommitment =
            calls_.length > uint256(0)
                ? _getRefinanceCommitment(refinancer_, deadline_, calls_)
                : bytes32(0);
    }

    /// @dev Sends `amount_` of `_collateral` to `destination_`.
    function _removeCollateral(uint256 amount_, address destination_) internal {
        _collateral -= amount_;

        require(ERC20Helper.transfer(_collateralAsset, destination_, amount_), "MLI:RC:TRANSFER_FAILED");
        require(_isCollateralMaintained(),                                     "MLI:RC:INSUFFICIENT_COLLATERAL");
    }

    /// @dev Registers the delivery of an amount of funds to be returned as `_drawableFunds`.
    function _returnFunds() internal returns (uint256 fundsReturned_) {
        _drawableFunds += (fundsReturned_ = _getUnaccountedAmount(_fundsAsset));
    }

    /************************************/
    /*** Internal Lend-side Functions ***/
    /************************************/

    /// @dev Processes refinance operations.
    function _acceptNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) internal returns (bytes32 acceptedRefinanceCommitment_) {
        // NOTE: A zero refinancer address and/or empty calls array will never (probabilistically) match a refinance commitment in storage.
        require(
            _refinanceCommitment == (acceptedRefinanceCommitment_ = _getRefinanceCommitment(refinancer_, deadline_, calls_)),
            "MLI:ANT:COMMITMENT_MISMATCH"
        );

        require(refinancer_.code.length != uint256(0), "MLI:ANT:INVALID_REFINANCER");

        require(block.timestamp <= deadline_, "MLI:ANT:EXPIRED_COMMITMENT");

        uint256 preRefinancePaymentInterval = _paymentInterval;

        // Get the amount of interest owed since the last payment due date, as well as the time since the last due date
        uint256 proRataInterest = _getRefinanceInterestParams(
            block.timestamp,
            preRefinancePaymentInterval,
            _principal,
            _endingPrincipal,
            _interestRate,
            _paymentsRemaining,
            _nextPaymentDueDate,
            _lateFeeRate,
            _lateInterestPremium
        );

        // In case there is still a refinance interest, just increment it instead of setting it.
        _refinanceInterest += proRataInterest;

        // Clear refinance commitment to prevent implications of re-acceptance of another call to `_acceptNewTerms`.
        _refinanceCommitment = bytes32(0);

        uint256 length = calls_.length;
        for (uint256 i; i < length;) {
            ( bool success, ) = refinancer_.delegatecall(calls_[i]);
            require(success, "MLI:ANT:FAILED");
            unchecked { ++i; }
        }

        // Increment the due date to be one full payment interval from now, to restart the payment schedule with new terms.
        // NOTE: `_paymentInterval` here is possibly newly set via the above delegate calls, so cache it.
        _nextPaymentDueDate = block.timestamp + _paymentInterval;

        // Ensure that collateral is maintained after changes made.
        require(_isCollateralMaintained(), "MLI:ANT:INSUFFICIENT_COLLATERAL");
    }

    /// @dev Sends `amount_` of `_claimableFunds` to `destination_`.
    ///      If `amount_` is higher than `_claimableFunds` the transaction will underflow and revert.
    function _claimFunds(uint256 amount_, address destination_) internal {
        _claimableFunds -= amount_;

        require(ERC20Helper.transfer(_fundsAsset, destination_, amount_), "MLI:CF:TRANSFER_FAILED");
    }

    /// @dev Fund the loan and kick off the repayment requirements.
    function _fundLoan(address lender_) internal returns (uint256 fundsLent_) {
        require(lender_ != address(0), "MLI:FL:INVALID_LENDER");

        // Can only fund loan if there are payments remaining (as defined by the initialization) and no payment is due yet (as set by a funding).
        require((_nextPaymentDueDate == uint256(0)) && (_paymentsRemaining != uint256(0)), "MLI:FL:LOAN_ACTIVE");

        _lender = lender_;

        _nextPaymentDueDate = block.timestamp + _paymentInterval;

        // Amount funded and principal are as requested.
        fundsLent_ = _principal = _principalRequested;

        // Cannot under-fund loan, but over-funding results in additional funds left unaccounted for.
        require(_getUnaccountedAmount(_fundsAsset) >= fundsLent_, "MLI:FL:WRONG_FUND_AMOUNT");

        _drawableFunds = fundsLent_;
    }

    /// @dev Explicitly cancel a proposed refinance commitment
    function _rejectNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) internal returns (bytes32 rejectedRefinanceCommitment_){
        require(_refinanceCommitment == (rejectedRefinanceCommitment_ = _getRefinanceCommitment(refinancer_, deadline_, calls_)), "MLI:RNT:COMMITMENT_MISMATCH");
        _refinanceCommitment = bytes32(0);
    }

    /// @dev Reset all state variables in order to release funds and collateral of a loan in default.
    function _repossess(address destination_) internal returns (uint256 collateralRepossessed_, uint256 fundsRepossessed_) {
        uint256 nextPaymentDueDate = _nextPaymentDueDate;

        require(
            nextPaymentDueDate != uint256(0) && (block.timestamp > nextPaymentDueDate + _gracePeriod),
            "MLI:R:NOT_IN_DEFAULT"
        );

        _clearLoanAccounting();

        // Uniquely in `_repossess`, stop accounting for all funds so that they can be swept.
        _collateral     = uint256(0);
        _claimableFunds = uint256(0);
        _drawableFunds  = uint256(0);

        address collateralAsset = _collateralAsset;

        // Either there is no collateral to repossess, or the transfer of the collateral succeeds.
        require(
            (collateralRepossessed_ = _getUnaccountedAmount(collateralAsset)) == uint256(0) ||
            ERC20Helper.transfer(collateralAsset, destination_, collateralRepossessed_),
            "MLI:R:C_TRANSFER_FAILED"
        );

        address fundsAsset = _fundsAsset;

        // Either there are no funds to repossess, or the transfer of the funds succeeds.
        require(
            (fundsRepossessed_ = _getUnaccountedAmount(fundsAsset)) == uint256(0) ||
            ERC20Helper.transfer(fundsAsset, destination_, fundsRepossessed_),
            "MLI:R:F_TRANSFER_FAILED"
        );
    }

    /*******************************/
    /*** Internal View Functions ***/
    /*******************************/

    /// @dev Returns whether the amount of collateral posted is commensurate with the amount of drawn down (outstanding) principal.
    function _isCollateralMaintained() internal view returns (bool isMaintained_) {
        return _collateral >= _getCollateralRequiredFor(_principal, _drawableFunds, _principalRequested, _collateralRequired);
    }

    /// @dev Get principal and interest breakdown for closing (paying off) the loan early.
    function _getClosingPaymentBreakdown() internal view returns (uint256 principal_, uint256 interest_) {
        // Compute interest and include any uncaptured interest from refinance.
        interest_ = (((principal_ = _principal) * _closingRate) / SCALED_ONE) + _refinanceInterest;
    }

    /// @dev Get principal and interest breakdown for next standard payment.
    function _getNextPaymentBreakdown() internal view returns (uint256 principal_, uint256 interest_) {
        ( principal_, interest_ ) = _getPaymentBreakdown(
            block.timestamp,
            _nextPaymentDueDate,
            _paymentInterval,
            _principal,
            _endingPrincipal,
            _paymentsRemaining,
            _interestRate,
            _lateFeeRate,
            _lateInterestPremium
        );

        // Include any uncaptured interest from refinance.
        interest_ += _refinanceInterest;
    }

    /// @dev Returns the amount of an `asset_` that this contract owns, which is not currently accounted for by its state variables.
    function _getUnaccountedAmount(address asset_) internal view returns (uint256 unaccountedAmount_) {
        return IERC20(asset_).balanceOf(address(this))
            - (asset_ == _collateralAsset ? _collateral : uint256(0))                   // `_collateral` is `_collateralAsset` accounted for.
            - (asset_ == _fundsAsset ? _claimableFunds + _drawableFunds : uint256(0));  // `_claimableFunds` and `_drawableFunds` are `_fundsAsset` accounted for.
    }

    /*******************************/
    /*** Internal Pure Functions ***/
    /*******************************/

    /// @dev Returns the total collateral to be posted for some drawn down (outstanding) principal and overall collateral ratio requirement.
    function _getCollateralRequiredFor(
        uint256 principal_,
        uint256 drawableFunds_,
        uint256 principalRequested_,
        uint256 collateralRequired_
    )
        internal pure returns (uint256 collateral_)
    {
        // Where (collateral / outstandingPrincipal) should be greater or equal to (collateralRequired / principalRequested).
        // NOTE: principalRequested_ cannot be 0, which is reasonable, since it means this was never a loan.
        return principal_ <= drawableFunds_ ? uint256(0) : (collateralRequired_ * (principal_ - drawableFunds_)) / principalRequested_;
    }

    /// @dev Returns principal and interest portions of a payment instalment, given generic, stateless loan parameters.
    function _getInstallment(uint256 principal_, uint256 endingPrincipal_, uint256 interestRate_, uint256 paymentInterval_, uint256 totalPayments_)
        internal pure returns (uint256 principalAmount_, uint256 interestAmount_)
    {
        /*************************************************************************************************\
         *                             |                                                                 *
         * A = installment amount      |      /                         \     /           R           \  *
         * P = principal remaining     |     |  /                 \      |   | ----------------------- | *
         * R = interest rate           | A = | | P * ( 1 + R ) ^ N | - E | * |   /             \       | *
         * N = payments remaining      |     |  \                 /      |   |  | ( 1 + R ) ^ N | - 1  | *
         * E = ending principal target |      \                         /     \  \             /      /  *
         *                             |                                                                 *
         *                             |---------------------------------------------------------------- *
         *                                                                                               *
         * - Where R           is `periodicRate`                                                         *
         * - Where (1 + R) ^ N is `raisedRate`                                                           *
         * - Both of these rates are scaled by 1e18 (e.g., 12% => 0.12 * 10 ** 18)                       *
        \*************************************************************************************************/

        uint256 periodicRate = _getPeriodicInterestRate(interestRate_, paymentInterval_);
        uint256 raisedRate   = _scaledExponent(SCALED_ONE + periodicRate, totalPayments_, SCALED_ONE);

        // NOTE: If a lack of precision in `_scaledExponent` results in a `raisedRate` smaller than one, assume it to be one and simplify the equation.
        if (raisedRate <= SCALED_ONE) return ((principal_ - endingPrincipal_) / totalPayments_, uint256(0));

        uint256 total = ((((principal_ * raisedRate) / SCALED_ONE) - endingPrincipal_) * periodicRate) / (raisedRate - SCALED_ONE);

        interestAmount_  = _getInterest(principal_, interestRate_, paymentInterval_);
        principalAmount_ = total >= interestAmount_ ? total - interestAmount_ : uint256(0);
    }

    /// @dev Returns an amount by applying an annualized and scaled interest rate, to a principal, over an interval of time.
    function _getInterest(uint256 principal_, uint256 interestRate_, uint256 interval_) internal pure returns (uint256 interest_) {
        return (principal_ * _getPeriodicInterestRate(interestRate_, interval_)) / SCALED_ONE;
    }

    /// @dev Returns total principal and interest portion of a number of payments, given generic, stateless loan parameters and loan state.
    function _getPaymentBreakdown(
        uint256 currentTime_,
        uint256 nextPaymentDueDate_,
        uint256 paymentInterval_,
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 lateInterestPremium_
    )
        internal pure
        returns (uint256 principalAmount_, uint256 interestAmount_)
    {
        ( principalAmount_, interestAmount_ ) = _getInstallment(
            principal_,
            endingPrincipal_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        principalAmount_ = paymentsRemaining_ == uint256(1) ? principal_ : principalAmount_;

        interestAmount_ += _getLateInterest(
            currentTime_,
            principal_,
            interestRate_,
            nextPaymentDueDate_,
            lateFeeRate_,
            lateInterestPremium_
        );
    }

    function _getRefinanceInterestParams(
        uint256 currentTime_,
        uint256 paymentInterval_,
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 interestRate_,
        uint256 paymentsRemaining_,
        uint256 nextPaymentDueDate_,
        uint256 lateFeeRate_,
        uint256 lateInterestPremium_
    )
        internal pure returns (uint256 refinanceInterest_)
    {
        // If the user has made an early payment, there is no refinance interest owed.
        if (currentTime_ + paymentInterval_ < nextPaymentDueDate_) return 0;

        uint256 timeSinceLastPaymentDueDate_ = currentTime_ - (nextPaymentDueDate_ - paymentInterval_);

        ( , refinanceInterest_ ) = _getInstallment(
            principal_,
            endingPrincipal_,
            interestRate_,
            timeSinceLastPaymentDueDate_,
            paymentsRemaining_
        );

        refinanceInterest_ += _getLateInterest(
            currentTime_,
            principal_,
            interestRate_,
            nextPaymentDueDate_,
            lateFeeRate_,
            lateInterestPremium_
        );
    }

    function _getLateInterest(
        uint256 currentTime_,
        uint256 principal_,
        uint256 interestRate_,
        uint256 nextPaymentDueDate_,
        uint256 lateFeeRate_,
        uint256 lateInterestPremium_
    )
        internal pure returns (uint256 lateInterest_)
    {
        if (currentTime_ <= nextPaymentDueDate_) return 0;

        // Calculates the number of full days late in seconds (will always be multiples of 86,400).
        // Rounds up and is inclusive so that if a payment is 1s late or 24h0m0s late it is 1 full day late.
        // 24h0m1s late would be two full days late.
        // (((86400n - 0n - 1n) / 86400n) + 1n) * 86400n = 86400n
        // (((86401n - 0n - 1n) / 86400n) + 1n) * 86400n = 172800n
        uint256 fullDaysLate = (((currentTime_ - nextPaymentDueDate_ - 1) / 1 days) + 1) * 1 days;

        lateInterest_ += _getInterest(principal_, interestRate_ + lateInterestPremium_, fullDaysLate);
        lateInterest_ += (lateFeeRate_ * principal_) / SCALED_ONE;
    }

    /// @dev Returns the interest rate over an interval, given an annualized interest rate.
    function _getPeriodicInterestRate(uint256 interestRate_, uint256 interval_) internal pure returns (uint256 periodicInterestRate_) {
        return (interestRate_ * interval_) / uint256(365 days);
    }

    /// @dev Returns refinance commitment given refinance parameters.
    function _getRefinanceCommitment(address refinancer_, uint256 deadline_, bytes[] calldata calls_) internal pure returns (bytes32 refinanceCommitment_) {
        return keccak256(abi.encode(refinancer_, deadline_, calls_));
    }

    /**
     *  @dev Returns exponentiation of a scaled base value.
     *
     *       Walk through example:
     *       LINE  |  base_          |  exponent_  |  one_  |  result_
     *             |  3_00           |  18         |  1_00  |  0_00
     *        A    |  3_00           |  18         |  1_00  |  1_00
     *        B    |  3_00           |  9          |  1_00  |  1_00
     *        C    |  9_00           |  9          |  1_00  |  1_00
     *        D    |  9_00           |  9          |  1_00  |  9_00
     *        B    |  9_00           |  4          |  1_00  |  9_00
     *        C    |  81_00          |  4          |  1_00  |  9_00
     *        B    |  81_00          |  2          |  1_00  |  9_00
     *        C    |  6_561_00       |  2          |  1_00  |  9_00
     *        B    |  6_561_00       |  1          |  1_00  |  9_00
     *        C    |  43_046_721_00  |  1          |  1_00  |  9_00
     *        D    |  43_046_721_00  |  1          |  1_00  |  387_420_489_00
     *        B    |  43_046_721_00  |  0          |  1_00  |  387_420_489_00
     *
     * Another implementation of this algorithm can be found in Dapphub's DSMath contract:
     * https://github.com/dapphub/ds-math/blob/ce67c0fa9f8262ecd3d76b9e4c026cda6045e96c/src/math.sol#L77
     */
    function _scaledExponent(uint256 base_, uint256 exponent_, uint256 one_) internal pure returns (uint256 result_) {
        // If exponent_ is odd, set result_ to base_, else set to one_.
        result_ = exponent_ & uint256(1) != uint256(0) ? base_ : one_;          // A

        // Divide exponent_ by 2 (overwriting itself) and proceed if not zero.
        while ((exponent_ >>= uint256(1)) != uint256(0)) {                      // B
            base_ = (base_ * base_) / one_;                                     // C

            // If exponent_ is even, go back to top.
            if (exponent_ & uint256(1) == uint256(0)) continue;

            // If exponent_ is odd, multiply result_ is multiplied by base_.
            result_ = (result_ * base_) / one_;                                 // D
        }
    }

}
