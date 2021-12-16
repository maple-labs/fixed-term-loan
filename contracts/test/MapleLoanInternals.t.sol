// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils, Hevm, StateManipulations } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }                           from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { MapleLoanInternalsHarness } from "./harnesses/MapleLoanInternalsHarness.sol";

import { LenderMock, MapleGlobalsMock, MockFactory } from "./mocks/Mocks.sol";

contract MapleLoanInternals_GetPaymentBreakdownTests is TestUtils {

    address internal _loan;

    function setUp() external {
        _loan = address(new MapleLoanInternalsHarness());
    }

    function _getPaymentsBreakdownWith(
        address loan_,
        uint256 currentTime_,
        uint256 nextPaymentDueDate_
    )
        internal pure
        returns (
            uint256 totalPrincipalAmount,
            uint256 totalInterestFees
        )
    {
        ( totalPrincipalAmount, totalInterestFees ) = MapleLoanInternalsHarness(loan_).getPaymentBreakdown(
            currentTime_,
            nextPaymentDueDate_,
            30 days,              // 30 day interval
            1_000_000,            // Principal
            0,                    // Ending principal
            12,                   // 12 payments
            0.12e18,              // 12% interest
            0,
            0.04e18               // 4% late premium interest
        );
    }

    function test_getPaymentsBreakdown_onePaymentOnePeriodBeforeDue() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            _loan,
            10_000_000 - 30 days,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,     9_863);  // 1_000_000 * 0.12 * 30/365 = 9_863
    }

    function test_getPaymentsBreakdown_onePaymentOneSecondBeforeDue() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            _loan,
            10_000_000 - 1,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,     9_863);
    }

    function test_getPaymentsBreakdown_onePaymentOnePeriodLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            _loan,
            10_000_000 + 30 days,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    23_013);  // 9_863 + (1_000_000 * 0.16 * (1 * 30/365)) = 9_863 + 13_150
    }

    function test_getPaymentsBreakdown_onePaymentTwoPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            _loan,
            10_000_000 + (2 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    36_164);  // 9_863 + (1_000_000 * 0.16 * (2 * 30/365)) = 9_863 + 26_301
    }

    function test_getPaymentsBreakdown_onePaymentThreePeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            _loan,
            10_000_000 + (3 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    49_315);  // 9_863 + (1_000_000 * 0.16 * (3 * 30/365)) = 9_863 + 39_452
    }

    function test_getPaymentsBreakdown_onePaymentFourPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentsBreakdownWith(
            _loan,
            10_000_000 + (4 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    62_465);  // 9_863 + (1_000_000 * 0.16 * (4 * 30/365)) = 9_863 + 52_602
    }

}

contract MapleLoanInternals_GetInterestTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();
    }

    function test_getInterest() external {
        assertEq(_loan.getInterest(1_000_000, 0.12e18, 365 days / 12), 10_000);  // 12% APY on 1M
        assertEq(_loan.getInterest(10_000,    1.20e18, 365 days / 12), 1_000);   // 120% APY on 10k
    }

}

contract MapleLoanInternals_GetPeriodicInterestRateTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();
    }

    function test_getPeriodicInterestRate() external {
        assertEq(_loan.getPeriodicInterestRate(0.12 ether, 365 days),      0.12 ether);  // 12%
        assertEq(_loan.getPeriodicInterestRate(0.12 ether, 365 days / 12), 0.01 ether);  // 1%
    }

}

contract MapleLoanInternals_GetInstallmentTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 1e18;
    uint256 internal constant MIN_TOKEN_AMOUNT = 1;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();
    }

    function test_getInstallment_withFixtures() external {
        ( uint256 principalAmount, uint256 interestAmount ) = _loan.getInstallment(1_000_000, 0, 0.12 ether, 365 days / 12, 12);

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

        _loan.getInstallment(principal_, endingPrincipal_, interestRate_, paymentInterval_, totalPayments_);

        assertTrue(true);
    }

    function test_getInstallment_edgeCases() external {
        uint256 principalAmount_;
        uint256 interestAmount_;

        // 100,000% APY charged all at once in one payment
        ( principalAmount_, interestAmount_ ) = _loan.getInstallment(MAX_TOKEN_AMOUNT, 0, 1000.00 ether, 365 days, 1);

        assertEq(principalAmount_, 1000000000000000000000000000000);
        assertEq(interestAmount_,  1000000000000000000000000000000000);

        // A payment a day for 30 years (10950 payments) at 100% APY
        ( principalAmount_, interestAmount_ ) = _loan.getInstallment(MAX_TOKEN_AMOUNT, 0, 1.00 ether, 1 days, 10950);

        assertEq(principalAmount_, 267108596355467);
        assertEq(interestAmount_,  2739726027397260000000000000);
    }

    // TODO: test where `raisedRate <= SCALED_ONE`?

}

