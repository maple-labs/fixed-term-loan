// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { TestUtils, Hevm, StateManipulations } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }                           from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { LoanPrimitiveHarness } from "./harnesses/LoanPrimitiveHarness.sol";

contract LoanPrimitivePaymentBreakDownTest is TestUtils {

    LoanPrimitiveHarness internal loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function _getPaymentsBreakdownWith(
        uint256 numberOfPayments_,
        uint256 currentTime_,
        uint256 nextPaymentDueDate_
    )
        internal view
        returns (
            uint256 totalPrincipalAmount,
            uint256 totalInterestFees
        )
    {
        ( totalPrincipalAmount, totalInterestFees ) = loan.getPaymentsBreakdown(
            numberOfPayments_,
            currentTime_,
            nextPaymentDueDate_,
            365 days / 12,        // Interval such that there are 12 payments in a year
            1_000_000,            // Principal
            0,                    // Ending principal
            12,                   // 12 payments
            0.12e18,              // 12% interest
            0.04e18               // 4% late premium interest
        );
    }

    function test_getPaymentsBreakdown_onePaymentOnePeriodBeforeDue() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            1,
            10_000_000 - (1 * (365 days / 12)),
            10_000_000
        );

        assertEq(principalAmount, 78_848);
        assertEq(interestFees,    10_000);
    }

    function test_getPaymentsBreakdown_onePaymentOneSecondBeforeDue() external {
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees ) = _getPaymentsBreakdownWith(
            1,
            10_000_000 - 1,
            10_000_000
        );

        assertEq(totalPrincipalAmount, 78_848);
        assertEq(totalInterestFees,    10_000);
    }

    function test_getPaymentsBreakdown_onePaymentOnePeriodLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            1,
            10_000_000 + (1 * (365 days / 12)),
            10_000_000
        );

        assertEq(principalAmount, 78_848);
        assertEq(interestFees,    23_333);  // 10_000 + (1_000_000) * 0.16 * (1/12) = 10_000 + 13_333
    }

    function test_getPaymentsBreakdown_onePaymentTwoPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            1,
            10_000_000 + (2 * (365 days / 12)),
            10_000_000
        );

        assertEq(principalAmount, 78_848);
        assertEq(interestFees,    36_666);  // 10_000 + (1_000_000) * 0.16 * (2/12) = 10_000 + 26_666
    }

    function test_getPaymentsBreakdown_onePaymentThreePeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            1,
            10_000_000 + (3 * (365 days / 12)),
            10_000_000
        );

        assertEq(principalAmount, 78_848);
        assertEq(interestFees,    50_000);  // 10_000 + (1_000_000) * 0.16 * (3/12) = 10_000 + 40_000
    }

    function test_getPaymentsBreakdown_onePaymentFourPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            1,
            10_000_000 + (4 * (365 days / 12)),
            10_000_000
        );

        assertEq(principalAmount, 78_848);
        assertEq(interestFees,    63_333);  // 10_000 + (1_000_000) * 0.16 * (4/12) = 10_000 + 53_333
    }

    function test_getPaymentsBreakdown_twoPaymentsOnePeriodBeforeDue() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            2,
            10_000_000 - (1 * (365 days / 12)),
            10_000_000
        );

        assertEq(principalAmount, 158_485);
        assertEq(interestFees,    19_211);
    }

    function test_getPaymentsBreakdown_twoPaymentsOneSecondBeforeDue() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            2,
            10_000_000 - 1,
            10_000_000
        );

        assertEq(principalAmount, 158_485);
        assertEq(interestFees,    19_211);
    }

    function test_getPaymentsBreakdown_twoPaymentsOnePeriodLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            2,
            10_000_000 + (1 * (365 days / 12)),
            10_000_000
        );

        assertEq(principalAmount, 158_485);
        assertEq(interestFees,    32_544);  // 10_000 + 9_211 + (1_000_000) * 0.16 * (1/12) = 10_000 + 9_211 + 13_333
    }

    function test_getPaymentsBreakdown_twoPaymentsTwoPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            2,
            10_000_000 + (2 * (365 days / 12)),
            10_000_000
        );

        assertEq(principalAmount, 158_485);
        assertEq(interestFees,    58_159);  // 10_000 + 9_211 + (1_000_000) * 0.16 * (2/12) + (921_152) * 0.16 * (1/12) = 10_000 + 9_211 + 26_666 + 12_282
    }

}

contract LoanPrimitiveFeeTest is TestUtils {

    LoanPrimitiveHarness internal loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function test_getInterest() external {
        assertEq(loan.getInterest(1_000_000, 0.12e18, 365 days / 12), 10_000);  // 12% APY on 1M
        assertEq(loan.getInterest(10_000,    1.20e18, 365 days / 12), 1_000);   // 120% APY on 10k
    }

    function test_getPeriodicInterestRate() external {
        assertEq(loan.getPeriodicInterestRate(0.12 ether, 365 days),      0.12 ether);  // 12%
        assertEq(loan.getPeriodicInterestRate(0.12 ether, 365 days / 12), 0.01 ether);  // 1%
    }

}

