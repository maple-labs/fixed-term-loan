// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IProxied }     from "../modules/proxy-factory/contracts/interfaces/IProxied.sol";
import { ProxyFactory } from "../modules/proxy-factory/contracts/ProxyFactory.sol";

import { IMapleLoanFactory } from "./interfaces/IMapleLoanFactory.sol";
import { IMapleGlobalsLike } from "./interfaces/Interfaces.sol";

//// @title Factory to facilitate the creation of the Maple loans.
contract MapleLoanFactory is IMapleLoanFactory, ProxyFactory {

    address public override mapleGlobals;

    uint256 public override latestVersion;
    uint256 public override loanCount;

    mapping(uint256 => address) public override loans;
    mapping(address => uint256) public override nonces;

    constructor(address mapleGlobals_) {
        mapleGlobals = mapleGlobals_;
    }

    modifier onlyGovernor() {
        require(msg.sender == IMapleGlobalsLike(mapleGlobals).governor(), "MLF:UNAUTHORIZED_EXECUTION");
        _;
    }

    function implementationOf(uint256 version_) override external view returns (address implementation_) {
        return _implementationOf[version_];
    }

    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) override external view returns (address migrator_) {
        return _migratorForPath[oldVersion_][newVersion_];
    } 

    function versionOf(address implementation_) override external view returns (uint256 version_) {
        return _versionOf[implementation_];
    }

    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) onlyGovernor override external {
        // Version 0 reserved as "no version" since default `latestVersion` is 0.
        require(version_ != uint256(0),                                    "MLF:INVALID_VERSION");
        require(_registerImplementation(version_, implementationAddress_), "MLF:FAIL_TO_REGISTER");
        
        // Set migrator for initialization, which understood as fromVersion == toVersion.
        _registerMigrator(version_, version_, initializer_);

        // Updating the current version so new loan always created with the same version and emits event.
        emit ImplementationRegistered(latestVersion = version_, implementationAddress_, initializer_);
    }

    function createLoan(bytes calldata arguments_) override external returns (address loan_) {
        require(latestVersion != uint256(0), "MLF:NO_IMPLEMENTATION_ADDRESS_EXISTS");

        // Creating the salt for create2 opcode so that the msg.sender's nth loan has a predeterminate address
        bytes32 salt_ = keccak256(abi.encodePacked(msg.sender, nonces[msg.sender]));
        
        bool success_;
        (success_, loan_) = _newInstanceWithSalt(latestVersion, arguments_, salt_);
        require(success_, "MLF:UNABLE_TO_INSTANTIATE");
        
        ++loanCount;
        nonces[msg.sender]++;
        loans[loanCount] = loan_;
        
        emit LoanDeployed(latestVersion, loan_, arguments_);
    }

    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) onlyGovernor override external {
        require(toVersion_ != uint256(0),   "MLF:ZERO_VERSION_NOT_ALLOWED");
        require(toVersion_ >= fromVersion_, "MLF:INVALID_VERSION");
        
        _registerMigrator(fromVersion_, toVersion_, migrator_);
        emit UpgradePathEnabled(fromVersion_, toVersion_, migrator_);
    }

    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) onlyGovernor override external {
        _registerMigrator(fromVersion_, toVersion_, address(0));
        emit UpgradePathDisabled(fromVersion_, toVersion_);
    }

    // TODO: Controversial implementation need to decide how we are going to facilitate.
    function upgradeLoan(uint256 toVersion_, bytes calldata arguments_) override external {
        require(_upgradeInstance(msg.sender, toVersion_, arguments_), "MLF:UPGRADE_FAILED");
        emit LoanUpgraded(msg.sender, _versionOf[IProxied(msg.sender).implementation()], toVersion_, arguments_);
    }

}
