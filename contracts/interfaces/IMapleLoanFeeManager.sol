// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IMapleLoanFeeManager {

    // TODO add proper natspec

    /**************************/
    /*** Mutating Functions ***/
    /**************************/

    /// @dev Called during `makePayment`
    function payServiceFees(address asset_, uint256 principalRequested_, uint256 interval_) external returns (uint256 feePaid_);

    /// @dev Called within `fundLoan` to pay the origination fee and save the pool and the poolDelegate for that loan
    function payOriginationFees(address asset_, uint256 principalRequested_, uint256 loanTerm_) external returns (uint256 feePaid_);

    /// @dev Update fee manager state as per loans terms
    function updateFeeTerms(uint256 adminOriginationFee_, uint256 adminFeeRate_) external;

    /// @dev Update platform fee rate for loan at fund and refinance
    function updatePlatformFeeRate() external;

    /**********************/
    /*** View Functions ***/
    /**********************/

    /// @dev Returns the origination fee for a loan
    function adminOriginationFee(address loan_) external view returns (uint256 adminOriginationFee_);

    /// @dev Returns both service fees for a given loan
    function getPaymentServiceFees(address loan_, uint256 principalRequested_, uint256 interval_) external view returns (uint256 adminFee_, uint256 platformFee_);

    /// @dev Returns the address of globals.
    function globals() external view returns (address globals_);

}