contract LoanPrimitiveInstallmentTest is TestUtils {

    LoanPrimitiveHarness internal loan;

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 1e18;
    uint256 internal constant MIN_TOKEN_AMOUNT = 1;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function test_getInstallment_withFixtures() external {
        ( uint256 principalAmount, uint256 interestAmount ) = loan.getInstallment(1_000_000, 0, 0.12 ether, 365 days / 12, 12);

        assertEq(principalAmount, 78_848);
        assertEq(interestAmount,  10_000);
    }

    function test_getInstallment_genericFuzzing(
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 totalPayments_
    ) external {
        principal_       = constrictToRange(principal_,       MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        endingPrincipal_ = constrictToRange(endingPrincipal_, 0,                principal_);
        interestRate_    = constrictToRange(interestRate_,    0,                1.00 ether);  // 0% - 100% APY
        paymentInterval_ = constrictToRange(paymentInterval_, 1 hours,          365 days);
        totalPayments_   = constrictToRange(totalPayments_,   1,                100);

        loan.getInstallment(principal_, endingPrincipal_, interestRate_, paymentInterval_, totalPayments_);

        assertTrue(true);
    }

    function test_getInstallment_edgeCases() external {
        uint256 principalAmount_;
        uint256 interestAmount_;

        // 100,000% APY charged all at once in one payment
        ( principalAmount_, interestAmount_ ) = loan.getInstallment(MAX_TOKEN_AMOUNT, 0, 1000.00 ether, 365 days, 1);

        assertEq(principalAmount_, 1000000000000000000000000000000);
        assertEq(interestAmount_,  1000000000000000000000000000000000);

        // A payment a day for 30 years (10950 payments) at 100% APY
        ( principalAmount_, interestAmount_ ) = loan.getInstallment(MAX_TOKEN_AMOUNT, 0, 1.00 ether, 1 days, 10950);

        assertEq(principalAmount_, 267108596355467);
        assertEq(interestAmount_,  2739726027397260000000000000);
    }

}

contract LoanPrimitiveScaledExponentTest is TestUtils {

    LoanPrimitiveHarness internal loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function test_scaledExponent_setOne() external {
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

    function test_scaledExponent_setTwo() external {
        assertEq(loan.scaledExponent(12340, 18, 10), 440223147468745562613840184469885558370587691142634536960);
        assertEq(loan.scaledExponent(12340, 19, 10), 543235363976432024265478787635838779029305210870011018608640);

        assertEq(loan.scaledExponent(uint256(2 * 10_000 * 100), 100, uint256(10_000 * 100)), uint256(1267650600228229401496703205376 * 10_000 * 100));
        assertEq(loan.scaledExponent(uint256(2 * 10_000 * 100), 120, uint256(10_000 * 100)), uint256(1329227995784915872903807060280344576 * 10_000 * 100));
        assertEq(loan.scaledExponent(uint256(2 * 10_000 * 100), 140, uint256(10_000 * 100)), uint256(1393796574908163946345982392040522594123776 * 10_000 * 100));
        assertEq(loan.scaledExponent(uint256(2 * 10_000 * 100), 160, uint256(10_000 * 100)), uint256(1461501637330902918203684832716283019655932542976 * 10_000 * 100));
        assertEq(loan.scaledExponent(uint256(2 * 10_000 * 100), 168, uint256(10_000 * 100)), uint256(374144419156711147060143317175368453031918731001856 * 10_000 * 100));
        assertEq(loan.scaledExponent(uint256(2 * 10_000 * 100), 180, uint256(10_000 * 100)), uint256(1532495540865888858358347027150309183618739122183602176 * 10_000 * 100));
        assertEq(loan.scaledExponent(uint256(2 * 10_000 * 100), 200, uint256(10_000 * 100)), uint256(1606938044258990275541962092341162602522202993782792835301376 * 10_000 * 100));
        assertEq(loan.scaledExponent(uint256(2 * 10_000 * 100), 216, uint256(10_000 * 100)), uint256(105312291668557186697918027683670432318895095400549111254310977536 * 10_000 * 100));
    }

}

contract LoanPrimitiveLendTest is TestUtils {

    uint256 internal constant MAX_REQUESTED_AMOUNT = type(uint256).max - 1;
    uint256 internal constant MIN_REQUESTED_AMOUNT = 2;

    LoanPrimitiveHarness internal loan;
    MockERC20            internal token;

    address internal mockCollateralToken = address(9);

    function setUp() external {
        loan  = new LoanPrimitiveHarness();
        token = new MockERC20("FundsAsset", "FA", 0);
    }

    function _initializeLoanWithRequestAmount(address loan_, uint256 requestedAmount_) internal {
        address[2] memory assets = [address(mockCollateralToken), address(token)];

        uint256[6] memory parameters = [
            uint256(10 days),       // Grace period.
            uint256(365 days / 6),  // Payment interval given 6 payments in a year.
            uint256(6),             // 6 payments.
            uint256(0.12e18),       // 12% interest.
            uint256(0.2e18),        // 2% early interest discount.
            uint256(0.4e18)         // 4% late interest premium.
        ];

        uint256[3] memory requests = [uint256(300_000), requestedAmount_, uint256(0)];

        LoanPrimitiveHarness(loan_).initialize(address(1), assets, parameters, requests);
    }

    function test_lend_initialState() external {
        assertEq(loan.lender(),                             address(0));
        assertEq(loan.drawableFunds(),                      0);
        assertEq(loan.nextPaymentDueDate(),                 0);
        assertEq(loan.getUnaccountedAmount(address(token)), 0);
        assertEq(loan.principal(),                          0);
    }

    function test_lend_getUnaccountedAmount(uint256 amount_) external {
        assertEq(loan.getUnaccountedAmount(address(token)), 0);

        token.mint(address(this), amount_);
        token.transfer(address(loan), amount_);

        assertEq(loan.getUnaccountedAmount(address(token)), amount_);
    }

    function test_lend_withoutSendingAsset(uint256 requestedAmount_) external {
        requestedAmount_ = constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(address(loan), requestedAmount_);

        ( bool ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");
    }

    function test_lend_fullLend(uint256 requestedAmount_) external {
        requestedAmount_ = constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(address(loan), requestedAmount_);

        token.mint(address(this), requestedAmount_);
        token.transfer(address(loan), requestedAmount_);

        assertEq(loan.getUnaccountedAmount(address(token)), requestedAmount_);

        ( bool ok, uint256 amount ) = loan.lend(address(this));
        assertTrue(ok, "lend should have succeeded");

        assertEq(loan.lender(),                             address(this));
        assertEq(amount,                                    requestedAmount_);
        assertEq(loan.getUnaccountedAmount(address(token)), 0);
        assertEq(loan.drawableFunds(),                      amount);
        assertEq(loan.nextPaymentDueDate(),                 block.timestamp + loan.paymentInterval());
        assertEq(loan.principal(),                          amount);
    }

    function test_lend_partialLend(uint256 requestedAmount_) external {
        requestedAmount_ = constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(address(loan), requestedAmount_);

        token.mint(address(this), requestedAmount_);
        token.transfer(address(loan), requestedAmount_ - 1);

        ( bool ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");

    }

    function test_lend_failWithDoubleLend(uint256 requestedAmount_) external {
        requestedAmount_ = constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);

        // Dividing by two to make sure we can mint twice
        _initializeLoanWithRequestAmount(address(loan), requestedAmount_ / 2);

        token.mint(address(this), requestedAmount_);
        token.transfer(address(loan), requestedAmount_ / 2);

        ( bool ok, uint256 amount ) = loan.lend(address(this));
        assertTrue(ok, "lend should have succeeded");

        assertEq(loan.lender(),                             address(this));
        assertEq(amount,                                    requestedAmount_ / 2);
        assertEq(loan.getUnaccountedAmount(address(token)), 0);
        assertEq(loan.drawableFunds(),                      amount);
        assertEq(loan.nextPaymentDueDate(),                 block.timestamp + loan.paymentInterval());
        assertEq(loan.principal(),                          amount);

        token.transfer(address(loan), requestedAmount_ / 2);

        ( ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");
    }

    function test_lend_sendingExtra(uint256 requestedAmount_) external {
        requestedAmount_ = constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(address(loan), requestedAmount_);

        token.mint(address(this), requestedAmount_ + 1);
        token.transfer(address(loan), requestedAmount_ + 1);

        ( bool ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");
    }

    function test_lend_claimImmediatelyAfterLend(uint256 requestedAmount_) external {
        requestedAmount_ = constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(address(loan), requestedAmount_);

        token.mint(address(this), requestedAmount_);
        token.transfer(address(loan), requestedAmount_);

        ( bool ok, uint256 amount ) = loan.lend(address(this));
        assertTrue(ok, "lend should have succeeded");

        assertEq(loan.lender(),                             address(this));
        assertEq(amount,                                    requestedAmount_);
        assertEq(loan.getUnaccountedAmount(address(token)), 0);
        assertEq(loan.drawableFunds(),                      amount);
        assertEq(loan.nextPaymentDueDate(),                 block.timestamp + loan.paymentInterval());
        assertEq(loan.principal(),                          amount);

        try loan.claimFunds(requestedAmount_, address(this)) { assertTrue(false); } catch { }
    }

}

contract LendPrimitivePostAndRemoveCollateralTest is TestUtils {

    MockERC20            internal collateralAsset;
    MockERC20            internal fundsAsset;
    LoanPrimitiveHarness internal loan;

    function setUp() external {
        collateralAsset = new MockERC20("CollateralAsset", "CA", 0);
        fundsAsset      = new MockERC20("FundsAsset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function _initializeLoanWithCollateralRequired(address loan_, uint256 collateralRequired_) internal {
        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),       // Grace period.
            uint256(365 days / 6),  // Payment interval given 6 payments in a year.
            uint256(6),             // 6 payments.
            uint256(0.12e18),       // 12% interest.
            uint256(0.2e18),        // 2% early interest discount.
            uint256(0.4e18)         // 4% late interest premium.
        ];

        uint256[3] memory requests = [collateralRequired_, uint256(1_000_000), uint256(0)];

        LoanPrimitiveHarness(loan_).initialize(address(1), assets, parameters, requests);
    }

    /***********************/
    /*** Post Collateral ***/
    /***********************/

    function test_postCollateral_initialState(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        assertEq(loan.collateral(), 0);
    }

    function testFail_postCollateral_uninitializedLoan() external {
        loan.postCollateral();
    }

    function test_postCollateral_exactAmount(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,            collateralAmount_);
        assertEq(loan.collateral(), collateralAmount_);
    }

    function test_postCollateral_lessThanRequired(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ == 0 ? 1 : collateralAmount_;
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_ - 1);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,            collateralAmount_ - 1);
        assertEq(loan.collateral(), amount);
    }

    function test_postCollateral_moreThanRequired(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ == type(uint256).max ? type(uint256).max - 1 : collateralAmount_;
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_ + 1);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,            collateralAmount_ + 1);
        assertEq(loan.collateral(), amount);
    }

    function test_postCollateral_zeroAmount() external {
        _initializeLoanWithCollateralRequired(address(loan), 0);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,            0);
        assertEq(loan.collateral(), 0);
    }

    function test_postCollateral_withUnaccountedFundsAsset(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        // Send funds asset to Loan
        fundsAsset.mint(address(loan), loan.principalRequested());
        collateralAsset.mint(address(loan), collateralAmount_);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,            collateralAmount_);
        assertEq(loan.collateral(), collateralAmount_);
    }

    function test_postCollateral_doesNotCountOtherAssets(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        // Send funds asset to Loan
        fundsAsset.mint(address(loan), collateralAmount_);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,            0);
        assertEq(loan.collateral(), 0);
    }

    function test_postCollateral_sameAssets(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ > type(uint256).max - 1_000_000 ? type(uint256).max - 1_000_000 : collateralAmount_;

        // Initialize Loan with same asset for fund and collateral
        address[2] memory assets = [address(collateralAsset), address(collateralAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(365 days / 6),
            uint256(6),
            uint256(0.12e18),
            uint256(0.2e18),
            uint256(0.4e18)
        ];

        uint256[3] memory requests = [uint256(collateralAmount_), uint256(1_000_000), uint256(0)];

        loan.initialize(address(1), assets, parameters, requests);

        // Fund Loan (note: lend() must be called for funds to be accounted for)
        collateralAsset.mint(address(loan), 1_000_000);
        loan.lend(address(this));

        // Post collateral
        collateralAsset.mint(address(loan), collateralAmount_);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,            collateralAmount_);
        assertEq(loan.collateral(), collateralAmount_);
    }

    /*************************/
    /*** Remove Collateral ***/
    /*************************/

    function test_removeCollateral_fullAmount(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,                                   collateralAmount_);
        assertEq(loan.collateral(),                        collateralAmount_);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralAmount_);
        assertEq(collateralAsset.balanceOf(address(this)), 0);

        assertTrue(loan.removeCollateral(collateralAmount_, address(this)));

        assertEq(loan.collateral(),                        0);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(collateralAsset.balanceOf(address(this)), collateralAmount_);
    }

    function test_removeCollateral_partialAmount(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ == 0 ? 1 : collateralAmount_;
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,                                   collateralAmount_);
        assertEq(loan.collateral(),                        collateralAmount_);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralAmount_);
        assertEq(collateralAsset.balanceOf(address(this)), 0);

        assertTrue(loan.removeCollateral(collateralAmount_ - 1, address(this)));

        assertEq(loan.collateral(),                        1);
        assertEq(collateralAsset.balanceOf(address(loan)), 1);
        assertEq(collateralAsset.balanceOf(address(this)), collateralAmount_ - 1);
    }

    function test_removeCollateral_moreThanAmount(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequired(address(loan), collateralAmount_);

        collateralAmount_ = collateralAmount_ == type(uint256).max ? type(uint256).max - 1 : collateralAmount_;
        collateralAsset.mint(address(loan), collateralAmount_);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,            collateralAmount_);
        assertEq(loan.collateral(), collateralAmount_);

        try loan.removeCollateral(collateralAmount_ + 1, address(this)) { assertTrue(false); } catch {}
    }

    function test_removeCollateral_sameAssets(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ > type(uint256).max - 1_000_000 ? type(uint256).max - 1_000_000 : collateralAmount_;

        // Initialize loan with same asset for fund and collateral
        address[2] memory assets = [address(collateralAsset), address(collateralAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),
            uint256(365 days / 6),
            uint256(6),
            uint256(0.12e18),
            uint256(0.2e18),
            uint256(0.4e18)
        ];

        uint256[3] memory requests = [uint256(collateralAmount_), uint256(1_000_000), uint256(0)];

        loan.initialize(address(1), assets, parameters, requests);

        // Fund Loan
        collateralAsset.mint(address(loan), 1_000_000);
        loan.lend(address(this));

        // Post collateral
        collateralAsset.mint(address(loan), collateralAmount_);

        ( bool success, uint256 amount ) = loan.postCollateral();

        assertTrue(success);

        assertEq(amount,                                   collateralAmount_);
        assertEq(loan.collateral(),                        collateralAmount_);
        assertEq(collateralAsset.balanceOf(address(loan)), 1_000_000 + collateralAmount_);

        assertTrue(loan.removeCollateral(collateralAmount_, address(this)));

        assertEq(loan.collateral(),                        0);
        assertEq(collateralAsset.balanceOf(address(loan)), 1_000_000);
        assertEq(collateralAsset.balanceOf(address(this)), collateralAmount_);
    }

}

