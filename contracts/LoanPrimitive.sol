// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IERC20 } from "../modules/erc20/src/interfaces/IERC20.sol";

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

/// @title LoanPrimitive maintains all accounting and functionality related to generic loans.
contract LoanPrimitive {

    uint256 private constant ONE = 10 ** 18;

    // Roles
    address internal _borrower;  // The address of the borrower.
    address internal _lender;    // The address of the lender.

    // Assets
    address internal _collateralAsset;  // The address of the asset used as collateral.
    address internal _fundsAsset;       // The address of the asset used as funds.

    // Static Loan Parameters
    uint256 internal _earlyInterestRateDiscount;  // The amount to decrease the interest rate by calling a loan early.
    uint256 internal _gracePeriod;                // The number of seconds a payment can be late.
    uint256 internal _interestRate;               // The annualized interest rate of the loan.
    uint256 internal _lateInterestRatePremium;    // The amount to increase the interest rate by for late payments.
    uint256 internal _paymentInterval;            // The number of seconds between payments.

    // Requested Amounts
    uint256 internal _collateralRequired;  // The collateral the borrower is expected to put up to draw down all _principalRequested.
    uint256 internal _endingPrincipal;     // The principal to remain at end of loan.
    uint256 internal _principalRequested;  // The funds the borrowers wants to borrower.

    // State
    uint256 internal _drawableFunds;       // The amount of funds that can be drawn down.
    uint256 internal _claimableFunds;      // The amount of funds that the lender can claim (principal repayments, interest, etc).
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
     *                         [0]: gracePeriod,
     *                         [1]: paymentInterval,
     *                         [2]: payments,
     *                         [3]: interestRate,
     *                         [4]: earlyInterestRateDiscount,
     *                         [5]: lateInterestRatePremium.
     *  @param amounts_   Requested amounts:
     *                         [0]: collateralRequired,
     *                         [1]: principalRequested,
     *                         [2]: endingPrincipal.
     */
    function _initialize(
        address borrower_,
        address[2] memory assets_,
        uint256[6] memory parameters_,
        uint256[3] memory amounts_
    )
        internal virtual returns (bool success_)
    {
        _borrower = borrower_;

        _collateralAsset = assets_[0];
        _fundsAsset      = assets_[1];

        _gracePeriod               = parameters_[0];
        _paymentInterval           = parameters_[1];
        _paymentsRemaining         = parameters_[2];
        _interestRate              = parameters_[3];
        _earlyInterestRateDiscount = parameters_[4];
        _lateInterestRatePremium   = parameters_[5];

        _collateralRequired = amounts_[0];
        _principalRequested = amounts_[1];
        _endingPrincipal    = amounts_[2];

        success_ = _principalRequested > uint256(0) && _endingPrincipal <= _principalRequested;
    }

    /// @dev Sends any unaccounted amount of token at `asset_` to `destination_`.
    function _skim(address asset_, address destination_) internal virtual returns (bool success_, uint256 amount_) {
        success_ = ERC20Helper.transfer(asset_, destination_, amount_ = _getUnaccountedAmount(asset_));
    }

    /**************************************/
    /*** Internal Borrow-side Functions ***/
    /**************************************/

    /// @dev Perform state changes to account for a payments made
    function _accountForPayments(uint256 numberOfPayments_, uint256 totalPaid_, uint256 principalPaid_) internal virtual returns (bool success_) {
        // The drawable funds are increased by the extra funds in the contract, minus the total needed for payment.
        _drawableFunds = _drawableFunds + _getUnaccountedAmount(_fundsAsset) - totalPaid_;

        _claimableFunds     += totalPaid_;
        _nextPaymentDueDate += _paymentInterval * numberOfPayments_;
        _principal          -= principalPaid_;
        _paymentsRemaining  -= numberOfPayments_;

        success_ = true;
    }

    /// @dev Sends `amount_` of `_drawableFunds` to `destination_`.
    function _drawdownFunds(uint256 amount_, address destination_) internal virtual returns (bool success_) {
        _drawableFunds -= amount_;
        return ERC20Helper.transfer(_fundsAsset, destination_, amount_) && _isCollateralMaintained();
    }

    /// @dev Registers the delivery of an amount of collateral to be posted.
    function _postCollateral() internal virtual returns (bool success_, uint256 amount_) {
        _collateral += (amount_ = _getUnaccountedAmount(_collateralAsset));
        success_ = true;
    }

    /// @dev Sends `amount_` of `_collateral` to `destination_`.
    function _removeCollateral(uint256 amount_, address destination_) internal virtual returns (bool success_) {
        _collateral -= amount_;
        return ERC20Helper.transfer(_collateralAsset, destination_, amount_) && _isCollateralMaintained();
    }

    /// @dev Registers the delivery of an amount of funds to be returned as `_drawableFunds`.
    function _returnFunds() internal virtual returns (bool success_, uint256 amount_) {
        _drawableFunds += (amount_ = _getUnaccountedAmount(_fundsAsset));
        success_ = true;
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
        _paymentsRemaining  = uint256(0);
        _principal          = uint256(0);

        return true;
    }

    /*******************************/
    /*** Internal View Functions ***/
    /*******************************/

    /// @dev Returns total principal and interest portion of a number of payments, given current loan state.
    function _getCurrentPaymentsBreakdown(uint256 numberOfPayments_) internal view virtual returns (uint256 principal_, uint256 interest_) {
        uint256 paymentsRemaining = _paymentsRemaining;

        // NOTE: Interest rate to use for all payments will be discounted if the entire loan is being paid off early.
        ( principal_, interest_ ) = _getPaymentsBreakdown(
            numberOfPayments_,
            block.timestamp,
            _nextPaymentDueDate,
            _paymentInterval,
            _principal,
            _endingPrincipal,
            _paymentsRemaining,
            _interestRate - (paymentsRemaining > 1 && numberOfPayments_ == paymentsRemaining ? _earlyInterestRateDiscount : uint256(0)),
            _lateInterestRatePremium
        );
    }

    /// @dev Returns the amount a token at `asset_`, above what has been currently accounted for.
    function _getUnaccountedAmount(address asset_) internal view virtual returns (uint256 amount_) {
        return IERC20(asset_).balanceOf(address(this))
            - (asset_ == _collateralAsset ? _collateral : uint256(0))
            - (asset_ == _fundsAsset ? _claimableFunds + _drawableFunds : uint256(0));
    }

    /// @dev Returns whether the amount of collateral posted is commensurate with the amount of drawn down (outstanding) principal.
    function _isCollateralMaintained() internal view returns (bool isMaintained_) {
        return _collateral >= _getCollateralRequiredFor(_principal, _drawableFunds, _principalRequested, _collateralRequired);
    }

    /*******************************/
    /*** Internal Pure Functions ***/
    /*******************************/

    /// @dev Returns the collateral to be posted for some drawn down (outstanding) principal and overall collateral ratio requirement.
    function _getCollateralRequiredFor(
        uint256 principal_,
        uint256 drawableFunds_,
        uint256 principalRequested_,
        uint256 collateralRequired_
    )
        internal pure returns (uint256 collateral_)
    {
        // Whether the final collateral ratio is commensurate with the amount of outstanding principal.
        // Where outstandingPrincipal is (principal - drawableFunds) if (principal > drawableFunds).
        // Where (collateral / outstandingPrincipal) should be greater or equal to (collateralRequired / principalRequested).
        return (collateralRequired_ * (principal_ > drawableFunds_ ? principal_ - drawableFunds_ : uint256(0))) / principalRequested_;
    }

    /// @dev Returns an amount by applying an annualized and scaled interest rate, to a principal, over an interval of time.
    function _getInterest(uint256 principal_, uint256 interestRate_, uint256 interval_) internal pure virtual returns (uint256 interest_) {
        return principal_ * _getPeriodicInterestRate(interestRate_, interval_) / ONE;
    }

    /// @dev Returns principal and interest portions of a payment instalment, given generic, stateless loan parameters.
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
         *                             |---------------------------------------------------------------- *
         *                                                                                               *
         * - Where R           is `periodicRate`                                                         *
         * - Where (1 + R) ^ N is `raisedRate`                                                           *
         * - Both of these rates are scaled by 1e18 (e.g., 12% => 0.12 * 10 ** 18)                       *
         *************************************************************************************************/

        uint256 periodicRate = _getPeriodicInterestRate(interestRate_, paymentInterval_);
        uint256 raisedRate   = _scaledExponent(ONE + periodicRate, totalPayments_, ONE);

        if (raisedRate <= ONE) return ((principal_ - endingPrincipal_) / totalPayments_, 0);

        uint256 total = ((((principal_ * raisedRate) / ONE) - endingPrincipal_) * periodicRate) / (raisedRate - ONE);

        // TODO: Remove this function: `interestAmount_ = principal_ * periodicRate / ONE;`
        interestAmount_  = _getInterest(principal_, interestRate_, paymentInterval_);
        principalAmount_ = total >= interestAmount_ ? total - interestAmount_ : 0;
    }

    /// @dev Returns total principal and interest portion of a number of payments, given generic, stateless loan parameters and loan state.
    function _getPaymentsBreakdown(
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
        internal pure virtual
        returns (uint256 principalAmount_, uint256 interestAmount_)
    {
        // For each payments (current and late)
        for (; numberOfPayments_ > uint256(0); --numberOfPayments_) {
            // Get the expected principal and interest portions for the payment.
            ( uint256 principalAmount, uint256 interestAmount ) = _getInstallment(
                principal_,
                endingPrincipal_,
                interestRate_,
                paymentInterval_,
                paymentsRemaining_--
            );

            // If payment is late, add interest premium given late interest rate premium and late time.
            // TODO: Revisit this late fee mechanism when comparing to CSVs
            if (currentTime_ > nextPaymentDueDate_) {
                interestAmount += _getInterest(principal_, interestRate_ + lateInterestRatePremium_, currentTime_ - nextPaymentDueDate_);
            }

            // Update local variables
            // NOTE: The principal amount is overridden with the entire remaining principal, if this is the last payment.
            interestAmount_     += interestAmount;
            nextPaymentDueDate_ += paymentInterval_;
            principalAmount_    += paymentsRemaining_ == 0 ? principal_ : principalAmount;
            principal_          -= principalAmount;
        }
    }

    /// @dev Returns the interest rate over an interval, given an annualized interest rate.
    function _getPeriodicInterestRate(uint256 interestRate_, uint256 interval_) internal pure virtual returns (uint256 periodicInterestRate_) {
        return (interestRate_ * interval_) / uint256(365 days);
    }

    /**
     *  @dev Returns exponentiation of a scaled base value.
     *
     *       Walk through example:
     *           base_         |  exponent_  |  one_  |  result_
     *           3_00          |  18         |  1_00  |  0_00
     *       A   3_00          |  18         |  1_00  |  1_00
     *       B   3_00          |  9          |  1_00  |  1_00
     *       C   9_00          |  9          |  1_00  |  1_00
     *       D   9_00          |  9          |  1_00  |  9_00
     *       B   9_00          |  4          |  1_00  |  9_00
     *       C   81_00         |  4          |  1_00  |  9_00
     *       B   81_00         |  2          |  1_00  |  9_00
     *       C   6_561_00      |  2          |  1_00  |  9_00
     *       B   6_561_00      |  1          |  1_00  |  9_00
     *       C   43_046_721_00 |  1          |  1_00  |  9_00
     *       D   43_046_721_00 |  1          |  1_00  |  387_420_489_00
     *       B   43_046_721_00 |  0          |  1_00  |  387_420_489_00
     */
    function _scaledExponent(uint256 base_, uint256 exponent_, uint256 one_) internal pure returns (uint256 result_) {
        // If exponent_ is odd, set result_ to base_, else set to one_
        result_ = exponent_ & uint256(1) != uint256(0) ? base_ : one_;       // A

        // Divide exponent_ by 2 (overwriting itself) and proceed if not zero
        while ((exponent_ >>= uint256(1)) != uint256(0)) {                   // B
            base_ = (base_ * base_) / one_;                                  // C

            // If exponent_ is even, go back to top
            if (exponent_ & uint256(1) == uint256(0)) continue;

            // If exponent_ is odd, multiply result_ is multiplied by base_
            result_ = (result_ * base_) / one_;                              // D
        }
    }

}
