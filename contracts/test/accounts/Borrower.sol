// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ILoan } from "../../interfaces/ILoan.sol";

import { LoanUser } from "./LoanUser.sol";

contract Borrower is LoanUser {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_drawdownFunds(address loan, uint256 amount, address destination) external {
        ILoan(loan).drawdownFunds(amount, destination);
    }

    function loan_removeCollateral(address loan, uint256 amount, address destination) external {
        ILoan(loan).removeCollateral(amount, destination);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_drawdownFunds(address loan, uint256 amount, address destination) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.drawdownFunds.selector, amount, destination));
    }

    function try_loan_removeCollateral(address loan, uint256 amount, address destination) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.removeCollateral.selector, amount, destination));
    }

}