contract LoanPrimitiveDrawdownTest is TestUtils {

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)

    MockERC20            internal collateralAsset;
    MockERC20            internal fundsAsset;
    LoanPrimitiveHarness internal loan;

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function _initializeLoanWithAmounts(address loan_, uint256 collateralRequired_, uint256 principalRequested_) internal {
        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),       // Grace period.
            uint256(365 days / 6),  // Payment interval given 6 payments in a year.
            uint256(6),             // 6 payments.
            uint256(0.12e18),       // 12% interest.
            uint256(0.2e18),        // 2% early interest discount.
            uint256(0.4e18)         // 4% late interest premium.
        ];

        uint256[3] memory requests = [collateralRequired_, principalRequested_, uint256(0)];

        LoanPrimitiveHarness(loan_).initialize(address(1), assets, parameters, requests);
    }

    function _initializeLoanAndLend(address loan_, uint256 collateralRequired_, uint256 principalRequested_) internal {
        _initializeLoanWithAmounts(loan_, collateralRequired_, principalRequested_);

        fundsAsset.mint(loan_, principalRequested_);
        LoanPrimitiveHarness(loan_).lend(address(this));
    }

    function _setUpDrawdown(
        address loan_,
        uint256 collateralRequired_,
        uint256 minCollateral_,
        uint256 maxCollateral_,
        uint256 principalRequested_,
        uint256 minPrincipal_,
        uint256 maxPrincipal_
    )
        internal returns (uint256 constrictedCollateralRequired_, uint256 constrictedPrincipalRequested_)
    {
        constrictedCollateralRequired_ = constrictToRange(collateralRequired_, minCollateral_, maxCollateral_);
        constrictedPrincipalRequested_ = constrictToRange(principalRequested_, minPrincipal_,  maxPrincipal_);

        _initializeLoanAndLend(loan_, constrictedCollateralRequired_, constrictedPrincipalRequested_);

        collateralAsset.mint(loan_, constrictedCollateralRequired_);
        LoanPrimitiveHarness(loan_).postCollateral();
    }

    function test_drawdownFunds_initialState(uint256 collateralRequired_, uint256 principalRequested_) external {
        ( collateralRequired_, principalRequested_ ) = _setUpDrawdown(address(loan), collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 1, MAX_TOKEN_AMOUNT);

        assertEq(loan.principal(),          principalRequested_);
        assertEq(loan.drawableFunds(),      principalRequested_);
        assertEq(loan.principalRequested(), principalRequested_);

        assertEq(loan.collateralRequired(), collateralRequired_);
        assertEq(loan.collateral(),         collateralRequired_);

        assertEq(fundsAsset.balanceOf(address(loan)),      principalRequested_);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralRequired_);
    }

    function test_drawdownFunds_withoutPostedCollateral(uint256 collateralRequired_, uint256 principalRequested_) external {
        // Must have non-zero collateral and principal amounts to cause failure
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);

        _initializeLoanAndLend(address(loan), collateralRequired_, principalRequested_);

        assertTrue(!loan.drawdownFunds(principalRequested_, address(this)));
    }

    function test_drawdownFunds_exactAmount(uint256 collateralRequired_, uint256 principalRequested_) external {
        ( , principalRequested_ ) = _setUpDrawdown(address(loan), collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 1, MAX_TOKEN_AMOUNT);

        assertEq(loan.drawableFunds(),                principalRequested_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_);
        assertEq(fundsAsset.balanceOf(address(this)), 0);

        assertTrue(loan.drawdownFunds(principalRequested_, address(this)));

        assertEq(loan.drawableFunds(),                0);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(fundsAsset.balanceOf(address(this)), principalRequested_);
    }

    function test_drawdownFunds_lessThanDrawableFunds(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        ( , principalRequested_ ) = _setUpDrawdown(address(loan), collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 1, MAX_TOKEN_AMOUNT);

        drawdownAmount_ = constrictToRange(drawdownAmount_, 0, principalRequested_);

        assertEq(loan.drawableFunds(),                principalRequested_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_);
        assertEq(fundsAsset.balanceOf(address(this)), 0);

        assertTrue(loan.drawdownFunds(drawdownAmount_, address(this)));

        assertEq(loan.drawableFunds(),                principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(this)), drawdownAmount_);
    }

    function test_drawdownFunds_greaterThanDrawableFunds(uint256 collateralRequired_, uint256 principalRequested_) external {
        ( , principalRequested_ ) = _setUpDrawdown(address(loan), collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 1, MAX_TOKEN_AMOUNT);

        try loan.drawdownFunds(principalRequested_ + 1, address(this)) { assertTrue(false); } catch {}
    }

    function test_drawdownFunds_multipleDrawdowns(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        ( , principalRequested_ ) = _setUpDrawdown(address(loan), collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 1, MAX_TOKEN_AMOUNT);

        drawdownAmount_ = constrictToRange(drawdownAmount_, 0, principalRequested_);

        assertTrue(loan.drawdownFunds(drawdownAmount_, address(this)));

        assertEq(loan.drawableFunds(),                principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(this)), drawdownAmount_);

        // Assert failure mode for amount larger than drawableFunds
        try loan.drawdownFunds(principalRequested_ - drawdownAmount_ + 1, address(this)) { assertTrue(false); } catch {}

        assertTrue(loan.drawdownFunds(principalRequested_ - drawdownAmount_, address(this)));

        assertEq(loan.drawableFunds(),                0);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(fundsAsset.balanceOf(address(this)), principalRequested_);
    }

    // TODO see if there is a way to make the transfer fail in drawdown due to lack of funds

    function testFail_drawdownFunds_collateralNotMaintained(uint256 collateralRequired_, uint256 principalRequested_) external {
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);

        _initializeLoanAndLend(address(loan), collateralRequired_, principalRequested_);

        collateralAsset.mint(address(loan), collateralRequired_ - 1);
        loan.postCollateral();

        assertEq(loan.collateral(), collateralRequired_ - 1);

        // _collateralMaintained condition after a drawdown of principalRequested is made
        assertTrue(loan.collateral() * loan.principalRequested() < loan.collateralRequired() * loan.principal());

        // try loan.drawdownFunds(principalRequested_, address(this)) { } catch { assertTrue(true); }

        require(loan.drawdownFunds(principalRequested_, address(this)));
    }

}

