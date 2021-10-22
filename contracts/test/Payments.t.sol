// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { TestUtils, Hevm, StateManipulations } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }                              from "../../modules/erc20/src/interfaces/IERC20.sol";
import { MockERC20 }                           from "../../modules/erc20/src/test/mocks/MockERC20.sol";
import { MapleProxyFactory }                   from "../../modules/maple-proxy-factory/contracts/MapleProxyFactory.sol";

import { MapleLoan }            from "../MapleLoan.sol";
import { MapleLoanInitializer } from "../MapleLoanInitializer.sol";

import { Borrower } from "./accounts/Borrower.sol";
import { Governor } from "./accounts/Governor.sol";

import { MapleGlobalsMock, LenderMock } from "./mocks/Mocks.sol";

contract MapleLoanPaymentsTest is StateManipulations, TestUtils {

    address constant mapleTreasury = address(8181);
    address constant poolDelegate  = address(6161);

    uint256 start;

    Borrower             borrower;
    Governor             governor;
    LenderMock           lender;
    MapleGlobalsMock     globals;
    MapleLoan            implementation;
    MapleProxyFactory    factory;
    MapleLoanInitializer initializer;
    MockERC20            collateralAsset;
    MockERC20            fundsAsset;

    function setUp() external {
        start = block.timestamp;

        borrower = new Borrower();
        governor = new Governor();
        lender   = new LenderMock();

        collateralAsset = new MockERC20("Collateral Asset", "CA", 18);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 18);

        globals = new MapleGlobalsMock(address(governor));

        factory        = new MapleProxyFactory(address(globals));
        implementation = new MapleLoan();
        initializer    = new MapleLoanInitializer();

        governor.mapleProxyFactory_registerImplementation(address(factory), 1, address(implementation), address(initializer));
        governor.mapleProxyFactory_setDefaultVersion(address(factory), 1);
    }

    function createLoanFundAndDrawdown(
        address[2] memory assets,
        uint256[6] memory parameters,
        uint256[3] memory requests,
        uint256[4] memory fees
    )
        internal returns (MapleLoan loan)
    {
        collateralAsset.mint(address(borrower), requests[0]);
        fundsAsset.mint(address(lender),        requests[1]);
        fundsAsset.mint(address(borrower),      requests[1]);  // Mint more than enough for borrower to make payments

        bytes memory arguments = initializer.encodeArguments(address(borrower), assets, parameters, requests, fees);

        // Create Loan
        loan = MapleLoan(factory.createInstance(arguments));

        // Approve and fund Loan
        lender.erc20_approve(address(fundsAsset), address(loan),   requests[1]);
        lender.loan_fundLoan(address(loan),       address(lender), requests[1]);

        // Transfer and post collateral and drawdown
        borrower.erc20_transfer(address(collateralAsset), address(loan), requests[0]);
        borrower.loan_postCollateral(address(loan), requests[0]);
        borrower.loan_drawdownFunds(address(loan), requests[1], address(borrower));  // Will drawdown 985k
    }

    function assertOnTimePayment(
        MapleLoan loan,
        uint256 principalPortion,
        uint256 interestPortion,
        uint256 principalRemaining,
        uint256 total,
        uint256 paymentsMade
    )
        internal returns (uint256 paymentAmount)
    {
        ( uint256 actualPrincipalPortion, uint256 actualInterestPortion, uint256 actualLateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        paymentAmount = actualPrincipalPortion + actualInterestPortion + actualLateFeesPortion;

        assertIgnoringDecimals(paymentAmount, total, 13);  // Constant payment amounts

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertIgnoringDecimals(principalPortion,      actualPrincipalPortion, 13);
        assertIgnoringDecimals(interestPortion,       actualInterestPortion,  13);
        assertIgnoringDecimals(actualLateFeesPortion, 0,                      13);

        // Warp to when payment is due and make payment
        hevm.warp(loan.nextPaymentDueDate());
        borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
        borrower.loan_makePayments(address(loan), 1, paymentAmount);

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract

        assertIgnoringDecimals(loan.principal(),  principalRemaining, 13);  // Principal decreasing in accordance with provided values

        assertEq(loan.paymentsRemaining(),  6 - paymentsMade);                                     // Payments remaining increases
        assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * (paymentsMade + 1));  // Payment due date increases
    }

    function onTimePaymentsTest(
        MapleLoan loan,
        uint256[3] memory requests,
        uint256[6] memory principalPortions,
        uint256[6] memory interestPortions,
        uint256[6] memory principalRemaining,
        uint256[6] memory totals,
        uint256 grandTotal
    )
        internal
    {
        assertEq(fundsAsset.balanceOf(address(loan)), 0);

        assertEq(loan.claimableFunds(),     0);
        assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval());
        assertEq(loan.principal(),          requests[1]);
        assertEq(loan.paymentsRemaining(),  6);  // Using six payments for all tests since array lengths are fixed

        uint256 grandTotalPaid;

        for (uint256 i = 0; i < 6; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                principalPortions[i],
                interestPortions[i],
                principalRemaining[i],
                totals[i],
                i + 1
            );

            assertEq(fundsAsset.balanceOf(address(loan)), grandTotalPaid);  // Balance increasing by amount paid exactly
            assertEq(loan.claimableFunds(),               grandTotalPaid);  // Claimable funds increasing by amount paid exactly
        }

        assertEq(loan.principal(), 0);

        assertIgnoringDecimals(grandTotalPaid, grandTotal, 13);
    }

}