contract MapleLoanInternals_ScaledExponentTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();
    }

    function test_scaledExponent_setOne() external {
        assertEq(_loan.scaledExponent(10_000, 0, 10_000), 10_000);
        assertEq(_loan.scaledExponent(10_000, 1, 10_000), 10_000);
        assertEq(_loan.scaledExponent(10_000, 2, 10_000), 10_000);
        assertEq(_loan.scaledExponent(10_000, 3, 10_000), 10_000);

        assertEq(_loan.scaledExponent(20_000, 0, 10_000), 10_000);
        assertEq(_loan.scaledExponent(20_000, 1, 10_000), 20_000);
        assertEq(_loan.scaledExponent(20_000, 2, 10_000), 40_000);
        assertEq(_loan.scaledExponent(20_000, 3, 10_000), 80_000);

        assertEq(_loan.scaledExponent(10_100, 0, 10_000), 10_000);
        assertEq(_loan.scaledExponent(10_100, 1, 10_000), 10_100);
        assertEq(_loan.scaledExponent(10_100, 2, 10_000), 10_201);
        assertEq(_loan.scaledExponent(10_100, 3, 10_000), 10_303);
    }

    function test_scaledExponent_setTwo() external {
        assertEq(_loan.scaledExponent(12340, 18, 10), 440223147468745562613840184469885558370587691142634536960);
        assertEq(_loan.scaledExponent(12340, 19, 10), 543235363976432024265478787635838779029305210870011018608640);

        assertEq(_loan.scaledExponent(uint256(2 * 10_000 * 100), 100, uint256(10_000 * 100)), uint256(1267650600228229401496703205376 * 10_000 * 100));
        assertEq(_loan.scaledExponent(uint256(2 * 10_000 * 100), 120, uint256(10_000 * 100)), uint256(1329227995784915872903807060280344576 * 10_000 * 100));
        assertEq(_loan.scaledExponent(uint256(2 * 10_000 * 100), 140, uint256(10_000 * 100)), uint256(1393796574908163946345982392040522594123776 * 10_000 * 100));
        assertEq(_loan.scaledExponent(uint256(2 * 10_000 * 100), 160, uint256(10_000 * 100)), uint256(1461501637330902918203684832716283019655932542976 * 10_000 * 100));
        assertEq(_loan.scaledExponent(uint256(2 * 10_000 * 100), 168, uint256(10_000 * 100)), uint256(374144419156711147060143317175368453031918731001856 * 10_000 * 100));
        assertEq(_loan.scaledExponent(uint256(2 * 10_000 * 100), 180, uint256(10_000 * 100)), uint256(1532495540865888858358347027150309183618739122183602176 * 10_000 * 100));
        assertEq(_loan.scaledExponent(uint256(2 * 10_000 * 100), 200, uint256(10_000 * 100)), uint256(1606938044258990275541962092341162602522202993782792835301376 * 10_000 * 100));
        assertEq(_loan.scaledExponent(uint256(2 * 10_000 * 100), 216, uint256(10_000 * 100)), uint256(105312291668557186697918027683670432318895095400549111254310977536 * 10_000 * 100));
    }

}

contract MapleLoanInternals_GetUnaccountedAmountTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _token;

    function setUp() external {
        _loan  = new MapleLoanInternalsHarness();
        _token = new MockERC20("Token", "T", 0);
    }

    function test_getUnaccountedAmount() external {
        assertEq(_loan.getUnaccountedAmount(address(_token)), 0);

        _token.mint(address(_loan), 1);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 1);

        _token.mint(address(_loan), type(uint256).max - 1);

        assertEq(_loan.getUnaccountedAmount(address(_token)), type(uint256).max);
    }

    // TODO: test with _drawableFunds, _claimableFunds, and _collateral set
}

