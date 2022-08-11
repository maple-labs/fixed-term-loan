// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan }            from "../MapleLoan.sol";
import { MapleLoanFactory }     from "../MapleLoanFactory.sol";
import { MapleLoanInitializer } from "../MapleLoanInitializer.sol";

import { MapleGlobalsMock, MockFeeManager, SomeAccount } from "./mocks/Mocks.sol";

import { Proxy } from "../../modules/maple-proxy-factory/modules/proxy-factory/contracts/Proxy.sol";

contract MapleLoanFactoryTest is TestUtils {

    MapleGlobalsMock internal globals;
    MapleLoanFactory internal factory;
    MockFeeManager   internal feeManager;
    address          internal implementation;
    address          internal initializer;

    function setUp() external {
        globals        = new MapleGlobalsMock(address(this));
        factory        = new MapleLoanFactory(address(globals));
        feeManager     = new MockFeeManager();
        implementation = address(new MapleLoan());
        initializer    = address(new MapleLoanInitializer());

        globals.setValidBorrower(address(1), true);

        factory.registerImplementation(1, implementation, initializer);
        factory.setDefaultVersion(1);
    }

    function test_createInstance(bytes32 someAccountSalt_) external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(1), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(address(globals), address(1), address(feeManager), assets, termDetails, amounts, rates, fees);
        bytes32 salt           = keccak256(abi.encodePacked("salt"));

        // Create a "random" loan creator from some fuzzed salt.
        SomeAccount account = new SomeAccount{ salt: someAccountSalt_ }();

        address loan = account.createLoan(address(factory), arguments, salt);

        address expectedAddress = address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(factory),
                keccak256(abi.encodePacked(arguments, salt)),
                keccak256(abi.encodePacked(type(Proxy).creationCode, abi.encode(address(factory), address(0))))
            )
        ))));

        // NOTE: Check that the loan address is deterministic, and does not depend on the account that calls `createInstance` at the factory.
        // TODO: Change back to hardcoded address once IPFS hashes can be removed on compilation in Foundry.
        assertEq(loan, expectedAddress);

        assertTrue(!factory.isLoan(address(1)));
        assertTrue( factory.isLoan(loan));
    }

    function testFail_createInstance_saltAndArgumentsCollision() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(1), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(address(globals), address(1), address(2), assets, termDetails, amounts, rates, fees);
        bytes32 salt           = keccak256(abi.encodePacked("salt"));

        factory.createInstance(arguments, salt);
        factory.createInstance(arguments, salt);
    }

}
