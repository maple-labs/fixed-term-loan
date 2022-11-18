// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

/// @title Ownable interface.
interface IOwnable {

    /**
     *  @dev   Ownership of the contact has been transferred and is pending acceptance.
     *  @param account_ The address that can accept ownership.
     */
    event OwnershipTransferPending(address indexed account_);

    /**
     *  @dev   Ownership of the contact has been transferred.
     *  @param owner_ The address that accepted ownership of the contract.
     */
    event OwnershipAccepted(address indexed owner_);

    /**
     *  @dev The owner of the contract.
     */
    function owner() external view returns (address owner_);

    /**
     *  @dev The account that can accept ownership.
     */
    function pendingOwner() external view returns (address owner_);

    /**
     *  @dev   Transfer the ownership of the contract to an account.
     *  @param account_ The address to transfer ownership of the contract to.
     */
    function transferOwnership(address account_) external;

    /**
     *  @dev Accept the ownership of the contract.
     */
    function acceptOwnership() external;

}
