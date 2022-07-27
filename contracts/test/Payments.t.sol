// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }                              from "../../modules/erc20/contracts/interfaces/IERC20.sol";
import { MockERC20 }                           from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { MapleProxyFactory }                   from "../../modules/maple-proxy-factory/contracts/MapleProxyFactory.sol";

import { MapleLoan }            from "../MapleLoan.sol";
import { MapleLoanInitializer } from "../MapleLoanInitializer.sol";

import { Borrower } from "./accounts/Borrower.sol";
import { Governor } from "./accounts/Governor.sol";
import { Lender }   from "./accounts/Lender.sol";

import { MapleGlobalsMock, MockFeeManager } from "./mocks/Mocks.sol";

// TODO: Add fees
contract MapleLoanPaymentsTestBase is TestUtils {

    uint256 start;

    Borrower             borrower;
    Governor             governor;
    Lender               lender;
    MapleGlobalsMock     globals;
    MapleLoan            implementation;
    MapleProxyFactory    factory;
    MapleLoanInitializer initializer;
    MockERC20            collateralAsset;
    MockERC20            fundsAsset;
    MockFeeManager       feeManager;

    function setUp() external {
        start = block.timestamp;

        borrower = new Borrower();
        governor = new Governor();
        lender   = new Lender();

        collateralAsset = new MockERC20("Collateral Asset", "CA", 18);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 18);

        globals = new MapleGlobalsMock(address(governor));

        feeManager     = new MockFeeManager();
        factory        = new MapleProxyFactory(address(globals));
        implementation = new MapleLoan();
        initializer    = new MapleLoanInitializer();

        globals.setValidBorrower(address(borrower), true);

        governor.mapleProxyFactory_registerImplementation(address(factory), 1, address(implementation), address(initializer));
        governor.mapleProxyFactory_setDefaultVersion(address(factory), 1);
    }

    function createLoanFundAndDrawdown(
        address[2] memory assets,
        uint256[3] memory termDetails,
        uint256[3] memory amounts,
        uint256[5] memory rates
    )
        internal returns (MapleLoan loan)
    {
        collateralAsset.mint(address(borrower), amounts[0]);
        fundsAsset.mint(address(lender),        amounts[1]);
        fundsAsset.mint(address(borrower),      amounts[1]);  // Mint more than enough for borrower to make payments

        bytes memory arguments = initializer.encodeArguments(address(globals), address(borrower), address(feeManager), 0, assets, termDetails, amounts, rates);
        bytes32 salt           = keccak256(abi.encodePacked("salt"));

        // Create Loan
        loan = MapleLoan(factory.createInstance(arguments, salt));

        // Approve and fund Loan
        lender.erc20_transfer(address(fundsAsset), address(loan), amounts[1]);
        lender.loan_fundLoan(address(loan), address(lender));

        // Transfer and post collateral and drawdown
        borrower.erc20_transfer(address(collateralAsset), address(loan), amounts[0]);
        borrower.loan_postCollateral(address(loan), 0);
        borrower.loan_drawdownFunds(address(loan), amounts[1], address(borrower));
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
        ( uint256 actualPrincipalPortion, uint256 actualInterestPortion, ) = loan.getNextPaymentBreakdown();

        paymentAmount = actualPrincipalPortion + actualInterestPortion;

        assertIgnoringDecimals(paymentAmount, total, 13);  // Constant payment amounts

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertIgnoringDecimals(principalPortion, actualPrincipalPortion, 13);
        assertIgnoringDecimals(interestPortion,  actualInterestPortion,  13);

        // Warp to when payment is due and make payment
        vm.warp(loan.nextPaymentDueDate());
        borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
        borrower.loan_makePayment(address(loan), 0);

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract

        assertIgnoringDecimals(loan.principal(),  principalRemaining, 13);  // Principal decreasing in accordance with provided values

        uint256 paymentsRemaining = 6 - paymentsMade;

        assertEq(loan.paymentsRemaining(), paymentsRemaining);  // Payments remaining increases

        assertEq(
            loan.nextPaymentDueDate(),
            paymentsRemaining == 0 ? 0 : start + loan.paymentInterval() * (paymentsMade + 1)  // Payment due cleared or increased
        );
    }

    function onTimePaymentsTest(
        MapleLoan loan,
        uint256[3] memory amounts,
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
        assertEq(loan.principal(),          amounts[1]);
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

contract ClosingTests is MapleLoanPaymentsTestBase {

    function test_payments_closing_flatRate_case1() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          800,000
        /*** Interest Rate             13%
        /*** Payment Interval (days)   30
        /*** Term                      180
        /*** Number of payments        6
        /*** Closing Rate              2%
        /*** Early Repayment Day       113
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(30 days),  // Monthly, 6 month term
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(800_000 ether)];

        uint256[5] memory rates = [uint256(0.13e18), uint256(0.02e18), uint256(0), uint256(0), uint256(0)];  // 2% flat rate for closing loan

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

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

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
        vm.warp(block.timestamp + 23 days);

        // Get amounts for the remaining loan payments
        ( uint256 principalPortion, uint256 interestPortion, ) = loan.getClosingPaymentBreakdown();

        uint256 paymentAmount = principalPortion + interestPortion;

        assertIgnoringDecimals(paymentAmount, uint256(919_625.984655 ether), 13);  // Constant payment amounts

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertIgnoringDecimals(principalPortion, uint256(901_594.102603 ether), 13);
        assertIgnoringDecimals(interestPortion,  uint256(18_031.882052 ether),  13);

        // Make payment
        borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
        borrower.loan_closeLoan(address(loan), 0);

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract

        assertEq(loan.principal(), 0);  // No principal left

        assertEq(loan.paymentsRemaining(),  0);  // Payments remaining increases
        assertEq(loan.nextPaymentDueDate(), 0);  // Payment due date increases
    }

    function test_payments_closing_flatRate_case2() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          0
        /*** Interest Rate             13%
        /*** Payment Interval (days)   30
        /*** Term                      90
        /*** Number of payments        6
        /*** Closing Rate              2%
        /*** Early Repayment Day       78
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(15 days),
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(0)];

        uint256[5] memory rates = [uint256(0.13e18), uint256(0.02e18), uint256(0), uint256(0), uint256(0)];  // 2% flat rate for closing loan

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

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

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
        vm.warp(block.timestamp + 14 days);

        // Get amounts for the remaining loan payments
        ( uint256 principalPortion, uint256 interestPortion, ) = loan.getClosingPaymentBreakdown();

        uint256 paymentAmount = principalPortion + interestPortion;

        assertIgnoringDecimals(paymentAmount, uint256(683_616.703375 ether), 13);  // Constant payment amounts

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertIgnoringDecimals(principalPortion, uint256(670_212.454289 ether), 13);
        assertIgnoringDecimals(interestPortion,  uint256(13_404.249086 ether),  13);

        // Make payment
        borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
        borrower.loan_closeLoan(address(loan), 0);

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract

        assertEq(loan.principal(), 0);  // No principal left

        assertEq(loan.paymentsRemaining(),  0);  // Payments remaining increases
        assertEq(loan.nextPaymentDueDate(), 0);  // Payment due date increases
    }

}

contract FullyAmortizedPaymentsTests is MapleLoanPaymentsTestBase {

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

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(30 days),  // Monthly, 6 month term
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(0)];

        uint256[5] memory rates = [uint256(0.1e18), uint256(0), uint256(0), uint256(0), uint256(0)];

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

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        onTimePaymentsTest(loan, amounts, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
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

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(15 days),  // Fortnightly, 6 month term
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(0)];

        uint256[5] memory rates = [uint256(0.15e18), uint256(0), uint256(0), uint256(0), uint256(0)];

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

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        onTimePaymentsTest(loan, amounts, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }
}

contract InterestOnlyPaymentsTests is MapleLoanPaymentsTestBase {

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

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(30 days),  // Monthly, 6 month term
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(1_000_000 ether)];

        uint256[5] memory rates = [uint256(0.1e18), uint256(0), uint256(0), uint256(0), uint256(0)];

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

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        onTimePaymentsTest(loan, amounts, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
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

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(15 days),  // Fortnightly, 6 month term
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(1_000_000 ether)];

        uint256[5] memory rates = [uint256(0.15e18), uint256(0), uint256(0), uint256(0), uint256(0)];

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

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        onTimePaymentsTest(loan, amounts, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }
}

contract LateRepaymentsTests is MapleLoanPaymentsTestBase {

    function test_payments_lateRepayment_flatRate_case1() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          350,000
        /*** Interest Rate             13%
        /*** Payment Interval (days)   15
        /*** Term                      90
        /*** Number of payments        6
        /*** Late Repayment Flat Rate  2%
        /*** Late Repayment Day        90 (One second late)
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(15 days),
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(350_000 ether)];

        uint256[5] memory rates = [uint256(0.13e18), uint256(0), uint256(0.05e18), uint256(0), uint256(0)];  // 5% Late fee flat rate on principal

        uint256[5] memory onTimeTotals = [
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether)
        ];

        uint256[5] memory onTimePrincipalPortions = [
            uint256(106_895.409823 ether),
            uint256(107_466.494889 ether),
            uint256(108_040.630958 ether),
            uint256(108_617.834329 ether),
            uint256(109_198.121389 ether)
        ];

        uint256[5] memory onTimeInterestPortions = [
            uint256(5_342.465753 ether),
            uint256(4_771.380687 ether),
            uint256(4_197.244619 ether),
            uint256(3_620.041248 ether),
            uint256(3_039.754188 ether)
        ];

        uint256[5] memory onTimePrincipalRemaining = [
            uint256(893_104.590177 ether),
            uint256(785_638.095288 ether),
            uint256(677_597.464330 ether),
            uint256(568_979.630001 ether),
            uint256(459_781.508613 ether)
        ];

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        uint256 grandTotalPaid;

        // Make first five on time payments
        for (uint256 i = 0; i < 5; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                i + 1
            );
        }

        // On day 75, warp to day 90 plus one second (one second late)
        vm.warp(block.timestamp + 15 days + 1 seconds);

        // Get amounts for the remaining loan payments
        ( uint256 principalPortion, uint256 interestPortion, )  = loan.getNextPaymentBreakdown();

        uint256 lateInterest = loan.principal() * 1300 * uint256(1 days) / 365 days / 10_000;  // Add one day of late payment (one second = one day of late interest)
        uint256 lateFee      = 22_989.075431 ether;

        uint256 paymentAmount = principalPortion + interestPortion;

        assertIgnoringDecimals(paymentAmount, uint256(485_226.951007 ether) + lateInterest, 12);  // Late interest wasn't accounted for in sheet

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertIgnoringDecimals(principalPortion, uint256(459_781.508613 ether),                          13);
        assertIgnoringDecimals(interestPortion,  uint256(  2_456.366964 ether) + lateInterest + lateFee, 13);  // Note: This was 2,292.609166 + 163.757798 from sheet, also late interest wasn't accounted for

        // Make payment
        borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
        borrower.loan_makePayment(address(loan), 0);

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract

        assertEq(loan.principal(), 0);  // No principal left

        assertEq(loan.paymentsRemaining(),  0);  // Payments remaining cleared
        assertEq(loan.nextPaymentDueDate(), 0);  // Payment due date cleared
    }

    function test_payments_lateRepayment_flatRate_case2() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                    1,000,000
        /*** Ending Principal          1,000,000
        /*** Interest Rate             10%
        /*** Payment Interval (days)   30
        /*** Term                      180
        /*** Number of payments        6
        /*** Late Repayment Flat Rate  5%
        /*** Late Repayment Day        90 (Two hours late)
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(30 days),
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(1_000_000 ether)];

        uint256[5] memory rates = [uint256(0.1e18), uint256(0), uint256(0.05e18), uint256(0), uint256(0)]; // 5% Late fee flat rate on principal

        // Payments 1, 2, 4, 5, 6
        uint256[5] memory onTimeTotals = [
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(1_008_219.178082 ether)
        ];

        uint256[5] memory onTimePrincipalPortions = [
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(1_000_000.000000 ether)
        ];

        uint256[5] memory onTimeInterestPortions = [
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether)
        ];

        uint256[5] memory onTimePrincipalRemaining = [
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(        0.000000 ether)
        ];

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        uint256 grandTotalPaid;

        // Make on two on time payments
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

        {
            // On day 60, warp to day 90 plus two hours
            vm.warp(block.timestamp + 30 days + 2 hours);

            // Get amounts for the remaining loan payments
            ( uint256 principalPortion, uint256 interestPortion, ) = loan.getNextPaymentBreakdown();

            uint256 lateInterest = loan.principal() * 1000 * uint256(1 days) / 365 days / 10_000;  // Add two hours of late interest (which is 1 day of default interest).
            uint256 lateFee      = uint256(50_000.000000 ether);

            uint256 paymentAmount = principalPortion + interestPortion;

            assertIgnoringDecimals(paymentAmount, uint256(58_219.178082 ether) + lateInterest, 12);  // Late interest wasn't accounted for in sheet.

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertIgnoringDecimals(principalPortion, uint256(     0.000000 ether),                          13);
            assertIgnoringDecimals(interestPortion,  uint256( 8_219.178082 ether) + lateInterest + lateFee, 13);  // Note: Late interest wasn't accounted for.

            // Make payment
            borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
            borrower.loan_makePayment(address(loan), 0);

            assertEq(loan.paymentsRemaining(),  3);  // Payments remaining increases
            assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * 4);  // Payment due date increases.
        }

        // Make on three on time payments
        for (uint256 i = 2; i < 5; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                i + 2
            );
        }

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract
        assertEq(loan.principal(),     0);  // No principal left
    }

    function test_payments_lateRepayment_flatRateAndDefaultRate_case1() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                     1,000,000
        /*** Ending Principal           350,000
        /*** Interest Rate              13%
        /*** Payment Interval (days)    15
        /*** Term                       90
        /*** Number of payments         6
        /*** Late Flat Rate             5%
        /*** Late Default Interest Rate 18%  // NOTE: Assuming sheet meant 5% premium
        /*** Late Repayment Day         46 (16 days late)
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(15 days),
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(350_000 ether)];

        uint256[5] memory rates = [uint256(0.13e18), uint256(0), uint256(0.05e18), uint256(0.05e18), uint256(0)];  // 5% Late fee flat rate on principal, 5% premium

        // All payment amounts under normal amortization schedule in sheet
        uint256[6] memory onTimeTotals = [
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(112_237.875576 ether),
            uint256(462_237.875576 ether)
        ];

        uint256[6] memory onTimePrincipalPortions = [
            uint256(106_895.409823 ether),
            uint256(107_466.494889 ether),
            uint256(108_040.630958 ether),
            uint256(108_617.834329 ether),
            uint256(109_198.121389 ether),
            uint256(459_781.508613 ether)
        ];

        uint256[6] memory onTimeInterestPortions = [
            uint256(5_342.465753 ether),
            uint256(4_771.380687 ether),
            uint256(4_197.244619 ether),
            uint256(3_620.041248 ether),
            uint256(3_039.754188 ether),
            uint256(2_456.366964 ether)
        ];

        uint256[6] memory onTimePrincipalRemaining = [
            uint256(893_104.590177 ether),
            uint256(785_638.095288 ether),
            uint256(677_597.464330 ether),
            uint256(568_979.630001 ether),
            uint256(459_781.508613 ether),
            uint256(0.000000       ether)
        ];

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        uint256 grandTotalPaid;

        // Make first payment
        grandTotalPaid += assertOnTimePayment(
            loan,
            onTimePrincipalPortions[0],
            onTimeInterestPortions[0],
            onTimePrincipalRemaining[0],
            onTimeTotals[0],
            1
        );

        /*****************************************/
        /*** First Late Payment (16 days late) ***/
        /*****************************************/
        {
            // On day 15, warp to day 46 (16 days late)
            vm.warp(block.timestamp + 31 days);

            // Get amounts for the remaining loan payments
            ( uint256 principalPortion, uint256 interestPortion, ) = loan.getNextPaymentBreakdown();

            uint256 lateInterest = loan.principal() * 1800 * uint256(16 days) / 365 days / 10_000;  // Add sixteen days of late interest
            uint256 lateFee      = loan.principal() * 500 / 10_000;

            assertIgnoringDecimals(lateInterest, 7046.962245 ether, 13);

            uint256 paymentAmount = principalPortion + interestPortion;

            assertIgnoringDecimals(paymentAmount, uint256(163_940.067331 ether), 13);

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertIgnoringDecimals(principalPortion, onTimePrincipalPortions[1],                         13);  // Principal should be in accordance with schedule always
            assertIgnoringDecimals(interestPortion,  onTimeInterestPortions[1] + lateInterest + lateFee, 13);  // Note: Late interest wasn't accounted for

            // Make payment
            borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
            borrower.loan_makePayment(address(loan), 0);

            assertEq(loan.paymentsRemaining(),  4);  // Payments remaining increases
            assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * 3);  // Payment due date increases to day 30 (still one day late)
        }

        /****************************************/
        /*** Second Late Payment (1 day late) ***/
        /****************************************/
        {
            // Same timestamp - Day 46, due date is day 45

            // Get amounts for the remaining loan payments
            ( uint256 principalPortion, uint256 interestPortion, ) = loan.getNextPaymentBreakdown();

            uint256 lateInterest = loan.principal() * 1800 * uint256(1 days) / 365 days / 10_000;  // Add one day of late interest
            uint256 lateFee      = loan.principal() * 500 / 10_000;

            assertIgnoringDecimals(lateInterest, 387.437964 ether, 13);

            uint256 paymentAmount = principalPortion + interestPortion;

            assertIgnoringDecimals(paymentAmount, uint256(151_907.218305 ether), 13);

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertIgnoringDecimals(principalPortion, onTimePrincipalPortions[2],                         13);  // Principal should be in accordance with schedule always
            assertIgnoringDecimals(interestPortion,  onTimeInterestPortions[2] + lateInterest + lateFee, 13);  // Note: Late interest wasn't accounted for

            // Make payment
            borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
            borrower.loan_makePayment(address(loan), 0);

            assertEq(loan.paymentsRemaining(),  3);  // Payments remaining increases
            assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * 4);  // Payment due date increases to day 45 (still one day late)
        }

        // Make last three payments
        for (uint256 i = 3; i < 6; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                i + 1
            );
        }

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract
        assertEq(loan.principal(),     0);  // No principal left
    }

    function test_payments_lateRepayment_flatRateAndDefaultRate_case2() external {
        /****************************************/
        /*** Loan Terms:
        /*** Amount                     1,000,000
        /*** Ending Principal           1,000,000
        /*** Interest Rate              10%
        /*** Payment Interval (days)    30
        /*** Term                       180
        /*** Number of payments         6
        /*** Late Flat Rate             2%
        /*** Late Default Interest Rate 15%  // NOTE: Assuming sheet meant 5% premium
        /*** Late Repayment Day         32 (2 days late)
        /****************************************/

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(30 days),
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(1_000_000 ether)];

        uint256[5] memory rates = [uint256(0.10e18), uint256(0), uint256(0.02e18), uint256(0.05e18), uint256(0)];  // 2% Late fee rate on principal

        // Payments 2, 3, 4, 5, 6
        uint256[5] memory onTimeTotals = [
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(    8_219.178082 ether),
            uint256(1_008_219.178082 ether)
        ];

        uint256[5] memory onTimePrincipalPortions = [
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(        0.000000 ether),
            uint256(1_000_000.000000 ether)
        ];

        uint256[5] memory onTimeInterestPortions = [
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether),
            uint256(8_219.178082 ether)
        ];

        uint256[5] memory onTimePrincipalRemaining = [
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(1_000_000.000000 ether),
            uint256(        0.000000 ether)
        ];

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        uint256 grandTotalPaid;

        {
            // On day 0, warp to day 32 (two days late)
            vm.warp(block.timestamp + 32 days);

            // Get amounts for the remaining loan payments
            ( uint256 principalPortion, uint256 interestPortion, ) = loan.getNextPaymentBreakdown();


            uint256 lateInterest = loan.principal() * 1500 * uint256(2 days) / 365 days / 10_000;  // Add two days of late interest (15%)
            uint256 lateFee      = loan.principal() * 0.02e18 / 10 ** 18;
            assertIgnoringDecimals(lateInterest, 821.917808 ether, 13);

            uint256 paymentAmount = principalPortion + interestPortion;

            assertIgnoringDecimals(paymentAmount, uint256(28_219.178082 ether) + lateInterest, 12);  // Late interest wasn't accounted for in sheet

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertIgnoringDecimals(principalPortion, uint256(     0.000000 ether),                13);
            assertIgnoringDecimals(interestPortion,  uint256( 8_219.178082 ether) + lateInterest + lateFee, 13);  // Note: Late interest wasn't accounted for

            // Make payment
            borrower.erc20_transfer(address(fundsAsset), address(loan), paymentAmount);
            borrower.loan_makePayment(address(loan), 0);

            assertEq(loan.paymentsRemaining(),  5);  // Payments remaining increases
            assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * 2);  // Payment due date increases
        }

        // Make on two on time payments
        for (uint256 i = 0; i < 5; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                i + 2 // Starting on second payment
            );
        }
    }

    function test_payments_dailyInterestAccrual() external {

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(30 days),
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(1_000_000 ether)];

        uint256[5] memory rates = [uint256(0.10e18), uint256(0), uint256(0.02e18), uint256(0.05e18), uint256(0)];  // 2% Late fee rate on principal

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        // On day 0, warp to day 30 plus one second (one second late)
        vm.warp(start + 30 days + 1 seconds);

        // Get amounts for the remaining loan payments
        ( , uint256 interestPortion1 , ) = loan.getNextPaymentBreakdown();

        // Warp to day 31 (one day late exactly)
        vm.warp(start  + 31 days);

        ( , uint256 interestPortion2 , ) = loan.getNextPaymentBreakdown();

        assertEq(interestPortion1, interestPortion2);  // Same entire day

        // Warp one more second (one day plus one second late)
        vm.warp(start  + 31 days + 1 seconds);

        // Get amounts for the remaining loan payments
        ( , uint256 interestPortion3 , ) = loan.getNextPaymentBreakdown();

        assertTrue(interestPortion3 > interestPortion1);  // Default interest gets updated on the day
    }
}

contract PartiallyAmortizedPaymentsTests is MapleLoanPaymentsTestBase {

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

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(30 days),  // Monthly, 6 month term
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(800_000 ether)];

        uint256[5] memory rates = [uint256(0.1e18), uint256(0), uint256(0), uint256(0), uint256(0)];

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

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        onTimePaymentsTest(loan, amounts, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
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

        uint256[3] memory termDetails = [
            uint256(10 days),
            uint256(15 days),  // Fortnightly, 6 month term
            uint256(6)
        ];

        uint256[3] memory amounts = [uint256(300_000 ether), uint256(1_000_000 ether), uint256(350_000 ether)];

        uint256[5] memory rates = [uint256(0.13e18), uint256(0), uint256(0), uint256(0), uint256(0)];

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

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates);

        onTimePaymentsTest(loan, amounts, principalPortions, interestPortions, principalRemaining, totals, grandTotal);
    }
}
