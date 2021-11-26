// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { TestUtils, StateManipulations } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }                     from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { Refinancer } from "../Refinancer.sol";

import { ConstructableMapleLoan, LenderMock } from "./mocks/Mocks.sol";

// Helper contract with common functionality
contract BaseRefinanceTest is TestUtils, StateManipulations {

    // Loan Boundaries
    uint256 internal constant MAX_RATE         = 1.00 ether;       // 100 %
    uint256 internal constant MAX_TIME         = 90 days;          // Assumed reasonable upper limit for payment intervals and grace periods
    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant MIN_TOKEN_AMOUNT = 10 ** 6;          // Needed so payments don't round down to zero
    uint256 internal constant MAX_PAYMENTS     = 20;

    ConstructableMapleLoan loan;
    LenderMock             lender;
    MockERC20              token;
    Refinancer             refinancer;

    function setUp() external {
        lender     = new LenderMock();
        refinancer = new Refinancer();
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
        token = new MockERC20("Test", "TST", 0);

        address[2] memory assets      = [address(token), address(token)];
        uint256[3] memory requests    = [collateralRequired_, principalRequested_, endingPrincipal_];
        uint256[3] memory termDetails = [gracePeriod_, paymentInterval_, paymentsRemaining_];
        uint256[4] memory rates       = [interestRate_, uint256(0.10 ether), uint256(0.15 ether), uint256(0)];

        loan = new ConstructableMapleLoan(address(this), assets, termDetails, requests, rates);

        token.mint(address(this), principalRequested_);
        token.approve(address(loan), principalRequested_);
        loan.fundLoan(address(lender), principalRequested_);

        token.mint(address(loan), collateralRequired_);
        loan.postCollateral(0);

        loan.drawdownFunds(principalRequested_, address(1));

        // Warp to when payment is due
        hevm.warp(loan.nextPaymentDueDate());

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion ) = loan.getNextPaymentBreakdown();

        // Make payment #1
        token.mint(address(loan), principalPortion + interestPortion);
        loan.makePayment(0);
    }

    function _encodeWithSignatureAndUint(string memory signature_, uint256 arg_) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature_, arg_);
    }

}

// TODO: Add permissioning testing for propose and accept terms functions

contract RefinancerEndingPrincipalTest is BaseRefinanceTest {

    function test_refinance_endingPrincipal_interestOnlyToAmortized(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newEndingPrincipal_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);  // Boundary increase so principal portion on 'paymentBreakdown' is always greater than 0
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        gracePeriod_        = constrictToRange(gracePeriod_,        0,                MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, principalRequested_, gracePeriod_,  interestRate_, paymentInterval_, paymentsRemaining_);

        newEndingPrincipal_ = constrictToRange(newEndingPrincipal_, 0, loan.principalRequested() - 1);

        // Current ending principal is requested amount
        assertEq(loan.endingPrincipal(), loan.principalRequested());

        ( uint256 principalPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion, 0);

        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.endingPrincipal(), newEndingPrincipal_);

        ( principalPortion, ) = loan.getNextPaymentBreakdown();

        assertTrue(principalPortion > 0);
    }

    function test_refinance_endingPrincipal_amortizedToInterestOnly(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);         // Boundary increase so principal portion on 'paymentBreakdown' is always greater than 0
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_ - 1);
        gracePeriod_        = constrictToRange(gracePeriod_,        0,                MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        uint256 newEndingPrincipal_ = loan.principal();

        // Current ending principal is requested amount
        assertTrue(loan.endingPrincipal() < loan.principalRequested());

        ( uint256 principalPortion, ) = loan.getNextPaymentBreakdown();

        assertTrue(principalPortion > 0);

        // Propose Refinance
        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.endingPrincipal(), newEndingPrincipal_);

        ( principalPortion, ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion, 0);
    }

    function test_refinance_endingPrincipal_failLargerThanPrincipal(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0, MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0, principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        0, MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0, MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1, MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3, MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        uint256 newEndingPrincipal_ = loan.principal() + 1;

        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        loan.proposeNewTerms(address(refinancer), data);

        assertTrue(!lender.try_loan_acceptNewTerms(address(loan), address(refinancer), data, 0));
    }

}

contract RefinancerGracePeriodTest is BaseRefinanceTest {

    function test_refinance_gracePeriod(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newGracePeriod_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100, MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,   MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,   MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,   MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newGracePeriod_ = constrictToRange(newGracePeriod_, 0, MAX_TIME);

        assertEq(loan.gracePeriod(), gracePeriod_);

        bytes[] memory data = _encodeWithSignatureAndUint("setGracePeriod(uint256)", newGracePeriod_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.gracePeriod(), newGracePeriod_);
    }

}

