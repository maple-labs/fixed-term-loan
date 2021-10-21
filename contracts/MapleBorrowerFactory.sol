// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ProxyFactory } from "../modules/proxy-factory/contracts/ProxyFactory.sol";

import { IMapleBorrower }        from "./interfaces/IMapleBorrower.sol";
import { IMapleBorrowerFactory } from "./interfaces/IMapleBorrowerFactory.sol";
import { IMapleGlobalsLike }     from "./interfaces/Interfaces.sol";

/// @title MapleBorrowerFactory facilitates the creation of the MapleBorrower contracts as proxies.
contract MapleBorrowerFactory is IMapleBorrowerFactory, ProxyFactory {

    address public override mapleGlobals;

    uint256 public override defaultVersion;

    mapping(address => uint256) public override nonceOf;

    mapping(uint256 => mapping(uint256 => bool)) public override upgradeEnabledForPath;

    constructor(address mapleGlobals_) {
        mapleGlobals = mapleGlobals_;
    }

    /********************************/
    /*** Administrative Functions ***/
    /********************************/

    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) override external {
        require(_isGovernor(msg.sender),                                 "MBF:DUP:NOT_GOVERNOR");
        require(fromVersion_ != toVersion_,                              "MBF:DUP:CANNOT_OVERWRITE_INITIALIZER");
        require(_registerMigrator(fromVersion_, toVersion_, address(0)), "MBF:DUP:FAILED");

        upgradeEnabledForPath[fromVersion_][toVersion_] = false;
        emit UpgradePathDisabled(fromVersion_, toVersion_);
    }

    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) override external {
        require(_isGovernor(msg.sender),                                "MBF:EUP:NOT_GOVERNOR");
        require(fromVersion_ != toVersion_,                             "MBF:EUP:CANNOT_OVERWRITE_INITIALIZER");
        require(_registerMigrator(fromVersion_, toVersion_, migrator_), "MBF:EUP:FAILED");

        upgradeEnabledForPath[fromVersion_][toVersion_] = true;
        emit UpgradePathEnabled(fromVersion_, toVersion_, migrator_);
    }

    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) override external {
        require(_isGovernor(msg.sender), "MBF:RI:NOT_GOVERNOR");

        // Version 0 reserved as "no version" since default `defaultVersion` is 0.
        require(version_ != uint256(0),                                    "MBF:RI:INVALID_VERSION");
        require(_registerImplementation(version_, implementationAddress_), "MBF:RI:FAIL_FOR_IMPLEMENTATION");

        // Set migrator for initialization, which understood as fromVersion == toVersion.
        require(_registerMigrator(version_, version_, initializer_), "MBF:RI:FAIL_FOR_MIGRATOR");

        // Updating the current version so new borrower always created with the same version and emits event.
        emit ImplementationRegistered(version_, implementationAddress_, initializer_);
    }

    function setDefaultVersion(uint256 version_) override external {
        require(_isGovernor(msg.sender), "MBF:SDV:NOT_GOVERNOR");

        // Version must be 0 (to disable creating borrowers) or be registered
        require(version_ == 0 || _implementationOf[version_] != address(0), "MBF:SDV:INVALID_VERSION");

        emit DefaultVersionSet(defaultVersion = version_);
    }

    /**************************/
    /*** Borrower Functions ***/
    /**************************/

    function createBorrower(bytes calldata arguments_) override external returns (address borrower_) {
        bool success_;
        ( success_, borrower_ ) = _newInstanceWithSalt(defaultVersion, arguments_, keccak256(abi.encodePacked(msg.sender, nonceOf[msg.sender]++)));
        require(success_, "MBF:CL:FAILED");

        emit BorrowerDeployed(defaultVersion, borrower_, arguments_);
    }

    // NOTE: The MapleBorrower implementation of MapleBorrower proxy contract defines the access control logic for its own upgrade.
    function upgradeBorrower(uint256 toVersion_, bytes calldata arguments_) override external {
        uint256 fromVersion_ = _versionOf[IMapleBorrower(msg.sender).implementation()];

        require(upgradeEnabledForPath[fromVersion_][toVersion_],      "MBF:UL:NOT_ALLOWED");
        require(_upgradeInstance(msg.sender, toVersion_, arguments_), "MBF:UL:FAILED");

        emit BorrowerUpgraded(msg.sender, fromVersion_, toVersion_, arguments_);
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function implementationOf(uint256 version_) override external view returns (address implementation_) {
        return _implementationOf[version_];
    }

    function isBorrower(address borrower_) override external view returns (bool isBorrower_) {
        return _isInstance(borrower_);
    }

    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) override external view returns (address migrator_) {
        return _migratorForPath[oldVersion_][newVersion_];
    }

    function versionOf(address implementation_) override external view returns (uint256 version_) {
        return _versionOf[implementation_];
    }

    /**************************/
    /*** Internal Functions ***/
    /**************************/

    function _isGovernor(address governor_) internal view returns (bool isGovernor_) {
        return governor_ == IMapleGlobalsLike(mapleGlobals).governor();
    }

}