contract MapleLoanInternals_FundLoanTests is TestUtils {

    uint256 internal constant MAX_PRINCIPAL = type(uint256).max - 1;
    uint256 internal constant MIN_PRINCIPAL = 1;

    LenderMock                internal _lender;
    MapleLoanInternalsHarness internal _loan;
    MapleGlobalsMock          internal _globals;
    MockERC20                 internal _fundsAsset;
    MockFactory               internal _factory;

    function setUp() external {
        _factory    = new MockFactory();
        _fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        _globals    = new MapleGlobalsMock(address(0), address(0), 0, 0);
        _lender     = new LenderMock();
        _loan       = new MapleLoanInternalsHarness();

        _factory.setGlobals(address(_globals));

        _loan.setFactory(address(_factory));
        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentsRemaining(1);
    }

    function testFail_fundLoan_withoutSendingAsset() external {
        _loan.setPrincipalRequested(1);
        _loan.fundLoan(address(_lender));
    }

    function test_fundLoan_fullFunding(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        assertEq(_loan.fundLoan(address(_lender)),                 principalRequested_);
        assertEq(_loan.lender(),                                   address(_lender));
        assertEq(_loan.nextPaymentDueDate(),                       block.timestamp + _loan.paymentInterval());
        assertEq(_loan.principal(),                                principalRequested_);
        assertEq(_loan.drawableFunds(),                            principalRequested_);
        assertEq(_loan.claimableFunds(),                           0);
        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), 0);
    }

    function test_fundLoan_overFunding(uint256 principalRequested_, uint256 extraAmount_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);
        extraAmount_        = constrictToRange(extraAmount_,        MIN_PRINCIPAL, MAX_PRINCIPAL - principalRequested_);

        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_ + extraAmount_);

        assertEq(_loan.fundLoan(address(_lender)),                 principalRequested_);
        assertEq(_loan.lender(),                                   address(_lender));
        assertEq(_loan.nextPaymentDueDate(),                       block.timestamp + _loan.paymentInterval());
        assertEq(_loan.principal(),                                principalRequested_);
        assertEq(_loan.drawableFunds(),                            principalRequested_);
        assertEq(_loan.claimableFunds(),                           0);
        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), extraAmount_);
    }

    function testFail_fundLoan_partialFunding(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_ - 1);

        _loan.fundLoan(address(_lender));
    }

    function testFail_fundLoan_doubleFund(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.fundLoan(address(_lender));

        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(address(_lender));
    }

    function testFail_fundLoan_claimImmediatelyAfterFullFunding(uint256 principalRequested_, uint256 claim_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);
        claim_              = constrictToRange(claim_,              1,             principalRequested_);

        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.fundLoan(address(_lender));

        _loan.claimFunds(claim_, address(this));
    }

    function testFail_fundLoan_invalidFundsAsset() external {
        _loan.setPrincipalRequested(1);
        _loan.setFundsAsset(address(0));

        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(address(_lender));
    }

    function test_fundLoan_withUnaccountedCollateralAsset() external {
        MockERC20 collateralAsset = new MockERC20("CollateralAsset", "CA", 0);

        _loan.setCollateralAsset(address(collateralAsset));
        _loan.setPrincipalRequested(1);

        collateralAsset.mint(address(_loan), 1);
        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(address(_lender));

        assertEq(_loan.getUnaccountedAmount(address(collateralAsset)), 1);
    }

    // TODO: testFail_fundLoan_noNextPaymentDueDate

    // TODO: testFail_fundLoan_hasPaymentsRemaining

    // TODO: testFail_fundLoan_transferFailedToTreasury

    // TODO: testFail_fundLoan_transferFailedToPoolDelegate

}

contract MapleLoanInternals_PostCollateralTests is TestUtils {

    uint256 internal constant MAX_COLLATERAL = type(uint256).max - 1;
    uint256 internal constant MIN_COLLATERAL = 0;

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _collateralAsset;

    function setUp() external {
        _loan            = new MapleLoanInternalsHarness();
        _collateralAsset = new MockERC20("CollateralAsset", "CA", 0);

        _loan.setCollateralAsset(address(_collateralAsset));
    }

    function testFail_postCollateral_invalidCollateralAsset() external {
        _loan.setCollateralAsset(address(0));

        _collateralAsset.mint(address(_loan), 1);

        _loan.postCollateral();
    }

    function test_postCollateral_once(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL);

        _collateralAsset.mint(address(_loan), collateral_);

        assertEq(_loan.postCollateral(), collateral_);
        assertEq(_loan.collateral(),     collateral_);
    }

    function test_postCollateral_multiple(uint256 collateral_, uint256 posts_) external {
        posts_      = constrictToRange(posts_,      2,              10);
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL / posts_);

        for (uint256 i = 1; i <= posts_; ++i) {
            _collateralAsset.mint(address(_loan), collateral_);

            assertEq(_loan.postCollateral(), collateral_);
            assertEq(_loan.collateral(),     collateral_ * i);
        }
    }

    function test_postCollateral_withUnaccountedFundsAsset() external {
        MockERC20 fundsAsset = new MockERC20("FundsAsset", "FA", 0);

        _loan.setFundsAsset(address(fundsAsset));

        fundsAsset.mint(address(_loan), 1);
        _collateralAsset.mint(address(_loan), 1);

        _loan.postCollateral();

        assertEq(_loan.getUnaccountedAmount(address(fundsAsset)), 1);
    }

}

