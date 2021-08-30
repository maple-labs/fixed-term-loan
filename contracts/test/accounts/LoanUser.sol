// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { IERC20 } from "../../../modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// TODO: this is missing LoanUser is BasicFundsTokenFDTUser, only possible when funds-distribution-token gets test accounts
import { ILoan } from "../../interfaces/ILoan.sol";

import { ERC20User } from "./ERC20User.sol";

contract LoanUser is ERC20User {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_makePayment(address loan) external {
        ILoan(loan).makePayment();
    }

    function loan_makeFullPayment(address loan) external {
        ILoan(loan).makeFullPayment();
    }

    function loan_unwind(address loan) external {
        ILoan(loan).unwind();
    }

    function loan_triggerDefault(address loan) external {
        ILoan(loan).triggerDefault();
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_makePayment(address loan) external returns (bool ok) {
        (ok,) = address(loan).call(abi.encodeWithSelector(ILoan.makePayment.selector));
    }

    function try_loan_makeFullPayment(address loan) external returns (bool ok) {
        (ok,) = address(loan).call(abi.encodeWithSelector(ILoan.makeFullPayment.selector));
    }

    function try_loan_unwind(address loan) external returns (bool ok) {
        (ok,) = address(loan).call(abi.encodeWithSelector(ILoan.unwind.selector));
    }

    function try_loan_triggerDefault(address loan) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.triggerDefault.selector));
    }

}
