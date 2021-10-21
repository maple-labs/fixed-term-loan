// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IProxied } from "../../modules/proxy-factory/contracts/interfaces/IProxied.sol";

import { IOwnable } from "./IOwnable.sol";

/// @title MapleBorrower facilitates atomic and batch borrower functionality for MapleLoans.
interface IMapleBorrower is IProxied, IOwnable {

    /********************************/
    /*** Administrative Functions ***/
    /********************************/

    /**
     *  @dev    Upgrade the MapleBorrower implementation used to a new version.
     *  @param  toVersion_ The MapleBorrower version to upgrade to.
     *  @param  arguments_ The encoded arguments used for migration, if any.
     */
    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

    /***********************/
    /*** Batch Functions ***/
    /***********************/

    function batchDrawdownFunds(address[] calldata loans_, uint256[] calldata amounts_, address destination_) external;

    function batchMakePayments(address[] calldata loans_, uint256[] calldata numberOfPayments_) external;

    function batchMakePaymentsWithCutoff(address[] calldata loans_, uint256 cutoffDate_) external;

    function batchPostCollateral(address[] calldata loans_, uint256[] calldata amounts_) external;

    function batchPostCollateralForDrawdown(address[] calldata loans_, uint256[] calldata drawdownAmounts_) external;

    function batchProposeNewTerms(address[] calldata loans_, address[] calldata refinancers_, bytes[][] calldata calls_) external;

    function batchRemoveAvailableCollateral(address[] calldata loans_, address destination_) external;

    function batchRemoveCollateral(address[] calldata loans_, uint256[] calldata amounts_, address destination_) external;

    function batchReturnFunds(address[] calldata loans_, uint256[] calldata amounts_) external;

    function batchReturnFundsAndRemoveCollateral(address[] calldata loans_, uint256[] calldata amounts_, address destination_) external;

    function batchSetBorrower(address[] calldata loans_, address borrower_) external;

    function batchUpgradeLoan(address[] calldata loans_, uint256[] calldata toVersions_, bytes[] calldata arguments_) external;

    /************************/
    /*** Single Functions ***/
    /************************/

    function drawdownFunds(address loan_, uint256 amount_, address destination_) external;

    function makePayments(address loan_, uint256 numberOfPayments_) external;

    function makePaymentsWithCutoff(address loan_, uint256 cutoffDate_) external;

    function postCollateral(address loan_, uint256 amount_) external;

    function postCollateralForDrawdown(address loan_, uint256 drawdownAmount_) external;

    function proposeNewTerms(address loan_, address refinancer_, bytes[] calldata calls_) external;

    function removeAvailableCollateral(address loan_, address destination_) external;

    function removeCollateral(address loan_, uint256 amount_, address destination_) external;

    function returnFunds(address loan_, uint256 amount_) external;

    function returnFundsAndRemoveCollateral(address loan_, uint256 amount_, address destination_) external;

    function setBorrower(address loan_, address borrower_) external;

    function upgradeLoan(address loans_, uint256 toVersions_, bytes calldata arguments_) external;

}
