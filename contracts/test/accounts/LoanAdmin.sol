// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { ILoan } from "../../interfaces/ILoan.sol";

contract LoanAdmin {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function try_pause(address loan) external {
        ILoan(loan).pause();
    }

    function try_unpause(address loan) external {
        ILoan(loan).unpause();
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_pause(address loan) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.pause.selector));
    }

    function try_loan_unpause(address loan) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.unpause.selector));
    }

}
