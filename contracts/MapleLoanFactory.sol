// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ProxyFactory } from "../modules/proxy-factory/contracts/ProxyFactory.sol";

import { IMapleGlobalsLike } from "./interfaces/Interfaces.sol";
import { IMapleLoan }        from "./interfaces/IMapleLoan.sol";
import { IMapleLoanFactory } from "./interfaces/IMapleLoanFactory.sol";

//// @title MapleLoanFactory facilitates the creation of the MapleLoan contracts as proxies.
contract MapleLoanFactory is IMapleLoanFactory, ProxyFactory {

    address public override mapleGlobals;

    uint256 public override defaultVersion;
    uint256 public override loanCount;

    mapping(uint256 => address) public override loanAtIndex;
    mapping(address => uint256) public override nonceOf;

    mapping(uint256 => mapping(uint256 => bool)) public override upgradeEnabledForPath;

    constructor(address mapleGlobals_) {
        mapleGlobals = mapleGlobals_;
    }

    /********************************/
    /*** Administrative Functions ***/
    /********************************/

    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) override external {
        require(_isGovernor(msg.sender),                                 "MLF:DUP:NOT_GOVERNOR");
        require(fromVersion_ != toVersion_,                              "MLF:DUP:CANNOT_OVERWRITE_INITIALIZER");
        require(_registerMigrator(fromVersion_, toVersion_, address(0)), "MLF:DUP:FAILED");

        upgradeEnabledForPath[fromVersion_][toVersion_] = false;
        emit UpgradePathDisabled(fromVersion_, toVersion_);
    }

    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) override external {
        require(_isGovernor(msg.sender),                                "MLF:EUP:NOT_GOVERNOR");
        require(fromVersion_ != toVersion_,                             "MLF:EUP:CANNOT_OVERWRITE_INITIALIZER");
        require(_registerMigrator(fromVersion_, toVersion_, migrator_), "MLF:EUP:FAILED");

        upgradeEnabledForPath[fromVersion_][toVersion_] = true;
        emit UpgradePathEnabled(fromVersion_, toVersion_, migrator_);
    }

    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) override external {
        require(_isGovernor(msg.sender), "MLF:RI:NOT_GOVERNOR");

        // Version 0 reserved as "no version" since default `defaultVersion` is 0.
        require(version_ != uint256(0),                                    "MLF:RI:INVALID_VERSION");
        require(_registerImplementation(version_, implementationAddress_), "MLF:RI:FAIL_FOR_IMPLEMENTATION");

        // Set migrator for initialization, which understood as fromVersion == toVersion.
        require(_registerMigrator(version_, version_, initializer_), "MLF:RI:FAIL_FOR_MIGRATOR");

        // Updating the current version so new loan always created with the same version and emits event.
        emit ImplementationRegistered(version_, implementationAddress_, initializer_);
    }

    function setDefaultVersion(uint256 version_) override external {
        require(_isGovernor(msg.sender), "MLF:SDV:NOT_GOVERNOR");

        // Version must be 0 (to disable creating loans) or be registered
        require(version_ == 0 || _implementationOf[version_] != address(0), "MLF:SDV:INVALID_VERSION");

        emit DefaultVersionSet(defaultVersion = version_);
    }

    /**********************/
    /*** Loan Functions ***/
    /**********************/

    function createLoan(bytes calldata arguments_) override external returns (address loan_) {
        bool success_;
        ( success_, loan_ ) = _newInstanceWithSalt(defaultVersion, arguments_, keccak256(abi.encodePacked(msg.sender, nonceOf[msg.sender]++)));
        require(success_, "MLF:CL:FAILED");

        emit LoanDeployed(defaultVersion, loanAtIndex[loanCount++] = loan_, arguments_);
    }

    // NOTE: The MapleLoan implementation of MapleLoan proxy contract defines the access control logic for its own upgrade.
    function upgradeLoan(uint256 toVersion_, bytes calldata arguments_) override external {
        uint256 fromVersion_ = _versionOf[IMapleLoan(msg.sender).implementation()];

        require(upgradeEnabledForPath[fromVersion_][toVersion_],      "MLF:UL:NOT_ALLOWED");
        require(_upgradeInstance(msg.sender, toVersion_, arguments_), "MLF:UL:FAILED");

        emit LoanUpgraded(msg.sender, fromVersion_, toVersion_, arguments_);
    }

    /************************/
    /*** Getter Functions ***/
    /************************/

    function implementationOf(uint256 version_) override external view returns (address implementation_) {
        return _implementationOf[version_];
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
