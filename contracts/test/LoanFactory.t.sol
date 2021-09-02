// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { LoanFactory } from "../LoanFactory.sol";

import { Borrower }         from "./accounts/Borrower.sol";
import { Governor }         from "./accounts/Governor.sol";
import { LoanFactoryAdmin } from "./accounts/LoanFactoryAdmin.sol";

import { CollateralLockerFactoryMock, FundingLockerFactoryMock, GlobalsMock } from "./mocks/Mocks.sol";

contract LoanFactorySettersTest is TestUtils {

    GlobalsMock globals;
    Governor    governor;
    Governor    notGovernor;
    LoanFactory loanFactory;

    function setUp() external {
        governor    = new Governor();
        notGovernor = new Governor();

        globals     = new GlobalsMock(address(governor));
        loanFactory = new LoanFactory(address(globals));
    }

    function test_setGlobals() external {
        assertTrue(!notGovernor.try_loanFactory_setGlobals(address(loanFactory), address(1)));
        assertTrue(    governor.try_loanFactory_setGlobals(address(loanFactory), address(1)));

        assertEq(loanFactory.globals(), address(1));
    }

    function test_setLoanFactoryAdmin() external {
        assertTrue(!notGovernor.try_loanFactory_setLoanFactoryAdmin(address(loanFactory), address(1), true));
        assertTrue(    governor.try_loanFactory_setLoanFactoryAdmin(address(loanFactory), address(1), true));

        assertTrue(loanFactory.loanFactoryAdmins(address(1)));

        assertTrue(!notGovernor.try_loanFactory_setLoanFactoryAdmin(address(loanFactory), address(1), false));
        assertTrue(    governor.try_loanFactory_setLoanFactoryAdmin(address(loanFactory), address(1), false));

        assertTrue(!loanFactory.loanFactoryAdmins(address(1)));
    }

    function test_pauseByGovernor() external {
        assertTrue(!notGovernor.try_loanFactory_pause(address(loanFactory)));
        assertTrue(    governor.try_loanFactory_pause(address(loanFactory)));

        assertTrue(loanFactory.paused());
    }

    function test_unpauseByGovernor() external {
        governor.loanFactory_pause(address(loanFactory));

        assertTrue(!notGovernor.try_loanFactory_unpause(address(loanFactory)));
        assertTrue(    governor.try_loanFactory_unpause(address(loanFactory)));

        assertTrue(!loanFactory.paused());
    }

    function test_pauseByAdmin() external {
        LoanFactoryAdmin admin    = new LoanFactoryAdmin();
        LoanFactoryAdmin notAdmin = new LoanFactoryAdmin();

        governor.loanFactory_setLoanFactoryAdmin(address(loanFactory), address(admin), true);

        assertTrue(!notAdmin.try_loanFactory_pause(address(loanFactory)));
        assertTrue(    admin.try_loanFactory_pause(address(loanFactory)));

        assertTrue(loanFactory.paused());
    }

    function test_unpauseByAdmin() external {
        LoanFactoryAdmin admin    = new LoanFactoryAdmin();
        LoanFactoryAdmin notAdmin = new LoanFactoryAdmin();

        governor.loanFactory_setLoanFactoryAdmin(address(loanFactory), address(admin), true);
        governor.loanFactory_pause(address(loanFactory));

        assertTrue(!notAdmin.try_loanFactory_unpause(address(loanFactory)));
        assertTrue(    admin.try_loanFactory_unpause(address(loanFactory)));

        assertTrue(!loanFactory.paused());
    }

}

