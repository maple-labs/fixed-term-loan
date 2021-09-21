// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { DSTest }    from "../../modules/ds-test/src/test.sol";
import { MockERC20 } from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { LoanPrimitiveHarness } from "./harnesses/LoanPrimitiveHarness.sol";

interface Hevm {
    function warp(uint256) external;
}

// TODO: user `contract-test-utils`

contract LoanPrimitivePaymentBreakDownTest is DSTest {

    LoanPrimitiveHarness loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function test_getPaymentBreakdown_onePeriodBeforeDue() external {
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentsBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentsBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentsBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentsBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentsBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentsBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentsBreakdown(
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
        ( uint256 totalPrincipalAmount, uint256 totalInterestFees, uint256 totalLateFees ) = loan.getPaymentsBreakdown(
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

}

contract LoanPrimitiveFeeTest is DSTest {

    LoanPrimitiveHarness loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function test_getFee() external {
        assertEq(loan.getFee(1_000_000, 120_000, 365 days / 12), 10_000);  // 12% APY on 1M
        assertEq(loan.getFee(10_000, 1_200_000, 365 days / 12), 1_000);    // 120% APY on 10k
    }


    function test_getPeriodicFeeRate() external {
        assertEq(loan.getPeriodicFeeRate(120_000, 365 days),      120_000);
        assertEq(loan.getPeriodicFeeRate(120_000, 365 days / 12), 10_000);
    }

}

contract LoanPrimitiveInstallmentTest is DSTest {

    LoanPrimitiveHarness loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
    }

    function test_getInstallment() external {
        ( uint256 principalAmount, uint256 interestAmount ) = loan.getInstallment(1_000_000, 0, 120_000, 365 days / 12, 12);

        assertEq(principalAmount, 78_850);
        assertEq(interestAmount,  10_000);
    }

}

contract LoanPrimitiveScaledExponentTest is DSTest {

    LoanPrimitiveHarness loan;

    function setUp() external {
        loan = new LoanPrimitiveHarness();
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

contract LoanPrimitiveLendTest is DSTest {

    uint256 constant MAX_REQUESTED_AMOUNT = type(uint256).max - 1;
    uint256 constant MIN_REQUESTED_AMOUNT = 2;

    LoanPrimitiveHarness loan;
    MockERC20            token;

    address mockCollateralToken = address(9);

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

    function _constrictToRange(uint256 input_, uint256 min_, uint256 max_) internal pure returns (uint256 output_) {
        return min_ == max_ ? max_ : input_ % (max_ - min_) + min_;
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
        requestedAmount_ = _constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(requestedAmount_);

        ( bool ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");
    }

    function test_lend_fullLend(uint256 requestedAmount_) external {
        requestedAmount_ = _constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(requestedAmount_);

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
        requestedAmount_ = _constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);

        _initializeLoanWithRequestAmount(requestedAmount_);

        token.mint(address(this), requestedAmount_);
        token.transfer(address(loan), requestedAmount_ - 1);

        ( bool ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");

    }

    function test_lend_failWithDoubleLend(uint256 requestedAmount_) external {
        requestedAmount_ = _constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);

        // Dividing by two to make sure we can mint twice
        _initializeLoanWithRequestAmount(requestedAmount_ / 2);

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
        requestedAmount_ = _constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(requestedAmount_);

        token.mint(address(this), requestedAmount_ + 1);
        token.transfer(address(loan), requestedAmount_ + 1);

        ( bool ok, ) = loan.lend(address(this));
        assertTrue(!ok, "lend should have failed");
    }

    function test_lend_claimImmediatelyAfterLend(uint256 requestedAmount_) external {
        requestedAmount_ = _constrictToRange(requestedAmount_, MIN_REQUESTED_AMOUNT, MAX_REQUESTED_AMOUNT);
        _initializeLoanWithRequestAmount(requestedAmount_);

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

contract LendPrimitivePostAndRemoveCollateralTest is DSTest {

    LoanPrimitiveHarness loan;
    MockERC20            collateralAsset;
    MockERC20            fundsAsset;

    function setUp() external {
        collateralAsset = new MockERC20("CollateralAsset", "CA", 0);
        fundsAsset      = new MockERC20("FundsAsset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function _initializeLoanWithCollateralRequested(uint256 collateralRequested_) internal {
        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(0),
            uint256(10 days),
            uint256(1_200 * 100),
            uint256(1_100 * 100),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [uint256(collateralRequested_), uint256(1_000_000)];

        loan.initialize(address(1), assets, parameters, requests);
    }

    /***********************/
    /*** Post Collateral ***/
    /***********************/

    function test_postCollateral_initialState(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequested(collateralAmount_);

        assertEq(loan.collateral(), 0);
    }

    function testFail_postCollateral_uninitializedLoan() external {
        loan.postCollateral();
    }

    function test_postCollateral_exactAmount(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequested(collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_);

        uint256 amount = loan.postCollateral();

        assertEq(amount,            collateralAmount_);
        assertEq(loan.collateral(), collateralAmount_);
    }

    function test_postCollateral_lessThanRequired(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ == 0 ? 1 : collateralAmount_;
        _initializeLoanWithCollateralRequested(collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_ - 1);

        uint256 amount = loan.postCollateral();

        assertEq(amount,            collateralAmount_ - 1);
        assertEq(loan.collateral(), amount);
    }

    function test_postCollateral_moreThanRequired(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ == type(uint256).max ? type(uint256).max - 1 : collateralAmount_;
        _initializeLoanWithCollateralRequested(collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_ + 1);

        uint256 amount = loan.postCollateral();

        assertEq(amount,            collateralAmount_ + 1);
        assertEq(loan.collateral(), amount);
    }

    function test_postCollateral_zeroAmount() external {
        _initializeLoanWithCollateralRequested(0);

        uint256 amount = loan.postCollateral();

        assertEq(amount,            0);
        assertEq(loan.collateral(), 0);
    }

    function test_postCollateral_withUnaccountedFundsAsset(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequested(collateralAmount_);

        // Send funds asset to Loan
        fundsAsset.mint(address(loan), loan.principalRequested());
        collateralAsset.mint(address(loan), collateralAmount_);

        uint256 amount = loan.postCollateral();

        assertEq(amount,            collateralAmount_);
        assertEq(loan.collateral(), collateralAmount_);
    }

    function test_postCollateral_doesNotCountOtherAssets(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequested(collateralAmount_);

        // Send funds asset to Loan
        fundsAsset.mint(address(loan), collateralAmount_);

        uint256 amount = loan.postCollateral();

        assertEq(amount,            0);
        assertEq(loan.collateral(), 0);
    }

    function test_postCollateral_sameAssets(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ > type(uint256).max - 1_000_000 ? type(uint256).max - 1_000_000 : collateralAmount_;

        // Initialize Loan with same asset for fund and collateral
        address[2] memory assets = [address(collateralAsset), address(collateralAsset)];

        uint256[6] memory parameters = [
            uint256(0),
            uint256(10 days),
            uint256(1_200 * 100),
            uint256(1_100 * 100),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [uint256(collateralAmount_), uint256(1_000_000)];

        loan.initialize(address(1), assets, parameters, requests);

        // Fund Loan (note: lend() must be called for funds to be accounted for)
        collateralAsset.mint(address(loan), 1_000_000);
        loan.lend(address(this));

        // Post collateral
        collateralAsset.mint(address(loan), collateralAmount_);

        uint256 amount = loan.postCollateral();

        assertEq(amount,            collateralAmount_);
        assertEq(loan.collateral(), collateralAmount_);
    }

    /*************************/
    /*** Remove Collateral ***/
    /*************************/

    function test_removeCollateral_fullAmount(uint256 collateralAmount_) external {
        _initializeLoanWithCollateralRequested(collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_);

        uint256 amount = loan.postCollateral();

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
        _initializeLoanWithCollateralRequested(collateralAmount_);

        collateralAsset.mint(address(loan), collateralAmount_);

        uint256 amount = loan.postCollateral();

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
        _initializeLoanWithCollateralRequested(collateralAmount_);

        collateralAmount_ = collateralAmount_ == type(uint256).max ? type(uint256).max - 1 : collateralAmount_;
        collateralAsset.mint(address(loan), collateralAmount_);

        uint256 amount =  loan.postCollateral();

        assertEq(amount,            collateralAmount_);
        assertEq(loan.collateral(), collateralAmount_);

        try loan.removeCollateral(collateralAmount_ + 1, address(this)) { assertTrue(false); } catch {}
    }

    function test_removeCollateral_sameAssets(uint256 collateralAmount_) external {
        collateralAmount_ = collateralAmount_ > type(uint256).max - 1_000_000 ? type(uint256).max - 1_000_000 : collateralAmount_;

        // Initialize loan with same asset for fund and collateral
        address[2] memory assets = [address(collateralAsset), address(collateralAsset)];

        uint256[6] memory parameters = [
            uint256(0),
            uint256(10 days),
            uint256(1_200 * 100),
            uint256(1_100 * 100),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [uint256(collateralAmount_), uint256(1_000_000)];

        loan.initialize(address(1), assets, parameters, requests);

        // Fund Loan
        collateralAsset.mint(address(loan), 1_000_000);
        loan.lend(address(this));

        // Post collateral
        collateralAsset.mint(address(loan), collateralAmount_);

        uint256 amount = loan.postCollateral();

        assertEq(amount,                                   collateralAmount_);
        assertEq(loan.collateral(),                        collateralAmount_);
        assertEq(collateralAsset.balanceOf(address(loan)), 1_000_000 + collateralAmount_);

        assertTrue(loan.removeCollateral(collateralAmount_, address(this)));

        assertEq(loan.collateral(),                        0);
        assertEq(collateralAsset.balanceOf(address(loan)), 1_000_000);
        assertEq(collateralAsset.balanceOf(address(this)), collateralAmount_);
    }

}

contract LoanPrimitiveDrawdownTest is DSTest {
    
    LoanPrimitiveHarness loan;
    MockERC20            collateralAsset;
    MockERC20            fundsAsset;

    uint256 MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function _initializeLoanWithAmounts(uint256 collateralRequired_, uint256 principalRequested_) internal {
        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            uint256(0),
            uint256(10 days),
            uint256(1_200 * 100),
            uint256(1_100 * 100),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [collateralRequired_, principalRequested_];

        loan.initialize(address(1), assets, parameters, requests);
    }

    function _constrictToRange(uint256 input_, uint256 min_, uint256 max_) internal pure returns (uint256 output_) {
        return min_ == max_ ? max_ : input_ % (max_ - min_) + min_;
    }

    function _createLoanAndLend(uint256 collateralRequired_, uint256 principalRequested_) internal {
        _initializeLoanWithAmounts(collateralRequired_, principalRequested_);

        fundsAsset.mint(address(loan), principalRequested_);
        loan.lend(address(this));
    }

    function _setUpDrawdown(
        uint256 collateralRequired_,
        uint256 minCollateral_,
        uint256 maxCollateral_,
        uint256 principalRequested_,
        uint256 minPrincipal_,
        uint256 maxPrincipal_
    )
        internal returns (uint256 constrictedCollateralRequired_, uint256 constrictedPrincipalRequested_)
    {
        constrictedCollateralRequired_ = _constrictToRange(collateralRequired_, minCollateral_, maxCollateral_);
        constrictedPrincipalRequested_ = _constrictToRange(principalRequested_, minPrincipal_,  maxPrincipal_);

        _createLoanAndLend(constrictedCollateralRequired_, constrictedPrincipalRequested_);

        collateralAsset.mint(address(loan), constrictedCollateralRequired_);
        loan.postCollateral();
    }

    function test_drawdown_initialState(uint256 collateralRequired_, uint256 principalRequested_) external {
        (
            collateralRequired_,
            principalRequested_
        ) = _setUpDrawdown(collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 0, MAX_TOKEN_AMOUNT);

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
        collateralRequired_ = _constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        principalRequested_ = _constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);

        _createLoanAndLend(collateralRequired_, principalRequested_);

        assertTrue(!loan.drawdownFunds(principalRequested_, address(this)));
    }

    function test_drawdownFunds_exactAmount(uint256 collateralRequired_, uint256 principalRequested_) external {
        ( , principalRequested_ ) = _setUpDrawdown(collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 0, MAX_TOKEN_AMOUNT);

        assertEq(loan.drawableFunds(),                principalRequested_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_);
        assertEq(fundsAsset.balanceOf(address(this)), 0);

        assertTrue(loan.drawdownFunds(principalRequested_, address(this)));

        assertEq(loan.drawableFunds(),                0);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(fundsAsset.balanceOf(address(this)), principalRequested_);
    }

    function test_drawdownFunds_lessThanDrawableFunds(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        ( , principalRequested_ ) = _setUpDrawdown(collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 0, MAX_TOKEN_AMOUNT);

        drawdownAmount_ = _constrictToRange(drawdownAmount_, 0, principalRequested_);

        assertEq(loan.drawableFunds(),                principalRequested_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_);
        assertEq(fundsAsset.balanceOf(address(this)), 0);

        assertTrue(loan.drawdownFunds(drawdownAmount_, address(this)));

        assertEq(loan.drawableFunds(),                principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(this)), drawdownAmount_);
    }

    function test_drawdownFunds_greaterThanDrawableFunds(uint256 collateralRequired_, uint256 principalRequested_) external {
        ( , principalRequested_ ) = _setUpDrawdown(collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 0, MAX_TOKEN_AMOUNT);

        try loan.drawdownFunds(principalRequested_ + 1, address(this)) { assertTrue(false); } catch {}
    }

    function test_drawdownFunds_multipleDrawdowns(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        ( , principalRequested_ ) = _setUpDrawdown(collateralRequired_, 0, MAX_TOKEN_AMOUNT, principalRequested_, 0, MAX_TOKEN_AMOUNT);

        drawdownAmount_ = _constrictToRange(drawdownAmount_, 0, principalRequested_);

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
        collateralRequired_ = _constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        principalRequested_ = _constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        _createLoanAndLend(collateralRequired_, principalRequested_);

        collateralAsset.mint(address(loan), collateralRequired_ - 1);
        loan.postCollateral();

        assertEq(loan.collateral(), collateralRequired_ - 1);

        // _collateralMaintained condition after a drawdown of principalRequested is made
        assertTrue(loan.collateral() * loan.principalRequested() < loan.collateralRequired() * loan.principal());

        // try loan.drawdownFunds(principalRequested_, address(this)) { } catch { assertTrue(true); }

        require(loan.drawdownFunds(principalRequested_, address(this)));
    }

}

contract LoanPrimitiveRepossessTest is DSTest {

    Hevm hevm;

    LoanPrimitiveHarness loan;
    MockERC20            collateralAsset;
    MockERC20            fundsAsset;

    uint256 start;

    uint256 MAX_TIME = 10_000 * 365 days;  // Assumed reasonable upper limit for payment intervals and grace periods

    function setUp() external {
        hevm = Hevm(address(bytes20(uint160(uint256(keccak256("hevm cheat code")))))); 

        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();

        start = block.timestamp;
    }

    function _constrictToRange(uint256 input_, uint256 min_, uint256 max_) internal pure returns (uint256 output_) {
        return min_ == max_ ? max_ : input_ % (max_ - min_) + min_;
    }

    function test_repossess(uint256 gracePeriod_, uint256 paymentInterval_) external {
        /*******************/
        /*** Create Loan ***/
        /*******************/

        // Not fuzzing since values are just set to zero
        uint256 collateralRequired =   300_000;
        uint256 principalRequested = 1_000_000;

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        uint256[6] memory parameters = [
            principalRequested,
            _constrictToRange(gracePeriod_, 0, MAX_TIME),
            uint256(1_200 * 100),
            uint256(1_100 * 100),
            _constrictToRange(paymentInterval_, 0, MAX_TIME),
            uint256(6)
        ];

        uint256[2] memory requests = [collateralRequired, principalRequested];

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

        ( uint256 principal, uint256 interest, uint256 lateFees ) = loan.getPaymentsBreakdown(
            1, 
            block.timestamp, 
            loan.nextPaymentDueDate(), 
            loan.paymentInterval(), 
            loan.principal(), 
            loan.endingPrincipal(), 
            loan.interestRate(), 
            loan.paymentsRemaining(), 
            loan.lateFeeRate()
        );

        uint256 totalPayment = principal + interest + lateFees;

        fundsAsset.mint(address(loan), totalPayment);

        hevm.warp(loan.nextPaymentDueDate());

        loan.makePayments(1);

        /*****************/
        /*** Repossess ***/
        /*****************/

        assertEq(loan.drawableFunds(),      600_000);      
        assertEq(loan.claimableFunds(),     totalPayment);     
        assertEq(loan.collateral(),         300_000);         
        assertEq(loan.nextPaymentDueDate(), start + loan.paymentInterval() * 2);  // Made a payment, so paymentInterval moved
        assertEq(loan.principal(),          1_000_000);          
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

contract LoanPrimitiveReturnFundsTest is DSTest {

    function _constrictToRange(uint256 input_, uint256 min_, uint256 max_) internal pure returns (uint256 output_) {
        return min_ == max_ ? max_ : input_ % (max_ - min_) + min_;
    }

    function test_returnFunds(uint256 fundsToReturn_) external {
        fundsToReturn_ = _constrictToRange(fundsToReturn_, 0, type(uint256).max >> 3);

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

        uint256[2] memory requests = [uint256(1), uint256(1)];

        loan.initialize(address(1), assets, parameters, requests);

        assertEq(loan.returnFunds(), 0);

        assertEq(loan.drawableFunds(), uint256(0));

        fundsAsset.mint(address(loan), fundsToReturn_);

        assertEq(loan.returnFunds(),   fundsToReturn_);
        assertEq(loan.drawableFunds(), fundsToReturn_);

        fundsAsset.mint(address(loan), fundsToReturn_);

        assertEq(loan.returnFunds(),   fundsToReturn_);
        assertEq(loan.drawableFunds(), 2 * fundsToReturn_);

        collateralAsset.mint(address(loan), fundsToReturn_);

        assertEq(loan.returnFunds(),   0);
        assertEq(loan.drawableFunds(), 2 * fundsToReturn_);
    }

}

contract LoanPrimitiveClaimFundsTest is DSTest {

    LoanPrimitiveHarness loan;
    MockERC20            collateralAsset;
    MockERC20            fundsAsset;

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        loan            = new LoanPrimitiveHarness();
    }

    function _constrictToRange(uint256 input_, uint256 min_, uint256 max_) internal pure returns (uint256 output_) {
        return min_ == max_ ? max_ : input_ % (max_ - min_) + min_;
    }

    function test_claimFunds(uint256 fundingAmount_, uint256 amountToClaim_) external {
        // `amountToClaim_` is constrict to half the constricted `fundingAmount_`
        fundingAmount_ = _constrictToRange(fundingAmount_, 2, type(uint256).max >> 10);
        amountToClaim_ = _constrictToRange(amountToClaim_, 1, fundingAmount_ / 2);

        address[2] memory assets = [address(collateralAsset), address(fundsAsset)];

        // 0% interest loan with 2 payments, so half of principal paid in each installment
        uint256[6] memory parameters = [
            uint256(0),
            uint256(1),
            uint256(0),
            uint256(0),
            uint256(100),
            uint256(2)
        ];

        uint256[2] memory requests = [uint256(0), uint256(fundingAmount_)];

        loan.initialize(address(1), assets, parameters, requests);
        fundsAsset.mint(address(loan), fundingAmount_);
        loan.lend(address(this));
        loan.makePayments(1);

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
            uint256(0),
            uint256(1),
            uint256(0),
            uint256(0),
            uint256(100),
            uint256(2)
        ];

        uint256[2] memory requests = [uint256(0), uint256(10_000)];

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
            uint256(0),
            uint256(1),
            uint256(0),
            uint256(0),
            uint256(100),
            uint256(2)
        ];

        uint256[2] memory requests = [uint256(0), uint256(10_000)];

        loan.initialize(address(1), assets, parameters, requests);
        fundsAsset.mint(address(loan), 10_000);
        loan.lend(address(this));
        loan.makePayments(1);

        assertEq(loan.claimableFunds(), 5_000);
        assertEq(fundsAsset.balanceOf(address(loan)), 10_000);

        loan.claimFunds(5_001, address(this));
    }

}
