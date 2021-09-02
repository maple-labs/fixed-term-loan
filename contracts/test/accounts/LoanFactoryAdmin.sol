// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { ILoanFactory } from "../../interfaces/ILoanFactory.sol"; 

contract LoanFactoryAdmin {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loanFactory_pause(address factory) external {
        ILoanFactory(factory).pause(); 
    }

    function loanFactory_unpause(address factory) external {
        ILoanFactory(factory).unpause(); 
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loanFactory_pause(address factory) external returns (bool ok) {
        (ok,) = factory.call(abi.encodeWithSelector(ILoanFactory.pause.selector));
    }

    function try_loanFactory_unpause(address factory) external returns (bool ok) {
        (ok,) = factory.call(abi.encodeWithSelector(ILoanFactory.unpause.selector));
    }

}
