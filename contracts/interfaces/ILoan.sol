// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

interface ILoan {

    /**************/
    /*** Events ***/
    /**************/

    /**
     *  @dev   Collateral was posted.
     *  @param amount The amount of collateral posted.
     */
    event CollateralPosted(uint256 amount);

    /**
     *  @dev   Collateral was removed.
     *  @param amount The amount of collateral removed.
     */
    event CollateralRemoved(uint256 amount);

    /**
     *  @dev   The loan was funded.
     *  @param lender             The address of the lender.
     *  @param nextPaymentDueDate The due date of the next payment.
     */
    event Funded(address indexed lender, uint256 nextPaymentDueDate);

    /**
     *  @dev   Funds were claimed.
     *  @param amount The amount of funds claimed.
     */
    event FundsClaimed(uint256 amount);

    /**
     *  @dev   Funds were drawn.
     *  @param amount The amount of funds drawn.
     */
    event FundsDrawnDown(uint256 amount);

    /**
     *  @dev   Funds were returned.
     *  @param amount The amount of funds returned.
     */
    event FundsReturned(uint256 amount);

    /**
     *  @dev   The loan was initialized.
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
    event Initialized(address indexed borrower, address[2] assets, uint256[6] parameters, uint256[2] requests);

    /**
     *  @dev   Payments were made.
     *  @param numberOfPayments The number of payment installments made.
     *  @param principalPaid    The portion of the total amount that went towards principal.
     *  @param interestPaid     The portion of the total amount that went towards interest fees.
     *  @param lateFeesPaid     The portion of the total amount that went towards late fees.
     */
    event PaymentsMade(uint256 numberOfPayments, uint256 principalPaid, uint256 interestPaid, uint256 lateFeesPaid);

    /**
     *  @dev   The loan was in default and funds and collateral was repossessed by the lender.
     *  @param collateralAssetAmount The amount of collateral asset repossessed.
     *  @param fundsAssetAmount      The amount of funds asset repossessed.
     */
    event Repossessed(uint256 collateralAssetAmount, uint256 fundsAssetAmount);

    /**
     *  @dev   Additional/unallocated asset was skimmed.
     *  @param asset       The address of the asset.
     *  @param destination The address where the asset was send.
     *  @param amount      The amount of the asset that was skimmed.
     */
    event Skimmed(address asset, address destination, uint256 amount);

    /***********************/
    /*** State Variables ***/
    /***********************/

    /**
     *  @dev The borrower of the loan, responsible for repayments.
     */
    function borrower() external view returns (address);

    /**
     *  @dev The amount of funds that have yet to be claimed by the lender.
     */
    function claimableFunds() external view returns (uint256);

    /**
     *  @dev The amount of collateral posted against outstanding (drawn down) principal.
     */
    function collateral() external view returns (uint256);

    /**
     *  @dev The address of the asset deposited by the borrower as collateral, if needed.
     */
    function collateralAsset() external view returns (address);

    /**
     *  @dev The amount of collateral required if all of the principal required is drawn down.
     */
    function collateralRequired() external view returns (uint256);

    /**
     *  @dev The amount of funds that have yet to be drawn down by the borrower.
     */
    function drawableFunds() external view returns (uint256);

    /**
     *  @dev The portion of principal to not be paid down as part of payment installments, which would need to be paid back upon final payment. 
     *  @dev If endingPrincipal = principal, loan is interest-only.
     */
    function endingPrincipal() external view returns (uint256);

    /**
     *  @dev The asset deposited by the lender to fund the loan.
     */
    function fundsAsset() external view returns (address);

    /**
     *  @dev The amount of time the borrower has, after a payment is due, to make a payment before being in default.
     */
    function gracePeriod() external view returns (uint256);

    /**
     *  @dev The annualized interest rate (APR), in basis points, scaled by 100 (i.e. 1% is 10_000).
     */
    function interestRate() external view returns (uint256);

    /**
     *  @dev The annualized fee rate charged on interest for late payments, in basis points, scaled by 100 (i.e. 1% is 10_000).
     */
    function lateFeeRate() external view returns (uint256);

    /**
     *  @dev The lender of the Loan.
     */
    function lender() external view returns (address);

    /**
     *  @dev The timestamp due date of the next payment.
     */
    function nextPaymentDueDate() external view returns (uint256);

    /**
     *  @dev The specified time between loan payments.
     */
    function paymentInterval() external view returns (uint256);

    /**
     *  @dev The number of payment installments remaining for the loan.
     */
    function paymentsRemaining() external view returns (uint256);

    /**
     *  @dev The amount of principal owed (initially, the requested amount), which needs to be paid back.
     */
    function principal() external view returns (uint256);

    /**
     *  @dev The initial principal amount requested by the borrower.
     */
    function principalRequired() external view returns (uint256);

    /********************************/
    /*** State Changing Functions ***/
    /********************************/

    /**
     *  @dev   Claim funds that have been paid (principal, interest, and late fees).
     *  @param amount      The amount to be claimed.
     *  @param destination The address to send the funds.
     */
    function claimFunds(uint256 amount, address destination) external;

    /**
     *  @dev   Draw down funds from the loan.
     *  @param amount      The amount to draw down.
     *  @param destination The address to send the funds.
     */
    function drawdownFunds(uint256 amount, address destination) external;

    /**
     *  @dev    Lend funds to the loan/borrower.
     *  @param  lender The address to be registered as the lender.
     *  @return The amount lent.
     */
    function lend(address lender) external returns (uint256);

    /**
     *  @dev    Make one installment payment to the loan.
     *  @return The amount paid.
     */
    function makePayment() external returns (uint256);

    /**
     *  @dev    Make several installment payments to the loan.
     *  @param  numberOfPayments The number of payment installments to make.
     *  @return The amount paid.
     */
    function makePayments(uint256 numberOfPayments) external returns (uint256);

    /**
     *  @dev    Post collateral to the loan.
     *  @return The amount posted.
     */
    function postCollateral() external returns (uint256);

    /**
     *  @dev   Remove collateral from the loan (opposite of posting collateral).
     *  @param amount      The amount removed.
     *  @param destination The destination to send the removed collateral.
     */
    function removeCollateral(uint256 amount, address destination) external;

    /**
     *  @dev    Return funds to the loan (opposite of drawing down).
     *  @return The amount returned.
     */
    function returnFunds() external returns (uint256);

    /**
     *  @dev    Repossess collateral, and any funds, for a loan in default.
     *  @param  collateralAssetDestination The address where the collateral asset is to be sent.
     *  @param  fundsAssetDestination      The address where the funds asset is to be sent.
     *  @return collateralAssetAmount      The amount of collateral asset repossessed.
     *  @return fundsAssetAmount           The amount of funds asset repossessed.
     */
    function repossess(address collateralAssetDestination, address fundsAssetDestination) external returns (
        uint256 collateralAssetAmount,
        uint256 fundsAssetAmount
    );

    /**************************/
    /*** Readonly Functions ***/
    /**************************/

    /**
     *  @dev    Get the breakdown of the total payment needed to satisfy `numberOfPayments` payment installments.
     *  @param  numberOfPayments     The number of payment installments.
     *  @return totalPrincipalAmount The portion of the total amount that will go towards principal.
     *  @return totalInterestFees    The portion of the total amount that will go towards interest fees.
     *  @return totalLateFees        The portion of the total amount that will go towards late fees.
     */
    function getNextPaymentsBreakDown(uint256 numberOfPayments) external view returns (
        uint256 totalPrincipalAmount,
        uint256 totalInterestFees,
        uint256 totalLateFees
    );

}
