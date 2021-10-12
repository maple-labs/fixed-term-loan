// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

/// @title Refinancer uses storage from Maple Loan.
interface IRefinancer {

    /********************+**/
    /*** Loan Parameters ***/
    /******************+****/

    function setEndingPrincipal(uint256 endingPrincipal_) external;

    function setGracePeriod(uint256 gracePeriod_) external;

    function setInterestRate(uint256 interestRate_) external;

    function setPaymentInterval(uint256 paymentInterval_) external;

}
