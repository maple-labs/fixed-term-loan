// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan }            from "../MapleLoan.sol";
import { MapleLoanFactory }     from "../MapleLoanFactory.sol";
import { MapleLoanInitializer } from "../MapleLoanInitializer.sol";

import { MapleGlobalsMock, MockFeeManager } from "./mocks/Mocks.sol";

import { Proxy } from "../../modules/maple-proxy-factory/modules/proxy-factory/contracts/Proxy.sol";

contract MapleLoanFactoryTest is TestUtils {

    MapleGlobalsMock internal globals;
    MapleLoanFactory internal factory;
    MockFeeManager   internal feeManager;

    address internal governor = address(new Address());

    address internal implementation;
    address internal initializer;

    function setUp() external {
        feeManager     = new MockFeeManager();
        globals        = new MapleGlobalsMock(governor);
        implementation = address(new MapleLoan());
        initializer    = address(new MapleLoanInitializer());

        factory = new MapleLoanFactory(address(globals));

        globals.setValidBorrower(address(1), true);

        vm.startPrank(governor);
        factory.registerImplementation(1, implementation, initializer);
        factory.setDefaultVersion(1);
        vm.stopPrank();
    }

    function test_createInstance(bytes32 salt_) external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(1), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(address(1), address(feeManager), assets, termDetails, amounts, rates, fees);

        address loan = factory.createInstance(arguments, salt_);

        address expectedAddress = address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(factory),
                keccak256(abi.encodePacked(arguments, salt_)),
                keccak256(abi.encodePacked(type(Proxy).creationCode, abi.encode(address(factory), address(0))))
            )
        ))));

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

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(address(1), address(feeManager), assets, termDetails, amounts, rates, fees);
        bytes32 salt           = keccak256(abi.encodePacked("salt"));

        factory.createInstance(arguments, salt);

        // TODO: use vm.expectRevert() without arguments when it is available.
        factory.createInstance(arguments, salt);
    }

}
