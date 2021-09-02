// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { ILoan }        from "../../interfaces/ILoan.sol"; 
import { ILoanFactory } from "../../interfaces/ILoanFactory.sol"; 

import { LoanFactoryAdmin } from "./LoanFactoryAdmin.sol";

contract Governor is LoanFactoryAdmin {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loanFactory_setGlobals(address factory, address globals) external {
        ILoanFactory(factory).setGlobals(globals); 
    }

    function loanFactory_setLoanFactoryAdmin(address factory, address loanFactoryAdmin, bool allowed) external {
        ILoanFactory(factory).setLoanFactoryAdmin(loanFactoryAdmin, allowed); 
    }

    function loan_reclaimERC20(address loan, address token) external {
        ILoan(loan).reclaimERC20(token);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loanFactory_setGlobals(address factory, address globals) external returns (bool ok) {
        (ok,) = factory.call(abi.encodeWithSelector(ILoanFactory.setGlobals.selector, globals));
    }

    function try_loanFactory_setLoanFactoryAdmin(address factory, address loanFactoryAdmin, bool allowed) external returns (bool ok) {
        (ok,) = factory.call(abi.encodeWithSelector(ILoanFactory.setLoanFactoryAdmin.selector, loanFactoryAdmin, allowed));
    }

    function try_loan_reclaimERC20(address loan, address token) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.reclaimERC20.selector, token));
    }

}
