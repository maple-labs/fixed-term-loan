// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

contract MapleGlobalsMock {

    address public governor;

    constructor (address governor_) {
        governor = governor_;
    }

}
