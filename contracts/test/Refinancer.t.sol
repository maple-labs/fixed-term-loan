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

        address[2] memory assets = [address(token), address(token)];

        uint256[6] memory parameters = [
            gracePeriod_,
            paymentInterval_,
            paymentsRemaining_,
            interestRate_,
            0,
            0
        ];

        uint256[4] memory fees = [uint256(15_000), uint256(0.10 ether), uint256(20_000), uint256(0.15 ether)];

        uint256[3] memory requests = [collateralRequired_, principalRequested_, endingPrincipal_];

        loan = new ConstructableMapleLoan(address(this), assets, parameters, requests, fees);

        token.mint(address(this),      principalRequested_);
        token.approve(address(loan),   principalRequested_);
        loan.fundLoan(address(lender), principalRequested_);

        token.mint(address(loan), collateralRequired_);
        loan.postCollateral();

        loan.drawdownFunds(principalRequested_, address(1));

        // Warp to when payment is due
        hevm.warp(loan.nextPaymentDueDate());

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion, uint256 lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        // Make payment #1
        token.mint(address(loan), principalPortion + interestPortion + lateFeesPortion);
        loan.makePayments(1);
    }

    function _encodeWithSignatureAndUint(string memory signature_, uint256 arg_) internal pure returns (bytes[] memory calls) {
        calls = new bytes[](1);
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
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT); // Boundary increase so principal portion on 'paymentBreakdown' is always greater than 0
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        gracePeriod_        = constrictToRange(gracePeriod_,        0,                MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, principalRequested_, gracePeriod_,  interestRate_, paymentInterval_, paymentsRemaining_);

        newEndingPrincipal_ = constrictToRange(newEndingPrincipal_, 0, loan.principalRequested() - 1);

        // Current ending principal is requested amount
        assertEq(loan.endingPrincipal(), loan.principalRequested());

        ( uint256 principalPortion, , ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion, 0);

        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer),  data);

        assertEq(loan.endingPrincipal(), newEndingPrincipal_);

        ( principalPortion, , ) = loan.getNextPaymentsBreakDown(1);
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
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT); // Boundary increase so principal portion on 'paymentBreakdown' is always greater than 0
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

        ( uint256 principalPortion, , ) = loan.getNextPaymentsBreakDown(1);
        assertTrue(principalPortion > 0);

        // Propose Refinance
        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer),  data);

        assertEq(loan.endingPrincipal(), newEndingPrincipal_);

        ( principalPortion, , ) = loan.getNextPaymentsBreakDown(1);
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

        try loan.acceptNewTerms(address(refinancer), data) { fail(); } catch { }
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
        lender.loan_acceptNewTerms(address(loan), address(refinancer),  data);

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
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE / 2); // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newInterestRate_ = constrictToRange(newInterestRate_, 0, MAX_RATE);

        assertEq(loan.interestRate(), interestRate_);

        bytes[] memory data = _encodeWithSignatureAndUint("setInterestRate(uint256)", newInterestRate_);

        // The new interest rate will be applied retroactively until the last payment made.
        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer),  data);

        assertEq(loan.interestRate(), newInterestRate_);
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
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE); // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newPaymentInterval_ = constrictToRange(newPaymentInterval_, 0, MAX_TIME);

        assertEq(loan.paymentInterval(), paymentInterval_);

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", newPaymentInterval_);

        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer),  data);

        assertEq(loan.paymentInterval(), newPaymentInterval_);
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
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT,         MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                        MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    principalRequested_ / 2, principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,                      MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       10_000,                   MAX_RATE / 2); // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    30 days,                  MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                        MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        // Asserting state
        assertEq(loan.endingPrincipal(), endingPrincipal_);
        assertEq(loan.gracePeriod(),     gracePeriod_);
        assertEq(loan.interestRate(),    interestRate_);
        assertEq(loan.paymentInterval(), paymentInterval_);

        // Defining refinance terms
        uint256 newEndingPrincipal_ = 0;
        uint256 newGracePeriod_     = 95;
        uint256 newInterestRate_    = 0;
        uint256 newPaymentInterval_ = 15 days;

        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeWithSignature("setEndingPrincipal(uint256)", newEndingPrincipal_);
        data[1] = abi.encodeWithSignature("setGracePeriod(uint256)",     newGracePeriod_);
        data[2] = abi.encodeWithSignature("setInterestRate(uint256)",    newInterestRate_);
        data[3] = abi.encodeWithSignature("setPaymentInterval(uint256)", newPaymentInterval_);

        // Executing refinance
        loan.proposeNewTerms(address(refinancer), data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer),  data);

        assertEq(loan.endingPrincipal(), newEndingPrincipal_);
        assertEq(loan.gracePeriod(),     newGracePeriod_);
        assertEq(loan.interestRate(),    newInterestRate_);
        assertEq(loan.paymentInterval(), newPaymentInterval_);
    }

}
