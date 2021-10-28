// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IMapleProxied } from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IOwnable } from "./IOwnable.sol";

/// @title MapleBorrower facilitates atomic and batch borrower functionality for MapleLoans.
interface IMapleBorrower is IMapleProxied, IOwnable {

    /***********************/
    /*** Batch Functions ***/
    /***********************/

    function batchDrawdownFunds(address[] calldata loans_, uint256[] calldata amounts_, address destination_) external;

    function batchMakePayment(address[] calldata loans_) external;

    function batchMakePayments(address[] calldata loans_, uint256[] calldata numberOfPayments_) external;

    function batchMakePaymentsWithCutoff(address[] calldata loans_, uint256 cutoffDate_) external;

    function batchPostCollateral(address[] calldata loans_, uint256[] calldata amounts_) external;

    function batchPostCollateralForDrawdown(address[] calldata loans_, uint256[] calldata drawdownAmounts_) external;

    function batchProposeNewTerms(address[] calldata loans_, address[] calldata refinancers_, bytes[][] calldata calls_) external;

    function batchRemoveExcessCollateral(address[] calldata loans_, address destination_) external;

    function batchRemoveCollateral(address[] calldata loans_, uint256[] calldata amounts_, address destination_) external;

    function batchReturnFunds(address[] calldata loans_, uint256[] calldata amounts_) external;

    function batchReturnFundsAndRemoveExcessCollateral(address[] calldata loans_, uint256[] calldata amounts_, address destination_) external;

    function batchSetBorrower(address[] calldata loans_, address borrower_) external;

    function batchUpgradeLoan(address[] calldata loans_, uint256[] calldata toVersions_, bytes[] calldata arguments_) external;

    /************************/
    /*** Single Functions ***/
    /************************/

    function drawdownFunds(address loan_, uint256 amount_, address destination_) external;

    function makePayment(address loan_) external;

    function makePayments(address loan_, uint256 numberOfPayments_) external;

    function makePaymentsWithCutoff(address loan_, uint256 cutoffDate_) external;

    function postCollateral(address loan_, uint256 amount_) external;

    function postCollateralForDrawdown(address loan_, uint256 drawdownAmount_) external;

    function proposeNewTerms(address loan_, address refinancer_, bytes[] calldata calls_) external;

    function removeExcessCollateral(address loan_, address destination_) external;

    function removeCollateral(address loan_, uint256 amount_, address destination_) external;

    function returnFunds(address loan_, uint256 amount_) external;

    function returnFundsAndRemoveExcessCollateral(address loan_, uint256 amount_, address destination_) external;

    function setBorrower(address loan_, address borrower_) external;

    function upgradeLoan(address loans_, uint256 toVersions_, bytes calldata arguments_) external;

}
