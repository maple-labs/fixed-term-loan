// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;


import { MapleLoan } from "../../MapleLoan.sol";

contract MapleGlobalsMock {

    address public governor;

    constructor (address governor_) {
        governor = governor_;
    }

}

contract ConstructableMapleLoan is MapleLoan {

    constructor(address borrower_, address[2] memory assets_, uint256[6] memory parameters_, uint256[2] memory amounts_) {
        _initialize(borrower_, assets_, parameters_, amounts_);
    }

}

