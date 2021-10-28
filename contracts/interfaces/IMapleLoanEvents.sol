// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

/// @title IMapleLoanEvents defines the events for a MapleLoan.
interface IMapleLoanEvents {

    /**
     *  @dev   Borrower was set to a new account.
     *  @param borrower_ The address of the new borrower.
     */
    event BorrowerSet(address indexed borrower_);

    /**
     *  @dev   Collateral was posted.
     *  @param amount_ The amount of collateral posted.
     */
    event CollateralPosted(uint256 amount_);

    /**
     *  @dev   Collateral was removed.
     *  @param amount_      The amount of collateral removed.
     *  @param destination_ The recipient of the collateral removed.
     */
    event CollateralRemoved(uint256 amount_, address indexed destination_);

    /**
     *  @dev   The loan was funded.
     *  @param lender_             The address of the lender.
     *  @param amount_             The amount funded.
     *  @param nextPaymentDueDate_ The due date of the next payment.
     */
    event Funded(address indexed lender_, uint256 amount_, uint256 nextPaymentDueDate_);

    /**
     *  @dev   Funds were claimed.
     *  @param amount_      The amount of funds claimed.
     *  @param destination_ The recipient of the funds claimed.
     */
    event FundsClaimed(uint256 amount_, address indexed destination_);

    /**
     *  @dev   Funds were drawn.
     *  @param amount_      The amount of funds drawn.
     *  @param destination_ The recipient of the funds drawn down.
     */
    event FundsDrawnDown(uint256 amount_, address indexed destination_);

    /**
     *  @dev   Funds were redirected on an additional `fundLoan` call.
     *  @param amount_      The amount of funds redirected.
     *  @param destination_ The recipient of the redirected funds.
     */
    event FundsRedirected(uint256 amount_, address indexed destination_);

    /**
     *  @dev   Funds were returned.
     *  @param amount_ The amount of funds returned.
     */
    event FundsReturned(uint256 amount_);

    /**
     *  @dev   The loan was initialized.
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
     *  @param fees_      Fee parameters:
     *                         [0]: earlyFee,
     *                         [1]: earlyFeeRate,
     *                         [2]: lateFee,
     *                         [3]: lateFeeRate.
     */
    event Initialized(address indexed borrower_, address[2] assets_, uint256[6] parameters_, uint256[3] amounts_, uint256[4] fees_);

    /**
     *  @dev   Lender was set to a new account.
     *  @param lender_ The address of the new lender.
     */
    event LenderSet(address indexed lender_);

    /**
     *  @dev  A refinance was proposed.
     *  @param refinanceCommitment_ The hash of the refinancer and calls proposed.
     *  @param refinancer_           The address that will execute the refinance.
     *  @param calls_               The individual calls for the refinancer contract.
     */
    event NewTermsAccepted(bytes32 refinanceCommitment_, address refinancer_, bytes[] calls_);

    /**
     *  @dev  A refinance was proposed.
     *  @param refinanceCommitment_ The hash of the refinancer and calls proposed.
     *  @param refinancer_           The address that will execute the refinance.
     *  @param calls_               The individual calls for the refinancer contract.
     */
    event NewTermsProposed(bytes32 refinanceCommitment_, address refinancer_, bytes[] calls_);

    /**
     *  @dev   Payments were made.
     *  @param principalPaid_    The portion of the total amount that went towards principal.
     *  @param interestPaid_     The portion of the total amount that went towards interest fees.
     */
    event PaymentMade(uint256 principalPaid_, uint256 interestPaid_);

    /**
     *  @dev   The loan was in default and funds and collateral was repossessed by the lender.
     *  @param collateralAssetAmount_ The amount of collateral asset repossessed.
     *  @param fundsAssetAmount_      The amount of funds asset repossessed.
     *  @param destination_           The recipient of the collateral and funds, if any.
     */
    event Repossessed(uint256 collateralAssetAmount_, uint256 fundsAssetAmount_, address indexed destination_);

}
