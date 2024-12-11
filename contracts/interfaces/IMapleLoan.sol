// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleProxied } from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleLoanEvents } from "./IMapleLoanEvents.sol";

/// @title MapleLoan implements a primitive loan with additional functionality, and is intended to be proxied.
interface IMapleLoan is IMapleProxied, IMapleLoanEvents {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev The borrower of the loan, responsible for repayments.
     */
    function borrower() external view returns (address borrower_);

    /**
     *  @dev The fee rate (applied to principal) to close the loan.
     *       This value should be configured so that it is less expensive to close a loan with more than one payment remaining, but
     *       more expensive to close it if on the last payment.
     */
    function closingRate() external view returns (uint256 closingRate_);

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
     *  @dev The portion of principal to not be paid down as part of payment installments,
     *       which would need to be paid back upon final payment.
     *       If endingPrincipal = principal, loan is interest-only.
     */
    function endingPrincipal() external view returns (uint256 endingPrincipal_);

    /**
     *  @dev The address of the contract that handles payments of fees on behalf of the loan.
     */
    function feeManager() external view returns (address feeManager_);

    /**
     *  @dev The asset deposited by the lender to fund the loan.
     */
    function fundsAsset() external view returns (address fundsAsset_);

    /**
     *  @dev The Maple globals address
     */
    function globals() external view returns (address globals_);

    /**
     *  @dev The address of the Maple Governor.
     */
    function governor() external view returns (address governor_);

    /**
     *  @dev The amount of time the borrower has, after a payment is due, to make a payment before being in default.
     */
    function gracePeriod() external view returns (uint256 gracePeriod_);

    /**
     *  @dev The annualized interest rate (APR), in units of 1e18, (i.e. 1% is 0.01e18).
     */
    function interestRate() external view returns (uint256 interestRate_);

    /**
     *  @dev The rate charged at late payments.
     */
    function lateFeeRate() external view returns (uint256 lateFeeRate_);

    /**
     *  @dev The premium over the regular interest rate applied when paying late.
     */
    function lateInterestPremiumRate() external view returns (uint256 lateInterestPremiumRate_);

    /**
     *  @dev The lender of the Loan.
     */
    function lender() external view returns (address lender_);

    /**
     *  @dev Whether the loan terms have been accepted by the borrower.
     */
    function loanTermsAccepted() external view returns (bool loanTermsAccepted_);

