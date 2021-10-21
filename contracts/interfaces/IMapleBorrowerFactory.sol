// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

/// @title MapleBorrowerFactory facilitates the creation of the MapleBorrower contracts as proxies.
interface IMapleBorrowerFactory {

    /**************/
    /*** Events ***/
    /**************/

    /**
     *  @dev   A default MapleBorrower version was set.
     *  @param version The default MapleBorrower version.
     */
    event DefaultVersionSet(uint256 indexed version);

    /**
     *  @dev   A version of a MapleBorrower implementation, at some address, was registered, with an optional initializer.
     *  @param version               The version of the MapleBorrower registered.
     *  @param implementationAddress The address of the MapleBorrower implementation.
     *  @param initializer           The address of the MapleBorrowerInitializer, if any.
     */
    event ImplementationRegistered(uint256 indexed version, address indexed implementationAddress, address indexed initializer);

    /**
     *  @dev   A MapleBorrower proxy contract was deployed with some initialization arguments.
     *  @param version                 The version of the MapleBorrower implementation being proxied by the deployed MapleBorrower proxy contract.
     *  @param borrower                The address of the MapleBorrower proxy contract deployed.
     *  @param initializationArguments The arguments used to initialize the MapleBorrower proxy contract, if any.
     */
    event BorrowerDeployed(uint256 indexed version, address indexed borrower, bytes initializationArguments);

    /**
     *  @dev   A MapleBorrower has upgraded by proxying to a new implementation version, with some migration arguments.
     *  @param borrower           The address of the MapleBorrower proxy contract.
     *  @param fromVersion        The initial version of the MapleBorrower.
     *  @param toVersion          The version the MapleBorrower was upgraded to.
     *  @param migrationArguments The arguments used to migrate the MapleBorrower proxy contract, if any.
     */
    event BorrowerUpgraded(address indexed borrower, uint256 indexed fromVersion, uint256 indexed toVersion, bytes migrationArguments);

    /**
     *  @dev   An upgrade path was disabled, with an optional migrator contract.
     *  @param fromVersion The starting version of the upgrade path.
     *  @param toVersion   The destination version of the upgrade path.
     */
    event UpgradePathDisabled(uint256 indexed fromVersion, uint256 indexed toVersion);

    /**
     *  @dev   An upgrade path was enabled, with an optional migrator contract.
     *  @param fromVersion The starting version of the upgrade path.
     *  @param toVersion   The destination version of the upgrade path.
     *  @param migrator    The address of the MapleBorrowerMigrator, if any.
     */
    event UpgradePathEnabled(uint256 indexed fromVersion, uint256 indexed toVersion, address indexed migrator);

    /***********************/
    /*** State Variables ***/
    /***********************/

    /**
     *  @dev The default MapleBorrower version.
     */
    function defaultVersion() external view returns (uint256 defaultVersion_);

    /**
     *  @dev The address of the MapleGlobals contract.
     */
    function mapleGlobals() external view returns (address mapleGlobals_);

    /**
     *  @dev    The nonce of an account for CREATE2 salts.
     *  @param  account_ The address of an account.
     *  @return nonce_   The nonce for an account.
     */
    function nonceOf(address account_) external view returns (uint256 nonce_);

    /**
     *  @dev    Whether the upgrade is enabled for a path from a version to another version.
     *  @param  toVersion_   The initial MapleBorrower version.
     *  @param  fromVersion_ The destination MapleBorrower version.
     *  @return allowed_     Whether the upgrade is enabled.
     */
    function upgradeEnabledForPath(uint256 toVersion_, uint256 fromVersion_) external view returns (bool allowed_);

    /********************************/
    /*** State Changing Functions ***/
    /********************************/

    /**
     *  @dev    Deploys a new MapleBorrower of the latest defined implementation version, with some initialization arguments.
     *  @dev    Uses the nonce and msg.sender as a salt for the CREATE2 opcode during instantiation to give deterministic addresses.
     *  @param  arguments_ The initialization arguments to use for the MapleBorrower deployment.
     *  @return borrower_  The address of the deployed MapleBorrower proxy contract.
     */
    function createBorrower(bytes calldata arguments_) external returns (address borrower_);

    /**
     *  @dev   Enables upgrading from a version to a version of a MapleBorrower implementation, with an optional migrator.
     *  @dev   Only the Governor can call this function.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     *  @param migrator_    The address of the MapleBorrowerMigrator, if any.
     */
    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    /**
     *  @dev   Disables upgrading from a version to a version of a MapleBorrower implementation.
     *  @dev   Only the Governor can call this function.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     */
    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) external;

    /**
     *  @dev   Registers the address of MapleBorrower implementation contract as a version, with an optional initializer.
     *  @dev   Only the Governor can call this function.
     *  @param version_               The version of MapleBorrower to register.
     *  @param implementationAddress_ The address of the MapleBorrower implementation.
     *  @param initializer_           The address of the MapleBorrowerInitializer, if any.
     */
    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) external;

    /**
     *  @dev   Sets the default MapleBorrower version.
     *  @dev   Only the Governor can call this function.
     *  @param version_ The MapleBorrower version to set as the default.
     */
    function setDefaultVersion(uint256 version_) external;

    /**
     *  @dev   Upgrades the calling MapleBorrower proxy contract's implementation, with some migration arguments.
     *  @param toVersion_ The MapleBorrower implementation version to upgrade the MapleBorrower proxy contract to.
     *  @param arguments_ The migration arguments to use for the MapleBorrower migration.
     */
    function upgradeBorrower(uint256 toVersion_, bytes calldata arguments_) external;

    /**********************/
    /*** View Functions ***/
    /**********************/

    /**
     *  @dev    Returns the address of a MapleBorrower implementation version.
     *  @param  version_        The MapleBorrower version.
     *  @return implementation_ The address of a MapleBorrower implementation.
     */
    function implementationOf(uint256 version_) external view returns (address implementation_);

    /**
     *  @dev    Returns whether a contract at an address is a MapleBorrower.
     *  @param  borrower_   The address of a contract.
     *  @return isBorrower_ Whether a contract is a MapleBorrower.
     */
    function isBorrower(address borrower_) external view returns (bool isBorrower_);

    /**
     *  @dev    Returns the address of the MapleBorrowerMigrator contract for a migration path (from version to version).
     *  @dev    If oldVersion_ == newVersion_, the MapleBorrowerMigrator is a MapleBorrowerInitializer.
     *  @param  oldVersion_ The MapleBorrower version.
     *  @param  newVersion_ The MapleBorrower version.
     *  @return migrator_   The address of a MapleBorrowerMigrator contract.
     */
    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) external view returns (address migrator_);

    /**
     *  @dev    Returns the version of a MapleBorrower implementation contract.
     *  @param  implementation_ The address of a MapleBorrower implementation contract.
     *  @return version_        The MapleBorrower version of the MapleBorrower implementation contract.
     */
    function versionOf(address implementation_) external view returns (uint256 version_);

}