contract FullyAmortizedPaymentsTest is MapleLoanPaymentsTest {

    function test_payments_fullyAmortized_case1() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          0
        /*** Interest Rate             10%
        /*** Payment Interval (days)   30
        /*** Term                      180
        /*** Number of payments        6
        /*** Interest Rate per period  0.82%
        /*** Payment Amount per period 171,494
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(30 days),  // Monthly, 6 month term
            uint256(6),
            uint256(0.10 ether),
            uint256(0.10 ether),
            uint256(0)
        ];

        uint256[3] memory requests = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(0)];

        uint256[4] memory fees = [uint256(0), uint256(0), uint256(0), uint256(0)];

        uint256[6] memory totals = [
            uint256(171_493.890825 ether),
            uint256(171_493.890825 ether),
            uint256(171_493.890825 ether),
            uint256(171_493.890825 ether),
            uint256(171_493.890825 ether),
            uint256(171_493.890825 ether)
        ];

        uint256[6] memory principalPortions = [
            uint256(163_274.712742 ether),
            uint256(164_616.696683 ether),
            uint256(165_969.710628 ether),
            uint256(167_333.845236 ether),
            uint256(168_709.191909 ether),
            uint256(170_095.842802 ether)
        ];

        uint256[6] memory interestPortions = [
            uint256(8_219.178082 ether),
            uint256(6_877.194142 ether),
            uint256(5_524.180197 ether),
            uint256(4_160.045589 ether),
            uint256(2_784.698915 ether),
            uint256(1_398.048023 ether)
        ];

        uint256[6] memory principalRemaining = [
            uint256(836_725.287258 ether),
            uint256(672_108.590575 ether),
            uint256(506_138.879947 ether),
            uint256(338_805.034711 ether),
            uint256(170_095.842802 ether),
            uint256(      0.000000 ether)
        ];

        uint256 grandTotal = 1_028_963.344948 ether;

        MapleLoan loan = createLoanFundAndDrawdown(assets, parameters, requests, fees);

        onTimePaymentsTest(loan, requests, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }

    function test_payments_fullyAmortized_case2() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          0
        /*** Interest Rate             15%
        /*** Payment Interval (days)   15
        /*** Term                      90
        /*** Number of payments        6
        /*** Interest Rate per period  0.62%
        /*** Payment Amount per period 170,281
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(15 days),  // Fortnightly, 6 month term
            uint256(6),
            uint256(0.15 ether),
            uint256(0.15 ether),
            uint256(0)
        ];

        uint256[3] memory requests = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(0)];

        uint256[4] memory fees = [uint256(0), uint256(0), uint256(0), uint256(0)];

        uint256[6] memory totals = [
            uint256(170_280.971987 ether),
            uint256(170_280.971987 ether),
            uint256(170_280.971987 ether),
            uint256(170_280.971987 ether),
            uint256(170_280.971987 ether),
            uint256(170_280.971987 ether)
        ];

        uint256[6] memory principalPortions = [
            uint256(164_116.588425 ether),
            uint256(165_128.266025 ether),
            uint256(166_146.179994 ether),
            uint256(167_170.368775 ether),
            uint256(168_200.871048 ether),
            uint256(169_237.725733 ether)
        ];

        uint256[6] memory interestPortions = [
            uint256(6_164.383562 ether),
            uint256(5_152.705962 ether),
            uint256(4_134.791993 ether),
            uint256(3_110.603212 ether),
            uint256(2_080.100939 ether),
            uint256(1_043.246255 ether)
        ];

        uint256[6] memory principalRemaining = [
            uint256(835_883.411575 ether),
            uint256(670_755.145549 ether),
            uint256(504_608.965555 ether),
            uint256(337_438.596781 ether),
            uint256(169_237.725733 ether),
            uint256(      0.000000 ether)
        ];

        uint256 grandTotal = 1_021_685.831922 ether;

        MapleLoan loan = createLoanFundAndDrawdown(assets, parameters, requests, fees);

        onTimePaymentsTest(loan, requests, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }
}

contract PartiallyAmortizedPaymentsTest is MapleLoanPaymentsTest {

    function test_payments_partiallyAmortized_case1() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          800,000
        /*** Interest Rate             10%
        /*** Payment Interval (days)   30
        /*** Term                      180
        /*** Number of payments        6
        /*** Interest Rate per period  0.82%
        /*** Payment Amount per period 40,874
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(30 days),  // Monthly, 6 month term
            uint256(6),
            uint256(0.10 ether),
            uint256(0.10 ether),
            uint256(0)
        ];

        uint256[3] memory requests = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(800_000 ether)];

        uint256[4] memory fees = [uint256(0), uint256(0), uint256(0), uint256(0)];

        uint256[6] memory totals = [
            uint256( 40_874.120631 ether),
            uint256( 40_874.120631 ether),
            uint256( 40_874.120631 ether),
            uint256( 40_874.120631 ether),
            uint256( 40_874.120631 ether),
            uint256(840_874.120631 ether)
        ];

        uint256[6] memory principalPortions = [
            uint256( 32_654.942548 ether),
            uint256( 32_923.339337 ether),
            uint256( 33_193.942126 ether),
            uint256( 33_466.769047 ether),
            uint256( 33_741.838382 ether),
            uint256(834_019.168560 ether)
        ];

        uint256[6] memory interestPortions = [
            uint256(8_219.178082 ether),
            uint256(7_950.781294 ether),
            uint256(7_680.178505 ether),
            uint256(7_407.351583 ether),
            uint256(7_132.282249 ether),
            uint256(6_854.952070 ether)
        ];

        uint256[6] memory principalRemaining = [
            uint256(967_345.057452 ether),
            uint256(934_421.718115 ether),
            uint256(901_227.775989 ether),
            uint256(867_761.006942 ether),
            uint256(834_019.168560 ether),
            uint256(      0.000000 ether)
        ];

        uint256 grandTotal = 1_045_244.723784 ether;

        MapleLoan loan = createLoanFundAndDrawdown(assets, parameters, requests, fees);

        onTimePaymentsTest(loan, requests, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }

    function test_payments_partiallyAmortized_case2() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          350,000
        /*** Interest Rate             13%
        /*** Payment Interval (days)   15
        /*** Term                      90
        /*** Number of payments        6
        /*** Interest Rate per period  0.53%
        /*** Payment Amount per period 112,238
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(15 days),  // Fortnightly, 6 month term
            uint256(6),
            uint256(0.13 ether),
            uint256(0.13 ether),
            uint256(0)
        ];

        uint256[3] memory requests = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(350_000 ether)];

        uint256[4] memory fees = [uint256(0), uint256(0), uint256(0), uint256(0)];

        uint256[6] memory totals = [
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(462_237.875576 ether)
        ];


        uint256[6] memory principalPortions = [
            uint256(106_895.409823 ether),
            uint256(107_466.494889 ether),
            uint256(108_040.630958 ether),
            uint256(108_617.834329 ether),
            uint256(109_198.121389 ether),
            uint256(459_781.508613 ether)
        ];

        uint256[6] memory interestPortions = [
            uint256(5_342.465753 ether),
            uint256(4_771.380687 ether),
            uint256(4_197.244619 ether),
            uint256(3_620.041248 ether),
            uint256(3_039.754188 ether),
            uint256(2_456.366964 ether)
        ];

        uint256[6] memory principalRemaining = [
            uint256(893_104.590177 ether),
            uint256(785_638.095288 ether),
            uint256(677_597.464330 ether),
            uint256(568_979.630001 ether),
            uint256(459_781.508613 ether),
            uint256(      0.000000 ether)
        ];

        uint256 grandTotal = 1_023_427.253459 ether;

        MapleLoan loan = createLoanFundAndDrawdown(assets, parameters, requests, fees);

        onTimePaymentsTest(loan, requests, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }
}

contract InterestOnlyPaymentsTest is MapleLoanPaymentsTest {

    function test_payments_interestOnly_case1() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          1,000,000
        /*** Interest Rate             10%
        /*** Payment Interval (days)   30
        /*** Term                      180
        /*** Number of payments        6
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(30 days),  // Monthly, 6 month term
            uint256(6),
            uint256(0.10 ether),
            uint256(0.10 ether),
            uint256(0)
        ];

        uint256[3] memory requests = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(1_000_000 ether)];

        uint256[4] memory fees = [uint256(0), uint256(0), uint256(0), uint256(0)];

        uint256[6] memory totals = [
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(1_008_219.178082 ether)
        ];

        uint256[6] memory principalPortions = [
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(1_000_000.000000 ether)
        ];

        uint256[6] memory interestPortions = [
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether)
        ];

        uint256[6] memory principalRemaining = [
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(        0.000000 ether)
        ];

        uint256 grandTotal = 1_049_315.068493 ether;

        MapleLoan loan = createLoanFundAndDrawdown(assets, parameters, requests, fees);

        onTimePaymentsTest(loan, requests, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }

    function test_payments_interestOnly_case2() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          1,000,000
        /*** Interest Rate             15%
        /*** Payment Interval (days)   15
        /*** Term                      90
        /*** Number of payments        6
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(15 days),  // Fortnightly, 6 month term
            uint256(6),
            uint256(0.15 ether),
            uint256(0.15 ether),
            uint256(0)
        ];

        uint256[3] memory requests = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(1_000_000 ether)];

        uint256[4] memory fees = [uint256(0), uint256(0), uint256(0), uint256(0)];

        uint256[6] memory totals = [
            uint256(    6_164.383562 ether),
            uint256(    6_164.383562 ether),
            uint256(    6_164.383562 ether),
            uint256(    6_164.383562 ether),
            uint256(    6_164.383562 ether),
            uint256(1_006_164.383562 ether)
        ];

        uint256[6] memory principalPortions = [
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(1_000_000.000000 ether)
        ];

        uint256[6] memory interestPortions = [
            uint256(6_164.383562 ether),
            uint256(6_164.383562 ether),
            uint256(6_164.383562 ether),
            uint256(6_164.383562 ether),
            uint256(6_164.383562 ether),
            uint256(6_164.383562 ether)
        ];

        uint256[6] memory principalRemaining = [
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(        0.000000 ether)
        ];

        uint256 grandTotal = 1_036_986.3013699 ether;

        MapleLoan loan = createLoanFundAndDrawdown(assets, parameters, requests, fees);

        onTimePaymentsTest(loan, requests, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }
}

contract EarlyRepaymentsTest is MapleLoanPaymentsTest {

    function test_payments_earlyRepaymentFlatRate_case1() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          800,000
        /*** Interest Rate             13%
        /*** Payment Interval (days)   30
        /*** Term                      180
        /*** Number of payments        6
        /*** Early Repayment Fee Rate  2%
        /*** Early Repayment Day       113
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(30 days),  // Monthly, 6 month term
            uint256(6),
            uint256(0.13e18),
            uint256(0.13e18),  // 100% early interest discount since no interest is charged
            uint256(0)
        ];

        uint256[3] memory requests = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(800_000 ether)];

        uint256[4] memory fees = [uint256(0), uint256(0.02e18), uint256(0), uint256(0)];  // 2% flat rate for early repayment

        uint256[3] memory onTimeTotals = [
            uint256(43_138.893875 ether),
            uint256(43_138.893875 ether),
            uint256(43_138.893875 ether)
        ];

        uint256[3] memory onTimePrincipalPortions = [
            uint256(32_453.962368 ether),
            uint256(32_800.730733 ether),
            uint256(33_151.204295 ether)
        ];

        uint256[3] memory onTimeInterestPortions = [
            uint256(10_684.931507 ether),
            uint256(10_338.163142 ether),
            uint256( 9_987.689581 ether)
        ];

        uint256[3] memory onTimePrincipalRemaining = [
            uint256(967_546.037632 ether),
            uint256(934_745.306898 ether),
            uint256(901_594.102603 ether)
        ];

        MapleLoan loan = createLoanFundAndDrawdown(assets, parameters, requests, fees);

        uint256 grandTotalPaid;

        // Make first three on time payments
        for (uint256 i = 0; i < 3; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                i + 1
            );
        }

        // On day 90, warp to day 113
        hevm.warp(block.timestamp + 23 days);

        // Get amounts for the remaining loan payments
        ( uint256 principalPortion, uint256 interestPortion, uint256 feesPortion ) = loan.getNextPaymentsBreakDown(3);

        uint256 paymentAmount = principalPortion + interestPortion + feesPortion;

        assertIgnoringDecimals(paymentAmount, uint256(919_625.984655 ether), 13);  // Constant payment amounts

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertIgnoringDecimals(principalPortion, uint256(901_594.102603 ether), 13);
        assertIgnoringDecimals(interestPortion,  uint256(0),                    13);
        assertIgnoringDecimals(feesPortion,      uint256(18_031.882052 ether),  13);

        // Make payment
        borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
        borrower.loan_makePayments(address(loan), 3, paymentAmount);

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract

        assertEq(loan.principal(), 0);  // No principal left

        assertEq(loan.paymentsRemaining(),  0);  // Payments remaining increases
        assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * (6 + 1));  // Payment due date increases
    }

    function test_payments_earlyRepaymentFlatRate_case2() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          0
        /*** Interest Rate             13%
        /*** Payment Interval (days)   30
        /*** Term                      90
        /*** Number of payments        6
        /*** Early Repayment Fee Rate  2%
        /*** Early Repayment Day       78
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(15 days),
            uint256(6),
            uint256(0.13e18),
            uint256(0.13e18),  // 100% early interest discount since no interest is charged
            uint256(0)
        ];

        uint256[3] memory requests = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(0)];

        uint256[4] memory fees = [uint256(0), uint256(0.02e18), uint256(0), uint256(0)];  // 2% flat rate for early repayment

        uint256[2] memory onTimeTotals = [
            uint256(169_796.942404 ether),
            uint256(169_796.942404 ether)
        ];

        uint256[2] memory onTimePrincipalPortions = [
            uint256(164_454.476651 ether),
            uint256(165_333.069060 ether)
        ];

        uint256[2] memory onTimeInterestPortions = [
            uint256(5_342.465753 ether),
            uint256(4_463.873344 ether)
        ];

        uint256[2] memory onTimePrincipalRemaining = [
            uint256(835_545.523349 ether),
            uint256(670_212.454289 ether)
        ];

        MapleLoan loan = createLoanFundAndDrawdown(assets, parameters, requests, fees);

        uint256 grandTotalPaid;

        // Make first three on time payments
        for (uint256 i = 0; i < 2; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                i + 1
            );
        }

        // On day 30, warp to day 44
        hevm.warp(block.timestamp + 14 days);

        // Get amounts for the remaining loan payments
        ( uint256 principalPortion, uint256 interestPortion, uint256 feesPortion ) = loan.getNextPaymentsBreakDown(4);

        uint256 paymentAmount = principalPortion + interestPortion + feesPortion;

        assertIgnoringDecimals(paymentAmount, uint256(683_616.703375 ether), 13);  // Constant payment amounts

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertIgnoringDecimals(principalPortion, uint256(670_212.454289 ether), 13);
        assertIgnoringDecimals(interestPortion,  uint256(0),                    13);
        assertIgnoringDecimals(feesPortion,      uint256(13_404.249086 ether),  13);

        // Make payment
        borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
        borrower.loan_makePayments(address(loan), 4, paymentAmount);

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract

        assertEq(loan.principal(), 0);  // No principal left

        assertEq(loan.paymentsRemaining(),  0);  // Payments remaining increases
        assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * (6 + 1));  // Payment due date increases
    }

}