contract RefinancerInterestRateTest is BaseRefinanceTest {

    function test_refinance_interestRate(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newInterestRate_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE / 2);         // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newInterestRate_ = constrictToRange(newInterestRate_, 0, MAX_RATE);

        assertEq(loan.interestRate(), interestRate_);

        bytes[] memory data = _encodeWithSignatureAndUint("setInterestRate(uint256)", newInterestRate_);

        // The new interest rate will be applied retroactively until the last payment made.
        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.interestRate(), newInterestRate_);
    }

}

contract RefinancerPaymentRemaining is BaseRefinanceTest {

    function test_refinance_paymentRemaining(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newPaymentsRemaining_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newPaymentsRemaining_ = constrictToRange(newPaymentsRemaining_, 0, 90);

        assertEq(loan.paymentsRemaining(), paymentsRemaining_ - 1);  // We've paid one during setUpOngoingLoan

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentsRemaining(uint256)", newPaymentsRemaining_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.paymentsRemaining(), newPaymentsRemaining_);
    }

}

contract RefinancerPaymentIntervalTest is BaseRefinanceTest {

    function test_refinance_paymentInterval(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newPaymentInterval_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newPaymentInterval_ = constrictToRange(newPaymentInterval_, 0, MAX_TIME);

        assertEq(loan.paymentInterval(), paymentInterval_);

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", newPaymentInterval_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.paymentInterval(), newPaymentInterval_);
    }

}

contract RefinancerFeeTests is BaseRefinanceTest {

    function test_refinance_earlyFeeRate(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newEarlyFeeRate_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newEarlyFeeRate_ = constrictToRange(newEarlyFeeRate_, 0, MAX_RATE);

        assertEq(loan.earlyFeeRate(), 0.1 ether);

        bytes[] memory data = _encodeWithSignatureAndUint("setEarlyFeeRate(uint256)", newEarlyFeeRate_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.earlyFeeRate(), newEarlyFeeRate_);
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
        uint256 newLateFeeRate_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);             // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newLateFeeRate_ = constrictToRange(newLateFeeRate_, 0, MAX_RATE);

        assertEq(loan.lateFeeRate(), 0.15 ether);

        bytes[] memory data = _encodeWithSignatureAndUint("setLateFeeRate(uint256)", newLateFeeRate_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.lateFeeRate(), newLateFeeRate_);
    }

    function test_refinance_lateInterestPremium(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newLateInterestPremium_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);             // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newLateInterestPremium_ = constrictToRange(newLateInterestPremium_, 0, MAX_RATE);

        assertEq(loan.lateInterestPremium(), 0 ether);

        bytes[] memory data = _encodeWithSignatureAndUint("setLateInterestPremium(uint256)", newLateInterestPremium_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.lateInterestPremium(), newLateInterestPremium_);
    }

}

contract RefinanceCollateralRequiredTest is BaseRefinanceTest {

    function test_refinance_collateralRequired(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 newCollateralRequired_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);             // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newCollateralRequired_ = constrictToRange(newCollateralRequired_, 0, MAX_TOKEN_AMOUNT);

        assertEq(loan.collateralRequired(), collateralRequired_);

        bytes[] memory data = _encodeWithSignatureAndUint("setCollateralRequired(uint256)", newCollateralRequired_);

        loan.proposeNewTerms(address(refinancer), data);

        uint256 requiredCollateral = loan.getCollateralRequiredFor(loan.principal(), loan.drawableFunds(), loan.principalRequested(), newCollateralRequired_);
        uint256 currentCollateral  = loan.collateral();

        if (requiredCollateral > currentCollateral) {
            assertTrue(!lender.try_loan_acceptNewTerms(address(loan), address(refinancer), data, 0));

            token.mint(address(loan), requiredCollateral - currentCollateral);
            loan.postCollateral(0);
        }

        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.collateralRequired(), newCollateralRequired_);

        if (requiredCollateral < currentCollateral) {
            // Some amount of collateral should've been freed
            loan.removeCollateral(currentCollateral - requiredCollateral, address(this));
        }
    }

}

