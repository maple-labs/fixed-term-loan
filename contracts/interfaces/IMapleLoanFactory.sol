// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

// TODO: Complete Natspec

interface IMapleLoanFactory {

    //// @dev Returns the address of the Maple Globals contract.
    function mapleGlobals() external view returns (address mapleGlobals_);

    //// @dev Returns the latest version of implementation address that get used to create loans.
    function latestVersion() external view returns (uint256 latestVersion_);

    //// @dev Returns the current count of loans get created using the factory.
    function loanCount() external view returns (uint256 loanCount_);

    //// @dev Returns the address of a Loan given some index.
    function loans(uint256 index_) external view returns (address loan_);

    //// @dev Returns the nonce of a account user for create2 salts.
    function nonces(address account_) external view returns (uint256 nonce_);

    /// @dev A version of an implementation of a Loan, at some address, was registered, with an optional initializer.
    event ImplementationRegistered(uint256 indexed version, address indexed implementationAddress, address indexed initializer);

    /// @dev A Loan was deployed with some initialization arguments.
    event LoanDeployed(uint256 indexed version, address indexed loan, bytes initializationArguments);

    /// @dev An upgrade path was enabled, with an optional migrator contract.
    event UpgradePathEnabled(uint256 indexed fromVersion, uint256 indexed toVersion, address indexed migrator);

    /// @dev An upgrade path was disabled, with an optional migrator contract.
    event UpgradePathDisabled(uint256 indexed fromVersion, uint256 indexed toVersion);

    /// @dev A Loan has upgraded top a new implementation version, with some migration arguments.
    event LoanUpgraded(address indexed loan, uint256 indexed fromVersion, uint256 indexed toVersion, bytes migrationArguments);

    /// @dev Returns the address of the Loan implementation of a version.
    function implementationOf(uint256 version_) external view returns (address implementation_);

    /// @dev Returns the address of the migration contract for a migration path (from version to version).
    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) external view returns (address migrator_);

    /// @dev Returns the version of an implementation address.
    function versionOf(address implementation_) external view returns (uint256 version_);

    /// @dev Set the addresses of a version of an implementation contract, with an optional initializer.
    /// @dev Only the Governor can call this function.
    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) external;

    /// @dev Deploys a new Loan, for a version of the implementation, with some initialization arguments.
    /// @dev Uses the nonce and msg.sender as a `salt` for the `CREATE2` opcode during instantiation to give deterministic addresses.
    function createLoan(bytes calldata arguments_) external returns (address loan_);

    /// @dev Enables upgrading from a version to a version of a Loan implementation, with an optional migrator.
    /// @dev Only the Governor can call this function.
    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    /// @dev Disables upgrading from a version to a version of a Loan implementation.
    /// @dev Only the Governor can call this function.
    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) external;

    /// @dev Upgrades an existing deployed Loan (the caller) to use a new implementation.
    function upgradeLoan(uint256 toVersion, bytes calldata arguments) external;

}
