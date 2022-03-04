// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleLoan } from "../../interfaces/IMapleLoan.sol";

import { LoanUser } from "./LoanUser.sol";

contract Lender is LoanUser {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_acceptLender(address loan_) external {
        IMapleLoan(loan_).acceptLender();
    }

    function loan_acceptNewTerms(address loan_, address refinancer_, uint256 deadline_, bytes[] calldata calls_, uint256 amount_) external {
        IMapleLoan(loan_).acceptNewTerms(refinancer_, deadline_, calls_, amount_);
    }

    function loan_claimFunds(address loan_, uint256 amount_, address destination_) external {
        IMapleLoan(loan_).claimFunds(amount_, destination_);
    }

    function loan_repossess(address loan_, address destination_) external returns ( uint256 collateralRepossessed_, uint256 fundsRepossessed_) {
        return IMapleLoan(loan_).repossess(destination_);
    }

    function loan_setPendingLender(address loan_, address lender_) external {
        IMapleLoan(loan_).setPendingLender(lender_);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_acceptNewTerms(address loan_, address refinancer_, uint256 deadline_, bytes[] calldata calls_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.acceptNewTerms.selector, refinancer_, deadline_, calls_, amount_));
    }

    function try_loan_claimFunds(address loan_, uint256 amount_, address destination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.claimFunds.selector, amount_, destination_));
    }

    function try_loan_repossess(address loan_, address destination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.repossess.selector, destination_));
    }

    function try_loan_setPendingLender(address loan_, address lender_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.setPendingLender.selector, lender_));
    }

    function try_loan_acceptLender(address loan_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.acceptLender.selector));
    }

}