    /**
     *  @dev The timestamp due date of the next payment.
     */
    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate_);

    /**
     *  @dev The saved original payment due date from a loan impairment.
     */
    function originalNextPaymentDueDate() external view returns (uint256 originalNextPaymentDueDate_);

    /**
     *  @dev The specified time between loan payments.
     */
    function paymentInterval() external view returns (uint256 paymentInterval_);

    /**
     *  @dev The number of payment installments remaining for the loan.
     */
    function paymentsRemaining() external view returns (uint256 paymentsRemaining_);

    /**
     *  @dev The address of the pending borrower.
     */
    function pendingBorrower() external view returns (address pendingBorrower_);

    /**
     *  @dev The address of the pending lender.
     */
    function pendingLender() external view returns (address pendingLender_);

    /**
     *  @dev The amount of principal owed (initially, the requested amount), which needs to be paid back.
     */
    function principal() external view returns (uint256 principal_);

    /**
     *  @dev The initial principal amount requested by the borrower.
     */
    function principalRequested() external view returns (uint256 principalRequested_);

    /**
     *  @dev The hash of the proposed refinance agreement.
     */
    function refinanceCommitment() external view returns (bytes32 refinanceCommitment_);

    /**
     *  @dev Amount of unpaid interest that has accrued before a refinance was accepted.
     */
    function refinanceInterest() external view returns (uint256 refinanceInterest_);

    /**************************************************************************************************************************************/
    /*** State Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev Accept the borrower role, must be called by pendingBorrower.
     */
    function acceptBorrower() external;

    /**
     *  @dev Accept the lender role, must be called by pendingLender.
     */
    function acceptLender() external;

    /**
     *  @dev Accept the loan terms, must be called by the borrower.
     */
    function acceptLoanTerms() external;

    /**
     *  @dev    Accept the proposed terms ans trigger refinance execution
     *  @param  refinancer_          The address of the refinancer contract.
     *  @param  deadline_            The deadline for accepting the new terms.
     *  @param  calls_               The encoded arguments to be passed to refinancer.
     *  @return refinanceCommitment_ The hash of the accepted refinance agreement.
     */
    function acceptNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    /**
     *  @dev    Repay all principal and interest and close a loan.
     *          FUNDS SHOULD NOT BE TRANSFERRED TO THIS CONTRACT NON-ATOMICALLY. IF THEY ARE, THE BALANCE MAY BE STOLEN USING `skim`.
     *  @param  amount_    An amount to pull from the caller, if any.
     *  @return principal_ The portion of the amount paying back principal.
     *  @return interest_  The portion of the amount paying interest.
     *  @return fees_      The portion of the amount paying service fees.
     */
    function closeLoan(uint256 amount_) external returns (uint256 principal_, uint256 interest_, uint256 fees_);

    /**
     *  @dev    Draw down funds from the loan.
     *  @param  amount_           The amount to draw down.
     *  @param  destination_      The address to send the funds.
     *  @return collateralPosted_ The amount of additional collateral posted, if any.
     */
    function drawdownFunds(uint256 amount_, address destination_) external returns (uint256 collateralPosted_);

    /**
     *  @dev    Lend funds to the loan/borrower.
     *  @return fundsLent_ The amount funded.
     */
    function fundLoan() external returns (uint256 fundsLent_);

    /**
     *  @dev Fast forward the next payment due date to the current time.
     *       This enables the pool delegate to force a payment (or default).
     */
    function impairLoan() external;

    /**
     *  @dev    Make a payment to the loan.
     *          FUNDS SHOULD NOT BE TRANSFERRED TO THIS CONTRACT NON-ATOMICALLY. IF THEY ARE, THE BALANCE MAY BE STOLEN USING `skim`.
     *  @param  amount_    An amount to pull from the caller, if any.
     *  @return principal_ The portion of the amount paying back principal.
     *  @return interest_  The portion of the amount paying interest fees.
     *  @return fees_      The portion of the amount paying service fees.
     */
    function makePayment(uint256 amount_) external returns (uint256 principal_, uint256 interest_, uint256 fees_);

    /**
     *  @dev    Post collateral to the loan.
     *          FUNDS SHOULD NOT BE TRANSFERRED TO THIS CONTRACT NON-ATOMICALLY. IF THEY ARE, THE BALANCE MAY BE STOLEN USING `skim`.
     *  @param  amount_           An amount to pull from the caller, if any.
     *  @return collateralPosted_ The amount posted.
     */
    function postCollateral(uint256 amount_) external returns (uint256 collateralPosted_);

    /**
     *  @dev    Propose new terms for refinance.
     *  @param  refinancer_          The address of the refinancer contract.
     *  @param  deadline_            The deadline for accepting the new terms.
     *  @param  calls_               The encoded arguments to be passed to refinancer.
     *  @return refinanceCommitment_ The hash of the proposed refinance agreement.
     */
    function proposeNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    /**
     *  @dev    Nullify the current proposed terms.
     *  @param  refinancer_          The address of the refinancer contract.
     *  @param  deadline_            The deadline for accepting the new terms.
     *  @param  calls_               The encoded arguments to be passed to refinancer.
     *  @return refinanceCommitment_ The hash of the rejected refinance agreement.
     */
    function rejectNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    /**
     *  @dev   Remove collateral from the loan (opposite of posting collateral).
     *  @param amount_      The amount removed.
     *  @param destination_ The destination to send the removed collateral.
     */
    function removeCollateral(uint256 amount_, address destination_) external;

    /**
     *  @dev Remove the loan impairment by restoring the original payment due date.
     */
    function removeLoanImpairment() external;

    /**
     *  @dev    Repossess collateral, and any funds, for a loan in default.
     *  @param  destination_           The address where the collateral and funds asset is to be sent, if any.
     *  @return collateralRepossessed_ The amount of collateral asset repossessed.
     *  @return fundsRepossessed_      The amount of funds asset repossessed.
     */
    function repossess(address destination_) external returns (uint256 collateralRepossessed_, uint256 fundsRepossessed_);

    /**
     *  @dev    Return funds to the loan (opposite of drawing down).
     *          FUNDS SHOULD NOT BE TRANSFERRED TO THIS CONTRACT NON-ATOMICALLY. IF THEY ARE, THE BALANCE MAY BE STOLEN USING `skim`.
     *  @param  amount_        An amount to pull from the caller, if any.
     *  @return fundsReturned_ The amount returned.
     */
    function returnFunds(uint256 amount_) external returns (uint256 fundsReturned_);

    /**
     *  @dev   Set the pendingBorrower to a new account.
     *  @param pendingBorrower_ The address of the new pendingBorrower.
     */
    function setPendingBorrower(address pendingBorrower_) external;

    /**
     *  @dev   Set the pendingLender to a new account.
     *  @param pendingLender_ The address of the new pendingLender.
     */
    function setPendingLender(address pendingLender_) external;

    /**
     *  @dev    Remove all token that is not accounted for by the loan (i.e. not `collateral` or `drawableFunds`).
     *  @param  token_       The address of the token contract.
     *  @param  destination_ The recipient of the token.
     *  @return skimmed_     The amount of token removed from the loan.
     */
    function skim(address token_, address destination_) external returns (uint256 skimmed_);

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the excess collateral that can be removed.
     *  @return excessCollateral_ The excess collateral that can be removed, if any.
     */
    function excessCollateral() external view returns (uint256 excessCollateral_);

    /**
     *  @dev    Get the additional collateral to be posted to drawdown some amount.
     *  @param  drawdown_             The amount desired to be drawn down.
     *  @return additionalCollateral_ The additional collateral that must be posted, if any.
     */
    function getAdditionalCollateralRequiredFor(uint256 drawdown_) external view returns (uint256 additionalCollateral_);

    /**
     *  @dev    Get the breakdown of the total payment needed to satisfy an early repayment to close the loan.
     *  @return principal_ The portion of the total amount that will go towards principal.
     *  @return interest_  The portion of the total amount that will go towards interest fees.
     *  @return fees_      The portion of the total amount that will go towards fees.
     */
    function getClosingPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

    /**
     *  @dev    Get the breakdown of the total payment needed to satisfy the next payment installment.
     *  @return principal_ The portion of the total amount that will go towards principal.
     *  @return interest_  The portion of the total amount that will go towards interest fees.
     *  @return fees_      The portion of the total amount that will go towards paying administrative fees.
     */
    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

    /**
     *  @dev    Get the detailed breakdown of the total payment needed to satisfy the next payment installment.
     *  @return principal_ The portion of the total amount that will go towards principal.
     *  @return interest_  The portion of the total amount that will go towards interest fees.
     *                      [0] Interest from the payment interval.
     *                      [1] Late interest.
     *                      [2] Refinance interest.
     *  @return fees_      The portion of the total amount that will go towards paying administrative fees.
     *                      [0] Delegate fees.
     *                      [1] Platform fees.
     */
    function getNextPaymentDetailedBreakdown()
        external view returns (uint256 principal_, uint256[3] memory interest_, uint256[2] memory fees_);

    /**
     *  @dev    Get the extra interest that will be charged according to loan terms before refinance, based on a given timestamp.
     *  @param  timestamp_       The timestamp when the new terms will be accepted.
     *  @return proRataInterest_ The interest portion to be added in the next payment.
     */
    function getRefinanceInterest(uint256 timestamp_) external view returns (uint256 proRataInterest_);

    /**
     *  @dev    Get the amount on an asset that in not accounted for by the accounting variables (and thus can be skimmed).
     *  @param  asset_             The address of a asset contract.
     *  @return unaccountedAmount_ The amount that is not accounted for.
     */
    function getUnaccountedAmount(address asset_) external view returns (uint256 unaccountedAmount_);

    /**
     *  @dev The value that represents 100%, to be easily comparable with the loan rates.
     */
    function HUNDRED_PERCENT() external pure returns (uint256 hundredPercent_);

    /**
     *  @dev    Return if the loan has been impaired.
     *  @return isImpaired_ Is the loan impaired or not.
     */
    function isImpaired() external view returns (bool isImpaired_);

}
