// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IMapleProxied } from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleLoanEvents } from "./IMapleLoanEvents.sol";

/// @title MapleLoan implements a primitive loan with additional functionality, and is intended to be proxied.
interface IMapleLoan is IMapleProxied, IMapleLoanEvents {

    /***********************/
    /*** State Variables ***/
    /***********************/

    /**
     *  @dev The borrower of the loan, responsible for repayments.
     */
    function borrower() external view returns (address borrower_);

    /**
     *  @dev The amount of funds that have yet to be claimed by the lender.
     */
    function claimableFunds() external view returns (uint256 claimableFunds_);

    /**
     *  @dev The amount of collateral posted against outstanding (drawn down) principal.
     */
    function collateral() external view returns (uint256 collateral_);

    /**
     *  @dev The address of the asset deposited by the borrower as collateral, if needed.
     */
    function collateralAsset() external view returns (address collateralAsset_);

    /**
     *  @dev The amount of collateral required if all of the principal required is drawn down.
     */
    function collateralRequired() external view returns (uint256 collateralRequired_);

    /**
     *  @dev The amount of funds that have yet to be drawn down by the borrower.
     */
    function drawableFunds() external view returns (uint256 drawableFunds_);

    /**
     *  @dev The flat fee charged at early payments.
     */
    function earlyFee() external view returns (uint256 earlyFee_);

    /**
     *  @dev The rate charged at early payments.
     */
    function earlyFeeRate() external view returns (uint256 earlyFeeRate_);

    /**
     *  @dev The discount over the regular interest rate applied when paying early.
     */
    function earlyInterestRateDiscount() external view returns (uint256 earlyInterestRateDiscount_);

    /**
     *  @dev The portion of principal to not be paid down as part of payment installments, which would need to be paid back upon final payment.
     *  @dev If endingPrincipal = principal, loan is interest-only.
     */
    function endingPrincipal() external view returns (uint256 endingPrincipal_);

    /**
     *  @dev The asset deposited by the lender to fund the loan.
     */
    function fundsAsset() external view returns (address fundsAsset_);

    /**
     *  @dev The amount of time the borrower has, after a payment is due, to make a payment before being in default.
     */
    function gracePeriod() external view returns (uint256 gracePeriod_);

    /**
     *  @dev The annualized interest rate (APR), in basis points, scaled by 100 (i.e. 1% is 10_000).
     */
    function interestRate() external view returns (uint256 interestRate_);

    /**
     *  @dev The flat fee charged at late payments.
     */
    function lateFee() external view returns (uint256 lateFee_);

    /**
     *  @dev The rate charged at late payments.
     */
    function lateFeeRate() external view returns (uint256 lateFeeRate_);

    /**
     *  @dev The premium over the regular interest rate applied when paying late.
     */
    function lateInterestRatePremium() external view returns (uint256 lateInterestRatePremium_);

    /**
     *  @dev The lender of the Loan.
     */
    function lender() external view returns (address lender_);

