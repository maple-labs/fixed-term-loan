// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

//// @title MapleLoanFactory facilitates the creation of the MapleLoan contracts as proxies.
interface IMapleLoanFactory {

    /**************/
    /*** Events ***/
    /**************/

    /**
     *  @dev   A default MapleLoan version was set.
     *  @param version The default MapleLoan version.
     */
    event DefaultVersionSet(uint256 indexed version);

    /**
     *  @dev   A version of a MapleLoan implementation, at some address, was registered, with an optional initializer.
     *  @param version               The version of the MapleLoan registered.
     *  @param implementationAddress The address of the MapleLoan implementation.
     *  @param initializer           The address of the MapleLoanInitializer, if any.
     */
    event ImplementationRegistered(uint256 indexed version, address indexed implementationAddress, address indexed initializer);

    /**
     *  @dev   A MapleLoan proxy contract was deployed with some initialization arguments.
     *  @param version                 The version of the MapleLoan implementation being proxied by the deployed MapleLoan proxy contract.
     *  @param loan                    The address of the MapleLoan proxy contract deployed.
     *  @param initializationArguments The arguments used to initialize the MapleLoan proxy contract, if any.
     */
    event LoanDeployed(uint256 indexed version, address indexed loan, bytes initializationArguments);

    /**
     *  @dev   A MapleLoan has upgraded by proxying to a new implementation version, with some migration arguments.
     *  @param loan               The address of the MapleLoan proxy contract.
     *  @param fromVersion        The initial version of the MapleLoan.
     *  @param toVersion          The version the MapleLoan was upgraded to.
     *  @param migrationArguments The arguments used to migrate the MapleLoan proxy contract, if any.
     */
    event LoanUpgraded(address indexed loan, uint256 indexed fromVersion, uint256 indexed toVersion, bytes migrationArguments);

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
     *  @param migrator    The address of the MapleLoanMigrator, if any.
     */
    event UpgradePathEnabled(uint256 indexed fromVersion, uint256 indexed toVersion, address indexed migrator);

    /***********************/
    /*** State Variables ***/
    /***********************/

    /**
     *  @dev The default MapleLoan version.
     */
    function defaultVersion() external view returns (uint256 defaultVersion_);

    /**
     *  @dev The current number of loans created using the factory.
     */
    function loanCount() external view returns (uint256 loanCount_);

    /**
     *  @dev    The address of the `index`-th MapleLoan proxy contract.
     *  @param  index_ The index of the MapleLoan.
     *  @return loan_  The address of a MapleLoan proxy contract.
     */
    function loanAtIndex(uint256 index_) external view returns (address loan_);

    /**
     *  @dev The address of the MapleGlobals contract.
     */
    function mapleGlobals() external view returns (address mapleGlobals_);

    /**
     *  @dev    The nonce of an account for CREATE2 salts.
     *  @param  account_ The address of an account.
     *  @return nonce_  The nonce for an account.
     */
    function nonceOf(address account_) external view returns (uint256 nonce_);

    /**
     *  @dev    Whether the upgrade is enabled for a path from a version to another version.
     *  @param  toVersion_   The initial MapleLoan version.
     *  @param  fromVersion_ The destination MapleLoan version.
     *  @return allowed_     Whether the upgrade is enabled.
     */
    function upgradeEnabledForPath(uint256 toVersion_, uint256 fromVersion_) external view returns (bool allowed_);

    /********************************/
    /*** State Changing Functions ***/
    /********************************/

    /**
     *  @dev    Deploys a new MapleLoan of the latest defined implementation version, with some initialization arguments.
     *  @dev    Uses the nonce and msg.sender as a salt for the CREATE2 opcode during instantiation to give deterministic addresses.
     *  @param  arguments_ The initialization arguments to use for the MapleLoan deployment.
     *  @return loan_      The address of the deployed MapleLoan proxy contract.
     */
    function createLoan(bytes calldata arguments_) external returns (address loan_);

    /**
     *  @dev   Enables upgrading from a version to a version of a MapleLoan implementation, with an optional migrator.
     *  @dev   Only the Governor can call this function.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     *  @param migrator_    The address of the MapleLoanMigrator, if any.
     */
    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    /**
     *  @dev   Disables upgrading from a version to a version of a MapleLoan implementation.
     *  @dev   Only the Governor can call this function.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     */
    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) external;

    /**
     *  @dev   Registers the address of MapleLoan implementation contract as a version, with an optional initializer.
     *  @dev   Only the Governor can call this function.
     *  @param version_               The version of MapleLoan to register.
     *  @param implementationAddress_ The address of the MapleLoan implementation.
     *  @param initializer_           The address of the MapleLoanInitializer, if any.
     */
    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) external;

    /**
     *  @dev   Sets the default MapleLoan version.
     *  @dev   Only the Governor can call this function.
     *  @param version_ The MapleLoan version to set as the default.
     */
    function setDefaultVersion(uint256 version_) external;

    /**
     *  @dev   Upgrades the calling MapleLoan proxy contract's implementation, with some migration arguments.
     *  @param toVersion_ The MapleLoan implementation version to upgrade the MapleLoan proxy contract to.
     *  @param arguments_ The migration arguments to use for the MapleLoan migration.
     */
    function upgradeLoan(uint256 toVersion_, bytes calldata arguments_) external;

    /**************************/
    /*** Readonly Functions ***/
    /**************************/

    /**
     *  @dev   Returns the address of a MapleLoan implementation version.
     *  @param  version_        The MapleLoan version.
     *  @return implementation_ The address of a MapleLoan implementation.
     */
    function implementationOf(uint256 version_) external view returns (address implementation_);

    /**
     *  @dev    Returns the address of the MapleLoanMigrator contract for a migration path (from version to version).
     *  @dev    If oldVersion_ == newVersion_, the MapleLoanMigrator is a MapleLoanInitializer.
     *  @param  oldVersion_ The MapleLoan version.
     *  @param  newVersion_ The MapleLoan version.
     *  @return migrator_   The address of a MapleLoanMigrator contract.
     */
    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) external view returns (address migrator_);

    /**
     *  @dev    Returns the version of a MapleLoan implementation contract.
     *  @param  implementation_ The address of a MapleLoan implementation contract.
     *  @return version_        The MapleLoan version of the MapleLoan implementation contract.
     */
    function versionOf(address implementation_) external view returns (uint256 version_);

}
