// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IRefinancer } from "./interfaces/IRefinancer.sol";

import { LoanPrimitive } from "./LoanPrimitive.sol";

/// @title Refinancer uses storage from Maple Loan.
contract Refinancer is IRefinancer, LoanPrimitive {

    /********************+**/
    /*** Loan Parameters ***/
    /******************+****/

    function setEndingPrincipal(uint256 endingPrincipal_) external override {
        require(endingPrincipal_ <= _principal);

        _endingPrincipal = endingPrincipal_;
    }

    function setGracePeriod(uint256 gracePeriod_) external override {
        _gracePeriod = gracePeriod_;
    }

    function setInterestRate(uint256 interestRate_) external override {
        _interestRate = interestRate_;
    }

    function setPaymentInterval(uint256 paymentInterval_) external override {
        _paymentInterval = paymentInterval_;
    }

}
