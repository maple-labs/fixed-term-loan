// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

// TODO: Finish NatSpec

interface IMapleLoanFeeManager {

    /**************/
    /*** Events ***/
    /**************/

    /**
     *  @dev   New fee terms have been set.
     *  @param loan_                   The address of the loan contract.
     *  @param delegateOriginationFee_ The new value for delegate origination fee.
     *  @param delegateServiceFee_     The new value for delegate service fee.
     */
    event FeeTermsUpdated(address loan_, uint256 delegateOriginationFee_, uint256 delegateServiceFee_);

    /**
     *  @dev   New fee terms have been set.
     *  @param loan_               The address of the loan contract.
     *  @param platformServiceFee_ The new value for the platform service fee.
     */
    event PlatformServiceFeeUpdated(address loan_, uint256 platformServiceFee_);

    /**
     *  @dev   A fee payment was made.
     *  @param loan_               The address of the loan contract.
     *  @param delegateServiceFee_ The amount of delegate service fee paid.
     *  @param platformServiceFee_ The amount of platform service fee paid.
    */
    event ServiceFeesPaid(address loan_, uint256 delegateServiceFee_, uint256 platformServiceFee_);

    /*************************/
    /*** Payment Functions ***/
    /*************************/

    /**
     *  @dev    Called during `makePayment`, performs fee payments to the pool delegate and treasury.
     *  @param  asset_            The address asset in which fees were paid.
     *  @param  numberOfPayments_ The number of payments for which service fees will be paid.
     */
    function payServiceFees(address asset_, uint256 numberOfPayments_) external returns (uint256 feePaid_);

    /**
     *  @dev    Called during `fundLoan`, performs fee payments to poolDelegate and treasury.
     *  @param  asset_              The address asset in which fees were paid.
     *  @param  principalRequested_ The total amount of principal requested, which will be used to calcuate fees.
     *  @return feePaid_            The total amount of fees paid.
     */
    function payOriginationFees(address asset_, uint256 principalRequested_) external returns (uint256 feePaid_);

    /****************************/
    /*** Fee Update Functions ***/
    /****************************/

    /**
     *  @dev    Called during loan creation or refinance, sets the fee terms.
     *  @param  delegateOriginationFee_ The amount of delegate origination fee to be paid.
     *  @param  delegateServiceFee_     The amount of delegate service fee to be paid.
     */
    function updateDelegateFeeTerms(uint256 delegateOriginationFee_, uint256 delegateServiceFee_) external;

    /**
     *  @dev Function called by loans to update the saved platform service fee rate.
     */
    function updatePlatformServiceFee(uint256 principalRequested_, uint256 paymentInterval_) external;

    /**********************/
    /*** View Functions ***/
    /**********************/

    /**
     *  @dev    Gets the delegate origination fee for the given loan.
     *  @param  loan_                   The address of the loan contract.
     *  @return delegateOriginationFee_ The amount of origination to be paid to delegate.
     */
    function delegateOriginationFee(address loan_) external view returns (uint256 delegateOriginationFee_);

    /**
     *  @dev    Gets the global contract address.
     *  @return globals_ The address of the global contract.
     */
    function globals() external view returns (address globals_);

    /**
     *  @dev    Gets the delegate service fee rate for the given loan.
     *  @param  loan_               The address of the loan contract.
     *  @return delegateServiceFee_ The amount of delegate service fee to be paid.
     */
    function delegateServiceFee(address loan_) external view returns (uint256 delegateServiceFee_);

    /**
     *  @dev     Gets the platform fee rate for the given loan.
     *  @param   loan_              The address of the loan contract.
     *  @return  platformServiceFee The amount of platform service fee to be paid.
     */
    function platformServiceFee(address loan_) external view returns (uint256 platformServiceFee);

}
