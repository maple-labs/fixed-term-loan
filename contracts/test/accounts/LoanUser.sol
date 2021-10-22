// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ERC20User } from "../../../modules/erc20/src/test/accounts/ERC20User.sol";

import { IMapleLoan } from "../../interfaces/IMapleLoan.sol";

contract LoanUser is ERC20User {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_makePayments(address loan_, uint256 numberOfPayments_, uint256 amount_)
        external returns (
            uint256 totalPrincipalAmount_,
            uint256 totalInterestFees_,
            uint256 totalLateFees_
        )
    {
        return IMapleLoan(loan_).makePayments(numberOfPayments_, amount_);
    }

    function loan_postCollateral(address loan_, uint256 amount_) external returns (uint256 postedAmount_) {
        return IMapleLoan(loan_).postCollateral(amount_);
    }

    function loan_returnFunds(address loan_, uint256 amount_) external returns (uint256 returnedAmount_) {
        return IMapleLoan(loan_).returnFunds(amount_);
    }

    function loan_fundLoan(address loan_, address lender_, uint256 amount_) external returns (uint256 amountFunded_) {
        return IMapleLoan(loan_).fundLoan(lender_, amount_);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_makePayments(address loan_, uint256 numberOfPayments_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.makePayments.selector, numberOfPayments_, amount_));
    }

    function try_loan_postCollateral(address loan_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.postCollateral.selector, amount_));
    }

    function try_loan_returnFunds(address loan_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.returnFunds.selector, amount_));
    }

    function try_loan_fundLoan(address loan_, address lender_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.fundLoan.selector, lender_, amount_));
    }

}
