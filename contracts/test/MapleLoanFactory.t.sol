// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { DSTest }               from "../../modules/ds-test/src/test.sol";

import { MapleLoan }            from "../MapleLoan.sol";
import { MapleLoanFactory }     from "../MapleLoanFactory.sol";
import { MapleLoanInitializer } from "../MapleLoanInitializer.sol";

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
    Borrower             notBorrower;
    Governor             governor;
    Governor             notGovernor;
    MapleGlobalsMock     globals;
    MapleLoan            mapleLoanV1;
    MapleLoan            mapleLoanV2;
    MapleLoanFactory     factory;
    MapleLoanInitializer initializerV1;
    MapleLoanInitializer initializerV2;

    function setUp() external {
        borrower      = new Borrower();
        governor      = new Governor();
        initializerV1 = new MapleLoanInitializer();
        initializerV2 = new MapleLoanInitializer();
        mapleLoanV1   = new MapleLoan();
        mapleLoanV2   = new MapleLoan();
        notBorrower   = new Borrower();
        notGovernor   = new Governor();

        globals = new MapleGlobalsMock(address(governor));
        factory = new MapleLoanFactory(address(globals));
    }

    function test_registerImplementation() external {
        assertTrue(!notGovernor.try_mapleLoanFactory_registerImplementation(address(factory), 1, address(mapleLoanV1), address(initializerV1)), "Should fail: not governor");
        assertTrue(   !governor.try_mapleLoanFactory_registerImplementation(address(factory), 0, address(mapleLoanV1), address(initializerV1)), "Should fail: invalid version");
        assertTrue(   !governor.try_mapleLoanFactory_registerImplementation(address(factory), 1, address(0),           address(initializerV1)), "Should fail: invalid implementation address");
        assertTrue(    governor.try_mapleLoanFactory_registerImplementation(address(factory), 1, address(mapleLoanV1), address(initializerV1)), "Should succeed");
        assertTrue(   !governor.try_mapleLoanFactory_registerImplementation(address(factory), 1, address(mapleLoanV1), address(initializerV1)), "Should fail: already registered version");

        assertEq(factory.implementationOf(1),             address(mapleLoanV1),   "Incorrect state of implementationOf");
        assertEq(factory.versionOf(address(mapleLoanV1)), 1,                      "Incorrect state of versionOf");
        assertEq(factory.migratorForPath(1, 1),           address(initializerV1), "Incorrect state of migratorForPath");
    }

    function test_setDefaultVersion() external {
        governor.mapleLoanFactory_registerImplementation(address(factory), 1, address(mapleLoanV1), address(initializerV1));

        assertTrue(!notGovernor.try_mapleLoanFactory_setDefaultVersion(address(factory), 1), "Should fail: not governor");
        assertTrue(   !governor.try_mapleLoanFactory_setDefaultVersion(address(factory), 2), "Should fail: version not registered");
        assertTrue(    governor.try_mapleLoanFactory_setDefaultVersion(address(factory), 1), "Should succeed: set");

        assertEq(factory.defaultVersion(), 1, "Incorrect state of defaultVersion");

        assertTrue(!notGovernor.try_mapleLoanFactory_setDefaultVersion(address(factory), 0), "Should fail: not governor");
        assertTrue(    governor.try_mapleLoanFactory_setDefaultVersion(address(factory), 0), "Should succeed: unset");

        assertEq(factory.defaultVersion(), 0, "Incorrect state of defaultVersion");
    }

    function test_createLoan() external {
        address[2] memory assets = [address(4567), address(9876)];

        uint256[6] memory parameters = [
            uint256(0),
            uint256(10 days),
            uint256(120_000),
            uint256(100_000),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [uint256(300_000), uint256(1_000_000)];

        bytes memory arguments = initializerV1.encodeArguments(address(borrower), assets, parameters, requests);

        assertTrue(!borrower.try_mapleLoanFactory_createLoan(address(factory), arguments), "Should fail: unregistered version");

        governor.mapleLoanFactory_registerImplementation(address(factory), 1, address(mapleLoanV1), address(initializerV1));
        governor.mapleLoanFactory_setDefaultVersion(address(factory), 1);

        assertTrue(!borrower.try_mapleLoanFactory_createLoan(address(factory), new bytes(0)), "Should fail: invalid arguments");

        MapleLoan loan1 = MapleLoan(borrower.mapleLoanFactory_createLoan(address(factory), arguments));

        assertTrue(factory.isLoan(address(loan1)));

        assertEq(loan1.factory(),                           address(factory));
        assertEq(loan1.implementation(),                    address(mapleLoanV1));
        assertEq(factory.versionOf(loan1.implementation()), 1);

        MapleLoan loan2 = MapleLoan(borrower.mapleLoanFactory_createLoan(address(factory), arguments));

        assertTrue(factory.isLoan(address(loan2)));

        assertEq(loan2.factory(),                           address(factory));
        assertEq(loan2.implementation(),                    address(mapleLoanV1));
        assertEq(factory.versionOf(loan2.implementation()), 1);

        assertTrue(address(loan1) != address(loan2), "Loans should have unique addresses");
    }

    function test_enableUpgradePath() external {
        governor.mapleLoanFactory_registerImplementation(address(factory), 1, address(mapleLoanV1), address(initializerV1));
        governor.mapleLoanFactory_registerImplementation(address(factory), 2, address(mapleLoanV2), address(initializerV2));

        assertTrue(!notGovernor.try_mapleLoanFactory_enableUpgradePath(address(factory), 1, 2, address(444444)), "Should fail: not governor");
        assertTrue(   !governor.try_mapleLoanFactory_enableUpgradePath(address(factory), 1, 1, address(444444)), "Should fail: overwriting initializer");
        assertTrue(    governor.try_mapleLoanFactory_enableUpgradePath(address(factory), 1, 2, address(444444)), "Should succeed: upgrade");

        assertEq(factory.migratorForPath(1, 2), address(444444), "Incorrect migrator");

        assertTrue(governor.try_mapleLoanFactory_enableUpgradePath(address(factory), 2, 1, address(555555)), "Should succeed: downgrade");

        assertEq(factory.migratorForPath(2, 1), address(555555), "Incorrect migrator");

        assertTrue(governor.try_mapleLoanFactory_enableUpgradePath(address(factory), 1, 2, address(888888)), "Should succeed: change migrator");

        assertEq(factory.migratorForPath(1, 2), address(888888), "Incorrect migrator");
    }

    function test_disableUpgradePath() external {
        governor.mapleLoanFactory_registerImplementation(address(factory), 1, address(mapleLoanV1), address(initializerV1));
        governor.mapleLoanFactory_registerImplementation(address(factory), 2, address(mapleLoanV2), address(initializerV2));
        governor.mapleLoanFactory_enableUpgradePath(address(factory), 1, 2, address(444444));

        assertEq(factory.migratorForPath(1, 2), address(444444), "Incorrect migrator");

        assertTrue(!notGovernor.try_mapleLoanFactory_disableUpgradePath(address(factory), 1, 2), "Should fail: not governor");
        assertTrue(   !governor.try_mapleLoanFactory_disableUpgradePath(address(factory), 1, 1), "Should fail: overwriting initializer");
        assertTrue(    governor.try_mapleLoanFactory_disableUpgradePath(address(factory), 1, 2), "Should succeed");

        assertEq(factory.migratorForPath(1, 2), address(0), "Incorrect migrator");
    }

    function test_upgradeLoan() external {
        governor.mapleLoanFactory_registerImplementation(address(factory), 1, address(mapleLoanV1), address(initializerV1));
        governor.mapleLoanFactory_registerImplementation(address(factory), 2, address(mapleLoanV2), address(initializerV2));
        governor.mapleLoanFactory_setDefaultVersion(address(factory), 1);

        address[2] memory assets = [address(4567), address(9876)];

        uint256[6] memory parameters = [
            uint256(0),
            uint256(10 days),
            uint256(120_000),
            uint256(100_000),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [uint256(300_000), uint256(1_000_000)];

        bytes memory arguments = initializerV1.encodeArguments(address(borrower), assets, parameters, requests);

        MapleLoan loan = MapleLoan(borrower.mapleLoanFactory_createLoan(address(factory), arguments));

        assertEq(loan.implementation(),                    address(mapleLoanV1));
        assertEq(factory.versionOf(loan.implementation()), 1);

        assertTrue(!borrower.try_loan_upgrade(address(loan), 2, new bytes(0)), "Should fail: upgrade path not enabled");

        governor.mapleLoanFactory_enableUpgradePath(address(factory), 1, 2, address(0));

        assertTrue(!notBorrower.try_loan_upgrade(address(loan), 2, new bytes(0)), "Should fail: not borrower");
        assertTrue(   !borrower.try_loan_upgrade(address(loan), 0, new bytes(0)), "Should fail: invalid version");
        assertTrue(   !borrower.try_loan_upgrade(address(loan), 1, new bytes(0)), "Should fail: same version");
        assertTrue(   !borrower.try_loan_upgrade(address(loan), 3, new bytes(0)), "Should fail: non-existent version");
        assertTrue(    borrower.try_loan_upgrade(address(loan), 2, new bytes(0)), "Should succeed");

        assertEq(loan.implementation(),                    address(mapleLoanV2));
        assertEq(factory.versionOf(loan.implementation()), 2);
    }

}
