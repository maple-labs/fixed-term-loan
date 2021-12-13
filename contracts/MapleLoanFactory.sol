// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleProxyFactory, MapleProxyFactory } from "../modules/maple-proxy-factory/contracts/MapleProxyFactory.sol";

import { IMapleLoanFactory } from "./interfaces/IMapleLoanFactory.sol";

/// @title MapleLoanFactory deploys Loan instances.
contract MapleLoanFactory is IMapleLoanFactory, MapleProxyFactory {

    mapping(address => bool) public override isLoan;

    constructor(address mapleGlobals_) MapleProxyFactory(mapleGlobals_) {}

    function createInstance(bytes calldata arguments_, bytes32 salt_)
        override(IMapleProxyFactory, MapleProxyFactory) public returns (
            address instance_
        )
    {
        isLoan[instance_ = super.createInstance(arguments_, salt_)] = true;
    }

}
