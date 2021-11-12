// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan }            from "../MapleLoan.sol";
import { MapleLoanFactory }     from "../MapleLoanFactory.sol";
import { MapleLoanInitializer } from "../MapleLoanInitializer.sol";

import { MapleGlobalsMock } from "./mocks/Mocks.sol";

contract MapleLoanFactoryTest is TestUtils {

    function test_createInstance() external {
        MapleGlobalsMock     globals        = new MapleGlobalsMock(address(this));
        MapleLoanFactory     factory        = new MapleLoanFactory(address(globals));
        address              implementation = address(new MapleLoan());
        MapleLoanInitializer initializer    = new MapleLoanInitializer();

        factory.registerImplementation(1, implementation, address(initializer));
        factory.setDefaultVersion(1);

        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(1), uint256(1), uint256(1)];
        uint256[3] memory requests    = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];

        bytes memory arguments = initializer.encodeArguments(address(1), assets, termDetails, requests, rates);

        address loan = factory.createInstance(arguments);

        assertTrue(loan != address(0));
        assertTrue(!factory.isLoan(address(1)));
        assertTrue( factory.isLoan(loan));
    }

}
