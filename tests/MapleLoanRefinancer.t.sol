// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleLoanFeeManager } from "../contracts/MapleLoanFeeManager.sol";
import { MapleRefinancer }     from "../contracts/MapleRefinancer.sol";

import { ConstructableMapleLoan } from "./harnesses/MapleLoanHarnesses.sol";

import {
    MockFactory,
    MockFeeManager,
    MockGlobals,
    MockLoanManager,
    MockPoolManager
} from "./mocks/Mocks.sol";

// Helper contract with common functionality
contract TestBase is TestUtils {

    // Loan Boundaries
    uint256 internal constant MAX_PAYMENTS     = 20;
    uint256 internal constant MAX_RATE         = 1e6;              // 100 %
    uint256 internal constant MAX_TIME         = 90 days;          // Assumed reasonable upper limit for payment intervals and grace periods
    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant MIN_TOKEN_AMOUNT = 10 ** 6;          // Needed so payments don't round down to zero

    ConstructableMapleLoan internal loan;
    MockERC20              internal token;
    MockFactory            internal factory;
    MockFeeManager         internal feeManager;
    MockGlobals            internal globals;
    MockLoanManager        internal lender;
    MapleRefinancer        internal refinancer;

    address internal borrower = address(new Address());
    address internal governor = address(new Address());

    function setUp() public virtual {
        feeManager = new MockFeeManager();
        globals    = new MockGlobals(governor);
        lender     = new MockLoanManager();
        refinancer = new MapleRefinancer();
        token      = new MockERC20("Test", "TST", 0);

        factory = new MockFactory(address(globals));

        lender.__setFundsAsset(address(token));

        globals.setValidBorrower(borrower,        true);
        globals.setValidPoolAsset(address(token), true);

        globals.__setIsInstanceOf(true);
    }

    function setUpOngoingLoan(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_
    )
        internal
    {
        globals.setValidCollateralAsset(address(token), true);

        address[2] memory assets      = [address(token), address(token)];
        uint256[3] memory amounts     = [collateralRequired_, principalRequested_, endingPrincipal_];
        uint256[3] memory termDetails = [gracePeriod_, paymentInterval_, paymentsRemaining_];
        uint256[4] memory rates       = [interestRate_, uint256(0.10e18), uint256(0.15e18), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        vm.prank(address(factory));
        loan = new ConstructableMapleLoan(address(factory), borrower, address(lender), address(feeManager), assets, termDetails, amounts, rates, fees);

        vm.prank(address(borrower));
        loan.acceptLoanTerms();

        token.mint(address(loan), principalRequested_);

        vm.prank(address(lender));
        loan.fundLoan();

        token.mint(address(loan), collateralRequired_);
        loan.postCollateral(0);

        vm.prank(borrower);
        loan.drawdownFunds(principalRequested_, address(1));

        // Warp to when payment is due
        vm.warp(loan.nextPaymentDueDate());

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion, ) = loan.getNextPaymentBreakdown();

        // Make payment #1
        token.mint(address(loan), principalPortion + interestPortion);
        loan.makePayment(0);
    }

    function _encodeWithSignatureAndUint(string memory signature_, uint256 arg_) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature_, arg_);
    }

}

contract MapleLoanRefinancerMiscellaneousTests is TestBase {

    function test_refinance_invalidRefinancer() external {
        setUpOngoingLoan(1, 1, 1, 12 hours, 1, 1, 1);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature("setEndingPrincipal(uint256)", 0);

        // Executing refinance
        vm.prank(borrower);
        loan.proposeNewTerms(address(1), block.timestamp, data);

        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:INVALID_REFINANCER");
        loan.acceptNewTerms(address(1), block.timestamp, data);
    }

}

