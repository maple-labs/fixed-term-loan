// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { ILoanFactory } from "../../interfaces/ILoanFactory.sol"; 

contract Governor {

    /************************/
    /*** Direct Functions ***/
    /************************/
    function loanFactory_setGlobals(address loanFactory, address globals) external {
        ILoanFactory(loanFactory).setGlobals(globals); 
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/
    function try_loanFactory_setGlobals(address loanFactory, address globals) external returns (bool ok) {
        string memory sig = "setGlobals(address)";
        (ok,) = loanFactory.call(abi.encodeWithSignature(sig, globals));
    }

}
