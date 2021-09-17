// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { DSTest }               from "../../modules/ds-test/src/test.sol";
import { MockImplementationV1 } from "../../modules/proxy-factory/contracts/test/mocks/Mocks.sol";

import { MapleLoanFactory } from "../MapleLoanFactory.sol";

import { Borrower } from "./accounts/Borrower.sol";
import { Governor } from "./accounts/Governor.sol";

contract MapleGlobalsMock {

    address public governor;

    constructor (address governor_) {
        governor = governor_;
    }

}

contract MapleLoanFactoryTest is DSTest {

    Borrower             borrower;
    Governor             governor;
    Governor             notGovernor;
    MapleGlobalsMock     globals;
    MapleLoanFactory     loanFactory;
    MockImplementationV1 implementationV1;


    address implementationAddress1 = address(111);
    address implementationAddress2 = address(333);
    address initializer1           = address(222);
    address initializer2           = address(444);
    address migrator               = address(999);

    bytes dummyArguments = bytes("Dummy arguments");

    function setUp() public {
        borrower         = new Borrower();
        governor         = new Governor();
        notGovernor      = new Governor();
        globals          = new MapleGlobalsMock(address(governor));
        loanFactory      = new MapleLoanFactory(address(globals));
        implementationV1 = new MockImplementationV1();
    }

    function test_registerImplementation() public {
        assertTrue(
            !notGovernor.try_mapleLoanFactory_registerImplementation(address(loanFactory), 1, implementationAddress1, initializer1),
            "Should fail to register: Invalid governor"
        );

        assertTrue(
            !governor.try_mapleLoanFactory_registerImplementation(address(loanFactory), 0, implementationAddress1, initializer1),
            "Should fail to register: Invalid version"
        );

        assertTrue(
            !governor.try_mapleLoanFactory_registerImplementation(address(loanFactory), 1, address(0), initializer1),
            "Should fail to register: Invalid implementation address"
        );

        assertTrue(
            governor.try_mapleLoanFactory_registerImplementation(address(loanFactory), 1, implementationAddress1, initializer1),
            "Should not fail to register"
        );

        // Try to register again with the same version.
        assertTrue(
            !governor.try_mapleLoanFactory_registerImplementation(address(loanFactory), 1, implementationAddress2, address(0)),
            "Should fail to register: Version already registered"
        );
        
        assertEq(loanFactory.latestVersion(),                   1,                      "Incorrect state of latestVersion");
        assertEq(loanFactory.implementationOf(1),               implementationAddress1, "Incorrect state of implementationOf");
        assertEq(loanFactory.versionOf(implementationAddress1), 1,                      "Incorrect state of versionOf");
        assertEq(loanFactory.migratorForPath(1, 1),             initializer1,           "Incorrect state of migratorForPath");
    }

    function test_createLoan() public {
        assertTrue(
            !borrower.try_mapleLoanFactory_createLoan(address(loanFactory), dummyArguments),
            "Should fail to create loan: Version is not registered yet"
        );

        assertTrue(
            governor.try_mapleLoanFactory_registerImplementation(address(loanFactory), 1, address(implementationV1), address(0)),
            "Should not fail to register"
        );

        assertTrue(borrower.try_mapleLoanFactory_createLoan(address(loanFactory), dummyArguments), "Should not fail to create loan");

        assertEq(loanFactory.loanCount(), 1);
        address loanAddress = loanFactory.loans(loanFactory.loanCount());

        // Create another loan with different arguments.
        assertTrue(borrower.try_mapleLoanFactory_createLoan(address(loanFactory), "Dummy arguments 123"), "Should not fail to create loan");
        assertEq(loanFactory.loanCount(), 2);
        address newLoanAddress = loanFactory.loans(loanFactory.loanCount());

        assertTrue(loanAddress != newLoanAddress, "Same address gets generated");
    }

    function test_enableUpgradePath() public {
        assertTrue(
            !notGovernor.try_mapleLoanFactory_enableUpgradePath(address(loanFactory), 1, 2, migrator),
            "Should fail to upgrade path: Unauthorized"
        );

        assertTrue(
            !governor.try_mapleLoanFactory_enableUpgradePath(address(loanFactory), 1, 0, migrator),
            "Should fail to upgrade path: Invalid version"
        );

        assertTrue(
            !governor.try_mapleLoanFactory_enableUpgradePath(address(loanFactory), 2, 1, migrator),
            "Should fail to upgrade path: Invalid version"
        );

        assertTrue(
            governor.try_mapleLoanFactory_registerImplementation(address(loanFactory), 1, implementationAddress1, initializer1),
            "Should not fail to register"
        );

        assertTrue(
            governor.try_mapleLoanFactory_enableUpgradePath(address(loanFactory), 1, 2, migrator),
            "Should not fail to upgrade path"
        );
        
        assertEq(
            loanFactory.migratorForPath(1, 2), migrator,
            "Incorrect state of migratorForPath"
        );
    }

    function test_disableUpgradePath() public {
        assertTrue(
            !notGovernor.try_mapleLoanFactory_disableUpgradePath(address(loanFactory), 1, 2),
            "Should fail to disable upgrade path: Unauthorized"
        );

        assertTrue(governor.try_mapleLoanFactory_enableUpgradePath(address(loanFactory),  1, 2, migrator), "Should not fail to upgrade path");

        assertEq(loanFactory.migratorForPath(1, 2), migrator, "Incorrect state of migratorForPath");

        assertTrue(governor.try_mapleLoanFactory_disableUpgradePath(address(loanFactory), 1, 2), "Should not fail to upgrade path");

        assertEq(loanFactory.migratorForPath(1, 2), address(0), "Incorrect state of migratorForPath");
    }

    function test_upgradeLoan() public {
        // TODO
    }

}