contract MapleLoanRefinancerMultipleParameterTests is TestBase {

    function test_refinance_multipleParameters(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT,        MAX_TOKEN_AMOUNT - MIN_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    principalRequested_ / 2, principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,                MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       10_000,                  MAX_RATE / 2);  // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    30 days,                 MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                       MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        // Asserting state
        assertEq(loan.collateralRequired(), collateralRequired_);
        assertEq(loan.endingPrincipal(),    endingPrincipal_);
        assertEq(loan.gracePeriod(),        gracePeriod_);
        assertEq(loan.interestRate(),       interestRate_);
        assertEq(loan.paymentInterval(),    paymentInterval_);
        assertEq(loan.principalRequested(), principalRequested_);

        uint256 currentPrincipal = loan.principal();

        // Defining refinance terms
        uint256 newCollateralRequired_ = MIN_TOKEN_AMOUNT;
        uint256 newEndingPrincipal_    = 0;
        uint256 newGracePeriod_        = 95;
        uint256 newInterestRate_       = 0;
        uint256 newPaymentInterval_    = 15 days;
        uint256 principalIncrease_     = MIN_TOKEN_AMOUNT;

        bytes[] memory data = new bytes[](6);
        data[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", newCollateralRequired_);
        data[1] = abi.encodeWithSignature("setEndingPrincipal(uint256)",    newEndingPrincipal_);
        data[2] = abi.encodeWithSignature("setGracePeriod(uint256)",        newGracePeriod_);
        data[3] = abi.encodeWithSignature("setInterestRate(uint256)",       newInterestRate_);
        data[4] = abi.encodeWithSignature("setPaymentInterval(uint256)",    newPaymentInterval_);
        data[5] = abi.encodeWithSignature("increasePrincipal(uint256)",     principalIncrease_);

        // Executing refinance
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        uint256 currentCollateral = loan.collateral();

        if (newCollateralRequired_ > currentCollateral) {
            token.mint(address(loan), newCollateralRequired_ - currentCollateral);
            loan.postCollateral(0);
        }

        token.mint(address(loan), principalIncrease_);

        uint256 expectedRefinanceInterest = loan.getRefinanceInterest(block.timestamp);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.collateralRequired(), newCollateralRequired_);
        assertEq(loan.endingPrincipal(),    newEndingPrincipal_);
        assertEq(loan.gracePeriod(),        newGracePeriod_);
        assertEq(loan.interestRate(),       newInterestRate_);
        assertEq(loan.paymentInterval(),    newPaymentInterval_);
        assertEq(loan.principal(),          currentPrincipal + principalIncrease_);
        assertEq(loan.refinanceInterest(),  expectedRefinanceInterest);
    }

}

contract RefinanceCollateralRequiredTests is TestBase {

    function test_refinance_collateralRequired(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newCollateralRequired_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        newCollateralRequired_ = constrictToRange(newCollateralRequired_, 0,               MAX_TOKEN_AMOUNT);
        deadline_              = constrictToRange(deadline_,              block.timestamp, type(uint256).max);

        assertEq(loan.collateralRequired(), collateralRequired_);

        bytes[] memory data = _encodeWithSignatureAndUint("setCollateralRequired(uint256)", newCollateralRequired_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        uint256 requiredCollateral = loan.__getCollateralRequiredFor(
            loan.principal(),
            loan.drawableFunds(),
            loan.principalRequested(),
            newCollateralRequired_
        );

        uint256 currentCollateral = loan.collateral();

        if (requiredCollateral > currentCollateral) {
            vm.prank(address(lender));
            vm.expectRevert("ML:ANT:INSUFFICIENT_COLLATERAL");
            loan.acceptNewTerms(address(refinancer), deadline_, data);

            token.mint(address(loan), requiredCollateral - currentCollateral);
            loan.postCollateral(0);
        }

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.collateralRequired(), newCollateralRequired_);

        if (requiredCollateral < currentCollateral) {
            // Some amount of collateral should've been freed
            vm.prank(borrower);
            loan.removeCollateral(currentCollateral - requiredCollateral, borrower);
        }
    }

}

contract RefinanceDeadlineTests is TestBase {

    // Using payments interval since it's a rather easy refinance with no need to handle principal/collateral assets.
    function test_refinance_afterDeadline(
        uint256 paymentInterval_,
        uint256 newPaymentInterval_,
        uint256 deadline_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    1 days, MAX_TIME / 2);
        newPaymentInterval_ = constrictToRange(newPaymentInterval_, 1 days, MAX_TIME);

        setUpOngoingLoan(1e18, 0, 0, 12 hours, 1, paymentInterval_, 2);

        assertEq(loan.paymentInterval(), paymentInterval_);

        deadline_ = constrictToRange(deadline_, block.timestamp, block.timestamp + MAX_TIME);

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", newPaymentInterval_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.warp(deadline_ + 1);

        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:EXPIRED_COMMITMENT");
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        vm.warp(deadline_);

        // Success
        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.paymentInterval(), newPaymentInterval_);
    }

    function test_refinance_differentDeadline(
        uint256 paymentInterval_,
        uint256 newPaymentInterval_,
        uint256 deadline_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    1 days, MAX_TIME / 2);
        newPaymentInterval_ = constrictToRange(newPaymentInterval_, 1 days, MAX_TIME);

        setUpOngoingLoan(1e18, 0, 0, 12 hours, 1, paymentInterval_, 2);

        deadline_ = constrictToRange(deadline_, block.timestamp, block.timestamp + MAX_TIME);

        assertEq(loan.paymentInterval(), paymentInterval_);

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", newPaymentInterval_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        loan.acceptNewTerms(address(refinancer), deadline_ - 1, data);

        // Success
        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.paymentInterval(), newPaymentInterval_);
    }

}

