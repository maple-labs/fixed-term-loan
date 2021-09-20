// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IERC20 } from "../modules/erc20/src/interfaces/IERC20.sol";

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

/// @title LoanPrimitive maintains all accounting and functionality related to generic loans.
contract LoanPrimitive {

    // Roles
    address internal _borrower;  // The address of the borrower.
    address internal _lender;    // The address of the lender.

    // Assets
    address internal _collateralAsset;  // The address of the asset used as collateral.
    address internal _fundsAsset;       // The address of the asset used as funds.

    // Static Loan Parameters
    uint256 internal _endingPrincipal;  // The principal to remain at end of loan.
    uint256 internal _gracePeriod;      // The number of seconds a payment can be late.
    uint256 internal _interestRate;     // The annualized interest rate of the loan.
    uint256 internal _lateFeeRate;      // The annualized late fee rate of the loan.
    uint256 internal _paymentInterval;  // The number of seconds between payments.

    // Requests
    uint256 internal _collateralRequired;  // The collateral the borrower is expected to put up to draw down all _principalRequested.
    uint256 internal _principalRequested;  // The funds the borrowers wants to borrower.

    // State
    uint256 internal _drawableFunds;       // The amount of funds that can be drawn down.
    uint256 internal _claimableFunds;      // The amount of funds that the lender can claim (principal repayments, interest fees, and late fees).
    uint256 internal _collateral;          // The amount of collateral, in collateral asset, that is currently posted.
    uint256 internal _nextPaymentDueDate;  // The timestamp of due date of next payment.
    uint256 internal _paymentsRemaining;   // The number of payment remaining.
    uint256 internal _principal;           // The amount of principal yet to be paid down.

    /**********************************/
    /*** Internal General Functions ***/
    /**********************************/

    /**
     *  @dev   Initializes the loan.
     *  @param borrower_   The address of the borrower.
     *  @param assets_     Array of asset addresses. 
     *                         [0]: collateralAsset, 
     *                         [1]: fundsAsset.
     *  @param parameters_ Array of loan parameters: 
     *                         [0]: endingPrincipal, 
     *                         [1]: gracePeriod, 
     *                         [2]: interestRate, 
     *                         [3]: lateFeeRate, 
     *                         [4]: paymentInterval, 
     *                         [5]: paymentsRemaining.
     *  @param amounts_   Requested amounts: 
     *                         [0]: collateralRequired, 
     *                         [1]: principalRequested.
     */
    function _initialize(
        address borrower_,
        address[2] memory assets_,
        uint256[6] memory parameters_,
        uint256[2] memory amounts_
    )
        internal virtual
    {
        _borrower = borrower_;

        _collateralAsset = assets_[0];
        _fundsAsset      = assets_[1];

        _endingPrincipal   = parameters_[0];
        _gracePeriod       = parameters_[1];
        _interestRate      = parameters_[2];
        _lateFeeRate       = parameters_[3];
        _paymentInterval   = parameters_[4];
        _paymentsRemaining = parameters_[5];

        _collateralRequired = amounts_[0];
        _principalRequested = amounts_[1];
    }

    /// @dev Sends any unaccounted amount of token at `asset_` to `destination_`.
    function _skim(address asset_, address destination_) internal virtual returns (bool success_, uint256 amount_) {
        success_ = ERC20Helper.transfer(asset_, destination_, amount_ = _getUnaccountedAmount(asset_));
    }

    /**************************************/
    /*** Internal Borrow-side Functions ***/
    /**************************************/

    /// @dev Sends `amount_` of `_drawableFunds` to `destination_`.
    function _drawdownFunds(uint256 amount_, address destination_) internal virtual returns (bool success_) {
        _drawableFunds -= amount_;
        return ERC20Helper.transfer(_fundsAsset, destination_, amount_) && _collateralMaintained();
    }

    /// @dev Registers the delivery of an amount of funds to make `numberOfPayments_` payments.
    function _makePayments(uint256 numberOfPayments_) 
        internal virtual
        returns (
            uint256 totalPrincipalAmount_,
            uint256 totalInterestFees_,
            uint256 totalLateFees_
        )
    {
        ( totalPrincipalAmount_, totalInterestFees_, totalLateFees_ ) = _getPaymentsBreakdown(
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

        uint256 totalAmountPaid = totalPrincipalAmount_ + totalInterestFees_ + totalLateFees_;

        // The drawable funds are increased by the extra funds in the contract, minus the total needed for payment
        _drawableFunds = _drawableFunds + _getUnaccountedAmount(_fundsAsset) - totalAmountPaid;

        _claimableFunds     += totalAmountPaid;
        _nextPaymentDueDate += _paymentInterval;
        _principal          -= totalPrincipalAmount_;
        _paymentsRemaining  -= numberOfPayments_;
    }

    /// @dev Registers the delivery of an amount of collateral to be posted.
    function _postCollateral() internal virtual returns (uint256 amount_) {
        _collateral += (amount_ = _getUnaccountedAmount(_collateralAsset));
    }

    /// @dev Sends `amount_` of `_collateral` to `destination_`.
    function _removeCollateral(uint256 amount_, address destination_) internal virtual returns (bool success_) {
        _collateral -= amount_;
        return ERC20Helper.transfer(_collateralAsset, destination_, amount_) && _collateralMaintained();
    }

    /// @dev Registers the delivery of an amount of funds to be returned as `_drawableFunds`.
    function _returnFunds() internal virtual returns (uint256 amount_) {
        _drawableFunds += (amount_ = _getUnaccountedAmount(_fundsAsset));
    }

    /************************************/
    /*** Internal Lend-side Functions ***/
    /************************************/

    /// @dev Sends `amount_` of `_claimableFunds` to `destination_`.
    function _claimFunds(uint256 amount_, address destination_) internal virtual returns (bool success_) {
        _claimableFunds -= amount_;
        return ERC20Helper.transfer(_fundsAsset, destination_, amount_);
    }

    /// @dev Registers the delivery of an amount of funds as `_principal` and `_drawableFunds`, on behalf of `lender_`.
    function _lend(address lender_) internal virtual returns (bool success_, uint256 amount_) {
        success_ =
            (_nextPaymentDueDate == uint256(0)) &&
            (_paymentsRemaining  != uint256(0)) &&
            (_principalRequested == (_drawableFunds = _principal = amount_ = _getUnaccountedAmount(_fundsAsset)));

        _lender             = lender_;
        _nextPaymentDueDate = block.timestamp + _paymentInterval;
    }

    /// @dev Reset all state variables in order to release funds and collateral of a loan in default.
    function _repossess() internal virtual returns (bool success_) {
        if (block.timestamp <= _nextPaymentDueDate + _gracePeriod) return false;

        _drawableFunds      = uint256(0);
        _claimableFunds     = uint256(0);
        _collateral         = uint256(0);
        _nextPaymentDueDate = uint256(0);
        _principal          = uint256(0);
        _paymentsRemaining  = uint256(0);

        return true;
    }

    /*******************************/
    /*** Internal View Functions ***/
    /*******************************/

    /// @dev Returns whether the amount of collateral posted is commensurate with the amount of drawn down (outstanding) principal.
    function _collateralMaintained() internal view returns (bool isMaintained_) {
        // Whether the final collateral ratio is commensurate with the amount of outstanding principal
        // uint256 outstandingPrincipal = principal > drawableFunds ? principal - drawableFunds : 0;
        // return collateral / outstandingPrincipal >= collateralRequired / principalRequested;
        return _collateral * _principalRequested >= _collateralRequired * (_principal > _drawableFunds ? _principal - _drawableFunds : uint256(0));
    }

    /// @dev Returns the amount a token at `asset_`, above what has been currently accounted for.
    function _getUnaccountedAmount(address asset_) internal view virtual returns (uint256 amount_) {
        return IERC20(asset_).balanceOf(address(this))
            - (asset_ == _collateralAsset ? _collateral : uint256(0))
            - (asset_ == _fundsAsset ? _claimableFunds + _drawableFunds : uint256(0));
    }

    /*******************************/
    /*** Internal Pure Functions ***/
    /*******************************/

    /// @dev Returns a fee by applying an annualized and scaled fee rate, to an amount, over an interval of time.
    function _getFee(uint256 amount_, uint256 feeRate_, uint256 interval_) internal pure virtual returns (uint256 fee_) {
        return amount_ * _getPeriodicFeeRate(feeRate_, interval_) / uint256(10_000 * 100);
    }

    /// @dev Returns principal and interest fee portions of a payment instalment, given generic, stateless loan parameters.
    function _getInstallment(uint256 principal_, uint256 endingPrincipal_, uint256 interestRate_, uint256 paymentInterval_, uint256 totalPayments_)
        internal pure virtual returns (uint256 principalAmount_, uint256 interestAmount_)
    {
        /*************************************************************************************************
         *                             |                                                                 *
         * A = installment amount      |      /                         \     /           R           \  *
         * P = principal remaining     |     |  /                 \      |   | ----------------------- | *
         * R = interest rate           | A = | | P * ( 1 + R ) ^ N | - E | * |   /             \       | *
         * N = payments remaining      |     |  \                 /      |   |  | ( 1 + R ) ^ N | - 1  | *
         * E = ending principal target |      \                         /     \  \             /      /  *
         *                             |                                                                 *
         *                             |-----------------------------------------------------------------*
         *                                                                                               *
         * - where R is in basis points, scaled by 100, for a payment interval (`periodicRate`)          *
         * - where (1 + R) ^ N is still in basis points and scaled by 100 (`raisedRate`)                 *
         *************************************************************************************************/

        uint256 periodicRate = _getPeriodicFeeRate(interestRate_, paymentInterval_);
        uint256 raisedRate   = _scaledExponent(uint256(10_000 * 100) + periodicRate, totalPayments_, uint256(10_000 * 100));

        // TODO: Check if raisedRate can be <= 10_000 * 100

        uint256 total =
            (
                (
                    (
                        (
                            principal_ * raisedRate
                        ) / uint256(10_000 * 100)    // go from basis points to absolute value, and descale by 100
                    ) - endingPrincipal_
                ) * periodicRate
            )
            /                                        // divide entire numerator above by entire denominator below
            (
                raisedRate - uint256(10_000 * 100)   // subtract `raisedRate` by 1 (which is 100%, in basis points, scaled by 100)
            );

        principalAmount_ = total - (interestAmount_ = _getFee(principal_, interestRate_, paymentInterval_));
    }

    /// @dev Returns principal, interest fee, and late fee portions of a payment, given generic, stateless loan parameters and loan state.
    function _getPaymentBreakdown(
        uint256 paymentDate_,
        uint256 nextPaymentDueDate_,
        uint256 paymentInterval_,
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 interestRate_,
        uint256 paymentsRemaining_,
        uint256 lateFeeRate_
    ) internal pure virtual returns (uint256 principalAmount_, uint256 interestFee_, uint256 lateFee_) {
        // Get the expected principal and interest portions for the payment, as if it was on-time
        ( principalAmount_, interestFee_ ) = _getInstallment(principal_, endingPrincipal_, interestRate_, paymentInterval_, paymentsRemaining_);

        if (paymentsRemaining_ == 1) {
            principalAmount_ = principal_;
        }

        // Determine how late the payment is
        uint256 secondsLate = paymentDate_ > nextPaymentDueDate_ ? paymentDate_ - nextPaymentDueDate_ : uint256(0);

        // Accumulate the potential late fees incurred on the expected interest portion
        lateFee_ = _getFee(interestFee_, lateFeeRate_, secondsLate);

        // Accumulate the interest and potential additional interest incurred in the late period
        interestFee_ += _getFee(principal_, interestRate_, secondsLate);
    }

    /// @dev Returns total principal, interest fee, and late fee portions of payments, given generic, stateless loan parameters and loan state.
    function _getPaymentsBreakdown(
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
        internal pure virtual
        returns (uint256 totalPrincipalAmount_, uint256 totalInterestFees_, uint256 totalLateFees_)
    {
        // TODO: check deployment and runtime costs of principalAmount, interestFee, and lateFee declare outside for-loop

        // For each payments (current and late)
        for (; numberOfPayments_ > uint256(0); --numberOfPayments_) {
            ( uint256 principalAmount, uint256 interestFee, uint256 lateFee ) = _getPaymentBreakdown(
                currentTime_,
                nextPaymentDueDate_,
                paymentInterval_,
                principal_,
                endingPrincipal_,
                interestRate_,
                paymentsRemaining_--,
                lateFeeRate_
            );

            // Update local variables
            totalPrincipalAmount_ += principalAmount;
            totalInterestFees_    += interestFee;
            totalLateFees_        += lateFee;
            nextPaymentDueDate_   += paymentInterval_;
            principal_            -= principalAmount;
        }
    }

    /// @dev Returns the fee rate over an interval, given an annualized fee rate.
    function _getPeriodicFeeRate(uint256 feeRate_, uint256 interval_) internal pure virtual returns (uint256 periodicFeeRate_) {
        return (feeRate_ * interval_) / uint256(365 days);
    }

    /// @dev Returns exponentiation of a scaled base value.
    function _scaledExponent(uint256 base_, uint256 exponent_, uint256 one_) internal pure returns (uint256 scaledExponent_) {
        return exponent_ == uint256(0)
            ? one_
            : (base_ * _scaledExponent(base_, exponent_ - uint256(1), one_)) / one_;
    }

}
