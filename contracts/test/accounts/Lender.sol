// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { ILoan } from "../../interfaces/ILoan.sol";

import { LoanUser } from "./LoanUser.sol";

contract Lender is LoanUser {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_fundLoan(address loan, uint256 amt, address account) external {
        ILoan(loan).fundLoan(account, amt);
    }


    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_fundLoan(address loan, address mintTo, uint256 amt) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.fundLoan.selector, mintTo, amt));
    }
}