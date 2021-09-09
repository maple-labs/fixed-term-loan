// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { LoanPrimitive } from "../../LoanPrimitive.sol";

contract LoanPrimitiveHarness is LoanPrimitive {

    function getUnaccountedAmount(address asset) external view returns (uint256) {
        return _getUnaccountedAmount(asset);
    }

    function initialize(address _borrower, address[2] memory _assets, uint256[6] memory _parameters, uint256[2] memory _requests) external {
        _initialize(_borrower, _assets, _parameters, _requests) ;
    }

    function skim(address _asset, address _destination) external returns (bool, uint256) {
        return _skim(_asset, _destination);
    }

    function getFee(uint256 _amount, uint256 _feeRate, uint256 _interval) external pure returns (uint256) {
        return _getFee(_amount, _feeRate, _interval);
    }

    function getInstallment(
        uint256 _principal,
        uint256 _endingPrincipal,
        uint256 _interestRate,
        uint256 _paymentInterval,
        uint256 _totalPayments
    )
        external pure returns (uint256 principalAmount, uint256 interestAmount)
    {
        return _getInstallment(_principal, _endingPrincipal, _interestRate, _paymentInterval, _totalPayments);
    }

    function getPaymentBreakdown(
        uint256 _paymentDate,
        uint256 _nextPaymentDueDate,
        uint256 _paymentInterval,
        uint256 _principal,
        uint256 _endingPrincipal,
        uint256 _interestRate,
        uint256 _paymentsRemaining,
        uint256 _lateFeeRate
    )
        external pure returns (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees)
    {
        return _getPaymentBreakdown(
            _paymentDate,
            _nextPaymentDueDate,
            _paymentInterval,
            _principal,
            _endingPrincipal,
            _interestRate,
            _paymentsRemaining,
            _lateFeeRate
        );
    }

    function getPaymentsBreakdown(
        uint256 _numberOfPayments,
        uint256 _currentTime,
        uint256 _nextPaymentDueDate,
        uint256 _paymentInterval,
        uint256 _principal,
        uint256 _endingPrincipal,
        uint256 _interestRate,
        uint256 _paymentsRemaining,
        uint256 _lateFeeRate
    )
        external pure 
        returns (
            uint256 totalPrincipalAmount,
            uint256 totalInterestFees,
            uint256 totalLateFees
        )
    {
        return _getPaymentsBreakdown(
            _numberOfPayments,
            _currentTime,
            _nextPaymentDueDate,
            _paymentInterval,
            _principal,
            _endingPrincipal,
            _interestRate,
            _paymentsRemaining,
            _lateFeeRate
        );
    }

    function getPeriodicFeeRate(uint256 _feeRate, uint256 _interval) external pure returns (uint256) {
        return _getPeriodicFeeRate(_feeRate, _interval);
    }

    function scaledExponent(uint256 base, uint256 exponent, uint256 one) external pure returns (uint256) {
        return _scaledExponent(base, exponent, one);
    }

}
