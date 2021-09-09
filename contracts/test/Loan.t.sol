// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { DSTest } from "../../modules/ds-test/src/test.sol";

import { LoanPrimitiveHarness } from "./harnesses/LoanPrimitiveHarness.sol";

contract LoanTest is DSTest {

    LoanPrimitiveHarness loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function test_getFee() external {
        assertEq(loan.getFee(1_000_000, 120_000, 365 days / 12), 10_000);  // 12% APY on 1M
        assertEq(loan.getFee(10_000, 1_200_000, 365 days / 12), 1_000);    // 120% APY on 10k
    }

    function test_getInstallment() external {
        (uint256 principalAmount, uint256 interestAmount) = loan.getInstallment(1_000_000, 0, 120_000, 365 days / 12, 12);
        assertEq(principalAmount, 78_850);
        assertEq(interestAmount,  10_000);
    }

    function test_getPaymentBreakdown_onePeriodBeforeDue() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentBreakdown(
            10_000_000 - (1 * (365 days / 12)),
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    10_000);
        assertEq(totalLateFees,        0);
    }

    function test_getPaymentBreakdown_oneSecondBeforeDue() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentBreakdown(
            10_000_000 - 1,
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    10_000);
        assertEq(totalLateFees,        0);
    }

    function test_getPaymentBreakdown_onePeriodLate() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentBreakdown(
            10_000_000 + (1 * (365 days / 12)),  // current time is 2 periods after next payment date
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    20_000);
        assertEq(totalLateFees,        83);
    }

    function test_getPaymentBreakdown_twoPeriodsLate() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentBreakdown(
            10_000_000 + (2 * (365 days / 12)),  // current time is 2 periods after next payment date
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    30_000);
        assertEq(totalLateFees,        166);
    }

    function test_getPaymentBreakdown_threePeriodsLate() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentBreakdown(
            10_000_000 + (3 * (365 days / 12)),  // current time is 2 periods after next payment date
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    40_000);
        assertEq(totalLateFees,        250);
    }

    function test_getPaymentBreakdown_fourPeriodsLate() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentBreakdown(
            10_000_000 + (4 * (365 days / 12)),  // current time is 2 periods after next payment date
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    50_000);
        assertEq(totalLateFees,        333);
    }

    function test_getPaymentsBreakdown_onePaymentOnePeriodBeforeDue() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentsBreakdown(
            1,
            10_000_000 - (1 * (365 days / 12)),
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    10_000);
        assertEq(totalLateFees,        0);
    }

    function test_getPaymentsBreakdown_twoPaymentsOnePeriodBeforeDue() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentsBreakdown(
            2,
            10_000_000 - (1 * (365 days / 12)),
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 158_489);
        assertEq(totalInterestFees,    19_211);
        assertEq(totalLateFees,        0);
    }

    function test_getPaymentsBreakdown_onePaymentOneSecondBeforeDue() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentsBreakdown(
            1,
            10_000_000 - 1,
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    10_000);
        assertEq(totalLateFees,        0);
    }

    function test_getPaymentsBreakdown_twoPaymentsOneSecondBeforeDue() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentsBreakdown(
            2,
            10_000_000 - 1,
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 158_489);
        assertEq(totalInterestFees,    19_211);
        assertEq(totalLateFees,        0);
    }

    function test_getPaymentsBreakdown_onePaymentOnePeriodLate() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentsBreakdown(
            1,
            10_000_000 + (1 * (365 days / 12)),
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    20_000);
        assertEq(totalLateFees,        83);
    }

    function test_getPaymentsBreakdown_twoPaymentsOnePeriodLate() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentsBreakdown(
            2,
            10_000_000 + (1 * (365 days / 12)),
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 158_489);
        assertEq(totalInterestFees,    29_211);
        assertEq(totalLateFees,        83);
    }

    function test_getPaymentsBreakdown_onePaymentTwoPeriodsLate() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentsBreakdown(
            1,
            10_000_000 + (2 * (365 days / 12)),
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 78_850);
        assertEq(totalInterestFees,    30_000);
        assertEq(totalLateFees,        166);
    }

    function test_getPaymentsBreakdown_twoPaymentsTwoPeriodsLate() external {
        (uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees) = loan.getPaymentsBreakdown(
            2,
            10_000_000 + (2 * (365 days / 12)),
            10_000_000,
            365 days / 12,
            1_000_000,
            0,
            120_000,
            12,
            100_000
        );

        assertEq(totalPrincipalAmount, 158_489);
        assertEq(totalInterestFees,    48_422);
        assertEq(totalLateFees,        242);
    }

    function test_getPeriodicFeeRate() external {
        assertEq(loan.getPeriodicFeeRate(120_000, 365 days),      120_000);
        assertEq(loan.getPeriodicFeeRate(120_000, 365 days / 12), 10_000);
    }

    function test_scaledExponent() external {
        assertEq(loan.scaledExponent(10_000, 0, 10_000), 10_000);
        assertEq(loan.scaledExponent(10_000, 1, 10_000), 10_000);
        assertEq(loan.scaledExponent(10_000, 2, 10_000), 10_000);
        assertEq(loan.scaledExponent(10_000, 3, 10_000), 10_000);

        assertEq(loan.scaledExponent(20_000, 0, 10_000), 10_000);
        assertEq(loan.scaledExponent(20_000, 1, 10_000), 20_000);
        assertEq(loan.scaledExponent(20_000, 2, 10_000), 40_000);
        assertEq(loan.scaledExponent(20_000, 3, 10_000), 80_000);

        assertEq(loan.scaledExponent(10_100, 0, 10_000), 10_000);
        assertEq(loan.scaledExponent(10_100, 1, 10_000), 10_100);
        assertEq(loan.scaledExponent(10_100, 2, 10_000), 10_201);
        assertEq(loan.scaledExponent(10_100, 3, 10_000), 10_303);
    }

}