contract MapleLoanInternals_RemoveCollateralTests is TestUtils {

    uint256 internal constant MAX_COLLATERAL = type(uint256).max - 1;
    uint256 internal constant MIN_COLLATERAL = 0;

    uint256 internal constant MAX_PRINCIPAL = type(uint256).max - 1;
    uint256 internal constant MIN_PRINCIPAL = 1;

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _collateralAsset;

    function setUp() external {
        _collateralAsset = new MockERC20("CollateralAsset", "CA", 0);
        _loan            = new MapleLoanInternalsHarness();

        _loan.setBorrower(address(this));
        _loan.setCollateralAsset(address(_collateralAsset));
        _loan.setPrincipalRequested(1);
    }

    function test_removeCollateral_fullAmountWithNoEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, MAX_COLLATERAL);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral();

        _loan.removeCollateral(collateral_, address(this));

        assertEq(_loan.collateral(),                         0);
        assertEq(_collateralAsset.balanceOf(address(_loan)), 0);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateral_);
    }

    function test_removeCollateral_partialAmountWithNoEncumbrances(uint256 collateral_, uint256 removedAmount_) external {
        collateral_    = constrictToRange(collateral_,    2, MAX_COLLATERAL);
        removedAmount_ = constrictToRange(removedAmount_, 1, collateral_);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral();

        _loan.removeCollateral(removedAmount_, address(this));

        assertEq(_loan.collateral(),                         collateral_ - removedAmount_);
        assertEq(_collateralAsset.balanceOf(address(_loan)), collateral_ - removedAmount_);
        assertEq(_collateralAsset.balanceOf(address(this)),  removedAmount_);
    }

    function testFail_removeCollateral_insufficientCollateralWithNoEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral();

        _loan.removeCollateral(collateral_ + 1, address(this));
    }

    function test_removeCollateral_sameAssetAsFundingAsset(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, MAX_COLLATERAL);

        _loan.setFundsAsset(address(_collateralAsset));

        _collateralAsset.mint(address(_loan), 1);

        _loan.setClaimableFunds(1);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral();

        assertEq(_loan.collateral(),                         collateral_);
        assertEq(_loan.claimableFunds(),                     1);
        assertEq(_collateralAsset.balanceOf(address(_loan)), collateral_ + 1);
        assertEq(_collateralAsset.balanceOf(address(this)),  0);

        _loan.removeCollateral(collateral_, address(this));

        assertEq(_loan.collateral(),                         0);
        assertEq(_loan.claimableFunds(),                     1);
        assertEq(_collateralAsset.balanceOf(address(_loan)), 1);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateral_);
    }

    // TODO: test_removeCollateral_fullAmountWithEncumbrances

    // TODO: test_removeCollateral_partialAmountWithEncumbrances

    // TODO: testFail_removeCollateral_fullAmountWithEncumbrances

    // TODO: testFail_removeCollateral_partialAmountWithEncumbrances

    // TODO: testFail_removeCollateral_transferFailed?

}

