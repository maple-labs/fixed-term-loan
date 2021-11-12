// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { MapleProxyFactory } from "../modules/maple-proxy-factory/contracts/MapleProxyFactory.sol";

/// @title MapleLoanFactory deploys Loan instances.
contract MapleLoanFactory is MapleProxyFactory {

    mapping(address => bool) public isLoan;

    constructor(address mapleGlobals_) MapleProxyFactory(mapleGlobals_) {}

    function createInstance(bytes calldata arguments_) override public returns (address instance_) {
        isLoan[instance_ = super.createInstance(arguments_)] = true;
    }

}
