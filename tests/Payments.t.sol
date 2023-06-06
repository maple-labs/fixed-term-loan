// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils, console } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { MapleProxyFactory }  from "../modules/maple-proxy-factory/contracts/MapleProxyFactory.sol";

import { MapleLoan }            from "../contracts/MapleLoan.sol";
import { MapleLoanFeeManager }  from "../contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer } from "../contracts/MapleLoanInitializer.sol";

import { MockGlobals, MockLoanManager, MockPoolManager } from "./mocks/Mocks.sol";

contract MapleLoanPaymentsTestBase is TestUtils {

    uint256 internal start;

    MapleLoan            internal implementation;
    MapleLoanFeeManager  internal feeManager;
    MapleLoanInitializer internal initializer;
    MapleProxyFactory    internal factory;
    MockERC20            internal collateralAsset;
    MockERC20            internal fundsAsset;
    MockGlobals          internal globals;
    MockLoanManager      internal lender;
    MockPoolManager      internal poolManager;

    address internal borrower     = address(new Address());
    address internal governor     = address(new Address());
    address internal poolDelegate = address(new Address());
    address internal treasury     = address(new Address());

    function setUp() external {
        start = block.timestamp;

        collateralAsset = new MockERC20("Collateral Asset", "CA", 18);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 18);
        globals         = new MockGlobals(governor);
        implementation  = new MapleLoan();
        initializer     = new MapleLoanInitializer();
        lender          = new MockLoanManager();
        poolManager     = new MockPoolManager(address(poolDelegate));

        feeManager = new MapleLoanFeeManager(address(globals));

        lender.__setPoolManager(address(poolManager));
        lender.__setFundsAsset(address(fundsAsset));

        factory = new MapleProxyFactory(address(globals));

        globals.setMapleTreasury(treasury);
        globals.setValidBorrower(borrower, true);

        globals.setPlatformServiceFeeRate(address(poolManager),     0.1e6);
        globals.setPlatformOriginationFeeRate(address(poolManager), 0.01e6);

        globals.setValidCollateralAsset(address(collateralAsset), true);
        globals.setValidPoolAsset(address(fundsAsset),            true);

        globals.__setIsInstanceOf(true);

        vm.startPrank(governor);
        factory.registerImplementation(1, address(implementation), address(initializer));
        factory.setDefaultVersion(1);
        vm.stopPrank();
    }

    function createLoanFundAndDrawdown(
        address[2] memory assets,
        uint256[3] memory termDetails,
        uint256[3] memory amounts,
        uint256[4] memory rates,
        uint256[2] memory fees
    )
        internal returns (MapleLoan loan)
    {
        collateralAsset.mint(borrower, amounts[0]);
        fundsAsset.mint(address(lender), amounts[1]);
        fundsAsset.mint(borrower, amounts[1]);  // Mint more than enough for borrower to make payments

        bytes memory arguments = initializer.encodeArguments(borrower, address(lender), address(feeManager), assets, termDetails, amounts, rates, fees);
        bytes32 salt           = keccak256(abi.encodePacked("salt"));

        // Create Loan
        loan = MapleLoan(factory.createInstance(arguments, salt));

        // Approve and fund Loan
        vm.startPrank(address(lender));
        fundsAsset.transfer(address(loan), amounts[1]);
        loan.fundLoan();
        vm.stopPrank();

        // Transfer and post collateral and drawdown
        vm.startPrank(borrower);

        collateralAsset.transfer(address(loan), amounts[0]);
        loan.postCollateral(0);
        loan.drawdownFunds(loan.drawableFunds(), borrower);

        vm.stopPrank();
    }

    function assertOnTimePayment(
        MapleLoan loan,
        uint256 principalPortion,
        uint256 interestPortion,
        uint256 principalRemaining,
        uint256 total,
        uint256 delegateServiceFee,
        uint256 platformServiceFee,
        uint256 paymentsMade
    )
        internal returns (uint256 paymentAmount)
    {
        // Stack too deep
        {
            ( uint256 actualPrincipalPortion, uint256 actualInterestPortion, uint256 actualFeePortion ) = loan.getNextPaymentBreakdown();

            paymentAmount = actualPrincipalPortion + actualInterestPortion + actualFeePortion;

            assertWithinDiff(actualPrincipalPortion + actualInterestPortion, total, 2);  // Constant payment amounts

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertWithinDiff(principalPortion, actualPrincipalPortion, 1);
            assertWithinDiff(interestPortion,  actualInterestPortion,  1);

            assertWithinDiff(delegateServiceFee + platformServiceFee, actualFeePortion, 2);
        }

        // Stack too deep
        {
            uint256 delegateBalanceBefore = fundsAsset.balanceOf(poolDelegate);
            uint256 treasuryBalanceBefore = fundsAsset.balanceOf(treasury);

            (
                uint256 delegateServiceFeeGetter,
                ,
                uint256 platformServiceFeeGetter,
            ) = MapleLoanFeeManager(loan.feeManager()).getServiceFeeBreakdown(address(loan), 1);

            // Warp to when payment is due and make payment
            vm.warp(loan.nextPaymentDueDate());
            vm.startPrank(borrower);
            fundsAsset.transfer(address(loan), paymentAmount);
            loan.makePayment(0);
            vm.stopPrank();

            // Check Service Fees correctly sent to Pool Delegate and Treasury
            assertEq(fundsAsset.balanceOf(poolDelegate), delegateBalanceBefore + delegateServiceFeeGetter);
            assertEq(fundsAsset.balanceOf(poolDelegate), delegateBalanceBefore + delegateServiceFee);
            assertEq(fundsAsset.balanceOf(treasury),     treasuryBalanceBefore + platformServiceFeeGetter);
            assertEq(fundsAsset.balanceOf(treasury),     treasuryBalanceBefore + platformServiceFee);
        }

        assertEq(loan.drawableFunds(), 0);  // No extra funds left in contract

        assertWithinDiff(loan.principal(), principalRemaining, 2);  // Principal decreasing in accordance with provided values

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
        uint256 delegateServiceFee,
        uint256 platformServiceFee,
        uint256 grandTotal
    )
        internal
    {
        assertEq(fundsAsset.balanceOf(address(lender)), 0);

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
                delegateServiceFee,
                platformServiceFee,
                i + 1
            ) - delegateServiceFee - platformServiceFee;

            // Balance increasing by amount paid exactly minus fees as they are sent to their respective addresses
            assertWithinDiff(fundsAsset.balanceOf(address(lender)), grandTotalPaid, 10);
        }

        assertEq(loan.principal(), 0);
        assertWithinDiff(grandTotalPaid, grandTotal, 10);
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(800_000e6)];

        uint256[4] memory rates = [uint256(0.13e6), uint256(0.02e6), uint256(0), uint256(0)];  // 2% flat rate for closing loan

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[3] memory onTimeTotals = [
            uint256(43_138.893875e6),
            uint256(43_138.893875e6),
            uint256(43_138.893875e6)
        ];

        uint256[3] memory onTimePrincipalPortions = [
            uint256(32_453.962368e6),
            uint256(32_800.730733e6),
            uint256(33_151.204295e6)
        ];

        uint256[3] memory onTimeInterestPortions = [
            uint256(10_684.931507e6),
            uint256(10_338.163142e6),
            uint256( 9_987.689581e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 30 / 365 = 8219.178082 per payment
        // Delegate service fee 300e18 per payment
        // Total fees 8219.178082 + 300e18 = 8_519.178082e18 per payment
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 30 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 8_219.178082e6);

        uint256[3] memory onTimePrincipalRemaining = [
            uint256(967_546.037632e6),
            uint256(934_745.306898e6),
            uint256(901_594.102603e6)
        ];

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 1_000_000e6 * 0.01e6 * uint256(6 * 30 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 4_931.506849e6);

        // // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(4_931.506849e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        uint256 grandTotalPaid;

        // Make first three on time payments
        for (uint256 i = 0; i < 3; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                delegateServiceFee,
                platformServiceFee,
                i + 1
            );
        }

        // On day 90, warp to day 113
        vm.warp(block.timestamp + 23 days);

        // Get amounts for the remaining loan payments
        ( uint256 principalPortion, uint256 interestPortion, uint256 feePortion ) = loan.getClosingPaymentBreakdown();

        uint256 paymentAmount = principalPortion + interestPortion + feePortion;

        assertEq(principalPortion + interestPortion, uint256(919_625.984654e6));  // Constant payment a);

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertEq(principalPortion, uint256(901_594.102602e6));
        assertEq(interestPortion,  uint256( 18_031.882052e6));

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 30 / 365 = 8219.178082 per payment
        // Delegate service fee 300e18 per payment
        // Platform service fee + delegate service fee = 25_557.534246e18  for remaining 3 payments to close loan
        platformServiceFee = (1_000_000e6 * uint256(0.1e18) * 30 days / 365 days / 1e18) * 3;  // Three payments
        delegateServiceFee = 300e6 * 3;  // Three payments

        assertEq(platformServiceFee, 24_657.534246e6);
        assertEq(feePortion,         25_557.534246e6);

        uint256 treasuryBalBefore = fundsAsset.balanceOf(treasury);
        uint256 delegateBalBefore = fundsAsset.balanceOf(poolDelegate);

        // Make payment
        vm.startPrank(borrower);
        fundsAsset.transfer(address(loan), paymentAmount);
        loan.closeLoan(0);
        vm.stopPrank();

        assertEq(fundsAsset.balanceOf(treasury),     treasuryBalBefore + platformServiceFee);
        assertEq(fundsAsset.balanceOf(poolDelegate), delegateBalBefore + delegateServiceFee);

        assertEq(loan.drawableFunds(),      0);  // No extra funds left in contract
        assertEq(loan.principal(),          0);  // No principal left
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(0)];

        uint256[4] memory rates = [uint256(0.13e6), uint256(0.02e6), uint256(0), uint256(0)];  // 2% flat rate for closing loan

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[2] memory onTimeTotals = [
            uint256(169_796.942404e6),
            uint256(169_796.942404e6)
        ];

        uint256[2] memory onTimePrincipalPortions = [
            uint256(164_454.476651e6),
            uint256(165_333.069060e6)
        ];

        uint256[2] memory onTimeInterestPortions = [
            uint256(5_342.465753e6),
            uint256(4_463.873344e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 15 / 365 = 4109.589041e18 per payment
        // Delegate service fee 300e18 per payment
        // Total fee per payment 4109.589041e18 + 300e18 = 4_409.589041e18
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 15 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 4_109.589041e6);

        uint256[2] memory onTimePrincipalRemaining = [
            uint256(835_545.523349e6),
            uint256(670_212.454289e6)
        ];

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 0.01e6 * 1_000_000e6 * uint256(90 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 2_465.753424e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(2_465.753424e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        uint256 grandTotalPaid;

        // Make first two on time payments
        for (uint256 i = 0; i < 2; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                delegateServiceFee,
                platformServiceFee,
                i + 1
            );
        }

        // On day 30, warp to day 44
        vm.warp(block.timestamp + 14 days);

        // Get amounts for the remaining loan payments
        ( uint256 principalPortion, uint256 interestPortion, uint256 feePortion) = loan.getClosingPaymentBreakdown();

        uint256 paymentAmount = principalPortion + interestPortion + feePortion;

        assertEq(principalPortion + interestPortion, uint256(683_616.703373e6));  // Constant payment a)

        // Check payment amounts against provided values
        // Five decimals of precision used (six provided with rounding)
        assertEq(principalPortion, uint256(670_212.454288e6));
        assertEq(interestPortion,  uint256( 13_404.249085e6));

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 15 / 365 = 4109.589041e18 per payment
        // Delegate service fee 300e18 per payment
        // Platform service fee + delegate service fee = 17_638.356164e18  for remaining 4 payments to close loan
        platformServiceFee = (1_000_000e6 * uint256(0.1e18) * 15 days / 365 days / 1e18) * 4;
        delegateServiceFee = 300e6 * 4;  // Four payments

        assertEq(platformServiceFee, 16_438.356164e6);

        assertEq(feePortion, uint256(17_638.356164e6));

        uint256 treasuryBalBefore = fundsAsset.balanceOf(treasury);
        uint256 delegateBalBefore = fundsAsset.balanceOf(poolDelegate);

        // Make payment
        vm.startPrank(borrower);
        fundsAsset.transfer(address(loan), paymentAmount);
        loan.closeLoan(0);
        vm.stopPrank();

        assertEq(fundsAsset.balanceOf(treasury),     treasuryBalBefore + platformServiceFee);
        assertEq(fundsAsset.balanceOf(poolDelegate), delegateBalBefore + delegateServiceFee);

        assertEq(loan.drawableFunds(),      0);  // No extra funds left in contract
        assertEq(loan.principal(),          0);  // No principal left
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(0)];

        uint256[4] memory rates = [uint256(0.1e6), uint256(0), uint256(0), uint256(0)];

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[6] memory totals = [
            uint256(171_493.890825e6),
            uint256(171_493.890825e6),
            uint256(171_493.890825e6),
            uint256(171_493.890825e6),
            uint256(171_493.890825e6),
            uint256(171_493.890825e6)
        ];

        uint256[6] memory principalPortions = [
            uint256(163_274.712742e6),
            uint256(164_616.696683e6),
            uint256(165_969.710628e6),
            uint256(167_333.845236e6),
            uint256(168_709.191909e6),
            uint256(170_095.842802e6)
        ];

        uint256[6] memory interestPortions = [
            uint256(8_219.178082e6),
            uint256(6_877.194142e6),
            uint256(5_524.180197e6),
            uint256(4_160.045589e6),
            uint256(2_784.698915e6),
            uint256(1_398.048023e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 30 / 365 = 8219.178082 per payment
        // Delegate service fee 300e18 per payment
        // Total fees 8219.178082 + 300e18 = 8_519.178082e18 per payment
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 30 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 8_219.178082e6);

        uint256[6] memory principalRemaining = [
            uint256(836_725.287258e6),
            uint256(672_108.590575e6),
            uint256(506_138.879947e6),
            uint256(338_805.034711e6),
            uint256(170_095.842802e6),
            uint256(      0.000000e6)
        ];

        uint256 grandTotal = 1_028_963.344948e6;

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 1_000_000e6 * 0.01e6 * uint256(6 * 30 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 4_931.506849e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(4_931.506849e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));  // 500e18 in loan);

        onTimePaymentsTest(
            loan,
            amounts,
            principalPortions,
            interestPortions,
            principalRemaining,
            totals,
            delegateServiceFee,
            platformServiceFee,
            grandTotal
        );
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(0)];

        uint256[4] memory rates = [uint256(0.15e6), uint256(0), uint256(0), uint256(0)];

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[6] memory totals = [
            uint256(170_280.971987e6),
            uint256(170_280.971987e6),
            uint256(170_280.971987e6),
            uint256(170_280.971987e6),
            uint256(170_280.971987e6),
            uint256(170_280.971987e6)
        ];

        uint256[6] memory principalPortions = [
            uint256(164_116.588425e6),
            uint256(165_128.266025e6),
            uint256(166_146.179994e6),
            uint256(167_170.368775e6),
            uint256(168_200.871048e6),
            uint256(169_237.725733e6)
        ];

        uint256[6] memory interestPortions = [
            uint256(6_164.383562e6),
            uint256(5_152.705962e6),
            uint256(4_134.791993e6),
            uint256(3_110.603212e6),
            uint256(2_080.100939e6),
            uint256(1_043.246255e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 15 / 365 = 4109.589041e18 per payment
        // Delegate service fee 300e18 per payment
        // Total fee per payment 4109.589041e18 + 300e18 = 4_409.589041e18
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 15 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 4_109.589041e6);

        uint256[6] memory principalRemaining = [
            uint256(835_883.411575e6),
            uint256(670_755.145549e6),
            uint256(504_608.965555e6),
            uint256(337_438.596781e6),
            uint256(169_237.725733e6),
            uint256(      0.000000e6)
        ];

        uint256 grandTotal = 1_021_685.831922e6;

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 0.01e6 * 1_000_000e6 * uint256(90 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 2_465.753424e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(2_465.753424e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        onTimePaymentsTest(
            loan,
            amounts,
            principalPortions,
            interestPortions,
            principalRemaining,
            totals,
            delegateServiceFee,
            platformServiceFee,
            grandTotal
        );
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(1_000_000e6)];

        uint256[4] memory rates = [uint256(0.1e6), uint256(0), uint256(0), uint256(0)];

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[6] memory totals = [
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(1_008_219.178082e6)
        ];

        uint256[6] memory principalPortions = [
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(1_000_000.000000e6)
        ];

        uint256[6] memory interestPortions = [
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 30 / 365 = 8219.178082 per payment
        // Delegate service fee 300e18 per payment
        // Total fees 8219.178082 + 300e18 = 8_519.178082e18 per payment
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 30 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 8_219.178082e6);

        uint256[6] memory principalRemaining = [
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(        0.000000e6)
        ];

        uint256 grandTotal = 1_049_315.068493e6;

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 1_000_000e6 * 0.01e6 * uint256(6 * 30 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 4_931.506849e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(4_931.506849e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        onTimePaymentsTest(
            loan,
            amounts,
            principalPortions,
            interestPortions,
            principalRemaining,
            totals,
            delegateServiceFee,
            platformServiceFee,
            grandTotal
        );
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(1_000_000e6)];

        uint256[4] memory rates = [uint256(0.15e6), uint256(0), uint256(0), uint256(0)];

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[6] memory totals = [
            uint256(    6_164.383562e6),
            uint256(    6_164.383562e6),
            uint256(    6_164.383562e6),
            uint256(    6_164.383562e6),
            uint256(    6_164.383562e6),
            uint256(1_006_164.383562e6)
        ];

        uint256[6] memory principalPortions = [
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(1_000_000.000000e6)
        ];

        uint256[6] memory interestPortions = [
            uint256(6_164.383562e6),
            uint256(6_164.383562e6),
            uint256(6_164.383562e6),
            uint256(6_164.383562e6),
            uint256(6_164.383562e6),
            uint256(6_164.383562e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 15 / 365 = 4109.589041e18 per payment
        // Delegate service fee 300e18 per payment
        // Total fee per payment 4109.589041e18 + 300e18 = 4_409.589041e18
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 15 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 4_109.589041e6);

        uint256[6] memory principalRemaining = [
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(        0.000000e6)
        ];

        uint256 grandTotal = 1_036_986.301369e6;

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 0.01e6 * 1_000_000e6 * uint256(90 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 2_465.753424e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(2_465.753424e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        onTimePaymentsTest(
            loan,
            amounts,
            principalPortions,
            interestPortions,
            principalRemaining,
            totals,
            delegateServiceFee,
            platformServiceFee,
            grandTotal
        );
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(350_000e6)];

        uint256[4] memory rates = [uint256(0.13e6), uint256(0), uint256(0.05e6), uint256(0)];  // 5% Late fee flat rate on principal

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[5] memory onTimeTotals = [
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6)
        ];

        uint256[5] memory onTimePrincipalPortions = [
            uint256(106_895.409823e6),
            uint256(107_466.494889e6),
            uint256(108_040.630958e6),
            uint256(108_617.834329e6),
            uint256(109_198.121389e6)
        ];

        uint256[5] memory onTimeInterestPortions = [
            uint256(5_342.465753e6),
            uint256(4_771.380687e6),
            uint256(4_197.244619e6),
            uint256(3_620.041248e6),
            uint256(3_039.754188e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 15 / 365 = 4109.589041e18 per payment
        // Delegate service fee 300e18 per payment
        // Total fee per payment 4109.589041e18 + 300e18 = 4_409.589041e18
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 15 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 4_109.589041e6);

        uint256[5] memory onTimePrincipalRemaining = [
            uint256(893_104.590177e6),
            uint256(785_638.095288e6),
            uint256(677_597.464330e6),
            uint256(568_979.630001e6),
            uint256(459_781.508613e6)
        ];

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 0.01e6 * 1_000_000e6 * uint256(90 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 2_465.753424e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(2_465.753424e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        uint256 grandTotalPaid;

        // Make first five on time payments
        for (uint256 i = 0; i < 5; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                delegateServiceFee,
                platformServiceFee,
                i + 1
            );
        }

        // On day 75, warp to day 90 plus one second (one second late)
        vm.warp(block.timestamp + 15 days + 1 seconds);

        // Get amounts for the remaining loan payments
        ( uint256 principalPortion, uint256 interestPortion, uint256 feePortion )  = loan.getNextPaymentBreakdown();

        uint256 paymentAmount = principalPortion + interestPortion + feePortion;

        {
            uint256 lateInterest = loan.principal() * 1300 * uint256(1 days) / 365 days / 10_000;  // Add one day of late payment (one second = one day of late interest)
            uint256 lateFee      = 22_989.075431e6;

            assertWithinDiff(principalPortion + interestPortion, uint256(485_226.951007e6) + lateInterest, 2);  // Late interest wasn't accounted for in);

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertWithinDiff(principalPortion, uint256(459_781.508613e6),                          1);
            assertWithinDiff(interestPortion,  uint256(  2_456.366964e6) + lateInterest + lateFee, 3);  // Note: This was 2,292.609166 + 163.757798 from sheet, also late interest wasn't accounted for
            assertWithinDiff(feePortion,       uint256(  4_409.589041e6),                          1);
        }

        uint256 delegateBeforeBal = fundsAsset.balanceOf(poolDelegate);
        uint256 treasuryBeforeBal = fundsAsset.balanceOf(treasury);

        // Make payment
        vm.startPrank(borrower);
        fundsAsset.transfer(address(loan), paymentAmount);
        loan.makePayment(0);
        vm.stopPrank();

        assertEq(fundsAsset.balanceOf(treasury),     treasuryBeforeBal + platformServiceFee);
        assertEq(fundsAsset.balanceOf(poolDelegate), delegateBeforeBal + delegateServiceFee);

        assertEq(loan.drawableFunds(),      0);  // No extra funds left in contract
        assertEq(loan.principal(),          0);  // No principal left
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(1_000_000e6)];

        uint256[4] memory rates = [uint256(0.1e6), uint256(0), uint256(0.05e6), uint256(0)];  // 5% Late fee flat rate on principal

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        // Payments 1, 2, 4, 5, 6
        uint256[5] memory onTimeTotals = [
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(1_008_219.178082e6)
        ];

        uint256[5] memory onTimePrincipalPortions = [
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(1_000_000.000000e6)
        ];

        uint256[5] memory onTimeInterestPortions = [
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 30 / 365 = 8219.178082 per payment
        // Delegate service fee 300e18 per payment
        // Total fees 8219.178082 + 300e18 = 8_519.178082e18 per payment
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 30 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 8_219.178082e6);

        uint256[5] memory onTimePrincipalRemaining = [
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(        0.000000e6)
        ];

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 1_000_000e6 * 0.01e6 * uint256(6 * 30 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 4_931.506849e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(4_931.506849e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        uint256 grandTotalPaid;

        // Make on two on time payments
        for (uint256 i = 0; i < 2; i++) {
            grandTotalPaid += assertOnTimePayment(
                loan,
                onTimePrincipalPortions[i],
                onTimeInterestPortions[i],
                onTimePrincipalRemaining[i],
                onTimeTotals[i],
                delegateServiceFee,
                platformServiceFee,
                i + 1
            );
        }

        {
            // On day 60, warp to day 90 plus two hours
            vm.warp(block.timestamp + 30 days + 2 hours);

            // Get amounts for the remaining loan payments
            ( uint256 principalPortion, uint256 interestPortion, uint256 feePortion ) = loan.getNextPaymentBreakdown();

            uint256 lateInterest = loan.principal() * 1000 * uint256(1 days) / 365 days / 10_000;  // Add two hours of late interest (which is 1 day of default interest).
            uint256 lateFee      = uint256(50_000.000000e6);

            uint256 paymentAmount = principalPortion + interestPortion + feePortion;

            assertWithinDiff(principalPortion + interestPortion, uint256(58_219.178082e6) + lateInterest, 2);  // Late interest wasn't accounted for in sheet.

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertWithinDiff(principalPortion, uint256(    0.000000e6),                          0);
            assertWithinDiff(interestPortion,  uint256(8_219.178082e6) + lateInterest + lateFee, 3);  // Note: Late interest wasn't accounted for.
            assertWithinDiff(feePortion,       uint256(8_519.178082e6),                          0);

            // Make payment
            vm.startPrank(borrower);
            fundsAsset.transfer(address(loan), paymentAmount);
            loan.makePayment(0);
            vm.stopPrank();

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
                delegateServiceFee,
                platformServiceFee,
                i + 2
            );
        }

        assertEq(loan.drawableFunds(),      0);  // No extra funds left in contract
        assertEq(loan.principal(),          0);  // No principal left
        assertEq(loan.paymentsRemaining(),  0);  // Payments remaining cleared
        assertEq(loan.nextPaymentDueDate(), 0);  // Payment due date cleared
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(350_000e6)];

        uint256[4] memory rates = [uint256(0.13e6), uint256(0), uint256(0.05e6), uint256(0.05e6)];  // 5% Late fee flat rate on principal, 5% premium

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        // All payment amounts under normal amortization schedule in sheet
        uint256[6] memory onTimeTotals = [
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(462_237.875576e6)
        ];

        uint256[6] memory onTimePrincipalPortions = [
            uint256(106_895.409823e6),
            uint256(107_466.494889e6),
            uint256(108_040.630958e6),
            uint256(108_617.834329e6),
            uint256(109_198.121389e6),
            uint256(459_781.508613e6)
        ];

        uint256[6] memory onTimeInterestPortions = [
            uint256(5_342.465753e6),
            uint256(4_771.380687e6),
            uint256(4_197.244619e6),
            uint256(3_620.041248e6),
            uint256(3_039.754188e6),
            uint256(2_456.366964e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 15 / 365 = 4109.589041e18 per payment
        // Delegate service fee 300e18 per payment
        // Total fee per payment 4109.589041e18 + 300e18 = 4_409.589041e18
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 15 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 4_109.589041e6);

        uint256[6] memory onTimePrincipalRemaining = [
            uint256(893_104.590177e6),
            uint256(785_638.095288e6),
            uint256(677_597.464330e6),
            uint256(568_979.630001e6),
            uint256(459_781.508613e6),
            uint256(      0.000000e6)
        ];

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        // Platform origination fee formula
        assertEq(0.01e6 * 1_000_000e6 * uint256(90 days) / 365 days / 1e6, 2_465.753424e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(2_465.753424e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        uint256 grandTotalPaid;

        // Make first payment
        grandTotalPaid += assertOnTimePayment(
            loan,
            onTimePrincipalPortions[0],
            onTimeInterestPortions[0],
            onTimePrincipalRemaining[0],
            onTimeTotals[0],
            delegateServiceFee,
            platformServiceFee,
            1
        );

        /*****************************************/
        /*** First Late Payment (16 days late) ***/
        /*****************************************/
        {
            // On day 15, warp to day 46 (16 days late)
            vm.warp(block.timestamp + 31 days);

            // Get amounts for the remaining loan payments
            ( uint256 principalPortion, uint256 interestPortion, uint256 feePortion ) = loan.getNextPaymentBreakdown();

            uint256 lateInterest = loan.principal() * 1800 * uint256(16 days) / 365 days / 10_000;  // Add sixteen days of late interest
            uint256 lateFee      = loan.principal() * 500 / 10_000;

            assertEq(lateInterest, 7046.962245e6);

            uint256 paymentAmount = principalPortion + interestPortion + feePortion;

            assertWithinDiff(principalPortion + interestPortion, uint256(163_940.067331e6), 2);

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertWithinDiff(principalPortion, onTimePrincipalPortions[1],                         1);  // Principal should be in accordance with schedule always
            assertWithinDiff(interestPortion,  onTimeInterestPortions[1] + lateInterest + lateFee, 3);  // Note: Late interest wasn't accounted for
            assertWithinDiff(feePortion,       delegateServiceFee + platformServiceFee,            2);

            // Make payment
            vm.startPrank(borrower);
            fundsAsset.transfer(address(loan), paymentAmount);
            loan.makePayment(0);
            vm.stopPrank();

            assertEq(loan.paymentsRemaining(),  4);  // Payments remaining increases
            assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * 3);  // Payment due date increases to day 30 (still one day late)
        }

        /****************************************/
        /*** Second Late Payment (1 day late) ***/
        /****************************************/
        {
            // Same timestamp - Day 46, due date is day 45

            // Get amounts for the remaining loan payments
            ( uint256 principalPortion, uint256 interestPortion, uint256 feePortion ) = loan.getNextPaymentBreakdown();

            uint256 lateInterest = loan.principal() * 1800 * uint256(1 days) / 365 days / 10_000;  // Add one day of late interest
            uint256 lateFee      = loan.principal() * 500 / 10_000;

            assertEq(lateInterest, 387.437964e6);

            uint256 paymentAmount = principalPortion + interestPortion + feePortion;

            assertWithinDiff(principalPortion + interestPortion, uint256(151_907.218305e6), 2);

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertWithinDiff(principalPortion, onTimePrincipalPortions[2],                         1);  // Principal should be in accordance with schedule always
            assertWithinDiff(interestPortion,  onTimeInterestPortions[2] + lateInterest + lateFee, 3);  // Note: Late interest wasn't accounted for
            assertWithinDiff(feePortion,       delegateServiceFee + platformServiceFee,            2);

            // Make payment
            vm.startPrank(borrower);
            fundsAsset.transfer(address(loan), paymentAmount);
            loan.makePayment(0);
            vm.stopPrank();

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
                delegateServiceFee,
                platformServiceFee,
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(1_000_000e6)];

        uint256[4] memory rates = [uint256(0.10e6), uint256(0), uint256(0.02e6), uint256(0.05e6)];  // 2% Late fee rate on principal

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        // Payments 2, 3, 4, 5, 6
        uint256[5] memory onTimeTotals = [
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(    8_219.178082e6),
            uint256(1_008_219.178082e6)
        ];

        uint256[5] memory onTimePrincipalPortions = [
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(        0.000000e6),
            uint256(1_000_000.000000e6)
        ];

        uint256[5] memory onTimeInterestPortions = [
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6),
            uint256(8_219.178082e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 30 / 365 = 8219.178082 per payment
        // Delegate service fee 300e18 per payment
        // Total fees 8219.178082 + 300e18 = 8_519.178082e18 per payment
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 30 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 8_219.178082e6);

        uint256[5] memory onTimePrincipalRemaining = [
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(1_000_000.000000e6),
            uint256(        0.000000e6)
        ];

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 1_000_000e6 * 0.01e6 * uint256(6 * 30 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 4_931.506849e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(4_931.506849e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        uint256 grandTotalPaid;

        {
            // On day 0, warp to day 32 (two days late)
            vm.warp(block.timestamp + 32 days);

            // Get amounts for the remaining loan payments
            ( uint256 principalPortion, uint256 interestPortion, uint256 feePortion ) = loan.getNextPaymentBreakdown();


            uint256 lateInterest = loan.principal() * 1500 * uint256(2 days) / 365 days / 10_000;  // Add two days of late interest (15%)
            uint256 lateFee      = loan.principal() * 0.02e18 / 10 ** 18;
            assertEq(lateInterest, 821.917808e6);

            uint256 paymentAmount = principalPortion + interestPortion + feePortion;

            assertWithinDiff(principalPortion + interestPortion, uint256(28_219.178082e6) + lateInterest, 2);  // Late interest wasn't accounted for in sheet

            // Check payment amounts against provided values
            // Five decimals of precision used (six provided with rounding)
            assertWithinDiff(principalPortion, uint256(    0.000000e6),                          0);
            assertWithinDiff(interestPortion,  uint256(8_219.178082e6) + lateInterest + lateFee, 3);  // Note: Late interest wasn't accounted for
            assertWithinDiff(feePortion,       uint256(8_519.178082e6),                          0);

            // Make payment
            vm.startPrank(borrower);
            fundsAsset.transfer(address(loan), paymentAmount);
            loan.makePayment(0);
            vm.stopPrank();

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
                delegateServiceFee,
                platformServiceFee,
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(1_000_000e6)];

        uint256[4] memory rates = [uint256(0.10e6), uint256(0), uint256(0.02e6), uint256(0.05e6)];  // 2% Late fee rate on principal

        uint256[2] memory fees = [uint256(0), uint256(0)];

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        // On day 0, warp to day 30 plus one second (one second late)
        vm.warp(start + 30 days + 1 seconds);

        // Get amounts for the remaining loan payments
        ( , uint256 interestPortion1 , ) = loan.getNextPaymentBreakdown();

        // Warp to day 31 (one day late exactly)
        vm.warp(start + 31 days);

        ( , uint256 interestPortion2 , ) = loan.getNextPaymentBreakdown();

        assertEq(interestPortion1, interestPortion2);  // Same entire day

        // Warp one more second (one day plus one second late)
        vm.warp(start + 31 days + 1 seconds);

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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(800_000e6)];

        uint256[4] memory rates = [uint256(0.1e6), uint256(0), uint256(0), uint256(0)];

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[6] memory totals = [
            uint256( 40_874.120631e6),
            uint256( 40_874.120631e6),
            uint256( 40_874.120631e6),
            uint256( 40_874.120631e6),
            uint256( 40_874.120631e6),
            uint256(840_874.120631e6)
        ];

        uint256[6] memory principalPortions = [
            uint256( 32_654.942548e6),
            uint256( 32_923.339337e6),
            uint256( 33_193.942126e6),
            uint256( 33_466.769047e6),
            uint256( 33_741.838382e6),
            uint256(834_019.168560e6)
        ];

        uint256[6] memory interestPortions = [
            uint256(8_219.178082e6),
            uint256(7_950.781294e6),
            uint256(7_680.178505e6),
            uint256(7_407.351583e6),
            uint256(7_132.282249e6),
            uint256(6_854.952070e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 30 / 365 = 8219.178082 per payment
        // Delegate service fee 300e18 per payment
        // Total fees 8219.178082 + 300e18 = 8_519.178082e18 per payment
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 30 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 8_219.178082e6);

        uint256[6] memory principalRemaining = [
            uint256(967_345.057452e6),
            uint256(934_421.718115e6),
            uint256(901_227.775989e6),
            uint256(867_761.006942e6),
            uint256(834_019.168560e6),
            uint256(      0.000000e6)
        ];

        uint256 grandTotal = 1_045_244.723784e6;

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 1_000_000e6 * 0.01e6 * uint256(6 * 30 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 4_931.506849e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(4_931.506849e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        onTimePaymentsTest(
            loan,
            amounts,
            principalPortions,
            interestPortions,
            principalRemaining,
            totals,
            delegateServiceFee,
            platformServiceFee,
            grandTotal
        );
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

        uint256[3] memory amounts = [uint256(300_000e6), uint256(1_000_000e6), uint256(350_000e6)];

        uint256[4] memory rates = [uint256(0.13e6), uint256(0), uint256(0), uint256(0)];

        uint256[2] memory fees = [uint256(500e6), uint256(300e6)];

        uint256[6] memory totals = [
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(112_237.875576e6),
            uint256(462_237.875576e6)
        ];


        uint256[6] memory principalPortions = [
            uint256(106_895.409823e6),
            uint256(107_466.494889e6),
            uint256(108_040.630958e6),
            uint256(108_617.834329e6),
            uint256(109_198.121389e6),
            uint256(459_781.508613e6)
        ];

        uint256[6] memory interestPortions = [
            uint256(5_342.465753e6),
            uint256(4_771.380687e6),
            uint256(4_197.244619e6),
            uint256(3_620.041248e6),
            uint256(3_039.754188e6),
            uint256(2_456.366964e6)
        ];

        // Platform service fee principalRequested * fee rate * interval / 365 days = 1_000_000 * 0.1 * 15 / 365 = 4109.589041e18 per payment
        // Delegate service fee 300e18 per payment
        // Total fee per payment 4109.589041e18 + 300e18 = 4_409.589041e18
        uint256 platformServiceFee = 1_000_000e6 * uint256(0.1e18) * 15 days / 365 days / 1e18;
        uint256 delegateServiceFee = 300e6;  // Part of terms

        assertEq(platformServiceFee, 4_109.589041e6);

        uint256[6] memory principalRemaining = [
            uint256(893_104.590177e6),
            uint256(785_638.095288e6),
            uint256(677_597.464330e6),
            uint256(568_979.630001e6),
            uint256(459_781.508613e6),
            uint256(      0.000000e6)
        ];

        uint256 grandTotal = 1_023_427.253459e6;

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     0);
        assertEq(fundsAsset.balanceOf(poolDelegate), 0);

        MapleLoan loan = createLoanFundAndDrawdown(assets, termDetails, amounts, rates, fees);

        uint256 platformOriginationFee = 0.01e6 * 1_000_000e6 * uint256(90 days) / 365 days / 1e6;

        assertEq(platformOriginationFee, 2_465.753424e6);

        // Assert the origination fee
        assertEq(fundsAsset.balanceOf(treasury),     uint256(2_465.753424e6));
        assertEq(fundsAsset.balanceOf(poolDelegate), uint256(500e6));

        onTimePaymentsTest(
            loan,
            amounts,
            principalPortions,
            interestPortions,
            principalRemaining,
            totals,
            delegateServiceFee,
            platformServiceFee,
            grandTotal
        );
    }

}