contract MapleLoanInternals_DrawdownFundsTests is TestUtils {

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)

    MockERC20                 internal _fundsAsset;
    MapleLoanInternalsHarness internal _loan;

    function setUp() external {
        _fundsAsset = new MockERC20("Funds Asset", "FA", 0);
        _loan       = new MapleLoanInternalsHarness();

        _loan.setBorrower(address(this));
        _loan.setFundsAsset(address(_fundsAsset));
    }

    function setupLoan(address loan_, uint256 principalRequested_) internal {
        MapleLoanInternalsHarness(loan_).setPrincipalRequested(principalRequested_);
        MapleLoanInternalsHarness(loan_).setPrincipal(principalRequested_);
        MapleLoanInternalsHarness(loan_).setDrawableFunds(principalRequested_);
    }

    function test_drawdownFunds_withoutPostedCollateral(uint256 principalRequested_, uint256 drawdownAmount_) external {
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        drawdownAmount_     = constrictToRange(drawdownAmount_,     1, principalRequested_);

        setupLoan(address(_loan), principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.drawdownFunds(drawdownAmount_, address(this));

        assertEq(_loan.drawableFunds(),                 principalRequested_ - drawdownAmount_);
        assertEq(_fundsAsset.balanceOf(address(_loan)), principalRequested_ - drawdownAmount_);
        assertEq(_fundsAsset.balanceOf(address(this)),  drawdownAmount_);
    }

    function test_drawdownFunds_postedCollateral(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        // Must have non-zero collateral and principal amounts to cause failure
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        drawdownAmount_     = constrictToRange(drawdownAmount_,     1, principalRequested_);

        setupLoan(address(_loan), principalRequested_);

        _loan.setCollateralRequired(collateralRequired_);
        _loan.setCollateral(collateralRequired_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.drawdownFunds(drawdownAmount_, address(this));

        assertEq(_loan.drawableFunds(),                 principalRequested_ - drawdownAmount_);
        assertEq(_fundsAsset.balanceOf(address(_loan)), principalRequested_ - drawdownAmount_);
        assertEq(_fundsAsset.balanceOf(address(this)),  drawdownAmount_);
    }

    function testFail_drawdownFunds_insufficientDrawableFunds(uint256 principalRequested_, uint256 extraAmount_) external {
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        extraAmount_        = constrictToRange(extraAmount_,        1, MAX_TOKEN_AMOUNT);

        setupLoan(address(_loan), principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.drawdownFunds(principalRequested_ + extraAmount_, address(this));
    }

    // TODO: testFail_drawdownFunds_transferFailed?

    function test_drawdownFunds_multipleDrawdowns(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        // Must have non-zero collateral and principal amounts to cause failure
        collateralRequired_ = constrictToRange(collateralRequired_, 2, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 2, MAX_TOKEN_AMOUNT);
        drawdownAmount_     = constrictToRange(drawdownAmount_,     1, principalRequested_ / 2);

        setupLoan(address(_loan), principalRequested_);

        _loan.setCollateralRequired(collateralRequired_);
        _loan.setCollateral(collateralRequired_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.drawdownFunds(drawdownAmount_, address(this));

        assertEq(_loan.drawableFunds(),                 principalRequested_ - drawdownAmount_);
        assertEq(_fundsAsset.balanceOf(address(_loan)), principalRequested_ - drawdownAmount_);
        assertEq(_fundsAsset.balanceOf(address(this)),  drawdownAmount_);

        _loan.drawdownFunds(_loan.drawableFunds(), address(this));

        assertEq(_loan.drawableFunds(),                 0);
        assertEq(_fundsAsset.balanceOf(address(_loan)), 0);
        assertEq(_fundsAsset.balanceOf(address(this)),  principalRequested_);
    }

    // TODO: see if there is a way to make the transfer fail in drawdown due to lack of funds

    function testFail_drawdownFunds_collateralNotMaintained(uint256 collateralRequired_, uint256 principalRequested_, uint256 collateral_) external {
        // Must have non-zero collateral and principal amounts to cause failure
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        collateral_         = constrictToRange(collateral_,         0, collateralRequired_ - 1);

        setupLoan(address(_loan), principalRequested_);

        _loan.setCollateralRequired(collateralRequired_);
        _loan.setCollateral(collateral_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.drawdownFunds(principalRequested_, address(this));
    }

}

contract MapleLoanInternals_RepossessTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _collateralAsset;
    MockERC20                 internal _fundsAsset;

    function setUp() external {
        _collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        _fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        _loan            = new MapleLoanInternalsHarness();

        _loan.setCollateralAsset(address(_collateralAsset));
        _loan.setFundsAsset(address(_fundsAsset));

        _loan.setDrawableFunds(1);
        _loan.setClaimableFunds(1);
        _loan.setCollateral(1);
        _loan.setLender(address(this));
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipal(1);
        _loan.setGracePeriod(10);

        _fundsAsset.mint(address(_loan), 2);
        _collateralAsset.mint(address(_loan), 1);
    }

    function test_repossess() external {
        _loan.setNextPaymentDueDate(block.timestamp - 11);

        _loan.repossess(address(this));

        assertEq(_loan.drawableFunds(),                     0);
        assertEq(_loan.claimableFunds(),                    0);
        assertEq(_loan.collateral(),                        0);
        assertEq(_loan.nextPaymentDueDate(),                0);
        assertEq(_loan.paymentsRemaining(),                 0);
        assertEq(_loan.principal(),                         0);
        assertEq(_collateralAsset.balanceOf(address(this)), 1);
        assertEq(_fundsAsset.balanceOf(address(this)),      2);
    }

    function testFail_repossess_beforePaymentDue() external {
        _loan.setNextPaymentDueDate(block.timestamp + 1);
        _loan.repossess(address(this));
    }

    function testFail_repossess_onPaymentDue() external {
        _loan.setNextPaymentDueDate(block.timestamp);
        _loan.repossess(address(this));
    }

    function testFail_repossess_withinGracePeriod() external {
        _loan.setNextPaymentDueDate(block.timestamp - 5);
        _loan.repossess(address(this));
    }

    function testFail_repossess_onGracePeriod() external {
        _loan.setNextPaymentDueDate(block.timestamp - 10);
        _loan.repossess(address(this));
    }

    // TODO: testFail_repossess_collateralTransferFailed?

    // TODO: testFail_repossess_fundsTransferFailed?

}

contract MapleLoanInternals_ReturnFundsTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _fundsAsset;

    function setUp() external {
        _fundsAsset = new MockERC20("Funds Asset", "FA", 0);
        _loan       = new MapleLoanInternalsHarness();

        _loan.setFundsAsset(address(_fundsAsset));
    }

    function test_returnFunds(uint256 fundsToReturn_) external {
        fundsToReturn_ = constrictToRange(fundsToReturn_, 0, type(uint256).max >> 3);

        assertEq(_loan.returnFunds(),   0);
        assertEq(_loan.drawableFunds(), 0);

        _fundsAsset.mint(address(_loan), fundsToReturn_);

        assertEq(_loan.returnFunds(),   fundsToReturn_);
        assertEq(_loan.drawableFunds(), fundsToReturn_);

        _fundsAsset.mint(address(_loan), fundsToReturn_);

        assertEq(_loan.returnFunds(),   fundsToReturn_);
        assertEq(_loan.drawableFunds(), 2 * fundsToReturn_);
    }

    function test_returnFunds_collateralAsset() external {
        MockERC20 _collateralAsset = new MockERC20("Collateral Asset", "CA", 0);

        _loan.setCollateralAsset(address(_collateralAsset));

        assertEq(_loan.returnFunds(),   0);
        assertEq(_loan.drawableFunds(), 0);

        _collateralAsset.mint(address(_loan), 1);

        assertEq(_loan.returnFunds(),   0);
        assertEq(_loan.drawableFunds(), 0);
    }

}

contract MapleLoanInternals_ClaimFundsTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _fundsAsset;

    function setUp() external {
        _fundsAsset = new MockERC20("Funds Asset",      "FA", 0);
        _loan       = new MapleLoanInternalsHarness();

        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setLender(address(this));
    }

    function test_claimFunds(uint256 claimable_, uint256 amountToClaim_) external {
        claimable_     = constrictToRange(claimable_,     1, type(uint256).max);
        amountToClaim_ = constrictToRange(amountToClaim_, 1, claimable_);

        _fundsAsset.mint(address(_loan), claimable_);

        _loan.setClaimableFunds(claimable_);

        _loan.claimFunds(amountToClaim_, address(this));

        assertEq(_loan.claimableFunds(),                claimable_ - amountToClaim_);
        assertEq(_fundsAsset.balanceOf(address(_loan)), claimable_ - amountToClaim_);
        assertEq(_fundsAsset.balanceOf(address(this)),  amountToClaim_);
    }

    function testFail_claimFunds_insufficientClaimableFunds(uint256 claimable_, uint256 amountToClaim_) external {
        claimable_     = constrictToRange(claimable_,     1,              type(uint256).max / 2);
        amountToClaim_ = constrictToRange(amountToClaim_, claimable_ + 1, type(uint256).max);

        _fundsAsset.mint(address(_loan), claimable_);

        _loan.setClaimableFunds(claimable_);

        _loan.claimFunds(amountToClaim_, address(this));
    }

    // TODO: testFail_claimFunds_transferFail?

}

contract MapleLoanInternals_MakePaymentTests is TestUtils {

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _fundsAsset;

    function setUp() external {
        _fundsAsset = new MockERC20("FundsAsset",      "FA", 0);
        _loan       = new MapleLoanInternalsHarness();

        _loan.setFundsAsset(address(_fundsAsset));
    }

    function setupLoan(
        address loan_,
        uint256 principalRequested_,
        uint256 paymentsRemaining_,
        uint256 paymentInterval_,
        uint256 interestRate_,
        uint256 endingPrincipal_
    ) internal {
        MapleLoanInternalsHarness(loan_).setPrincipalRequested(principalRequested_);
        MapleLoanInternalsHarness(loan_).setPrincipal(principalRequested_);
        MapleLoanInternalsHarness(loan_).setDrawableFunds(principalRequested_);

        MapleLoanInternalsHarness(loan_).setPaymentsRemaining(paymentsRemaining_);
        MapleLoanInternalsHarness(loan_).setPaymentInterval(paymentInterval_);
        MapleLoanInternalsHarness(loan_).setInterestRate(interestRate_);
        MapleLoanInternalsHarness(loan_).setEndingPrincipal(endingPrincipal_);
        MapleLoanInternalsHarness(loan_).setNextPaymentDueDate(block.timestamp + paymentInterval_);

        _fundsAsset.mint(address(_loan), principalRequested_);
    }

    function test_makePayment_withDrawableFunds(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100, 365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,   50);
        interestRate_       = constrictToRange(interestRate_,       0,   1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_);

        uint256 extraDrawableFunds = MAX_TOKEN_AMOUNT * 150;

        _fundsAsset.mint(address(_loan), extraDrawableFunds);

        uint256 startingDrawableFunds = _loan.drawableFunds() + extraDrawableFunds;

        _loan.setDrawableFunds(startingDrawableFunds);

        assertEq(_loan.drawableFunds(),      startingDrawableFunds);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        ( uint256 principal, uint256 interest ) = _loan.makePayment();

        uint256 totalPaid = principal + interest;

        assertEq(_loan.drawableFunds(),      startingDrawableFunds - totalPaid);
        assertEq(_loan.claimableFunds(),     totalPaid);
        assertEq(_loan.principal(),          principalRequested_ - principal);
        assertEq(_loan.nextPaymentDueDate(), _loan.paymentsRemaining() == 0 ? 0 : block.timestamp + (2 * paymentInterval_));
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_ - 1);
    }

    function test_makePayment(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100, 365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,   50);
        interestRate_       = constrictToRange(interestRate_,       0,   1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_);

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        _fundsAsset.mint(address(_loan), fundsForPayments);

        ( uint256 principal, uint256 interest ) = _loan.makePayment();

        uint256 totalPaid = principal + interest;

        assertEq(_loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(_loan.claimableFunds(),     totalPaid);
        assertEq(_loan.principal(),          principalRequested_ - principal);
        assertEq(_loan.nextPaymentDueDate(), _loan.paymentsRemaining() == 0 ? 0 : block.timestamp + (2 * paymentInterval_));
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_ - 1);
    }

    // TODO: testFail_makePayment_insufficientAmount

    // TODO: test_makePayment_overPay

    // TODO: test_makePayment_lastPaymentClearsLoan

}