    /**
     *  @dev The timestamp due date of the next payment.
     */
    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate_);

    /**
     *  @dev The specified time between loan payments.
     */
    function paymentInterval() external view returns (uint256 paymentInterval_);

    /**
     *  @dev The number of payment installments remaining for the loan.
     */
    function paymentsRemaining() external view returns (uint256 paymentsRemaining_);

    /**
     *  @dev The amount of principal owed (initially, the requested amount), which needs to be paid back.
     */
    function principal() external view returns (uint256 principal_);

    /**
     *  @dev The initial principal amount requested by the borrower.
     */
    function principalRequested() external view returns (uint256 principalRequested_);

    /********************************/
    /*** State Changing Functions ***/
    /********************************/

    /**
     *  @dev   Accept the proposed terms ans trigger refinance execution
     *  @param refinancer_ The address of the refinancer contract.
     *  @param calls_      The encoded arguments to be passed to refinancer.
     *  @param amount_    An amount to pull from the caller, if any.
     */
    function acceptNewTerms(address refinancer_, bytes[] calldata calls_, uint256 amount_) external;

    /**
     *  @dev   Claim funds that have been paid (principal, interest, and late fees).
     *  @param amount_      The amount to be claimed.
     *  @param destination_ The address to send the funds.
     */
    function claimFunds(uint256 amount_, address destination_) external;

    /**
     *  @dev   Draw down funds from the loan.
     *  @param amount_      The amount to draw down.
     *  @param destination_ The address to send the funds.
     */
    function drawdownFunds(uint256 amount_, address destination_) external;

    /**
     *  @dev    Lend funds to the loan/borrower.
     *  @param  lender_       The address to be registered as the lender.
     *  @param  amount_       An amount to pull from the caller, if any.
     *  @return amountFunded_ The amount funded.
     */
    function fundLoan(address lender_, uint256 amount_) external returns (uint256 amountFunded_);

    /**
     *  @dev    Make several installment payments to the loan.
     *  @param  numberOfPayments_ The number of payment installments to make.
     *  @param  amount_           An amount to pull from the caller, if any.
     *  @return principal_        The portion of the amount paid paying back principal.
     *  @return interest_         The portion of the amount paid paying interest fees.
     *  @return fees_             The portion of the amount paid paying late fees.
     */
    function makePayments(uint256 numberOfPayments_, uint256 amount_) external returns (uint256 principal_, uint256 interest_, uint256 fees_);

    /**
     *  @dev    Post collateral to the loan.
     *  @param  amount_       An amount to pull from the caller, if any.
     *  @return postedAmount_ The amount posted.
     */
    function postCollateral(uint256 amount_) external returns (uint256 postedAmount_);

    /**
     *  @dev   Propose new terms for refinance
     *  @param refinancer_ The address of the refinancer contract.
     *  @param calls_  The encoded arguments to be passed to refinancer.
     */
    function proposeNewTerms(address refinancer_, bytes[] calldata calls_) external;

    /**
     *  @dev   Remove collateral from the loan (opposite of posting collateral).
     *  @param amount_      The amount removed.
     *  @param destination_ The destination to send the removed collateral.
     */
    function removeCollateral(uint256 amount_, address destination_) external;

    /**
     *  @dev    Return funds to the loan (opposite of drawing down).
     *  @param  amount_         An amount to pull from the caller, if any.
     *  @return returnedAmount_ The amount returned.
     */
    function returnFunds(uint256 amount_) external returns (uint256 returnedAmount_);

    /**
     *  @dev    Repossess collateral, and any funds, for a loan in default.
     *  @param  destination_           The address where the collateral and funds asset is to be sent, if any.
     *  @return collateralAssetAmount_ The amount of collateral asset repossessed.
     *  @return fundsAssetAmount_      The amount of funds asset repossessed.
     */
    function repossess(address destination_) external returns (uint256 collateralAssetAmount_, uint256 fundsAssetAmount_);

    /**
     *  @dev    Set the borrower to a new account.
     *  @param  borrower_ The address of the new borrower.
     */
    function setBorrower(address borrower_) external;

    /**
     *  @dev    Set the lender to a new account.
     *  @param  lender_ The address of the new lender.
     */
    function setLender(address lender_) external;

    /**********************/
    /*** View Functions ***/
    /**********************/

    function getAdditionalCollateralRequiredFor(uint256 drawdownAmount_) external view returns (uint256 additionalCollateral_);

    /**
     *  @dev    Get the breakdown of the total payment needed to satisfy `numberOfPayments` payment installments.
     *  @param  numberOfPayments_     The number of payment installments.
     *  @return totalPrincipalAmount_ The portion of the total amount that will go towards principal.
     *  @return totalInterestFees_    The portion of the total amount that will go towards interest fees.
     *  @return totalLateFees_        The portion of the total amount that will go towards late fees.
     */
    function getNextPaymentsBreakDown(uint256 numberOfPayments_) external view returns (
        uint256 totalPrincipalAmount_,
        uint256 totalInterestFees_,
        uint256 totalLateFees_
    );

    function getRemovableCollateral() external view returns (uint256 removableCollateral_);

}
