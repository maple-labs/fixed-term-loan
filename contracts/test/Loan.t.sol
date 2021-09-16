// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { DSTest }    from "../../modules/ds-test/src/test.sol";
import { MockERC20 } from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { Lender } from "./accounts/Lender.sol";

import { LoanPrimitiveHarness } from "./harnesses/LoanPrimitiveHarness.sol";

//TODO separate getFee and getInstallment tests
contract LoanPaymentBreakDownTest is DSTest {

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

contract LoanLendTest is DSTest {

    LoanPrimitiveHarness loan;
    MockERC20            token;

    uint256 constant MIN_REQUESTED_AMOUNT = 2;
    uint256 constant MAX_REQUESTED_AMOUNT = type(uint256).max - 1;
    address constant mockCollateralToken  = address(9);

    function setUp() external {
        loan  = new LoanPrimitiveHarness();
        token = new MockERC20("FundsAsset", "FA", 0);
    }

    function _initializeLoanWithRequestAmount(uint256 requestedAmount_) internal {
        address[2] memory assets = [address(mockCollateralToken), address(token)];

        uint256[6] memory parameters = [
            uint256(0),
            uint256(10 days),
            uint256(1_200 * 100),
            uint256(1_100 * 100),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [uint256(300_000), requestedAmount_];

        loan.initialize(address(1), assets, parameters, requests);
    }

    function _constrainRequestAmount(uint256 requestedAmount_) internal pure returns (uint256) {
        return requestedAmount_ < MIN_REQUESTED_AMOUNT ? MIN_REQUESTED_AMOUNT : (requestedAmount_ > MAX_REQUESTED_AMOUNT ? MAX_REQUESTED_AMOUNT : requestedAmount_);
    }

    function test_lend_initialState() external {
        assertEq(loan.lender(),                             address(0));
        assertEq(loan.drawableFunds(),                      0);
        assertEq(loan.nextPaymentDueDate(),                 0);
        assertEq(loan.getUnaccountedAmount(address(token)), 0);
        assertEq(loan.principal(),                          0);
    }

    function test_lend_getUnaccountedAmount(uint amount_) external {
        assertEq(loan.getUnaccountedAmount(address(token)), 0);

        token.mint(address(this), amount_);

        token.transfer(address(loan), amount_);

        assertEq(loan.getUnaccountedAmount(address(token)), amount_);
    }

    function test_lend_withoutSendingAsset(uint256 requestedAmount_) external {
        uint256 requestedAmount = _constrainRequestAmount(requestedAmount_);
        _initializeLoanWithRequestAmount(requestedAmount);

        (bool ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");
    }

    function test_lend_fullLend(uint256 requestedAmount_) external {
        uint256 requestedAmount = _constrainRequestAmount(requestedAmount_);
        _initializeLoanWithRequestAmount(requestedAmount);
        
        token.mint(address(this), requestedAmount);
        token.transfer(address(loan), requestedAmount);

        assertEq(loan.getUnaccountedAmount(address(token)), requestedAmount);

        (bool ok, uint256 amount) = loan.lend(address(this));
        assertTrue(ok, "lend should have succeded");

        assertEq(loan.lender(),                             address(this));
        assertEq(amount,                                    requestedAmount);
        assertEq(loan.getUnaccountedAmount(address(token)), 0);
        assertEq(loan.drawableFunds(),                      amount);
        assertEq(loan.nextPaymentDueDate(),                 block.timestamp + loan.paymentInterval());
        assertEq(loan.principal(),                          amount);
    }

    function test_lend_partialLend(uint256 requestedAmount_) external {
        uint256 requestedAmount = _constrainRequestAmount(requestedAmount_);

        _initializeLoanWithRequestAmount(requestedAmount);

        token.mint(address(this), requestedAmount);
        token.transfer(address(loan), requestedAmount - 1);

        (bool ok, uint256 amount) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");

    }

    function test_lend_failWithDoubleLend(uint256 requestedAmount_) external {
        uint256 requestedAmount = _constrainRequestAmount(requestedAmount_);

        // Dividing by two to make sure we can mint twice
        _initializeLoanWithRequestAmount(requestedAmount / 2);

        token.mint(address(this), requestedAmount);

        token.transfer(address(loan), requestedAmount / 2);

        (bool ok, uint256 amount) = loan.lend(address(this));
        assertTrue(ok, "lend should have succeded");

        assertEq(loan.lender(),                             address(this));
        assertEq(amount,                                    requestedAmount / 2);
        assertEq(loan.getUnaccountedAmount(address(token)), 0);
        assertEq(loan.drawableFunds(),                      amount);
        assertEq(loan.nextPaymentDueDate(),                 block.timestamp + loan.paymentInterval());
        assertEq(loan.principal(),                          amount);

        token.transfer(address(loan), requestedAmount / 2);

        (ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");
    }

    function test_lend_sendingExtra(uint256 requestedAmount_) external {
        uint256 requestedAmount = _constrainRequestAmount(requestedAmount_);
        _initializeLoanWithRequestAmount(requestedAmount);

        token.mint(address(this), requestedAmount + 1);
        token.transfer(address(loan), requestedAmount + 1);

        (bool ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");
    }

    function test_lend_claimImmediatelyAfterLend(uint256 requestedAmount_) external {
        uint256 requestedAmount = _constrainRequestAmount(requestedAmount_);
        _initializeLoanWithRequestAmount(requestedAmount);

        token.mint(address(this), requestedAmount);
        token.transfer(address(loan), requestedAmount);

        (bool ok, uint256 amount) = loan.lend(address(this));
        assertTrue(ok, "lend should have succeded");

        assertEq(loan.lender(),                             address(this));
        assertEq(amount,                                    requestedAmount);
        assertEq(loan.getUnaccountedAmount(address(token)), 0);
        assertEq(loan.drawableFunds(),                      amount);
        assertEq(loan.nextPaymentDueDate(),                 block.timestamp + loan.paymentInterval());
        assertEq(loan.principal(),                          amount);

        try loan.claimFunds(requestedAmount, address(this)) {
            assertTrue(false);
        } catch {
            assertTrue(true);
        }
    }

}
