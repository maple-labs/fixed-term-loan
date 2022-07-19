// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { MapleLoan }            from "../../MapleLoan.sol";
import { MapleLoanInitializer } from "../../MapleLoanInitializer.sol";

contract MapleLoanHarness is MapleLoan {

    /**************************/
    /*** Mutating Functions ***/
    /**************************/

    function __clearLoanAccounting() external {
        _clearLoanAccounting();
    }

    /***********************/
    /*** View Functions ****/
    /***********************/

    function __isCollateralMaintained() external view returns (bool isMaintained_) {
        return _isCollateralMaintained();
    }

    /**********************/
    /*** State Setters ****/
    /**********************/

    function __setBorrower(address borrower_) external {
        _borrower = borrower_;
    }

    function __setClaimableFunds(uint256 claimableFunds_) external {
        _claimableFunds = claimableFunds_;
    }

    function __setClosingRate(uint256 closingRate_) external {
        _closingRate = closingRate_;
    }

    function __setCollateral(uint256 collateral_) external {
        _collateral = collateral_;
    }

    function __setCollateralAsset(address collateralAsset_) external {
        _collateralAsset = collateralAsset_;
    }

    function __setCollateralRequired(uint256 collateralRequired_) external {
        _collateralRequired = collateralRequired_;
    }

    function __setDrawableFunds(uint256 drawableFunds_) external {
        _drawableFunds = drawableFunds_;
    }

    function __setEndingPrincipal(uint256 endingPrincipal_) external {
        _endingPrincipal = endingPrincipal_;
    }

    function __setFactory(address factory_) external {
        _setFactory(factory_);
    }

    function __setFeeManager(address feeManager_) external {
        _feeManager = feeManager_;
    }

    function __setFundsAsset(address fundsAsset_) external {
        _fundsAsset = fundsAsset_;
    }

    function __setGracePeriod(uint256 gracePeriod_) external {
        _gracePeriod = gracePeriod_;
    }

    function __setInterestRate(uint256 interestRate_) external {
        _interestRate = interestRate_;
    }

    function __setLateFeeRate(uint256 lateFeeRate_) external {
        _lateFeeRate = lateFeeRate_;
    }

    function __setLateInterestPremium(uint256 lateInterestPremium_) external {
        _lateInterestPremium = lateInterestPremium_;
    }

    function __setLender(address lender_) external {
        _lender = lender_;
    }

    function __setNextPaymentDueDate(uint256 nextPaymentDueDate_) external {
        _nextPaymentDueDate = nextPaymentDueDate_;
    }

    function __setPaymentInterval(uint256 paymentInterval_) external {
        _paymentInterval = paymentInterval_;
    }

    function __setPaymentsRemaining(uint256 paymentsRemaining_) external {
        _paymentsRemaining = paymentsRemaining_;
    }

    function __setPendingBorrower(address pendingBorrower_) external {
        _pendingBorrower = pendingBorrower_;
    }

    function __setPendingLender(address pendingLender_) external {
        _pendingLender = pendingLender_;
    }

    function __setPrincipal(uint256 principal_) external {
        _principal = principal_;
    }

    function __setPrincipalRequested(uint256 principalRequested_) external {
        _principalRequested = principalRequested_;
    }

    function __setRefinanceCommitment(bytes32 refinanceCommitment_) external {
        _refinanceCommitment = refinanceCommitment_;
    }

    function __setRefinanceInterest(uint256 refinanceInterest_) external {
        _refinanceInterest = refinanceInterest_;
    }

    /***********************/
    /*** Pure Functions ****/
    /***********************/

    function __getCollateralRequiredFor(
        uint256 principal_,
        uint256 drawableFunds_,
        uint256 principalRequested_,
        uint256 collateralRequired_
    )
        external pure returns (uint256 collateral_)
    {
        return _getCollateralRequiredFor(principal_, drawableFunds_, principalRequested_, collateralRequired_);
    }

    function __getInstallment(
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

    function __getInterest(uint256 principal_, uint256 interestRate_, uint256 interval_) external pure returns (uint256 interest_) {
        return _getInterest(principal_, interestRate_, interval_);
    }

    function __getPaymentBreakdown(
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
            lateInterestPremium_
        );
    }

    function __getPeriodicInterestRate(uint256 interestRate_, uint256 interval_) external pure returns (uint256 periodicInterestRate_) {
        return _getPeriodicInterestRate(interestRate_, interval_);
    }

    function __getRefinanceCommitment(address refinancer_, uint256 deadline_, bytes[] calldata calls_) external pure returns (bytes32 refinanceCommitment_) {
        return _getRefinanceCommitment(refinancer_, deadline_, calls_);
    }

    function __scaledExponent(uint256 base_, uint256 exponent_, uint256 one_) external pure returns (uint256 result_) {
        return _scaledExponent(base_, exponent_, one_);
    }

}

contract ConstructableMapleLoan is MapleLoanHarness {

    constructor(
        address factory_,
        address globals_,
        address borrower_,
        address feeManager_,
        uint256 originationFee_,
        address[2] memory assets_,
        uint256[3] memory termDetails_,
        uint256[3] memory amounts_,
        uint256[5] memory rates_
    ) {
        _setFactory(factory_);

        MapleLoanInitializer initializer = new MapleLoanInitializer();

        _delegateCall(address(initializer), initializer.encodeArguments(globals_, borrower_, feeManager_, originationFee_, assets_, termDetails_, amounts_, rates_));
    }

    function _delegateCall(address account_, bytes memory data_) internal {
        ( bool success, bytes memory result ) = account_.delegatecall(data_);

        if (success) return;

        if (result.length < 68) revert();

        assembly {
            result := add(result, 0x04)
        }

        revert(abi.decode(result, (string)));
    }

}
