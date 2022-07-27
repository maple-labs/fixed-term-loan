// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }    from "../../modules/erc20/contracts/interfaces/IERC20.sol";
import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { ConstructableMapleLoan } from "./harnesses/MapleLoanHarnesses.sol";

import { MapleGlobalsMock, MockFactory, MockFeeManager } from "./mocks/Mocks.sol";

import { Borrower } from "./accounts/Borrower.sol";
import { Lender }   from "./accounts/Lender.sol";

// TODO: Add fees
contract MapleLoanStoryTests is TestUtils {

    Borrower       borrower;
    Lender         lender;
    MapleGlobalsMock globals;
    MockERC20      token;
    MockFactory    factory;
    MockFeeManager feeManager;

    function setUp() external {
        globals  = new MapleGlobalsMock(address(this));
        borrower   = new Borrower();
        lender     = new Lender();
        token      = new MockERC20("Test", "TST", 0);
        factory    = new MockFactory();
        feeManager = new MockFeeManager();

        globals.setValidBorrower(address(borrower), true);
    }

    function test_story_fullyAmortized() external {

        token.mint(address(borrower), 1_000_000);
        token.mint(address(lender),   1_000_000);

        address[2] memory assets      = [address(token), address(token)];
        uint256[3] memory termDetails = [uint256(10 days), uint256(365 days / 6), uint256(6)];
        uint256[3] memory amounts     = [uint256(300_000), uint256(1_000_000), uint256(0)];
        uint256[5] memory rates       = [uint256(0.12 ether), uint256(0), uint256(0), uint256(0), uint256(0)];

        ConstructableMapleLoan loan = new ConstructableMapleLoan(address(factory), address(globals), address(borrower), address(feeManager), 0, assets, termDetails, amounts, rates);

        // Fund via a 1M transfer
        lender.erc20_transfer(address(token), address(loan), 1_000_000);

        assertTrue(lender.try_loan_fundLoan(address(loan), address(lender)), "Cannot lend");

        assertEq(loan.drawableFunds(), 1_000_000, "Different drawable funds");

        borrower.erc20_transfer(address(token), address(loan), 150_000);
        borrower.erc20_approve(address(token), address(loan), 150_000);

        assertTrue(borrower.try_loan_postCollateral(address(loan), 150_000),                      "Cannot post");
        assertTrue(borrower.try_loan_drawdownFunds(address(loan),  1_000_000, address(borrower)), "Cannot drawdown");

        assertEq(loan.drawableFunds(), 0, "Different drawable funds");

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         158_525,   "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(loan.paymentsRemaining(), 6,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #1 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #1
        borrower.erc20_transfer(address(token), address(loan), 78_526);
        borrower.erc20_approve(address(token), address(loan), 100_000);

        assertTrue(borrower.try_loan_makePayment(address(loan), 100_000), "Cannot pay");

        // Check details for upcoming payment #2
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         161_696, "Different principal");
        assertEq(interestPortion,          16_829,  "Different interest");
        assertEq(loan.paymentsRemaining(), 5,       "Different payments remaining");
        assertEq(loan.principal(),         841_475, "Different payments remaining");

        // Warp to 1 second before payment #2 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #2
        borrower.erc20_transfer(address(token), address(loan), 178_526);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Check details for upcoming payment #3
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         164_930, "Different principal");
        assertEq(interestPortion,          13_595,  "Different interest");
        assertEq(loan.paymentsRemaining(), 4,       "Different payments remaining");
        assertEq(loan.principal(),         679_779, "Different payments remaining");

        // Warp to 1 second before payment #3 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #3
        borrower.erc20_transfer(address(token), address(loan), 178_525);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Remove some collateral
        assertTrue(!borrower.try_loan_removeCollateral(address(loan), 145_547, address(borrower)), "Removed more collateral than expected");
        assertTrue( borrower.try_loan_removeCollateral(address(loan), 145_546, address(borrower)), "Cannot remove collateral");

        assertEq(loan.collateral(), 154_454, "Different collateral");

        // Check details for upcoming payment #4
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         168_230, "Different principal");
        assertEq(interestPortion,          10_296,  "Different interest");
        assertEq(loan.paymentsRemaining(), 3,       "Different payments remaining");
        assertEq(loan.principal(),         514_849, "Different payments remaining");

        // Warp to 1 second before payment #4 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #4
        borrower.erc20_transfer(address(token), address(loan), 178_525);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Return some funds and remove some collateral
        borrower.erc20_transfer(address(token), address(loan), 75_000);
        borrower.erc20_approve(address(token), address(loan), 75_000);

        assertTrue(borrower.try_loan_returnFunds(address(loan), 75_000), "Cannot return funds");

        assertEq(loan.drawableFunds(), 150_001, "Different drawable funds");

        assertTrue(!borrower.try_loan_removeCollateral(address(loan), 95_470, address(borrower)), "Removed more collateral than expected");
        assertTrue( borrower.try_loan_removeCollateral(address(loan), 95_469, address(borrower)), "Cannot remove collateral");

        assertEq(loan.collateral(), 58_985, "Different collateral");

        // Claim loan proceeds thus far
        assertTrue(lender.try_loan_claimFunds(address(loan), 714_101, address(lender)), "Cannot claim funds");

        // Check details for upcoming payment #5
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         171_593, "Different principal");
        assertEq(interestPortion,          6_932,   "Different interest");
        assertEq(loan.paymentsRemaining(), 2,       "Different payments remaining");
        assertEq(loan.principal(),         346_619, "Different payments remaining");

        // Warp to 1 second before payment #5 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #5
        borrower.erc20_transfer(address(token), address(loan), 178_525);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Check details for upcoming payment #6
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         175_026, "Different principal");
        assertEq(interestPortion,          3_500,   "Different interest");
        assertEq(loan.paymentsRemaining(), 1,       "Different payments remaining");
        assertEq(loan.principal(),         175_026, "Different payments remaining");

        // Warp to 1 second before payment #6 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #6
        borrower.erc20_transfer(address(token), address(loan), 178_525);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Check details for upcoming payment which should not be necessary
        assertEq(loan.paymentsRemaining(), 0, "Different payments remaining");
        assertEq(loan.principal(),         0, "Different payments remaining");

        // Remove rest of available funds and collateral
        assertTrue( borrower.try_loan_drawdownFunds(address(loan), 150_000, address(borrower)),   "Cannot drawdown");
        assertTrue(!borrower.try_loan_removeCollateral(address(loan), 58_986, address(borrower)), "Removed more collateral than expected");
        assertTrue( borrower.try_loan_removeCollateral(address(loan), 58_985, address(borrower)), "Cannot remove collateral");

        assertEq(loan.collateral(), 0, "Different collateral");

        // Claim remaining loan proceeds
        assertTrue(lender.try_loan_claimFunds(address(loan), 357_049, address(lender)), "Cannot remove collateral");
    }

    function test_story_interestOnly() external {
        token.mint(address(borrower), 1_000_000);
        token.mint(address(lender),   1_000_000);

        address[2] memory assets      = [address(token), address(token)];
        uint256[3] memory termDetails = [uint256(10 days), uint256(365 days / 6), uint256(6)];
        uint256[3] memory amounts     = [uint256(300_000), uint256(1_000_000), uint256(1_000_000)];
        uint256[5] memory rates       = [uint256(0.12 ether), uint256(0), uint256(0), uint256(0), uint256(0)];

        ConstructableMapleLoan loan = new ConstructableMapleLoan(address(factory), address(globals), address(borrower), address(feeManager), 0, assets, termDetails, amounts, rates);

        // Fund via a 1M transfer
        lender.erc20_transfer(address(token), address(loan), 1_000_000);

        assertTrue(lender.try_loan_fundLoan(address(loan), address(lender)), "Cannot lend");

        assertEq(loan.drawableFunds(), 1_000_000, "Different drawable funds");

        borrower.erc20_transfer(address(token), address(loan), 150_000);
        borrower.erc20_approve(address(token), address(loan), 150_000);

        assertTrue(borrower.try_loan_postCollateral(address(loan), 150_000),                      "Cannot post");
        assertTrue(borrower.try_loan_drawdownFunds(address(loan),  1_000_000, address(borrower)), "Cannot drawdown");

        assertEq(loan.drawableFunds(), 0, "Different drawable funds");

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(loan.paymentsRemaining(), 6,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #1 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #1
        borrower.erc20_transfer(address(token), address(loan), 10_000);
        borrower.erc20_approve(address(token), address(loan), 10_000);

        assertTrue(borrower.try_loan_makePayment(address(loan), 10_000), "Cannot pay");

        // Check details for upcoming payment #2
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(loan.paymentsRemaining(), 5,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #2 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #2
        borrower.erc20_transfer(address(token), address(loan), 20_000);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Check details for upcoming payment #3
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(loan.paymentsRemaining(), 4,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #3 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #3
        borrower.erc20_transfer(address(token), address(loan), 20_000);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Check details for upcoming payment #4
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(loan.paymentsRemaining(), 3,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #4 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #4
        borrower.erc20_transfer(address(token), address(loan), 20_000);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Return some funds and remove some collateral
        borrower.erc20_transfer(address(token), address(loan), 250_000);
        borrower.erc20_approve(address(token), address(loan), 250_000);

        assertTrue(borrower.try_loan_returnFunds(address(loan), 250_000), "Cannot return funds");

        assertEq(loan.drawableFunds(), 500_000, "Different drawable funds");

        assertTrue(borrower.try_loan_removeCollateral(address(loan), 150_000, address(borrower)), "Cannot remove collateral");

        assertEq(loan.collateral(), 150_000, "Different collateral");

        // Claim loan proceeds thus far
        assertTrue(lender.try_loan_claimFunds(address(loan), 80000, address(lender)), "Cannot claim funds");

        // Check details for upcoming payment #5
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(loan.paymentsRemaining(), 2,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #5 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #5
        borrower.erc20_transfer(address(token), address(loan), 20_000);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Check details for upcoming payment #6
        ( principalPortion, interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion,         1_000_000, "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(loan.paymentsRemaining(), 1,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #6 becomes late
        vm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #6
        borrower.erc20_transfer(address(token), address(loan), 1_020_000);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0), "Cannot pay");

        // Check details for upcoming payment which should not be necessary
        assertEq(loan.paymentsRemaining(), 0, "Different payments remaining");
        assertEq(loan.principal(),         0, "Different payments remaining");

        // Remove rest of available funds and collateral
        assertTrue(borrower.try_loan_drawdownFunds(address(loan),    150_000, address(borrower)), "Cannot drawdown");
        assertTrue(borrower.try_loan_removeCollateral(address(loan), 150_000, address(borrower)), "Cannot remove collateral");

        assertEq(loan.collateral(), 0, "Different collateral");

        // Claim remaining loan proceeds
        assertTrue(lender.try_loan_claimFunds(address(loan), 1_040_000, address(lender)), "Cannot remove collateral");
    }

}
