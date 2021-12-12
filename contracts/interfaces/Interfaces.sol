// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface ILenderLike {

    function investorFee() external view returns (uint256 investorFee_);

    function mapleTreasury() external view returns (address mapleTreasury_);

    function poolDelegate() external view returns (address poolDelegate_);

    function treasuryFee() external view returns (uint256 treasuryFee_);

}

interface IMapleGlobalsLike {

    /// @dev The address of the Governor responsible for management of global Maple variables.
    function governor() external view returns (address governor_);

    /// @dev A boolean indicating whether the protocol is paused.
    function protocolPaused() external view returns (bool paused_);

}
