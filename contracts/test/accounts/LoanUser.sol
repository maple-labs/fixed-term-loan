// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ILoan } from "../../interfaces/ILoan.sol";

import { ERC20User } from "../../../modules/erc20/src/test/accounts/ERC20User.sol";

contract LoanUser is ERC20User {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_makePayment(address loan) external returns (uint256, uint256, uint256) {
        return ILoan(loan).makePayment();
    }

    function loan_makePayments(address loan, uint256 numberOfPayments) external returns (uint256, uint256, uint256) {
        return ILoan(loan).makePayments(numberOfPayments);
    }

    function loan_postCollateral(address loan) external returns (uint256) {
        return ILoan(loan).postCollateral();
    }

    function loan_returnFunds(address loan) external returns (uint256) {
        return ILoan(loan).returnFunds();
    }

    function loan_lend(address loan, address lender) external returns (uint256) {
        return ILoan(loan).lend(lender);
    }

    function loan_skim(address loan, address asset, address destination) external returns (uint256) {
        return ILoan(loan).skim(asset, destination);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_makePayment(address loan) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.makePayment.selector));
    }

    function try_loan_makePayments(address loan, uint256 numberOfPayments) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.makePayments.selector, numberOfPayments));
    }

    function try_loan_postCollateral(address loan) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.postCollateral.selector));
    }

    function try_loan_returnFunds(address loan) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.returnFunds.selector));
    }

    function try_loan_lend(address loan, address lender) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.lend.selector, lender));
    }

    function try_loan_skim(address loan, address asset, address destination) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.skim.selector, asset, destination));
    }

}
