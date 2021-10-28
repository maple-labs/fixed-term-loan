// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { User as ProxyUser } from "../../../modules/maple-proxy-factory/contracts/test/accounts/User.sol";

import { IMapleLoan } from "../../interfaces/IMapleLoan.sol";

import { LoanUser } from "./LoanUser.sol";

contract Borrower is LoanUser, ProxyUser {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function loan_drawdownFunds(address loan_, uint256 amount_, address destination_) external returns (uint256 collateralPosted_) {
        return IMapleLoan(loan_).drawdownFunds(amount_, destination_);
    }

    function loan_proposeNewTerms(address loan_, address refinancer_, bytes[] calldata calls_) external {
        IMapleLoan(loan_).proposeNewTerms(refinancer_, calls_);
    }

    function loan_removeCollateral(address loan_, uint256 amount_, address destination_) external {
        IMapleLoan(loan_).removeCollateral(amount_, destination_);
    }

    function loan_setBorrower(address loan_, uint256 toVersion_, bytes calldata arguments_) external {
        IMapleLoan(loan_).upgrade(toVersion_, arguments_);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_loan_drawdownFunds(address loan_, uint256 amount_, address destination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.drawdownFunds.selector, amount_, destination_));
    }

    function try_loan_proposeNewTerms(address loan_, address refinancer_, bytes[] calldata calls_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.proposeNewTerms.selector, refinancer_, calls_));
    }

    function try_loan_removeCollateral(address loan_, uint256 amount_, address destination_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.removeCollateral.selector, amount_, destination_));
    }

    function try_loan_setBorrower(address loan_, address borrower_) external returns (bool ok_) {
        ( ok_, ) = loan_.call(abi.encodeWithSelector(IMapleLoan.setBorrower.selector, borrower_));
    }

}
