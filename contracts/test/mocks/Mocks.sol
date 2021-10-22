// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { MapleLoan } from "../../MapleLoan.sol";

import { IMapleLoan } from "../../interfaces/IMapleLoan.sol";

import { Lender } from "../accounts/Lender.sol";

contract MapleGlobalsMock {

    address public governor;

    constructor (address governor_) {
        governor = governor_;
    }

}

contract ConstructableMapleLoan is MapleLoan {

    constructor(address borrower_, address[2] memory assets_, uint256[6] memory parameters_, uint256[3] memory amounts_,  uint256[4] memory fees_) {
        _initialize(borrower_, assets_, parameters_, amounts_, fees_);
    }

    function getCollateralRequiredFor(
        uint256 principal_,
        uint256 drawableFunds_,
        uint256 principalRequested_,
        uint256 collateralRequired_
    )
        external pure returns (uint256 collateral_)
    {
        return _getCollateralRequiredFor(principal_, drawableFunds_, principalRequested_, collateralRequired_);
    }

}

contract LenderMock is Lender {

    address public mapleTreasury = address(9);
    address public poolDelegate  = address(8);

    uint256 public investorFee = uint256(0);
    uint256 public treasuryFee = uint256(0);

}

contract ManipulatableMapleLoan is MapleLoan {

    function setCollateralRequired(uint256 collateralRequired_) external {
        _collateralRequired = collateralRequired_;
    }

    function setPrincipalRequested(uint256 principalRequested_) external {
        _principalRequested = principalRequested_;
    }

    function setPrincipal(uint256 principal_) external {
        _principal = principal_;
    }

    function setCollateral(uint256 collateral_) external {
        _collateral = collateral_;
    }

    function setDrawableFunds(uint256 drawableFunds_) external {
        _drawableFunds = drawableFunds_;
    }

}