contract LoanPrimitiveRepossessTest is TestUtils, StateManipulations {

    uint256 internal constant MAX_TIME = 10_000 * 365 days;  // Assumed reasonable upper limit for payment intervals and grace periods

    LoanPrimitiveHarness internal loan;
    MockERC20            internal collateralAsset;
    MockERC20            internal fundsAsset;

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function test_repossess(uint256 gracePeriod_, uint256 paymentInterval_) external {
        /*******************/
        /*** Create Loan ***/
        /*******************/

        // Not fuzzing since values are just set to zero
        uint256 collateralRequired =   300_000;
        uint256 principalRequested = 1_000_000;
        paymentInterval_ = constrictToRange(paymentInterval_, 1, MAX_TIME);
        gracePeriod_     = constrictToRange(gracePeriod_,     0, paymentInterval_ - 1);

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            gracePeriod_,
            paymentInterval_,
            uint256(6),        // 6 payments.
            uint256(0.12e18),  // 12% interest.
            uint256(0.02e18),  // 2% early interest discount.
            uint256(0.04e18)   // 4% late interest premium.
        ];

        uint256[3] memory requests = [collateralRequired, principalRequested, uint256(0)];

        uint256 start = block.timestamp;

        loan.initialize(address(1), assets, parameters, requests);

        /*********************************/
        /*** Lend and Partial Drawdown ***/
        /*********************************/

        fundsAsset.mint(address(loan), principalRequested);
        loan.lend(address(this));

        collateralAsset.mint(address(loan), collateralRequired);
        loan.postCollateral();

        loan.drawdownFunds(400_000, address(this));  // Drawdown 400k, leaving 600k as drawable funds

        /********************/
        /*** Make Payment ***/
        /********************/

        ( uint256 principalPortion, uint256 interestPortion ) = loan.getCurrentPaymentsBreakdown(uint256(1));

        uint256 totalPayment = principalPortion + interestPortion;

        fundsAsset.mint(address(loan), totalPayment);

        hevm.warp(loan.nextPaymentDueDate());

        loan.accountForPayments(1, totalPayment, principalPortion);

        /*****************/
        /*** Repossess ***/
        /*****************/

        assertEq(loan.drawableFunds(),      600_000);
        assertEq(loan.claimableFunds(),     totalPayment);
        assertEq(loan.collateral(),         300_000);
        assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * 2);  // Made a payment, so paymentInterval moved
        assertEq(loan.principal(),          1_000_000 - principalPortion);
        assertEq(loan.paymentsRemaining(),  5);

        assertTrue(!loan.repossess(), "Should fail: not past grace period");

        hevm.warp(loan.nextPaymentDueDate() + loan.gracePeriod()); // Warp to timestamp of payment due date plus grace period

        assertTrue(!loan.repossess(), "Should fail: not past grace period");

        hevm.warp(loan.nextPaymentDueDate() + loan.gracePeriod() + 1); // Warp to one second past grace period

        assertTrue(loan.repossess(), "Should pass: past grace period");

        assertEq(loan.drawableFunds(),      0);
        assertEq(loan.claimableFunds(),     0);
        assertEq(loan.collateral(),         0);
        assertEq(loan.nextPaymentDueDate(), 0);
        assertEq(loan.principal(),          0);
        assertEq(loan.paymentsRemaining(),  0);
    }

}

