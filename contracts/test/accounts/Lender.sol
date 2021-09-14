// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ILoan } from "../../interfaces/ILoan.sol";

import { LoanUser } from "./LoanUser.sol";

contract Lender is LoanUser {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_claimFunds(address loan_, uint256 amount_, address destination_) external {
        ILoan(loan_).claimFunds(amount_, destination_);
    }

    function loan_repossess(address loan_, address collateralAssetDestination_, address fundsAssetDestination_)
        external returns (
            uint256 collateralAssetAmount_,
            uint256 fundsAssetAmount_
        )
    {
        return ILoan(loan_).repossess(collateralAssetDestination_, fundsAssetDestination_);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_claimFunds(address loan_, uint256 amount_, address destination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(ILoan.claimFunds.selector, amount_, destination_));
    }

    function try_loan_repossess(address loan_, address collateralAssetDestination_, address fundsAssetDestination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(ILoan.repossess.selector, collateralAssetDestination_, fundsAssetDestination_));
    }

}