contract MapleLoanInternals_CloseLoanTests is StateManipulations, TestUtils {

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _fundsAsset;

    function setUp() external {
        _fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        _loan       = new MapleLoanInternalsHarness();

        _loan.setFundsAsset(address(_fundsAsset));
    }

    function setupLoan(
        address loan_,
        uint256 principalRequested_,
        uint256 paymentsRemaining_,
        uint256 paymentInterval_,
        uint256 interestRate_,
        uint256 endingPrincipal_,
        uint256 earlyFeeRate_
    ) internal {
        MapleLoanInternalsHarness(loan_).setPrincipalRequested(principalRequested_);
        MapleLoanInternalsHarness(loan_).setPrincipal(principalRequested_);
        MapleLoanInternalsHarness(loan_).setDrawableFunds(principalRequested_);

        MapleLoanInternalsHarness(loan_).setPaymentsRemaining(paymentsRemaining_);
        MapleLoanInternalsHarness(loan_).setPaymentInterval(paymentInterval_);
        MapleLoanInternalsHarness(loan_).setInterestRate(interestRate_);
        MapleLoanInternalsHarness(loan_).setEndingPrincipal(endingPrincipal_);
        MapleLoanInternalsHarness(loan_).setNextPaymentDueDate(block.timestamp + paymentInterval_);

        MapleLoanInternalsHarness(loan_).setEarlyFeeRate(earlyFeeRate_);
    }

    function test_closeLoan(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_,
        uint256 earlyFeeRate_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,     365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,       120);
        interestRate_       = constrictToRange(interestRate_,       0,       1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,       principalRequested_);
        earlyFeeRate_       = constrictToRange(earlyFeeRate_,       0.01e18, 1.00e18);

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_, earlyFeeRate_);

        // Setting drawable to zero to simulate a drawdown
        MapleLoanInternalsHarness(_loan).setDrawableFunds(0);

        uint256 closingAmount = principalRequested_ + (principalRequested_ * earlyFeeRate_ / 10 ** 18);

        assertEq(_loan.drawableFunds(),      0);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        _fundsAsset.mint(address(_loan), closingAmount);

        ( uint256 principal, uint256 interest ) = _loan.closeLoan();

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                  closingAmount);
        assertEq(_loan.drawableFunds(),      0);
        assertEq(_loan.claimableFunds(),     totalPaid);
        assertEq(_loan.principal(),          0);
        assertEq(_loan.nextPaymentDueDate(), 0);
        assertEq(_loan.paymentsRemaining(),  0);
    }

    function test_closeLoan_withDrawableFunds(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_,
        uint256 earlyFeeRate_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,     365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,       120);
        interestRate_       = constrictToRange(interestRate_,       0,       1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,       principalRequested_);
        earlyFeeRate_       = constrictToRange(earlyFeeRate_,       0.01e18, 1.00e18);

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_, earlyFeeRate_);

        // Sending funds to loan
        _fundsAsset.mint(address(_loan), principalRequested_);

        // Only fee needs to be sent, since drawdown never ocurred
        uint256 closingAmount = principalRequested_ * earlyFeeRate_ / 10 ** 18;

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        _fundsAsset.mint(address(_loan), closingAmount);

        ( uint256 principal, uint256 interest ) = _loan.closeLoan();

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid - principalRequested_, closingAmount);
        assertEq(_loan.claimableFunds(),          totalPaid);
        assertEq(_loan.drawableFunds(),           0);
        assertEq(_loan.principal(),               0);
        assertEq(_loan.nextPaymentDueDate(),      0);
        assertEq(_loan.paymentsRemaining(),       0);
    }

    function test_closeLoan_withRemainderAsDrawableFunds(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_,
        uint256 earlyFeeRate_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,     365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,       120);
        interestRate_       = constrictToRange(interestRate_,       0,       1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,       principalRequested_);
        earlyFeeRate_       = constrictToRange(earlyFeeRate_,       0.01e18, 1.00e18);

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_, earlyFeeRate_);

        // Sending funds to loan
        _fundsAsset.mint(address(_loan), principalRequested_);

        // Only fee needs to be sent, since drawdown never ocurred
        uint256 closingAmount = principalRequested_ * earlyFeeRate_ / 10 ** 18;
        uint256 extraFunds    = 1 ether;

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        _fundsAsset.mint(address(_loan), closingAmount + extraFunds);

        ( uint256 principal, uint256 interest ) = _loan.closeLoan();

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid - principalRequested_,  closingAmount);
        assertEq(_loan.drawableFunds(),            extraFunds);
        assertEq(_loan.claimableFunds(),           totalPaid);
        assertEq(_loan.principal(),                0);
        assertEq(_loan.nextPaymentDueDate(),       0);
        assertEq(_loan.paymentsRemaining(),        0);
    }

    function test_closeLoan_failIfPaymentIsLate(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_,
        uint256 earlyFeeRate_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,     365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,       120);
        interestRate_       = constrictToRange(interestRate_,       0,       1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,       principalRequested_);
        earlyFeeRate_       = constrictToRange(earlyFeeRate_,       0.01e18, 1.00e18);

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_, earlyFeeRate_);

        // Sending funds to loan
        _fundsAsset.mint(address(_loan), principalRequested_);

        uint256 closingAmount = principalRequested_ * earlyFeeRate_ / 10 ** 18;

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        _fundsAsset.mint(address(_loan), closingAmount);

        hevm.warp(block.timestamp + paymentInterval_ + 1);

        try _loan.closeLoan() { assertTrue(false, "Cannot close when late"); } catch { }

        // Returning to being on-time
        hevm.warp(block.timestamp - 2);

        ( uint256 principal, uint256 interest ) = _loan.closeLoan();

        uint256 totalPaid = principal + interest;

        assertEq(_loan.drawableFunds(),      0);
        assertEq(_loan.claimableFunds(),     totalPaid);
        assertEq(_loan.principal(),          0);
        assertEq(_loan.nextPaymentDueDate(), 0);
        assertEq(_loan.paymentsRemaining(),  0);
    }

}