contract LoanPrimitiveReturnFundsTest is TestUtils {

    function test_returnFunds(uint256 fundsToReturn_) external {
        fundsToReturn_ = constrictToRange(fundsToReturn_, 0, type(uint256).max >> 3);

        LoanPrimitiveHarness loan            = new LoanPrimitiveHarness();
        MockERC20            collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        MockERC20            fundsAsset      = new MockERC20("Funds Asset", "FA", 0);

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(1),
            uint256(1),
            uint256(1),
            uint256(1),
            uint256(1),
            uint256(1)
        ];

        uint256[3] memory requests = [uint256(1), uint256(1), uint256(1)];

        loan.initialize(address(1), assets, parameters, requests);

        ( bool success, uint256 amount ) = loan.returnFunds();

        assertTrue(success);

        assertEq(amount,               uint256(0));
        assertEq(loan.drawableFunds(), uint256(0));

        fundsAsset.mint(address(loan), fundsToReturn_);

        ( success, amount ) = loan.returnFunds();

        assertTrue(success);

        assertEq(amount,               fundsToReturn_);
        assertEq(loan.drawableFunds(), fundsToReturn_);

        fundsAsset.mint(address(loan), fundsToReturn_);

        ( success, amount ) = loan.returnFunds();

        assertTrue(success);

        assertEq(amount,              fundsToReturn_);
        assertEq(loan.drawableFunds(), 2 * fundsToReturn_);

        collateralAsset.mint(address(loan), fundsToReturn_);

        ( success, amount ) = loan.returnFunds();

        assertTrue(success);

        assertEq(amount,               0);
        assertEq(loan.drawableFunds(), 2 * fundsToReturn_);
    }

}