contract RefinanceEndingPrincipalTests is TestBase {

    function test_refinance_endingPrincipal_interestOnlyToAmortized(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newEndingPrincipal_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);  // Boundary increase so principal portion on 'paymentBreakdown' is always greater than 0
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            principalRequested_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        newEndingPrincipal_ = constrictToRange(newEndingPrincipal_, 0,               loan.principalRequested() - 1);
        deadline_           = constrictToRange(deadline_,           block.timestamp, type(uint256).max);

        // Current ending principal is requested amount
        assertEq(loan.endingPrincipal(), loan.principalRequested());

        ( uint256 principalPortion , , ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion, 0);

        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.endingPrincipal(), newEndingPrincipal_);

        ( principalPortion , , ) = loan.getNextPaymentBreakdown();

        assertTrue(principalPortion > 0);
    }

    function test_refinance_endingPrincipal_amortizedToInterestOnly(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);  // Boundary increase so principal portion on 'paymentBreakdown' is always greater than 0
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_ - 1);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        // Current ending principal is requested amount
        assertTrue(loan.endingPrincipal() < loan.principalRequested());

        ( uint256 principalPortion, , ) = loan.getNextPaymentBreakdown();

        assertTrue(principalPortion > 0);

        // Propose Refinance
        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", loan.principal());

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.endingPrincipal(), loan.principal());

        ( principalPortion, , ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion, 0);
    }

    function test_refinance_endingPrincipal_failLargerThanPrincipal(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, 1,        MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,        MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,        principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours, MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,        MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,        MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,        MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        uint256 newEndingPrincipal_ = loan.principal() + 1;

        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:FAILED");
        loan.acceptNewTerms(address(refinancer), deadline_, data);
    }

}

contract RefinanceFeeTests is TestBase {

    function test_refinance_closingRate(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newClosingRate_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        newClosingRate_ = constrictToRange(newClosingRate_, 0,               MAX_RATE);
        deadline_       = constrictToRange(deadline_,       block.timestamp, type(uint256).max);

        assertEq(loan.closingRate(), 0.1e18);

        bytes[] memory data = _encodeWithSignatureAndUint("setClosingRate(uint256)", newClosingRate_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.closingRate(), newClosingRate_);
    }

    function test_refinance_lateFeeRate(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newLateFeeRate_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        newLateFeeRate_ = constrictToRange(newLateFeeRate_, 0,               MAX_RATE);
        deadline_       = constrictToRange(deadline_,       block.timestamp, type(uint256).max);

        assertEq(loan.lateFeeRate(), 0.15e18);

        bytes[] memory data = _encodeWithSignatureAndUint("setLateFeeRate(uint256)", newLateFeeRate_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.lateFeeRate(), newLateFeeRate_);
    }

    function test_refinance_lateInterestPremiumRate(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newLateInterestPremiumRate_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        newLateInterestPremiumRate_ = constrictToRange(newLateInterestPremiumRate_, 0,               MAX_RATE);
        deadline_                   = constrictToRange(deadline_,                   block.timestamp, type(uint256).max);

        assertEq(loan.lateInterestPremiumRate(), 0);

        bytes[] memory data = _encodeWithSignatureAndUint("setLateInterestPremiumRate(uint256)", newLateInterestPremiumRate_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.lateInterestPremiumRate(), newLateInterestPremiumRate_);
    }

}

contract RefinanceGracePeriodTests is TestBase {

    function test_refinance_gracePeriod(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newGracePeriod_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, 1,        MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,        MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,        principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours, MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,        MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,        MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,        MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        newGracePeriod_ = constrictToRange(newGracePeriod_, 0, MAX_TIME);

        assertEq(loan.gracePeriod(), gracePeriod_);

        bytes[] memory data = _encodeWithSignatureAndUint("setGracePeriod(uint256)", newGracePeriod_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.gracePeriod(), newGracePeriod_);
    }

}

contract RefinanceInterestRateTests is TestBase {

    function test_refinance_interestRate(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newInterestRate_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE / 2);  // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        newInterestRate_ = constrictToRange(newInterestRate_, 0,               MAX_RATE);
        deadline_        = constrictToRange(deadline_,        block.timestamp, type(uint256).max);

        assertEq(loan.interestRate(), interestRate_);

        bytes[] memory data = _encodeWithSignatureAndUint("setInterestRate(uint256)", newInterestRate_);

        // The new interest rate will be applied retroactively until the last payment made.
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.interestRate(), newInterestRate_);
    }

}

