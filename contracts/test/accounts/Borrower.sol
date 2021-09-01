// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { ILoan }        from "../../interfaces/ILoan.sol";
import { ILoanFactory } from "../../interfaces/ILoanFactory.sol";

import { LoanAdmin } from "./LoanAdmin.sol";
import { LoanUser }  from "./LoanUser.sol";

contract Borrower is LoanAdmin, LoanUser {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loanFactory_createLoan(
        address loanFactory,
        address liquidityAsset,
        address collateralAsset,
        address flFactory,
        address clFactory,
        uint256[5] memory specs,
        address[3] memory calcs
    )
        external returns (address loanAddress)
    {
        return ILoanFactory(loanFactory).createLoan(liquidityAsset, collateralAsset, flFactory, clFactory, specs, calcs); 
    }

    function loan_drawdown(address loan, uint256 amount) external {
        ILoan(loan).drawdown(amount);
    }

    function loan_setLoanAdmin(address loan, address loanAdmin, bool status) external {
        ILoan(loan).setLoanAdmin(loanAdmin, status);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loanFactory_createLoan(
        address loanFactory,
        address liquidityAsset,
        address collateralAsset,
        address flFactory,
        address clFactory,
        uint256[5] memory specs,
        address[3] memory calcs
    )
        external returns (bool ok)
    {
        (ok,) = loanFactory.call(
            abi.encodeWithSelector(ILoanFactory.createLoan.selector, liquidityAsset, collateralAsset, flFactory, clFactory, specs, calcs)
        );
    }

    function try_loan_drawdown(address loan, uint256 amount) external returns (bool ok) {
        (ok,) = address(loan).call(abi.encodeWithSelector(ILoan.drawdown.selector, amount));
    }

    function try_loan_setLoanAdmin(address loan, address loanAdmin, bool status) external returns (bool ok) {
        (ok,) = address(loan).call(abi.encodeWithSelector(ILoan.setLoanAdmin.selector, loanAdmin, status));
    }

}
