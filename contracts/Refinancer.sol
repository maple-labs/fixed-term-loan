// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IRefinancer } from "./interfaces/IRefinancer.sol";

import { MapleLoanInternals } from "./MapleLoanInternals.sol";

/// @title Refinancer uses storage from Maple Loan.
contract Refinancer is IRefinancer, MapleLoanInternals {

    function decreasePrincipal(uint256 amount_) external override {
        require(_drawableFunds >= amount_, "R:DP:OUTSTANDING_TOO_LARGE");

        _principal          -= amount_;
        _principalRequested -= amount_;
        _drawableFunds      -= amount_;

        require(_principal >= _endingPrincipal, "R:DP:BELOW_ENDING_PRINCIPAL");

        emit PrincipalDecreased(amount_);
    }

    function increasePrincipal(uint256 amount_) external override {
        _principal          += amount_;
        _principalRequested += amount_;
        _drawableFunds      += amount_;
        _claimableFunds     += _getUnaccountedAmount(_fundsAsset);

        emit PrincipalIncreased(amount_);
    }

    function setCollateralRequired(uint256 collateralRequired_) external override {
        emit CollateralRequiredSet(_collateralRequired = collateralRequired_);
    }

    function setEarlyFee(uint256 earlyFee_) external override {
        emit EarlyFeeSet(_earlyFee = earlyFee_);
    }

    function setEarlyFeeRate(uint256 earlyFeeRate_) external override {
        emit EarlyFeeRateSet(_earlyFeeRate = earlyFeeRate_);
    }

    function setEarlyInterestRateDiscount(uint256 earlyInterestRateDiscount_) external override {
        emit EarlyInterestRateDiscountSet(_earlyInterestRateDiscount = earlyInterestRateDiscount_);
    }

    function setEndingPrincipal(uint256 endingPrincipal_) external override {
        require(endingPrincipal_ <= _principal, "R:DP:ABOVE_CURRENT_PRINCIPAL");
        emit EndingPrincipalSet(_endingPrincipal = endingPrincipal_);
    }

    function setGracePeriod(uint256 gracePeriod_) external override {
        emit GracePeriodSet(_gracePeriod = gracePeriod_);
    }

    function setInterestRate(uint256 interestRate_) external override {
        emit InterestRateSet(_interestRate = interestRate_);
    }

    function setLateFee(uint256 lateFee_) external override {
        emit LateFeeSet(_lateFee = lateFee_);
    }

    function setLateFeeRate(uint256 lateFeeRate_) external override {
        emit LateFeeRateSet(_lateFeeRate = lateFeeRate_);
    }

    function setLateInterestRatePremium(uint256 lateInterestRatePremium_) external override {
        emit LateInterestRatePremiumSet(_lateInterestRatePremium = lateInterestRatePremium_);
    }

    function setPaymentInterval(uint256 paymentInterval_) external override {
        emit PaymentIntervalSet(_paymentInterval = paymentInterval_);
    }

    function setPaymentsRemaining(uint256 paymentsRemaining_) external override {
        emit PaymentsRemainingSet(_paymentsRemaining = paymentsRemaining_);
    }

}