contract LoanPrimitiveClaimFundsTest is TestUtils {

    LoanPrimitiveHarness internal loan;
    MockERC20            internal collateralAsset;
    MockERC20            internal fundsAsset;

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function test_claimFunds(uint256 fundingAmount_, uint256 amountToClaim_) external {
        // `amountToClaim_` is constrict to half the constricted `fundingAmount_`
        fundingAmount_ = constrictToRange(fundingAmount_, 2, type(uint256).max >> 10);
        amountToClaim_ = constrictToRange(amountToClaim_, 1, fundingAmount_ / 2);

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        // 0% interest loan with 2 payments, so half of principal paid in each installment
        uint256[6] memory parameters = [
            uint256(1),  // Grace period.
            uint256(0),  // Payment interval.
            uint256(2),  // 2 payments.
            uint256(0),  // 0% interest.
            uint256(0),  // 0% early interest discount.
            uint256(0)   // 0% late interest premium.
        ];

        uint256[3] memory requests = [uint256(0), uint256(fundingAmount_), uint256(0)];

        loan.initialize(address(1), assets, parameters, requests);
        fundsAsset.mint(address(loan), fundingAmount_);
        loan.lend(address(this));

        (uint256 principal, uint256 interest) = loan.getCurrentPaymentsBreakdown(1);
        loan.accountForPayments(1, principal + interest, principal);

        // Half the `fundingAmount_` should be claimable, and all `fundingAmount_` should still be in the contract
        assertEq(loan.claimableFunds(),               fundingAmount_ / 2);
        assertEq(fundsAsset.balanceOf(address(loan)), fundingAmount_);

        loan.claimFunds(amountToClaim_, address(this));

        uint256 newClaimableAmount =  (fundingAmount_ / 2) - amountToClaim_;

        assertEq(loan.claimableFunds(),               newClaimableAmount);
        assertEq(fundsAsset.balanceOf(address(loan)), fundingAmount_ - amountToClaim_);
        assertEq(fundsAsset.balanceOf(address(this)), amountToClaim_);

        loan.claimFunds(newClaimableAmount, address(this));

        assertEq(loan.claimableFunds(),               0);
        assertEq(fundsAsset.balanceOf(address(loan)), fundingAmount_ - (amountToClaim_ + newClaimableAmount));
        assertEq(fundsAsset.balanceOf(address(this)), amountToClaim_ + newClaimableAmount);
    }

    function testFail_claimFunds_noClaimableFunds() external {
        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(1),  // Grace period.
            uint256(1),  // Payment interval.
            uint256(2),  // 2 payments.
            uint256(0),  // 0% interest.
            uint256(0),  // 0% early interest discount.
            uint256(0)   // 0% late interest premium.
        ];

        uint256[3] memory requests = [uint256(0), uint256(10_000), uint256(0)];

        loan.initialize(address(1), assets, parameters, requests);
        fundsAsset.mint(address(loan), 10_000);
        loan.lend(address(this));

        assertEq(loan.claimableFunds(),               0);
        assertEq(fundsAsset.balanceOf(address(loan)), 10_000);

        loan.claimFunds(1, address(this));
    }

    function testFail_claimFunds_insufficientClaimableFunds() external {
        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(1),  // Grace period.
            uint256(1),  // Payment interval.
            uint256(2),  // 2 payments.
            uint256(0),  // 0% interest.
            uint256(0),  // 0% early interest discount.
            uint256(0)   // 0% late interest premium.
        ];

        uint256[3] memory requests = [uint256(0), uint256(10_000), uint256(0)];

        loan.initialize(address(1), assets, parameters, requests);
        fundsAsset.mint(address(loan), 10_000);
        loan.lend(address(this));

        (uint256 principal, uint256 interest) = loan.getCurrentPaymentsBreakdown(1);
        loan.accountForPayments(1, principal + interest, principal);

        assertEq(loan.claimableFunds(), 5_000);
        assertEq(fundsAsset.balanceOf(address(loan)), 10_000);

        loan.claimFunds(5_001, address(this));
    }

}

