// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { MapleProxyFactory } from "../modules/maple-proxy-factory/contracts/MapleProxyFactory.sol";

/// @title MapleLoanFactory deploys Loan instances.
contract MapleLoanFactory is MapleProxyFactory {

    constructor(address mapleGlobals_) MapleProxyFactory(mapleGlobals_) {}

    function isLoan(address loan_) external view returns (bool isLoan_) {
        return _isInstance(loan_);
    }

}
