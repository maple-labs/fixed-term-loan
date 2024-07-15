// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleLoan }             from "../contracts/MapleLoan.sol";
import { MapleLoanFactory}       from "../contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer }  from "../contracts/MapleLoanInitializer.sol";
import { MapleLoanV502Migrator } from "../contracts/MapleLoanV502Migrator.sol";

import { MockGlobals, MockFeeManager, MockLoanManager, MockLoanManagerFactory } from "./mocks/Mocks.sol";

contract MapleLoanV502MigratorTests is TestUtils {

    address internal governor      = address(new Address());
    address internal securityAdmin = address(new Address());
    address internal implementation501;
    address internal implementation502;
    address internal initializer;

    MapleLoan              loan501;
    MapleLoan              loan502;
    MapleLoanFactory       oldFactory;
    MapleLoanFactory       newFactory;
    MapleLoanV502Migrator  migrator;
    MockERC20              asset;
    MockFeeManager         feeManager;
    MockGlobals            globals;
    MockLoanManager        lender;
    MockLoanManagerFactory loanManagerFactory;

    function setUp() external {
        asset             = new MockERC20("Asset", "ASSET", 18);
        globals           = new MockGlobals(governor);
        feeManager        = new MockFeeManager();
        implementation501 = address(new MapleLoan());
        implementation502 = address(new MapleLoan());
        initializer       = address(new MapleLoanInitializer());
        lender            = new MockLoanManager();
        migrator          = new MapleLoanV502Migrator();
        oldFactory        = new MapleLoanFactory(address(globals), address(0));

        loanManagerFactory = MockLoanManagerFactory(lender.factory());

        lender.__setFundsAsset(address(asset));

        globals.setValidBorrower(address(1),            true);
        globals.setValidCollateralAsset(address(asset), true);
        globals.setValidPoolAsset(address(asset),       true);
        globals.__setIsInstanceOf(true);
        globals.__setCanDeploy(true);
        globals.__setSecurityAdmin(securityAdmin);

        vm.startPrank(governor);
        oldFactory.registerImplementation(501, implementation501, initializer);
        oldFactory.setDefaultVersion(501);
        oldFactory.registerImplementation(502, implementation502, initializer);
        oldFactory.enableUpgradePath(501, 502, address(migrator));
        vm.stopPrank();

        address[2] memory assets      = [address(asset),    address(asset)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(365 days),    uint256(1)];
        uint256[3] memory amounts     = [uint256(0),        uint256(1_000_000e6), uint256(1_000_000e6)];
        uint256[4] memory rates       = [uint256(0.1e18),   uint256(0.02e18),     uint256(0.03e18), uint256(0.04e18)];
        uint256[2] memory fees        = [uint256(0),        uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        loan501 = MapleLoan(oldFactory.createInstance(arguments, "SALT1"));

        vm.prank(address(1));
        loan501.acceptLoanTerms();

        asset.mint(address(loan501), 1_000_000e6);

        vm.prank(address(lender));
        loan501.fundLoan();

        loan502 = MapleLoan(oldFactory.createInstance(arguments, "SALT2"));
    }

    function test_migration_sameFactory_noOp() external {
        newFactory = new MapleLoanFactory(address(globals), address(oldFactory));

        bytes memory arguments = abi.encode(address(oldFactory));

        vm.expectRevert("MPF:UI:FAILED");
        vm.prank(securityAdmin);
        loan501.upgrade(502, arguments);
    }

    function test_migration_invalidFactory() external {
        newFactory = new MapleLoanFactory(address(globals), address(oldFactory));

        bytes memory arguments = abi.encode(address(newFactory));

        globals.__setIsInstanceOf(false);

        vm.expectRevert("MPF:UI:FAILED");
        vm.prank(securityAdmin);
        loan501.upgrade(502, arguments);
    }

    function test_migration_factoryChange() external {
        assertEq(loan501.factory(),        address(oldFactory));
        assertEq(loan501.implementation(), address(implementation501));

        newFactory = new MapleLoanFactory(address(globals), address(oldFactory));

        bytes memory arguments = abi.encode(address(newFactory));

        // Upgrade
        vm.prank(securityAdmin);
        loan501.upgrade(502, arguments);

        // Set loan502 using loan501 as it is now upgraded.
        loan502 = loan501;

        assertEq(loan502.factory(),        address(newFactory));
        assertEq(loan502.implementation(), address(implementation502));
        assertEq(loan502.fundsAsset(),     address(asset));

        assertEq(loan502.principal(), 1_000_000e6);
    }

}