contract LoanPrimitiveMakePaymentTest is TestUtils, StateManipulations {

    uint256 internal constant MAX_TIME         = 365 days;         // Assumed reasonable upper limit for payment intervals and grace periods
    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)

    LoanPrimitiveHarness internal loan;
    MockERC20            internal collateralAsset;
    MockERC20            internal fundsAsset;

    function setUp() external {
        collateralAsset = new MockERC20("CollateralAsset", "CA", 0);
        fundsAsset      = new MockERC20("FundsAsset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function _initializeLoanWithPaymentsRemaining(address loan_, uint256 paymentsRemaining_) internal {
        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),       // Grace period.
            uint256(365 days / 6),  // Payment interval given 6 payments in a year.
            paymentsRemaining_,
            uint256(0.12e18),       // 12% interest.
            uint256(0.02e18),       // 2% early interest discount.
            uint256(0.04e18)        // 4% late interest premium.
        ];

        uint256[3] memory requests = [uint256(300_000), uint256(1_000_000), uint256(0)];

        LoanPrimitiveHarness(loan_).initialize(address(1), assets, parameters, requests);
    }

    function test_makePayments(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 numberOfPayments_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);
        interestRate_       = constrictToRange(interestRate_,       0,   10_000 * 100);
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,   10_000 * 100);
        paymentInterval_    = constrictToRange(paymentInterval_,    100, MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,   120);
        numberOfPayments_   = constrictToRange(numberOfPayments_,   1,   paymentsRemaining_);

        uint256[6] memory parameters = [
            0,
            paymentInterval_,
            paymentsRemaining_,
            interestRate_,
            0,
            0
        ];

        loan.initialize(
            address(1),
            [address(collateralAsset), address(fundsAsset)],
            parameters,
            [collateralRequired_, principalRequested_, endingPrincipal_]
        );

        /*************************/
        /*** Lend and Drawdown ***/
        /*************************/

        fundsAsset.mint(address(loan), principalRequested_);
        loan.lend(address(this));

        collateralAsset.mint(address(loan), collateralRequired_);
        loan.postCollateral();

        loan.drawdownFunds(principalRequested_, address(this));

        /********************/
        /*** Make Payment ***/
        /********************/

        assertEq(loan.drawableFunds(),  0);
        assertEq(loan.claimableFunds(), 0);
        assertEq(loan.principal(),      principalRequested_);

        ( uint256 principal, uint256 interest ) = loan.getCurrentPaymentsBreakdown(numberOfPayments_);

        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), totalPayment);

        loan.accountForPayments(numberOfPayments_, totalPayment, principal);

        assertEq(loan.drawableFunds(),      0);
        assertEq(loan.claimableFunds(),     totalPayment);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + paymentInterval_ * (numberOfPayments_ + 1));  // Made a payment, so paymentInterval moved
        assertEq(loan.principal(),          principalRequested_ - principal);
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_ - numberOfPayments_);
    }

    function test_makePayments_morePaymentsThanRemaining(uint256 paymentsRemaining_) external {
        paymentsRemaining_ = constrictToRange(paymentsRemaining_, 1, 120);

        _initializeLoanWithPaymentsRemaining(address(loan), paymentsRemaining_);

        hevm.warp(loan.nextPaymentDueDate());

        // Provide more than enough tokens
        fundsAsset.mint(address(loan), MAX_TOKEN_AMOUNT);

        try loan.getCurrentPaymentsBreakdown(paymentsRemaining_ + 1) { assertTrue(false); } catch { }
    }

}