contract RefinancePrincipalRequestedTest is BaseRefinanceTest {

    function test_refinance_increasePrincipalRequested(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 principalIncrease_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT - MIN_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);                             // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        principalIncrease_ = constrictToRange(principalIncrease_, 1, MIN_TOKEN_AMOUNT);  // If we increase too much we get overflows

        assertEq(loan.principalRequested(), principalRequested_);

        uint256 initialPrincipal = loan.principal();
        uint256 initialDrawable  = loan.drawableFunds();

        bytes[] memory data = _encodeWithSignatureAndUint("increasePrincipal(uint256)", principalIncrease_);

        loan.proposeNewTerms(address(refinancer), data);

        // Increasing the amount without sending it first should fail
        assertTrue(!lender.try_loan_acceptNewTerms(address(loan), address(refinancer), data, 0));

        // Since the collateral rate has remained the same, we need to also send more collateral
        uint256 extraCollateral = collateralRequired_ * principalIncrease_ / principalRequested_;

        token.mint(address(loan), extraCollateral);
        loan.postCollateral(0);

        // Sending extra funds
        token.mint(address(loan), principalIncrease_);

        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.principalRequested(), principalRequested_ + principalIncrease_);
        assertEq(loan.principal(),          initialPrincipal + principalIncrease_);
        assertEq(loan.drawableFunds(),      initialDrawable + principalIncrease_);
    }

    function testFail_refinance_increasePrincipalRequested(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 principalIncrease_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT - MIN_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);                             // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        principalIncrease_ = constrictToRange(principalIncrease_, 1, MIN_TOKEN_AMOUNT);  // If we increase too much we get overflows

        assertEq(loan.principalRequested(), principalRequested_);

        bytes[] memory data = _encodeWithSignatureAndUint("increasePrincipal(uint256)", principalIncrease_);

        loan.proposeNewTerms(address(refinancer), data);

        // Increasing the amount without sending it first should fail
        assertTrue(!lender.try_loan_acceptNewTerms(address(loan), address(refinancer), data, 0));

        // Since the collateral rate has remained the same, we need to also send more collateral
        uint256 extraCollateral = collateralRequired_ * principalIncrease_ / principalRequested_;

        token.mint(address(loan), extraCollateral);
        loan.postCollateral(0);

        // Sending too much, causes revert
        token.mint(address(loan), principalIncrease_ + 1);

        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);
    }

    function test_refinance_decreasePrincipalRequested(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 principalDecrease_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);             // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        principalDecrease_ = constrictToRange(principalDecrease_, 1, loan.principal() - loan.endingPrincipal());

        assertEq(loan.principalRequested(), principalRequested_);

        uint256 initialPrincipal = loan.principal();

        bytes[] memory data = _encodeWithSignatureAndUint("decreasePrincipal(uint256)", principalDecrease_);

        loan.proposeNewTerms(address(refinancer), data);

        // Decreasing the amount without enough drawable funds will fail
        try lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0) { fail(); } catch { }

        token.mint(address(loan), principalDecrease_);
        loan.returnFunds(0);

        // Now we can accept terms
        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.principal(), initialPrincipal - principalDecrease_);
    }

}

contract RefinanceMultipleParameterTest is BaseRefinanceTest {

    function test_refinance_multipleParameters(
        uint256 principalRequested_,
        uint256 collateralRequired_,
        uint256 endingPrincipal_,
        uint256 gracePeriod_,
        uint256 interestRate_,
        uint256 paymentInterval_,
        uint256 paymentsRemaining_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT,         MAX_TOKEN_AMOUNT - MIN_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                        MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    principalRequested_ / 2, principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,                      MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       10_000,                   MAX_RATE / 2);                         // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    30 days,                  MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                        MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        // Asserting state
        assertEq(loan.collateralRequired(), collateralRequired_);
        assertEq(loan.endingPrincipal(), endingPrincipal_);
        assertEq(loan.gracePeriod(),     gracePeriod_);
        assertEq(loan.interestRate(),    interestRate_);
        assertEq(loan.paymentInterval(), paymentInterval_);
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
        loan.proposeNewTerms(address(refinancer), data);

        uint256 currentCollateral = loan.collateral();

        if (newCollateralRequired_ > currentCollateral) {
            token.mint(address(loan), newCollateralRequired_ - currentCollateral);
            loan.postCollateral(0);
        }

        token.mint(address(loan), principalIncrease_);

        lender.loan_acceptNewTerms(address(loan), address(refinancer), data, 0);

        assertEq(loan.collateralRequired(), newCollateralRequired_);
        assertEq(loan.endingPrincipal(),    newEndingPrincipal_);
        assertEq(loan.gracePeriod(),        newGracePeriod_);
        assertEq(loan.interestRate(),       newInterestRate_);
        assertEq(loan.paymentInterval(),    newPaymentInterval_);
        assertEq(loan.principal(),          currentPrincipal + principalIncrease_);
    }

}

contract RefinanceMiscellaneousTests is BaseRefinanceTest {

    function testFail_refinance_invalidRefinancer() external {
        setUpOngoingLoan(1, 1, 1, 1, 1, 1, 1);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature("setEndingPrincipal(uint256)", 0);

        // Executing refinance
        loan.proposeNewTerms(address(1), data);

        lender.loan_acceptNewTerms(address(loan), address(1), data, 0);
    }

}
