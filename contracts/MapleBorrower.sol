// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IMapleProxyFactory } from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { IMapleBorrower } from "./interfaces/IMapleBorrower.sol";

import { MapleBorrowerInternals } from "./MapleBorrowerInternals.sol";

/// @title MapleBorrower facilitates atomic and batch borrower functionality for MapleLoans.
contract MapleBorrower is IMapleBorrower, MapleBorrowerInternals {

    /********************************/
    /*** Administrative Functions ***/
    /********************************/

    function migrate(address migrator_, bytes calldata arguments_) external override {
        require(msg.sender == _factory(),        "MB:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "MB:M:FAILED");
    }

    function setImplementation(address newImplementation_) external override {
        require(msg.sender == _factory(),               "MB:SI:NOT_FACTORY");
        require(_setImplementation(newImplementation_), "MB:SI:FAILED");
    }

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external override onlyOwner {
        IMapleProxyFactory(_factory()).upgradeInstance(toVersion_, arguments_);
    }

    /*************************/
    /*** Ownable Functions ***/
    /*************************/

    function acceptOwnership() external override {
        require(msg.sender == _pendingOwner, "MB:AO:NOT_PENDING_OWNER");

        _pendingOwner = address(0);

        emit OwnershipAccepted(_owner = msg.sender);
    }

    function transferOwnership(address account_) external override onlyOwner {
        emit OwnershipTransferPending(_pendingOwner = account_);
    }

    /***********************/
    /*** Batch Functions ***/
    /***********************/

    function batchDrawdownFunds(address[] calldata loans_, uint256[] calldata amounts_, address destination_) external override onlyOwner {
        for (uint256 i; i < loans_.length; ++i) {
            _drawdownFunds(loans_[i], amounts_[i], destination_);
        }
    }

    function batchMakePayment(address[] calldata loans_) external override {
        for (uint256 i; i < loans_.length; ++i) {
            _makePayment(loans_[i]);
        }
    }

    function batchMakePayments(address[] calldata loans_, uint256[] calldata numbersOfPayments_) external override {
        for (uint256 i; i < loans_.length; ++i) {
            _makePayments(loans_[i], numbersOfPayments_[i]);
        }
    }

    function batchMakePaymentsWithCutoff(address[] calldata loans_, uint256 cutoffDate_) external override {
        bool paymentWithinCutoff;

        for (uint256 i; i < loans_.length; ++i) {
            paymentWithinCutoff = paymentWithinCutoff || _makePaymentsWithCutoff(loans_[i], cutoffDate_);
        }

        require(paymentWithinCutoff, "MB:BMPWC:NONE_WITHIN_CUTOFF");
    }

    function batchPostCollateral(address[] calldata loans_, uint256[] calldata amounts_) external override {
        for (uint256 i; i < loans_.length; ++i) {
            _postCollateral(loans_[i], amounts_[i]);
        }
    }

    function batchPostCollateralForDrawdown(address[] calldata loans_, uint256[] calldata drawdownAmounts_) external override {
        bool needed;

        for (uint256 i; i < loans_.length; ++i) {
            needed = needed || _postCollateralForDrawdown(loans_[i], drawdownAmounts_[i]);
        }

        require(needed, "MB:BPCFD:NONE_NECESSARY");
    }

    function batchProposeNewTerms(
        address[] calldata loans_,
        address[] calldata refinancers_,
        bytes[][] calldata calls_
    ) external override onlyOwner {
        for (uint256 i; i < loans_.length; ++i) {
            _proposeNewTerms(loans_[i], refinancers_[i], calls_[i]);
        }
    }

    function batchRemoveAvailableCollateral(address[] calldata loans_, address destination_) external override onlyOwner {
        bool needed;

        for (uint256 i; i < loans_.length; ++i) {
            needed = needed || _removeAvailableCollateral(loans_[i], destination_);
        }

        require(needed, "MB:BRC:NONE_REMOVABLE");
    }

    function batchRemoveCollateral(address[] calldata loans_, uint256[] calldata amounts_, address destination_) external override onlyOwner {
        for (uint256 i; i < loans_.length; ++i) {
            _removeCollateral(loans_[i], amounts_[i], destination_);
        }
    }

    function batchReturnFunds(address[] calldata loans_, uint256[] calldata amounts_) external override {
        for (uint256 i; i < loans_.length; ++i) {
            _returnFunds(loans_[i], amounts_[i]);
        }
    }

    function batchReturnFundsAndRemoveCollateral(
        address[] calldata loans_,
        uint256[] calldata amounts_,
        address destination_
    ) external override onlyOwner {
        bool needed;

        for (uint256 i; i < loans_.length; ++i) {
            needed = needed || _returnFundsAndRemoveCollateral(loans_[i], amounts_[i], destination_);
        }

        require(needed, "MB:BRFARC:NONE_REMOVABLE");
    }

    function batchSetBorrower(address[] calldata loans_, address borrower_) external override onlyOwner {
        for (uint256 i; i < loans_.length; ++i) {
            _setBorrower(loans_[i], borrower_);
        }
    }

    function batchUpgradeLoan(address[] calldata loans_, uint256[] calldata toVersions_, bytes[] calldata arguments_) external override onlyOwner {
        for (uint256 i; i < loans_.length; ++i) {
            _upgradeLoan(loans_[i], toVersions_[i], arguments_[i]);
        }
    }

    /************************/
    /*** Single Functions ***/
    /************************/

    function drawdownFunds(address loan_, uint256 amount_, address destination_) external override onlyOwner {
        _drawdownFunds(loan_, amount_, destination_);
    }

    function makePayment(address loan_) external override {
        _makePayment(loan_);
    }

    function makePayments(address loan_, uint256 numberOfPayments_) external override {
        _makePayments(loan_, numberOfPayments_);
    }

    function makePaymentsWithCutoff(address loan_, uint256 cutoffDate_) external override {
        require(_makePaymentsWithCutoff(loan_, cutoffDate_), "MB:MPWC:NONE_WITHIN_CUTOFF");
    }

    function postCollateral(address loan_, uint256 amount_) external override {
        _postCollateral(loan_, amount_);
    }

    function postCollateralForDrawdown(address loan_, uint256 drawdownAmount_) external override {
        require(_postCollateralForDrawdown(loan_, drawdownAmount_), "MB:PCFD:NOT_NECESSARY");
    }

    function proposeNewTerms(address loan_, address refinancer_, bytes[] calldata calls_) external override onlyOwner {
        _proposeNewTerms(loan_, refinancer_, calls_);
    }

    function removeAvailableCollateral(address loan_, address destination_) external override onlyOwner {
        require(_removeAvailableCollateral(loan_, destination_), "MB:RC:NONE_REMOVABLE");
    }

    function removeCollateral(address loan_, uint256 amount_, address destination_) external override onlyOwner {
        _removeCollateral(loan_, amount_, destination_);
    }

    function returnFunds(address loan_, uint256 amount_) external override {
        _returnFunds(loan_, amount_);
    }

    function returnFundsAndRemoveCollateral(address loan_, uint256 amount_, address destination_) external override onlyOwner {
        require(_returnFundsAndRemoveCollateral(loan_, amount_, destination_), "MB:RFARC:NONE_REMOVABLE");
    }

    function setBorrower(address loan_, address borrower_) external override onlyOwner {
        _setBorrower(loan_, borrower_);
    }

    function upgradeLoan(address loans_, uint256 toVersions_, bytes calldata arguments_) external override onlyOwner {
        _upgradeLoan(loans_, toVersions_, arguments_);
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function factory() external view override returns (address factory_) {
        return _factory();
    }

    function implementation() external view override returns (address implementation_) {
        return _implementation();
    }

    function owner() external view override returns (address owner_) {
        return _owner;
    }

    function pendingOwner() external view override returns (address pendingOwner_) {
        return _pendingOwner;
    }

}