contract LoanFactoryCreateTest is TestUtils {

    Borrower    borrower;
    GlobalsMock globals;
    Governor    governor;
    LoanFactory loanFactory;

    address collateralAsset;
    address collateralLockerFactory;
    address fundingLockerFactory;
    address lateFeeCalc;
    address liquidityAsset;
    address premiumCalc;
    address repaymentCalc;

    uint256[5] specs;

    function setUp() external {
        governor = new Governor();

        collateralAsset = address(111);
        lateFeeCalc     = address(222);
        liquidityAsset  = address(333);
        premiumCalc     = address(444);
        repaymentCalc   = address(555);

        collateralLockerFactory = address(new CollateralLockerFactoryMock());
        fundingLockerFactory    = address(new FundingLockerFactoryMock());

        borrower    = new Borrower();
        globals     = new GlobalsMock(address(governor));
        loanFactory = new LoanFactory(address(globals));

        globals.setSubFactoryValidity(address(loanFactory), collateralLockerFactory, 0, true);
        globals.setSubFactoryValidity(address(loanFactory), fundingLockerFactory,    2, true);
        
        globals.setCalcValidity(repaymentCalc, 10, true);
        globals.setCalcValidity(lateFeeCalc,   11, true);
        globals.setCalcValidity(premiumCalc,   12, true);

        globals.setCollateralAssetValidity(collateralAsset, true);
        globals.setLiquidityAssetValidity(liquidityAsset,   true);

        specs = [uint256(10), 10, 2, 10_000_000, 30];
    }

    function testFail_createLoan_whilePaused() external {
        address[3] memory calcs = [repaymentCalc, lateFeeCalc, premiumCalc];
        governor.loanFactory_pause(address(loanFactory));

        loanFactory.createLoan(
            liquidityAsset,
            collateralAsset,
            fundingLockerFactory,
            collateralLockerFactory,
            specs,
            calcs
        );
    }

    function testFail_createLoan_whileProtocolPaused() external {
        address[3] memory calcs = [repaymentCalc, lateFeeCalc, premiumCalc];
        globals.setProtocolPause(true);

        loanFactory.createLoan(
            liquidityAsset,
            collateralAsset,
            fundingLockerFactory,
            collateralLockerFactory,
            specs,
            calcs
        );
    }

    function testFail_createLoan_withInvalidFundingLockerFactory() external {
        address[3] memory calcs = [repaymentCalc, lateFeeCalc, premiumCalc];

        loanFactory.createLoan(
            liquidityAsset,
            collateralAsset,
            address(1),
            collateralLockerFactory,
            specs,
            calcs
        );
    }

    function testFail_createLoan_withInvalidCollateralLockerFactory() external {
        address[3] memory calcs = [repaymentCalc, lateFeeCalc, premiumCalc];

        loanFactory.createLoan(
            liquidityAsset,
            collateralAsset,
            fundingLockerFactory,
            address(1),
            specs,
            calcs
        );
    }

    function testFail_createLoan_withInvalidRepaymentCalc() external {
        loanFactory.createLoan(
            liquidityAsset,
            collateralAsset,
            fundingLockerFactory,
            collateralLockerFactory,
            specs,
            [address(1), lateFeeCalc, premiumCalc]
        );
    }

    function testFail_createLoan_withInvalidLateFeeCalc() external {
        loanFactory.createLoan(
            liquidityAsset,
            collateralAsset,
            fundingLockerFactory,
            collateralLockerFactory,
            specs,
            [repaymentCalc, address(1), premiumCalc]
        );
    }

    function testFail_createLoan_withInvalidPremiumCalc() external {
        loanFactory.createLoan(
            liquidityAsset,
            collateralAsset,
            fundingLockerFactory,
            collateralLockerFactory,
            specs,
            [repaymentCalc, lateFeeCalc, address(1)]
        );
    }

    function test_createLoan() external {
        address[3] memory calcs = [repaymentCalc, lateFeeCalc, premiumCalc];

        assertEq(loanFactory.loansCreated(), 0);

        assertTrue(borrower.try_loanFactory_createLoan(address(loanFactory), liquidityAsset, collateralAsset, fundingLockerFactory, collateralLockerFactory, specs, calcs));

        assertEq(loanFactory.loansCreated(), 1);

        address loanAddress = loanFactory.loans(0);

        assertTrue(loanAddress != address(0));
        assertTrue(loanFactory.isLoan(loanAddress));  // Confirms that both `loans` and `isLoan` mappings were added to correctly
    }

}
