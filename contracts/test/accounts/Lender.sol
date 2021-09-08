// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ILoan } from "../../interfaces/ILoan.sol";

import { LoanUser } from "./LoanUser.sol";

contract Lender is LoanUser {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_claimFunds(address loan, uint256 amount, address destination) external {
        ILoan(loan).claimFunds(amount, destination);
    }

    function loan_repossess(address loan, address collateralAssetDestination, address fundsAssetDestination) external returns (
        uint256 collateralAssetAmount,
        uint256 fundsAssetAmount
    ) {
        return ILoan(loan).repossess(collateralAssetDestination, fundsAssetDestination);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_claimFunds(address loan, uint256 amount, address destination) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.claimFunds.selector, amount, destination));
    }

    function try_loan_repossess(address loan, address collateralAssetDestination, address fundsAssetDestination) external returns (bool ok) {
        (ok,) = loan.call(abi.encodeWithSelector(ILoan.repossess.selector, collateralAssetDestination, fundsAssetDestination));
    }

}
