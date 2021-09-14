// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ILoan } from "../../interfaces/ILoan.sol";

import { ERC20User } from "../../../modules/erc20/src/test/accounts/ERC20User.sol";

contract LoanUser is ERC20User {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_makePayment(address loan_) external returns (uint256 totalPrincipalAmount_, uint256 totalInterestFees_, uint256 totalLateFees_) {
        return ILoan(loan_).makePayment();
    }

    function loan_makePayments(address loan_, uint256 numberOfPayments_)
        external returns (
            uint256 totalPrincipalAmount_,
            uint256 totalInterestFees_,
            uint256 totalLateFees_
        )
    {
        return ILoan(loan_).makePayments(numberOfPayments_);
    }

    function loan_postCollateral(address loan_) external returns (uint256 amount_) {
        return ILoan(loan_).postCollateral();
    }

    function loan_returnFunds(address loan_) external returns (uint256 amount_) {
        return ILoan(loan_).returnFunds();
    }

    function loan_lend(address loan_, address lender_) external returns (uint256 amount_) {
        return ILoan(loan_).lend(lender_);
    }

    function loan_skim(address loan_, address asset_, address destination_) external returns (uint256 amount_) {
        return ILoan(loan_).skim(asset_, destination_);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_makePayment(address loan_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(ILoan.makePayment.selector));
    }

    function try_loan_makePayments(address loan_, uint256 numberOfPayments_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(ILoan.makePayments.selector, numberOfPayments_));
    }

    function try_loan_postCollateral(address loan_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(ILoan.postCollateral.selector));
    }

    function try_loan_returnFunds(address loan_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(ILoan.returnFunds.selector));
    }

    function try_loan_lend(address loan_, address lender_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(ILoan.lend.selector, lender_));
    }

    function try_loan_skim(address loan_, address asset_, address destination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(ILoan.skim.selector, asset_, destination_));
    }

}
