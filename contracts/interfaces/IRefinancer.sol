// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

/// @title Refinancer uses storage from Maple Loan.
interface IRefinancer {

    /**************/
    /*** Events ***/
    /**************/

    /**
     *  @dev   A new value for collateralRequired has been set.
     *  @param collateralRequired_ The new value for collateralRequired.
     */
    event CollateralRequiredSet(uint256 collateralRequired_);

    /**
     *  @dev   A new value for EarlyFee has been set.
     *  @param earlyFee_ The new value for earlyFee.
     */
    event EarlyFeeSet(uint256 earlyFee_);

    /**
     *  @dev   A new value for earlyFeeRate has been set.
     *  @param earlyFeeRate_ The new value for earlyFeeRate.
     */
    event EarlyFeeRateSet(uint256 earlyFeeRate_);

    /**
     *  @dev   A new value for earlyInterestRateDiscount has been set.
     *  @param earlyInterestRateDiscount_ The new value for earlyInterestRateDiscount.
     */
    event EarlyInterestRateDiscountSet(uint256 earlyInterestRateDiscount_);

    /**
     *  @dev   A new value for endingPrincipal has been set.
     *  @param endingPrincipal_ The new value for endingPrincipal.
     */
    event EndingPrincipalSet(uint256 endingPrincipal_);

    /**
     *  @dev   A new value for gracePeriod has been set.
     *  @param gracePeriod_ The new value for gracePeriod.
     */
    event GracePeriodSet(uint256 gracePeriod_);

    /**
     *  @dev   A new value for interestRate has been set.
     *  @param interestRate_ The new value for interestRate.
     */
    event InterestRateSet(uint256 interestRate_);

    /**
     *  @dev   A new value for lateFee has been set.
     *  @param lateFee_ The new value for lateFee.
     */
    event LateFeeSet(uint256 lateFee_);

    /**
     *  @dev   A new value for lateFeeRate has been set.
     *  @param lateFeeRate_ The new value for lateFeeRate.
     */
    event LateFeeRateSet(uint256 lateFeeRate_);

    /**
     *  @dev   A new value for lateInterestRatePremium has been set.
     *  @param lateInterestRatePremium_ The new value for lateInterestRatePremium.
     */
    event LateInterestRatePremiumSet(uint256 lateInterestRatePremium_);

    /**
     *  @dev   A new value for paymentInterval has been set.
     *  @param paymentInterval_ The new value for paymentInterval.
     */
    event PaymentIntervalSet(uint256 paymentInterval_);

    /**
     *  @dev   A new value for paymentsRemaining has been set.
     *  @param paymentsRemaining_ The new value for paymentsRemaining.
     */
    event PaymentsRemainingSet(uint256 paymentsRemaining_);

    /**
     *  @dev   The value of the principal has been decreased.
     *  @param decreasedBy_ The amount of which the value was decreased by.
     */
    event PrincipalDecreased(uint256 decreasedBy_);

    /**
     *  @dev   The value of the principal has been increased.
     *  @param increasedBy_ The amount of which the value was increased by.
     */
    event PrincipalIncreased(uint256 increasedBy_);

    /*****************/
    /*** Functions ***/
    /*****************/

    /**
     *  @dev   Function to decrease the principal during a refinance.
     *  @param amount_ The amount of which the value will decrease by.
     */
    function decreasePrincipal(uint256 amount_) external;

    /**
     *  @dev   Function to increase the principal during a refinance.
     *  @param amount_ The amount of which the value will increase by.
     */
    function increasePrincipal(uint256 amount_) external;

    /**
     *  @dev   Function to set the collateralRequired_ during a refinance.
     *  @param collateralRequired_ The new value for collateralRequired_.
     */
    function setCollateralRequired(uint256 collateralRequired_) external;

    /**
     *  @dev   Function to set the earlyFee_ during a refinance.
     *  @param earlyFee_ The new value for earlyFee_.
     */
    function setEarlyFee(uint256 earlyFee_) external;

    /**
     *  @dev   Function to set the earlyFeeRate_ during a refinance.
     *  @param earlyFeeRate_ The new value for earlyFeeRate_.
     */
    function setEarlyFeeRate(uint256 earlyFeeRate_) external;

    /**
     *  @dev   Function to set the earlyInterestRateDiscount_ during a refinance.
     *  @param earlyInterestRateDiscount_ The new value for earlyInterestRateDiscount_.
     */
    function setEarlyInterestRateDiscount(uint256 earlyInterestRateDiscount_) external;

    /**
     *  @dev   Function to set the endingPrincipal_ during a refinance.
     *  @param endingPrincipal_ The new value for endingPrincipal_.
     */
    function setEndingPrincipal(uint256 endingPrincipal_) external;

    /**
     *  @dev   Function to set the gracePeriod_ during a refinance.
     *  @param gracePeriod_ The new value for gracePeriod_.
     */
    function setGracePeriod(uint256 gracePeriod_) external;

    /**
     *  @dev   Function to set the interestRate_ during a refinance.
     *  @param interestRate_ The new value for interestRate_.
     */
    function setInterestRate(uint256 interestRate_) external;

    /**
     *  @dev   Function to set the lateFee_ during a refinance.
     *  @param lateFee_ The new value for lateFee_.
     */
    function setLateFee(uint256 lateFee_) external;

    /**
     *  @dev   Function to set the lateFeeRate_ during a refinance.
     *  @param lateFeeRate_ The new value for lateFeeRate_.
     */
    function setLateFeeRate(uint256 lateFeeRate_) external;

    /**
     *  @dev   Function to set the lateInterestRatePremium_ during a refinance.
     *  @param lateInterestRatePremium_ The new value for lateInterestRatePremium_.
     */
    function setLateInterestRatePremium(uint256 lateInterestRatePremium_) external;

    /**
     *  @dev   Function to set the paymentInterval_ during a refinance.
     *  @param paymentInterval_ The new value for paymentInterval_.
     */
    function setPaymentInterval(uint256 paymentInterval_) external;

    /**
     *  @dev   Function to set the paymentsRemaining_ during a refinance.
     *  @param paymentsRemaining_ The new value for paymentsRemaining_.
     */
    function setPaymentsRemaining(uint256 paymentsRemaining_) external;

}
