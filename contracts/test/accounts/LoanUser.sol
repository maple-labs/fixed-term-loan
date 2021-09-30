// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ERC20User } from "../../../modules/erc20/src/test/accounts/ERC20User.sol";

import { IMapleLoan } from "../../interfaces/IMapleLoan.sol";

contract LoanUser is ERC20User {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_makePayment(address loan_) external returns (uint256 totalPrincipalAmount_, uint256 totalInterestFees_, uint256 totalLateFees_) {
        return IMapleLoan(loan_).makePayment();
    }

    function loan_makePayments(address loan_, uint256 numberOfPayments_)
        external returns (
            uint256 totalPrincipalAmount_,
            uint256 totalInterestFees_,
            uint256 totalLateFees_
        )
    {
        return IMapleLoan(loan_).makePayments(numberOfPayments_);
    }

    function loan_postCollateral(address loan_) external returns (uint256 amount_) {
        return IMapleLoan(loan_).postCollateral();
    }

    function loan_returnFunds(address loan_) external returns (uint256 amount_) {
        return IMapleLoan(loan_).returnFunds();
    }

    function loan_fundLoan(address loan_, address lender_, uint256 amount_) external returns (uint256 amountFunded_) {
        IMapleLoan(loan_).fundLoan(lender_, amount_);
    }

    function loan_skim(address loan_, address asset_, address destination_) external returns (uint256 amount_) {
        return IMapleLoan(loan_).skim(asset_, destination_);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_makePayment(address loan_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.makePayment.selector));
    }

    function try_loan_makePayments(address loan_, uint256 numberOfPayments_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.makePayments.selector, numberOfPayments_));
    }

    function try_loan_postCollateral(address loan_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.postCollateral.selector));
    }

    function try_loan_returnFunds(address loan_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.returnFunds.selector));
    }

    function try_loan_fundLoan(address loan_, address lender_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.fundLoan.selector, lender_, amount_));
    }

    function try_loan_skim(address loan_, address asset_, address destination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.skim.selector, asset_, destination_));
    }

}
