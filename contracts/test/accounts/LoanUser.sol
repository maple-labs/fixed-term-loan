// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20User } from "../../../modules/erc20/contracts/test/accounts/ERC20User.sol";

import { IMapleLoan } from "../../interfaces/IMapleLoan.sol";

contract LoanUser is ERC20User {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_fundLoan(address loan_, address lender_, uint256 amount_) external returns (uint256 fundsLent_) {
        return IMapleLoan(loan_).fundLoan(lender_, amount_);
    }

    function loan_makePayment(address loan_, uint256 amount_) external returns (uint256 principal_, uint256 interest_, uint256 delegateFee_, uint256 treasuryFee_) {
        return IMapleLoan(loan_).makePayment(amount_);
    }

    function loan_postCollateral(address loan_, uint256 amount_) external returns (uint256 collateralPosted_) {
        return IMapleLoan(loan_).postCollateral(amount_);
    }

    function loan_returnFunds(address loan_, uint256 amount_) external returns (uint256 fundsReturned_) {
        return IMapleLoan(loan_).returnFunds(amount_);
    }

    function loan_skim(address loan_, address token_, address destination_) external returns (uint256 fundsReturned_) {
        return IMapleLoan(loan_).skim(token_, destination_);
    }

    function loan_closeLoan(address loan_, uint256 amount_) external returns (uint256 principal_, uint256 interest_, uint256 delegateFee_, uint256 treasuryFee_) {
        return IMapleLoan(loan_).closeLoan(amount_);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_fundLoan(address loan_, address lender_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.fundLoan.selector, lender_, amount_));
    }

    function try_loan_makePayment(address loan_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.makePayment.selector, amount_));
    }

    function try_loan_postCollateral(address loan_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.postCollateral.selector, amount_));
    }

    function try_loan_returnFunds(address loan_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.returnFunds.selector, amount_));
    }

    function try_loan_skim(address loan_, address token_, address destination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.skim.selector, token_, destination_));
    }

    function try_loan_closeLoan(address loan_, uint256 amount_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.closeLoan.selector, amount_));
    }

}