contract MapleLoanInternals_GetCollateralRequiredForTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();
    }

    function test_getCollateralRequiredFor() external {
        // No principal.
        assertEq(_loan.getCollateralRequiredFor(0, 10_000, 4_000_000, 500_000), 0);

        // No outstanding principal.
        assertEq(_loan.getCollateralRequiredFor(10_000, 10_000, 4_000_000, 500_000), 0);

        // No collateral required.
        assertEq(_loan.getCollateralRequiredFor(10_000, 1_000, 4_000_000, 0), 0);

        // 1125 = (500_000 * (10_000 > 1_000 ? 10_000 - 1_000 : 0)) / 4_000_000;
        assertEq(_loan.getCollateralRequiredFor(10_000, 1_000, 4_000_000, 500_000), 1125);

        // 500_000 = (500_000 * (4_500_000 > 500_000 ? 4_500_000 - 500_000 : 0)) / 4_000_000;
        assertEq(_loan.getCollateralRequiredFor(4_500_000, 500_000, 4_000_000, 500_000), 500_000);
    }

}

contract MapleLoanInternals_InitializeTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _token0;
    MockERC20                 internal _token1;
    address                   internal _defaultBorrower;
    address[2]                internal _defaultAssets;
    uint256[3]                internal _defaultTermDetails;
    uint256[3]                internal _defaultAmounts;
    uint256[4]                internal _defaultRates;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();

        _token0 = new MockERC20("Token0", "T0", 0);
        _token1 = new MockERC20("Token1", "T1", 0);
        
        // Happy path dummy arguments to pass to initialize().
        _defaultBorrower    = address(1);
        _defaultAssets      = [address(_token0), address(_token1)]; 
        _defaultTermDetails = [uint256(1), uint256(2), uint256(3)];
        _defaultAmounts     = [uint256(5), uint256(4)];
        _defaultRates       = [uint256(6), uint256(7), uint256(8), uint256(9)];
    }

    function test_initialize_happyPath() external {
        // Call initialize() with all happy path arguments, should not revert().
        _loan.initialize(_defaultBorrower, _defaultAssets, _defaultTermDetails, _defaultAmounts, _defaultRates);

        assertEq(_loan.collateralAsset(),     _defaultAssets[0]);
        assertEq(_loan.fundsAsset(),          _defaultAssets[1]);
                                             
        assertEq(_loan.gracePeriod(),         _defaultTermDetails[0]);
        assertEq(_loan.paymentInterval(),     _defaultTermDetails[1]);
        assertEq(_loan.paymentsRemaining(),   _defaultTermDetails[2]);
                                             
        assertEq(_loan.collateralRequired(),  _defaultAmounts[0]);
        assertEq(_loan.principalRequested(),  _defaultAmounts[1]);
        assertEq(_loan.endingPrincipal(),     _defaultAmounts[2]);
                                             
        assertEq(_loan.interestRate(),        _defaultRates[0]);
        assertEq(_loan.earlyFeeRate(),        _defaultRates[1]);
        assertEq(_loan.lateFeeRate(),         _defaultRates[2]);
        assertEq(_loan.lateInterestPremium(), _defaultRates[3]);
    }

    function test_initialize_invalidPrincipal() external {
        uint256[3] memory amounts; 

        // Set principal requested to invalid amount.
        amounts[1] = 0;

        // Call initialize, expecting to revert with correct error message. 
        try _loan.initialize(_defaultBorrower, _defaultAssets, _defaultTermDetails, amounts, _defaultRates) { 
            assertTrue(false, "Principal requested must be non-zero."); 
        } 
        catch Error(string memory reason) {
            assertEq(reason, "MLI:I:INVALID_PRINCIPAL"); 
        }
    }

    function test_initialize_invalidEndingPrincipal() external {
        uint256[3] memory amounts; 

        // Set ending principal to invalid amount. 
        amounts[1] = 12;
        amounts[2] = 24;

        // Call initialize(), expecting to revert with correct error message. 
        try _loan.initialize(_defaultBorrower, _defaultAssets, _defaultTermDetails, amounts, _defaultRates) {
            assertTrue(false, "Ending principal needs to be less than or equal to principal requested."); 
        } 
        catch Error(string memory reason) {
            assertEq(reason, "MLI:I:INVALID_ENDING_PRINCIPAL"); 
        }
    }

    function test_initialize_invalidBorrower() external {
        // Define invalid borrower.
        address invalidBorrower = address(0);

        // Call initialize, expecting to revert with correct error message.
        try _loan.initialize(invalidBorrower, _defaultAssets, _defaultTermDetails, _defaultAmounts, _defaultRates) {
            assertTrue(false, "Borrow cannot be address(0)."); 
        } 
        catch Error(string memory reason) {
            assertEq(reason, "MLI:I:INVALID_BORROWER"); 
        }
    }
}

// TODO: MapleLoanInternals_AcceptNewTermsTests

// TODO: MapleLoanInternals_InitializeTests

// TODO: MapleLoanInternals_ProposeNewTermsTests

// TODO: MapleLoanInternals_GetEarlyPaymentBreakdownTests

// TODO: MapleLoanInternals_GetNextPaymentBreakdownTests

// TODO: MapleLoanInternals_SsCollateralMaintainedTests

// TODO: MapleLoanInternals_GetRefinanceCommitmentTests
