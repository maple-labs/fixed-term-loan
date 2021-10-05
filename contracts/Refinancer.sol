// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { LoanPrimitive } from "./LoanPrimitive.sol";

/// @title Refinancer uses storage from Maple Loan
contract Refinancer is LoanPrimitive {

    /********************+**/
    /*** Loan Parameters ***/
    /******************+****/

    function setEndingPrincipal(uint256 newEndingPrincipal_) external {
        require(newEndingPrincipal_ <= _principal);

        _endingPrincipal = newEndingPrincipal_;
    }

    function setGracePeriod(uint256 newGracePeriod_) external {
        _gracePeriod = newGracePeriod_;
    }

    function setInterestRate(uint256 newInterestRate_) external {
        _interestRate = newInterestRate_;
    }

    function setPaymentInterval(uint256 newInterval_) external {
        _paymentInterval = newInterval_;
    }

}