contract RefinanceInterestTests is TestUtils {

    // Loan Boundaries
    uint256 internal constant MAX_PAYMENTS     = 20;
    uint256 internal constant MAX_RATE         = 1e6;              // 100 %
    uint256 internal constant MAX_TIME         = 90 days;          // Assumed reasonable upper limit for payment intervals and grace periods
    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant MIN_TOKEN_AMOUNT = 10 ** 6;          // Needed so payments don't round down to zero
    uint256 internal constant USD              = 1e6;
    uint256 internal constant WAD              = 1e18;

    ConstructableMapleLoan internal loan;
    MockERC20              internal token;
    MockFactory            internal factory;
    MockFeeManager         internal feeManager;
    MockGlobals            internal globals;
    MockLoanManager        internal lender;
    MapleRefinancer        internal refinancer;

    address internal borrower = address(new Address());
    address internal governor = address(new Address());

    function setUp() external {
        feeManager = new MockFeeManager();
        globals    = new MockGlobals(address(governor));
        lender     = new MockLoanManager();
        refinancer = new MapleRefinancer();
        token      = new MockERC20("Test", "TST", 0);

        factory = new MockFactory(address(globals));

        lender.__setFundsAsset(address(token));

        globals.setValidBorrower(borrower,        true);
        globals.setValidPoolAsset(address(token), true);

        globals.__setIsInstanceOf(true);
    }

    function test_acceptNewTerms_makePayment_withRefinanceInterest() external {
        uint256 start = block.timestamp;

        _setUpAndDrawdownLoan({
            principalRequested_: 1_000_000 * USD,
            collateralRequired_: 0,
            endingPrincipal_:    1_000_000 * USD,
            gracePeriod_:        10 days,
            interestRate_:       0.1e6,
            paymentInterval_:    30 days,
            paymentsRemaining_ : 3
        });

        assertEq(loan.principalRequested(), 1_000_000 * USD);
        assertEq(loan.collateralRequired(), 0);
        assertEq(loan.endingPrincipal(),    1_000_000 * USD);
        assertEq(loan.gracePeriod(),        10 days);
        assertEq(loan.interestRate(),       0.1e6);
        assertEq(loan.paymentInterval(),    30 days);
        assertEq(loan.nextPaymentDueDate(), start + 30 days);
        assertEq(loan.paymentsRemaining(),  3);

        // Warp to when payment is due
        vm.warp(loan.nextPaymentDueDate());

        // Check details for upcoming payment #1
        ( , uint256 interestPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(token.balanceOf(address(lender)), 0);

        // Make payment #1
        token.mint(address(loan), interestPortion);  // Interest only payment
        loan.makePayment(0);

        assertEq(interestPortion, 8_219_178_082);
        assertEq(token.balanceOf(address(lender)), interestPortion);

        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeWithSignature("setInterestRate(uint256)",      0.12e6);
        data[1] = abi.encodeWithSignature("setPaymentInterval(uint256)",   60 days);
        data[2] = abi.encodeWithSignature("increasePrincipal(uint256)",    1_000_000 * USD);  // Ending principal stays the same so switches to amortized
        data[3] = abi.encodeWithSignature("setPaymentsRemaining(uint256)", 3);  // Ending principal stays the same so switches to amortized

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), start + 40 days, data);

        vm.warp(start + 40 days);  // Warp 10 days into next payment cycle

        token.mint(address(loan), 1_000_000 * USD);

        // Assert that there is no refinanceInterest until acceptNewTerms
        assertEq(loan.refinanceInterest(), 0);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), start + 40 days, data);

        assertEq(loan.principalRequested(), 2_000_000 * USD);
        assertEq(loan.collateralRequired(), 0);
        assertEq(loan.endingPrincipal(),    1_000_000 * USD);
        assertEq(loan.gracePeriod(),        10 days);
        assertEq(loan.interestRate(),       0.12e6);
        assertEq(loan.paymentInterval(),    60 days);
        assertEq(loan.nextPaymentDueDate(), start + 40 days + 60 days);  // New payment interval from refinance date
        assertEq(loan.paymentsRemaining(),  3);

        assertEq(loan.refinanceInterest(), 2_739_726027);                                          // 1m * 10% * 10 / 365
        assertEq(loan.refinanceInterest(), 1_000_000 * USD * 1000 * 10 days / 365 days / 10_000);  // 1m * 10% * 10 / 365
    }

    function _setUpAndDrawdownLoan(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_
    )
        internal
    {
        globals.setValidCollateralAsset(address(token), true);

        address[2] memory assets      = [address(token), address(token)];
        uint256[3] memory amounts     = [collateralRequired_, principalRequested_, endingPrincipal_];
        uint256[3] memory termDetails = [gracePeriod_, paymentInterval_, paymentsRemaining_];
        uint256[4] memory rates       = [interestRate_, uint256(0.10e18), uint256(0.15e18), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        vm.prank(address(factory));
        loan = new ConstructableMapleLoan(address(factory), borrower, address(lender), address(feeManager), assets, termDetails, amounts, rates, fees);

        vm.prank(borrower);
        loan.acceptLoanTerms();

        token.mint(address(loan), principalRequested_);

        vm.prank(address(lender));
        loan.fundLoan();

        token.mint(address(loan), collateralRequired_);
        loan.postCollateral(0);

        vm.prank(borrower);
        loan.drawdownFunds(principalRequested_, address(1));
    }

    function _encodeWithSignatureAndUint(string memory signature_, uint256 arg_) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature_, arg_);
    }

}

