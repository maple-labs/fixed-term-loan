// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IERC20 } from "../modules/erc20/src/interfaces/IERC20.sol";

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

/// @title LoanPrimitive maintains all accounting and functionality related to generic loans.
contract LoanPrimitive {

    // Roles
    address internal _borrower;
    address internal _lender;

    // Assets
    address internal _collateralAsset;
    address internal _fundsAsset;

    // Static Loan Parameters
    uint256 internal _endingPrincipal;
    uint256 internal _gracePeriod;
    uint256 internal _interestRate;
    uint256 internal _lateFeeRate;
    uint256 internal _paymentInterval;

    // Requests
    uint256 internal _collateralRequired;
    uint256 internal _principalRequired;

    // State
    uint256 internal _drawableFunds;
    uint256 internal _claimableFunds;
    uint256 internal _collateral;
    uint256 internal _nextPaymentDueDate;
    uint256 internal _paymentsRemaining;
    uint256 internal _principal;

    /**********************************/
    /*** Internal General Functions ***/
    /**********************************/

    /**
     *  @dev   Initializes the loan.
     *  @param borrower   The address of the borrower.
     *  @param assets     Array of asset addresses. 
     *                        [0]: collateralAsset, 
     *                        [1]: fundsAsset.
     *  @param parameters Array of loan parameters: 
     *                        [0]: endingPrincipal, 
     *                        [1]: gracePeriod, 
     *                        [2]: interestRate, 
     *                        [3]: lateFeeRate, 
     *                        [4]: paymentInterval, 
     *                        [5]: paymentsRemaining.
     *  @param requests   Requested amounts: 
     *                        [0]: collateralRequired, 
     *                        [1]: principalRequired.
     */
    function _initialize(
        address borrower,
        address[2] memory assets,
        uint256[6] memory parameters,
        uint256[2] memory requests
    )
        internal virtual
    {
        _borrower = borrower;

        _collateralAsset = assets[0];
        _fundsAsset      = assets[1];

        _endingPrincipal   = parameters[0];
        _gracePeriod       = parameters[1];
        _interestRate      = parameters[2];
        _lateFeeRate       = parameters[3];
        _paymentInterval   = parameters[4];
        _paymentsRemaining = parameters[5];

        _collateralRequired = requests[0];
        _principalRequired  = requests[1];
    }

    /**
     *  @dev Sends any unaccounted amount of an asset to an address.
     */
    function _skim(address asset, address destination) internal virtual returns (bool success, uint256 amount) {
        amount = asset == _collateralAsset
            ? _getExtraCollateral()
            : asset == _fundsAsset
                ? _getExtraFunds()
                : IERC20(asset).balanceOf(address(this));

        success = ERC20Helper.transfer(asset, destination, amount);
    }

    /**************************************/
    /*** Internal Borrow-side Functions ***/
    /**************************************/

    function _drawdownFunds(uint256 amount, address destination) internal virtual returns (bool) {
        _drawableFunds -= amount;
        return ERC20Helper.transfer(_fundsAsset, destination, amount) && _collateralMaintained();
    }

    function _makePayments(uint256 numberOfPayments) internal virtual returns (uint256 totalAmountPaid) {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = _getPaymentsBreakdown(
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

        // The drawable funds are increased by the extra funds in the contract, minus the total needed for payment
        _drawableFunds = _drawableFunds + _getExtraFunds() - (totalAmountPaid = (totalPrincipalAmount + totalInterestFees + totalLateFees));

        _claimableFunds     += totalAmountPaid;
        _nextPaymentDueDate += _paymentInterval;
        _principal          -= totalPrincipalAmount;
        _paymentsRemaining  -= numberOfPayments;

        // TODO: How to ensure we don't end up with some principal remaining but no payments remaining?
        //       Perhaps force the last payment to include all outstanding principal, just in case _getPaymentsBreakdown produces a rounding error.
    }

    function _postCollateral() internal virtual returns (uint256 amount) {
        _collateral += (amount = _getExtraCollateral());
    }

    function _removeCollateral(uint256 amount, address destination) internal virtual returns (bool) {
        _collateral -= amount;
        return ERC20Helper.transfer(_collateralAsset, destination, amount) && _collateralMaintained();
    }

    function _returnFunds() internal virtual returns (uint256 amount) {
        _drawableFunds += (amount = _getExtraFunds());
    }

    /************************************/
    /*** Internal Lend-side Functions ***/
    /************************************/

    function _claimFunds(uint256 amount, address destination) internal virtual returns (bool) {
        _claimableFunds -= amount;
        return ERC20Helper.transfer(_fundsAsset, destination, amount) && _fundsMaintained();
    }

    function _lend(address lender) internal virtual returns (bool success, uint256 amount) {
        success = (_nextPaymentDueDate == uint256(0)) &&
                  (_paymentsRemaining != uint256(0)) &&
                  (_principalRequired == (_drawableFunds = _principal = amount = _getExtraFunds()));

        _lender             = lender;
        _nextPaymentDueDate = block.timestamp + _paymentInterval;
    }

    function _repossess() internal virtual returns (bool) {
        if (block.timestamp <= _nextPaymentDueDate + _gracePeriod) return false;

        _drawableFunds      = uint256(0);
        _claimableFunds     = uint256(0);
        _collateral         = uint256(0);
        _collateral         = uint256(0);
        _nextPaymentDueDate = uint256(0);
        _principal          = uint256(0);
        _paymentsRemaining  = uint256(0);

        return true;
    }

    /*******************************/
    /*** Internal View Functions ***/
    /*******************************/

    function _collateralMaintained() internal view returns (bool) {
        // Whether the final collateral ratio is commensurate with the amount of outstanding principal
        // uint256 outstandingPrincipal = principal > drawableFunds ? principal - drawableFunds : 0;
        // return collateral / outstandingPrincipal >= collateralRequired / principalRequired;
        return _collateral * _principalRequired >= _collateralRequired * (_principal > _drawableFunds ? _principal - _drawableFunds : uint256(0));
    }

    function _fundsMaintained() internal view returns (bool) {
        // Whether the final funds balance of the loan is sufficient
        return IERC20(_fundsAsset).balanceOf(address(this)) >=
            _drawableFunds + _claimableFunds + (_collateralAsset == _fundsAsset ? _collateral : uint256(0));
    }

    /**
     *  @dev Returns the amount of collateralAsset above what has been currently accounted for.
     */
    function _getExtraCollateral() internal view virtual returns (uint256) {
        return IERC20(_collateralAsset).balanceOf(address(this))
            - _collateral
            - (_collateralAsset == _fundsAsset ? _drawableFunds + _claimableFunds : uint256(0));
    }

    /**
     *  @dev Returns the amount of fundsAsset above what has been currently accounted for.
     */
    function _getExtraFunds() internal view virtual returns (uint256) {
        return IERC20(_fundsAsset).balanceOf(address(this))
            - _drawableFunds
            - _claimableFunds
            - (_collateralAsset == _fundsAsset ? _collateral : uint256(0));
    }

    /*******************************/
    /*** Internal Pure Functions ***/
    /*******************************/

    /**
     *  @dev Returns the fee by applying an annualized fee rate over an interval of time.
     */
    function _getFee(uint256 amount, uint256 feeRate, uint256 interval) internal pure virtual returns (uint256) {
        return amount * _getPeriodicFeeRate(feeRate, interval) / uint256(1_000_000);
    }

    /**
     *  @dev Returns principal and interest fee portions of a payment, given generic loan parameters.
     */
    function _getPayment(uint256 principal, uint256 endingPrincipal, uint256 interestRate, uint256 paymentInterval, uint256 totalPayments)
        internal pure virtual returns (uint256 principalAmount, uint256 interestAmount)
    {
        uint256 periodicRate = _getPeriodicFeeRate(interestRate, paymentInterval);
        uint256 raisedRate   = _scaledExponent(uint256(1_000_000) + periodicRate, totalPayments, uint256(1_000_000));

        // TODO: Check if raisedRate can be <= 1_000_000

        uint256 total =
            (
                (
                    (
                        (
                            principal * raisedRate
                        ) / uint256(1_000_000)
                    ) - endingPrincipal
                ) * periodicRate
            ) / (raisedRate - uint256(1_000_000));

        principalAmount = total - (interestAmount = _getFee(principal, interestRate, paymentInterval));
    }

    /**
     *  @dev Returns principal, interest fee, and late fee portions of a payment, given generic loan parameters and conditions.
     */
    function _getPaymentBreakdown(
        uint256 paymentDate,
        uint256 nextPaymentDueDate,
        uint256 paymentInterval,
        uint256 principal,
        uint256 endingPrincipal,
        uint256 interestRate,
        uint256 paymentsRemaining,
        uint256 lateFeeRate
    ) internal pure virtual returns (uint256 principalAmount, uint256 interestFee, uint256 lateFee) {
        // Get the expected principal and interest portions for the payment, as if it was on-time
        (principalAmount, interestFee) = _getPayment(principal, endingPrincipal, interestRate, paymentInterval, paymentsRemaining);

        // Determine how late the payment is
        uint256 secondsLate = paymentDate > nextPaymentDueDate ? paymentDate - nextPaymentDueDate : uint256(0);

        // Accumulate the potential late fees incurred on the expected interest portion
        lateFee = _getFee(interestFee, lateFeeRate, secondsLate);

        // Accumulate the interest and potential additional interest incurred in the late period
        interestFee += _getFee(principal, interestRate, secondsLate);
    }

    /**
     *  @dev Returns accumulated principal, interest fee, and late fee portions of several payments, given generic loan parameters and conditions.
     */
    function _getPaymentsBreakdown(
        uint256 numberOfPayments,
        uint256 currentTime,
        uint256 nextPaymentDueDate,
        uint256 paymentInterval,
        uint256 principal,
        uint256 endingPrincipal,
        uint256 interestRate,
        uint256 paymentsRemaining,
        uint256 lateFeeRate
    )
        internal pure virtual
        returns (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees)
    {
        // For each payments (current and late)
        for (; numberOfPayments > uint256(0); --numberOfPayments) {
            (uint256 principalAmount, uint256 interestFee, uint256 lateFee) = _getPaymentBreakdown(
                currentTime,
                nextPaymentDueDate,
                paymentInterval,
                principal,
                endingPrincipal,
                interestRate,
                paymentsRemaining--,
                lateFeeRate
            );

            // Update local variables
            totalPrincipalAmount += principalAmount;
            totalInterestFees    += interestFee;
            totalLateFees        += lateFee;
            nextPaymentDueDate   += paymentInterval;
            principal            -= principalAmount;
        }
    }

    /**
     *  @dev Returns the fee rate over an interval, given an annualized fee rate.
     */
    function _getPeriodicFeeRate(uint256 feeRate, uint256 interval) internal pure virtual returns (uint256) {
        return (feeRate * interval) / uint256(365 days);
    }

    /**
     *  @dev Returns exponentiation of a scaled base value.
     */
    function _scaledExponent(uint256 base, uint256 exponent, uint256 one) internal pure virtual returns (uint256) {
        return exponent == uint256(0) ? one : (base * _scaledExponent(base, exponent - uint256(1), one)) / one;
    }

}