contract LoanPrimitiveSkimTest is TestUtils {

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    address internal constant DESTINATION      = address(999);

    LoanPrimitiveHarness internal loan;
    MockERC20            internal collateralAsset;
    MockERC20            internal fundsAsset;

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function _initializeLoanWithRequestAmount(address loan_, uint256 requestedAmount_) internal {
        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(10 days),       // Grace period.
            uint256(365 days / 6),  // Payment interval given 6 payments in a year.
            uint256(6),             // 6 payments.
            uint256(0.12e18),       // 12% interest.
            uint256(0.2e18),        // 2% early interest discount.
            uint256(0.4e18)         // 4% late interest premium.
        ];

        uint256[3] memory requests = [uint256(300_000), requestedAmount_, uint256(0)];

        LoanPrimitiveHarness(loan_).initialize(address(1), assets, parameters, requests);
    }

    function test_skim_assetIsGeneric(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 0, MAX_TOKEN_AMOUNT);

        MockERC20 anyAsset = new MockERC20("Any Asset", "AA", 0);

        // Mint some funds of any ERC20 token to loan to claim it again.
        anyAsset.mint(address(loan), amount_);

        // Initialize the loan.
        _initializeLoanWithRequestAmount(address(loan), 800_000);

        assertEq(anyAsset.balanceOf(address(loan)), amount_);
        assertEq(anyAsset.balanceOf(DESTINATION),   0);

        ( bool success, uint256 amountTransferred ) = loan.skim(address(anyAsset), DESTINATION);

        assertTrue(success, "Not able to transfer unaccounted funds to given destination");

        assertEq(amountTransferred, amount_);

        assertEq(anyAsset.balanceOf(address(loan)), 0);
        assertEq(anyAsset.balanceOf(DESTINATION),   amount_);
    }

    function test_skim_assetIsCollateralAsset(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 0, MAX_TOKEN_AMOUNT);

        // Initialize the loan.
        _initializeLoanWithRequestAmount(address(loan), 800_000);

        // Mint some collateral asset to loan
        collateralAsset.mint(address(loan), 5000);

        // Call postCollateral to make it accountable as collateral.
        loan.postCollateral();

        assertEq(collateralAsset.balanceOf(address(loan)), 5000);
        assertEq(collateralAsset.balanceOf(DESTINATION),   0);

        ( bool success, uint256 amountTransferred ) = loan.skim(address(collateralAsset), DESTINATION);

        assertTrue(success, "Not able to transfer unaccounted funds to given destination");

        assertEq(collateralAsset.balanceOf(address(loan)), 5000);
        assertEq(amountTransferred,                        0);
        assertEq(collateralAsset.balanceOf(DESTINATION),   0);

        // Mint some more collateral asset to loan to skim those
        collateralAsset.mint(address(loan), amount_);

        assertEq(collateralAsset.balanceOf(address(loan)), 5000 + amount_);

        ( success, amountTransferred ) = loan.skim(address(collateralAsset), DESTINATION);

        assertTrue(success, "Not able to transfer unaccounted funds to given destination");

        assertEq(amountTransferred,                        amount_);
        assertEq(collateralAsset.balanceOf(DESTINATION),   amount_);
        assertEq(collateralAsset.balanceOf(address(loan)), 5000);
    }

    function test_skim_assetIsFundingAsset(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 0, MAX_TOKEN_AMOUNT);

        // Initialize the loan.
        _initializeLoanWithRequestAmount(address(loan), 800_000);

        // Mint some funding asset to loan
        fundsAsset.mint(address(loan), 5000);

        // Call returnFunds to make it accountable as claimable funds.
        loan.returnFunds();

        assertEq(fundsAsset.balanceOf(address(loan)), 5000);
        assertEq(fundsAsset.balanceOf(DESTINATION),   0);

        ( bool success, uint256 amountTransferred ) = loan.skim(address(fundsAsset), DESTINATION);

        assertTrue(success, "Not able to transfer unaccounted funds to given destination");

        assertEq(fundsAsset.balanceOf(address(loan)), 5000);
        assertEq(amountTransferred,                   0);
        assertEq(fundsAsset.balanceOf(DESTINATION),   0);

        // Mint some more funds asset to loan to skim those
        fundsAsset.mint(address(loan), amount_);

        assertEq(fundsAsset.balanceOf(address(loan)), 5000 + amount_);

        ( success, amountTransferred ) = loan.skim(address(fundsAsset), DESTINATION);

        assertTrue(success, "Not able to transfer unaccounted funds to given destination");

        assertEq(amountTransferred,                   amount_);
        assertEq(fundsAsset.balanceOf(DESTINATION),   amount_);
        assertEq(fundsAsset.balanceOf(address(loan)), 5000);
    }

}

contract LoanPrimitiveGetCollateralForTest is TestUtils {

    LoanPrimitiveHarness internal loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function test_getCollateralRequiredFor() external {
        // No principal.
        assertEq(loan.getCollateralRequiredFor(0, 10_000, 4_000_000, 500_000), 0);

        // No outstanding principal.
        assertEq(loan.getCollateralRequiredFor(10_000, 10_000, 4_000_000, 500_000), 0);

        // No collateral required.
        assertEq(loan.getCollateralRequiredFor(10_000, 1_000, 4_000_000, 0), 0);

        // 1125 = (500_000 * (10_000 > 1_000 ? 10_000 - 1_000 : 0)) / 4_000_000;
        assertEq(loan.getCollateralRequiredFor(10_000, 1_000, 4_000_000, 500_000), 1125);

        // 500_000 = (500_000 * (4_500_000 > 500_000 ? 4_500_000 - 500_000 : 0)) / 4_000_000;
        assertEq(loan.getCollateralRequiredFor(4_500_000, 500_000, 4_000_000, 500_000), 500_000);
    }

}