contract RefinancePaymentIntervalTests is TestBase {

    function test_refinance_paymentInterval_zeroAmount() external {
        setUpOngoingLoan(MIN_TOKEN_AMOUNT, 0, MIN_TOKEN_AMOUNT, 12 hours, 0.1e6, 30 days, 6);

        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", 0);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, data);

        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:FAILED");
        loan.acceptNewTerms(address(refinancer), deadline, data);

        data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", 1);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline, data);
    }

    function test_refinance_paymentInterval(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newPaymentInterval_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1 days,           MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);
        deadline_           = constrictToRange(deadline_,           block.timestamp,  type(uint256).max);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        newPaymentInterval_ = constrictToRange(newPaymentInterval_, 1 days,          MAX_TIME);
        deadline_           = constrictToRange(deadline_,           block.timestamp, type(uint256).max);

        assertEq(loan.paymentInterval(), paymentInterval_);

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", newPaymentInterval_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.paymentInterval(), newPaymentInterval_);
    }

}

contract RefinancePaymentsRemainingTests is TestBase {

    function test_refinance_paymentRemaining_zeroAmount() external {
        setUpOngoingLoan(MIN_TOKEN_AMOUNT, 0, MIN_TOKEN_AMOUNT, 12 hours, 0.1e6, 30 days, 6);

        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentsRemaining(uint256)", 0);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, data);

        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:FAILED");
        loan.acceptNewTerms(address(refinancer), deadline, data);

        data = _encodeWithSignatureAndUint("setPaymentsRemaining(uint256)", 1);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline, data);
    }

    function test_refinance_paymentRemaining(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newPaymentsRemaining_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1 days,           MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        newPaymentsRemaining_ = constrictToRange(newPaymentsRemaining_, 1, 90);

        assertEq(loan.paymentsRemaining(), paymentsRemaining_ - 1);  // We've paid one during setUpOngoingLoan

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentsRemaining(uint256)", newPaymentsRemaining_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        assertEq(loan.paymentsRemaining(), newPaymentsRemaining_);
    }

}

contract RefinancePrincipalRequestedTests is TestBase {

    // Saving as storage variables to avoid stack too deep
    uint256 initialDrawableFunds;
    uint256 initialPrincipal;

    function test_refinance_increasePrincipalRequested(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 principalIncrease_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT - MIN_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);
        deadline_           = constrictToRange(deadline_,           block.timestamp,  type(uint256).max);  // Hardcoding deadline to not cause stack too deep

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        principalIncrease_ = constrictToRange(principalIncrease_, 1, MIN_TOKEN_AMOUNT);  // If we increase too much we get overflows

        assertEq(loan.principalRequested(), principalRequested_);

        bytes[] memory data = _encodeWithSignatureAndUint("increasePrincipal(uint256)", principalIncrease_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp, data);

        // Increasing the amount without sending it first should fail
        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:FAILED");
        loan.acceptNewTerms(address(refinancer), block.timestamp, data);

        {
            // Since the collateral rate has remained the same, we need to also send more collateral
            uint256 extraCollateral = collateralRequired_ * principalIncrease_ / principalRequested_;

            token.mint(address(loan), extraCollateral);
            loan.postCollateral(0);
        }

        token.mint(address(loan), principalIncrease_);

        initialPrincipal     = loan.principal();
        initialDrawableFunds = loan.drawableFunds();

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), block.timestamp, data);

        assertEq(loan.principalRequested(), principalRequested_  + principalIncrease_);
        assertEq(loan.principal(),          initialPrincipal     + principalIncrease_);
        assertEq(loan.drawableFunds(),      initialDrawableFunds + principalIncrease_);
    }

    function test_refinance_increasePrincipalRequestedWithInsufficientFunds(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 principalIncrease_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT - MIN_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(
            principalRequested_,
            collateralRequired_,
            endingPrincipal_,
            gracePeriod_,
            interestRate_,
            paymentInterval_,
            paymentsRemaining_
        );

        principalIncrease_ = constrictToRange(principalIncrease_, 1,               MIN_TOKEN_AMOUNT);  // If we increase too much we get overflows
        deadline_          = constrictToRange(deadline_,          block.timestamp, type(uint256).max);

        assertEq(loan.principalRequested(), principalRequested_);

        bytes[] memory data = _encodeWithSignatureAndUint("increasePrincipal(uint256)", principalIncrease_);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        // Increasing the amount without sending it first should fail
        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:FAILED");
        loan.acceptNewTerms(address(refinancer), deadline_, data);

        // Since the collateral rate has remained the same, we need to also send more collateral
        uint256 extraCollateral = collateralRequired_ * principalIncrease_ / principalRequested_;

        token.mint(address(loan), extraCollateral);
        loan.postCollateral(0);

        // Sending 1 too little, causes revert
        token.mint(address(loan), principalIncrease_ - 1);

        vm.prank(address(lender));
        vm.expectRevert("ML:ANT:FAILED");
        loan.acceptNewTerms(address(refinancer), deadline_, data);
    }

}

// Not Using TestBase due to the need to use Mocks for the
contract RefinancingFeesTerms is TestUtils {

    address internal POOL_DELEGATE = address(new Address());
    address internal TREASURY      = address(new Address());

    // Loan Boundaries
    uint256 internal constant MAX_FEE_RATE     = 100_0000;         // 100 %
    uint256 internal constant MAX_PAYMENTS     = 20;
    uint256 internal constant MAX_RATE         = 1e6;              // 100 %
    uint256 internal constant MAX_TIME         = 90 days;          // Assumed reasonable upper limit for payment intervals and grace periods
    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant MIN_TOKEN_AMOUNT = 10 ** 6;          // Needed so payments don't round down to zero

    ConstructableMapleLoan internal loan;
    MapleLoanFeeManager    internal feeManager;
    MockERC20              internal token;
    MockFactory            internal factory;
    MockGlobals            internal globals;
    MockLoanManager        internal lender;
    MockPoolManager        internal poolManager;
    MapleRefinancer        internal refinancer;

    address internal borrower = address(new Address());
    address internal governor = address(new Address());

    function setUp() public virtual {
        lender      = new MockLoanManager();
        globals     = new MockGlobals(governor);
        poolManager = new MockPoolManager(address(POOL_DELEGATE));
        refinancer  = new MapleRefinancer();

        factory    = new MockFactory(address(globals));
        feeManager = new MapleLoanFeeManager(address(globals));
        token      = new MockERC20("Test", "TST", 0);

        lender.__setPoolManager(address(poolManager));  // Set so correct PD address is used.
        lender.__setFundsAsset(address(token));

        globals.setValidBorrower(borrower,        true);
        globals.setValidPoolAsset(address(token), true);
        globals.setMapleTreasury(TREASURY);

        globals.__setIsInstanceOf(true);
    }

    function setUpOngoingLoan(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_
    )
        internal
    {
        MockERC20 collateralToken = new MockERC20("Collateral", "COL", 0);

        globals.setValidCollateralAsset(address(collateralToken), true);

        address[2] memory assets      = [address(collateralToken), address(token)];
        uint256[3] memory amounts     = [collateralRequired_, principalRequested_, endingPrincipal_];
        uint256[3] memory termDetails = [gracePeriod_, paymentInterval_, paymentsRemaining_];
        uint256[4] memory rates       = [interestRate_, uint256(0.10e18), uint256(0.15e18), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        vm.prank(address(factory));
        loan = new ConstructableMapleLoan(address(factory), borrower, address(lender), address(feeManager), assets, termDetails, amounts, rates, fees);

        vm.prank(borrower);
        loan.acceptLoanTerms();

        token.mint(address(loan), principalRequested_);

        vm.prank(address(lender));
        loan.fundLoan();

        collateralToken.mint(address(loan), collateralRequired_);
        loan.postCollateral(0);

        vm.prank(borrower);
        loan.drawdownFunds(principalRequested_, borrower);

        // Warp to when payment is due
        vm.warp(loan.nextPaymentDueDate());

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion, ) = loan.getNextPaymentBreakdown();

        // Make payment #1
        token.mint(address(loan), principalPortion + interestPortion);
        loan.makePayment(0);
    }

    function test_refinance_updateRefinanceServiceFees() external {
        setUpOngoingLoan(1_000_000e18, 50_000e18, 1_000_000e18, 10 days, 0.01e6, 365 days, 6);

        // Set Globals values
        globals.setPlatformServiceFeeRate(address(poolManager), 1_0000);

        // Prank as loan to update delegate service fee to be non-zero
        vm.prank(address(loan));
        feeManager.updateDelegateFeeTerms(0, 10_000);

        // Warp to 1/10 of payment period
        vm.warp(block.timestamp + 365 days / 10);
        uint256 deadline_ = type(uint256).max;

        // Using dummy refinance call
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setPaymentsRemaining(uint256)", 5);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, calls);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, calls);

        assertEq(feeManager.platformRefinanceServiceFee(address(loan)), 1_000_000e18 * 0.01 / 10); // Saved fee is 1/10 of annual refinance fee
        assertEq(feeManager.delegateRefinanceServiceFee(address(loan)), 10_000 / 10);
    }

     function test_refinance_updateRefinanceServiceFeesOnDoubleRefinance() external {
        setUpOngoingLoan(1_000_000e18, 50_000e18, 1_000_000e18, 10 days, 0.01e6, 365 days, 6);

        // Set Globals values
        globals.setPlatformServiceFeeRate(address(poolManager), 1_0000);

        // Prank as loan to update delegate service fee to be non-zero
        vm.prank(address(loan));
        feeManager.updateDelegateFeeTerms(0, 10_000);

        // Warp to 1/10 of payment period
        vm.warp(block.timestamp + 365 days / 10);
        uint256 deadline_ = type(uint256).max;

        // Using dummy refinance call
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setPaymentsRemaining(uint256)", 5);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, calls);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, calls);

        assertEq(feeManager.platformRefinanceServiceFee(address(loan)), 1_000_000e18 * 0.01 / 10); // Saved fee is 1/10 of annual refinance fee
        assertEq(feeManager.delegateRefinanceServiceFee(address(loan)), 10_000 / 10);

        // Warp to 1/10 of payment period
        vm.warp(block.timestamp + 365 days / 10);

        // Refinance again, without making any payment
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, calls);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, calls);

        // Now assert that fees include 2 periods
        assertEq(feeManager.platformRefinanceServiceFee(address(loan)), 1_000_000e18 * (0.01 / 10 * 2)); // Saved fee is 1/10 of annual refinance fee
        assertEq(feeManager.delegateRefinanceServiceFee(address(loan)), 10_000 * 2 / 10);
    }

    function testFuzz_refinance_pdOriginationFeeTransferFail(uint256 newDelegateOriginationFee_) external {
        setUpOngoingLoan(1_000_000e18, 50_000e18, 1_000_000e18, 10 days, 0.01e6, 30 days, 6);

        uint256 deadline_ = type(uint256).max;

        newDelegateOriginationFee_ = constrictToRange(newDelegateOriginationFee_, 1, MAX_TOKEN_AMOUNT);

        // Initial values are zeroed
        assertEq(feeManager.delegateOriginationFee(address(loan)), 0);
        assertEq(feeManager.delegateServiceFee(address(loan)),     0);

        bytes[] memory calls = new bytes[](1);

        calls[0] = abi.encodeWithSignature("updateDelegateFeeTerms(uint256,uint256)", newDelegateOriginationFee_, 100e18);

        token.mint(address(loan), newDelegateOriginationFee_ - 1);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, calls);

        vm.prank(address(lender));
        vm.expectRevert("MLFM:POF:PD_TRANSFER");
        loan.acceptNewTerms(address(refinancer), deadline_, calls);
    }

    function testFuzz_refinance_treasuryOriginationFeeTransferFail(
        uint256 newDelegateOriginationFee_,
        uint256 newPlatformOriginationFeeRate_
    )
        external
    {
        setUpOngoingLoan(1_000_000e18, 50_000e18, 1_000_000e18, 10 days, 0.01e6, 30 days, 6);

        uint256 deadline_ = type(uint256).max;

        newDelegateOriginationFee_     = constrictToRange(newDelegateOriginationFee_,     1, MAX_TOKEN_AMOUNT);
        newPlatformOriginationFeeRate_ = constrictToRange(newPlatformOriginationFeeRate_, 1, MAX_FEE_RATE);

        globals.setPlatformOriginationFeeRate(address(poolManager), newPlatformOriginationFeeRate_);

        // Initial values are zeroed
        assertEq(feeManager.delegateOriginationFee(address(loan)), 0);
        assertEq(feeManager.delegateServiceFee(address(loan)),     0);

        bytes[] memory calls = new bytes[](1);

        newDelegateOriginationFee_ = 0;

        calls[0] = abi.encodeWithSignature("updateDelegateFeeTerms(uint256,uint256)", newDelegateOriginationFee_, 100e18);

        // Annualized over course of remaining loan term (150 days since payment was made).
        uint256 platformOriginationFee_ = 1_000_000e18 * newPlatformOriginationFeeRate_ * 150 days / 365 days / 1e18;

        token.mint(address(loan), platformOriginationFee_ + newDelegateOriginationFee_ - 1);

        vm.prank(address(borrower));
        loan.proposeNewTerms(address(refinancer), deadline_, calls);

        vm.prank(address(lender));
        vm.expectRevert("MLFM:POF:TREASURY_TRANSFER");
        loan.acceptNewTerms(address(refinancer), deadline_, calls);
    }

    function testFuzz_refinance_payOriginationFees(uint256 newDelegateOriginationFee_, uint256 newPlatformOriginationFeeRate_) external {
        setUpOngoingLoan(1_000_000e18, 50_000e18, 1_000_000e18, 10 days, 0.01e6, 30 days, 6);

        uint256 deadline_ = type(uint256).max;

        newDelegateOriginationFee_     = constrictToRange(newDelegateOriginationFee_,     1, MAX_TOKEN_AMOUNT);
        newPlatformOriginationFeeRate_ = constrictToRange(newPlatformOriginationFeeRate_, 1, MAX_FEE_RATE);

        // Initial values are zeroed
        assertEq(feeManager.delegateOriginationFee(address(loan)), 0);
        assertEq(feeManager.delegateServiceFee(address(loan)),     0);

        globals.setPlatformOriginationFeeRate(address(poolManager), newPlatformOriginationFeeRate_);

        bytes[] memory calls = new bytes[](1);

        calls[0] = abi.encodeWithSignature("updateDelegateFeeTerms(uint256,uint256)", newDelegateOriginationFee_, 100e18);

        // Annualized over course of remaining loan term (150 days since payment was made)
        uint256 platformOriginationFee_ = 1_000_000e18 * newPlatformOriginationFeeRate_ * 150 days / 365 days / 100_0000;

        token.mint(address(loan), platformOriginationFee_ + newDelegateOriginationFee_);

        // Funds need to be returned through this function, otherwise drawableFunds won't be increased.
        loan.returnFunds(0);

        assertEq(token.balanceOf(POOL_DELEGATE), 0);
        assertEq(token.balanceOf(TREASURY),      0);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, calls);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, calls);

        // Fees were paid during loan origination
        assertEq(token.balanceOf(POOL_DELEGATE), newDelegateOriginationFee_);
        assertEq(token.balanceOf(TREASURY),      platformOriginationFee_);

        // Fees were updated on FeeManager
        assertEq(feeManager.delegateOriginationFee(address(loan)), newDelegateOriginationFee_);
        assertEq(feeManager.delegateServiceFee(address(loan)),     100e18);
    }

    function testFuzz_refinance_updatesPlatformServiceFees(uint256 newPlatformServiceFeeRate_) external {
        setUpOngoingLoan(1_000_000e18, 50_000e18, 1_000_000e18, 10 days, 0.01e6, 30 days, 6);

        newPlatformServiceFeeRate_ = constrictToRange(newPlatformServiceFeeRate_, 1, MAX_FEE_RATE);

        globals.setPlatformServiceFeeRate(address(poolManager), newPlatformServiceFeeRate_);

        // Initial values are zeroed
        assertEq(feeManager.platformServiceFee(address(loan)), 0);

        uint256 deadline_ = type(uint256).max;

        // Using dummy refinance call
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("updateDelegateFeeTerms(uint256,uint256)", 0, 0);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, calls);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, calls);

        assertEq(feeManager.platformServiceFee(address(loan)), 1_000_000e18 * newPlatformServiceFeeRate_ * 30 days / 365 days / 100_0000);
    }

    function testFuzz_refinance_updateFeeTerms(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newOriginationFee_,
        uint256 newDelegateServiceFee_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        12 hours,         MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1 days,           MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        newOriginationFee_     = constrictToRange(newOriginationFee_,     1, MAX_TOKEN_AMOUNT);
        newDelegateServiceFee_ = constrictToRange(newDelegateServiceFee_, 1, MAX_TOKEN_AMOUNT);

        // Initial values are zeroed
        assertEq(feeManager.delegateOriginationFee(address(loan)), 0);
        assertEq(feeManager.delegateServiceFee(address(loan)),     0);

        bytes[] memory calls = new bytes[](1);

        calls[0] = abi.encodeWithSignature("updateDelegateFeeTerms(uint256,uint256)", newOriginationFee_, newDelegateServiceFee_);

        // Minting origination fee because the fees are paid after the refinance calls, so the new fees are in effect.
        token.mint(address(loan), newOriginationFee_);
        loan.returnFunds(0);

        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline_, calls);

        vm.prank(address(lender));
        loan.acceptNewTerms(address(refinancer), deadline_, calls);

        assertEq(feeManager.delegateOriginationFee(address(loan)), newOriginationFee_);
        assertEq(feeManager.delegateServiceFee(address(loan)),     newDelegateServiceFee_);
    }

}
