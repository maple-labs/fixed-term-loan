// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { Refinancer } from "../Refinancer.sol";

import { ConstructableMapleLoan, LenderMock, MockFactory, MapleGlobalsMock } from "./mocks/Mocks.sol";

// Helper contract with common functionality
contract BaseRefinanceTest is  TestUtils {

    // Loan Boundaries
    uint256 internal constant MAX_RATE         = 1e18;             // 100 %
    uint256 internal constant MAX_TIME         = 90 days;          // Assumed reasonable upper limit for payment intervals and grace periods
    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant MIN_TOKEN_AMOUNT = 10 ** 6;          // Needed so payments don't round down to zero
    uint256 internal constant MAX_PAYMENTS     = 20;

    ConstructableMapleLoan loan;
    LenderMock             lender;
    MapleGlobalsMock       globals;
    MockERC20              token;
    MockFactory            factory;
    Refinancer             refinancer;

    function setUp() external {
        lender     = new LenderMock();
        refinancer = new Refinancer();
        globals    = new MapleGlobalsMock(address(this), address(0), 0, 0);
        factory    = new MockFactory();

        factory.setGlobals(address(globals));
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
        uint256[3] memory amounts     = [collateralRequired_, principalRequested_, endingPrincipal_];
        uint256[3] memory termDetails = [gracePeriod_, paymentInterval_, paymentsRemaining_];
        uint256[4] memory rates       = [interestRate_, uint256(0.10e18), uint256(0.15e18), uint256(0)];

        loan = new ConstructableMapleLoan(address(factory), address(this), assets, termDetails, amounts, rates);

        token.mint(address(this), principalRequested_);
        token.approve(address(loan), principalRequested_);
        loan.fundLoan(address(lender), principalRequested_);

        token.mint(address(loan), collateralRequired_);
        loan.postCollateral(0);

        loan.drawdownFunds(principalRequested_, address(1));

        // Warp to when payment is due
        vm.warp(loan.nextPaymentDueDate());

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion, uint256 delegateFeePortion, uint256 treasuryFeePortion ) = loan.getNextPaymentBreakdown();

        // Make payment #1
        token.mint(address(loan), principalPortion + interestPortion + delegateFeePortion + treasuryFeePortion);
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
        uint256 newEndingPrincipal_,
        uint256 deadline_
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

        newEndingPrincipal_ = constrictToRange(newEndingPrincipal_, 0,               loan.principalRequested() - 1);
        deadline_           = constrictToRange(deadline_,           block.timestamp, type(uint256).max);

        // Current ending principal is requested amount
        assertEq(loan.endingPrincipal(), loan.principalRequested());

        ( uint256 principalPortion, , , ) = loan.getNextPaymentBreakdown();

        assertEq(principalPortion, 0);

        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

        assertEq(loan.endingPrincipal(), newEndingPrincipal_);

        ( principalPortion, , , ) = loan.getNextPaymentBreakdown();

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
        gracePeriod_        = constrictToRange(gracePeriod_,        0,                MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);


        // Current ending principal is requested amount
        assertTrue(loan.endingPrincipal() < loan.principalRequested());

        ( uint256 principalPortion, , , ) = loan.getNextPaymentBreakdown();

        assertTrue(principalPortion > 0);

        // Propose Refinance
        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", loan.principal());

        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

        assertEq(loan.endingPrincipal(), loan.principal());

        ( principalPortion, , , ) = loan.getNextPaymentBreakdown();

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
        principalRequested_ = constrictToRange(principalRequested_, 1,               MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,               MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,               principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        0,               MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,               MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,               MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,               MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        uint256 newEndingPrincipal_ = loan.principal() + 1;

        bytes[] memory data = _encodeWithSignatureAndUint("setEndingPrincipal(uint256)", newEndingPrincipal_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);

        assertTrue(!lender.try_loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0));
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
        uint256 newGracePeriod_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, 1,               MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,               MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,               principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,             MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,               MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,               MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,               MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        newGracePeriod_ = constrictToRange(newGracePeriod_, 0, MAX_TIME);

        assertEq(loan.gracePeriod(), gracePeriod_);

        bytes[] memory data = _encodeWithSignatureAndUint("setGracePeriod(uint256)", newGracePeriod_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

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
        uint256 newInterestRate_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE / 2);  // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newInterestRate_ = constrictToRange(newInterestRate_, 0,               MAX_RATE);
        deadline_        = constrictToRange(deadline_,        block.timestamp, type(uint256).max);

        assertEq(loan.interestRate(), interestRate_);

        bytes[] memory data = _encodeWithSignatureAndUint("setInterestRate(uint256)", newInterestRate_);

        // The new interest rate will be applied retroactively until the last payment made.
        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

        assertEq(loan.interestRate(), newInterestRate_);
    }

}

contract RefinancerPaymentRemaining is BaseRefinanceTest {

    function test_refinance_paymentRemaining_zeroAmount() external {
        setUpOngoingLoan(MIN_TOKEN_AMOUNT, 0, MIN_TOKEN_AMOUNT, 0, 0.1e18, 30 days, 6);

        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentsRemaining(uint256)", 0);

        loan.proposeNewTerms(address(refinancer), deadline, data);
        vm.expectRevert("MLI:ANT:FAILED");
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline, data, 0);

        data = _encodeWithSignatureAndUint("setPaymentsRemaining(uint256)", 1);

        loan.proposeNewTerms(address(refinancer), deadline, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline, data, 0);
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
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1 days,           MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        deadline_ = constrictToRange(deadline_, block.timestamp, type(uint256).max);

        newPaymentsRemaining_ = constrictToRange(newPaymentsRemaining_, 1, 90);

        assertEq(loan.paymentsRemaining(), paymentsRemaining_ - 1);  // We've paid one during setUpOngoingLoan

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentsRemaining(uint256)", newPaymentsRemaining_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

        assertEq(loan.paymentsRemaining(), newPaymentsRemaining_);
    }

}

contract RefinancerPaymentIntervalTest is BaseRefinanceTest {

    function test_refinance_paymentInterval_zeroAmount() external {
        setUpOngoingLoan(MIN_TOKEN_AMOUNT, 0, MIN_TOKEN_AMOUNT, 0, 0.1e18, 30 days, 6);

        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", 0);

        loan.proposeNewTerms(address(refinancer), deadline, data);
        vm.expectRevert("MLI:ANT:FAILED");
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline, data, 0);

        data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", 1);

        loan.proposeNewTerms(address(refinancer), deadline, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline, data, 0);
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
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1 days,           MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);
        deadline_           = constrictToRange(deadline_,           block.timestamp,  type(uint256).max);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newPaymentInterval_ = constrictToRange(newPaymentInterval_, 1 days,          MAX_TIME);
        deadline_           = constrictToRange(deadline_,           block.timestamp, type(uint256).max);

        assertEq(loan.paymentInterval(), paymentInterval_);

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", newPaymentInterval_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

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
        uint256 newEarlyFeeRate_,
        uint256 deadline_
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

        newEarlyFeeRate_ = constrictToRange(newEarlyFeeRate_, 0,               MAX_RATE);
        deadline_        = constrictToRange(deadline_,        block.timestamp, type(uint256).max);

        assertEq(loan.earlyFeeRate(), 0.1e18);

        bytes[] memory data = _encodeWithSignatureAndUint("setEarlyFeeRate(uint256)", newEarlyFeeRate_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

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
        uint256 newLateFeeRate_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newLateFeeRate_ = constrictToRange(newLateFeeRate_, 0,               MAX_RATE);
        deadline_       = constrictToRange(deadline_,       block.timestamp, type(uint256).max);

        assertEq(loan.lateFeeRate(), 0.15e18);

        bytes[] memory data = _encodeWithSignatureAndUint("setLateFeeRate(uint256)", newLateFeeRate_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

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
        uint256 newLateInterestPremium_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newLateInterestPremium_ = constrictToRange(newLateInterestPremium_, 0,               MAX_RATE);
        deadline_               = constrictToRange(deadline_,               block.timestamp, type(uint256).max);

        assertEq(loan.lateInterestPremium(), 0);

        bytes[] memory data = _encodeWithSignatureAndUint("setLateInterestPremium(uint256)", newLateInterestPremium_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

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
        uint256 newCollateralRequired_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        newCollateralRequired_ = constrictToRange(newCollateralRequired_, 0,               MAX_TOKEN_AMOUNT);
        deadline_              = constrictToRange(deadline_,              block.timestamp, type(uint256).max);

        assertEq(loan.collateralRequired(), collateralRequired_);

        bytes[] memory data = _encodeWithSignatureAndUint("setCollateralRequired(uint256)", newCollateralRequired_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);

        uint256 requiredCollateral = loan.getCollateralRequiredFor(loan.principal(), loan.drawableFunds(), loan.principalRequested(), newCollateralRequired_);
        uint256 currentCollateral  = loan.collateral();

        if (requiredCollateral > currentCollateral) {
            assertTrue(!lender.try_loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0));

            token.mint(address(loan), requiredCollateral - currentCollateral);
            loan.postCollateral(0);
        }

        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

        assertEq(loan.collateralRequired(), newCollateralRequired_);

        if (requiredCollateral < currentCollateral) {
            // Some amount of collateral should've been freed
            loan.removeCollateral(currentCollateral - requiredCollateral, address(this));
        }
    }

}

contract RefinancePrincipalRequestedTest is BaseRefinanceTest {

    // Saving as storage variables to avoid stack too deep
    uint256 initialClaimableFunds;
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
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);
        deadline_           = constrictToRange(deadline_,           block.timestamp,  type(uint256).max);  // Hardcoding deadline to not cause stack too deep

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        principalIncrease_ = constrictToRange(principalIncrease_, 1, MIN_TOKEN_AMOUNT);  // If we increase too much we get overflows

        assertEq(loan.principalRequested(), principalRequested_);

        bytes[] memory data = _encodeWithSignatureAndUint("increasePrincipal(uint256)", principalIncrease_);

        loan.proposeNewTerms(address(refinancer), block.timestamp, data);

        // Increasing the amount without sending it first should fail
        assertTrue(!lender.try_loan_acceptNewTerms(address(loan), address(refinancer), block.timestamp, data, 0));

        {
            // Since the collateral rate has remained the same, we need to also send more collateral
            uint256 extraCollateral = collateralRequired_ * principalIncrease_ / principalRequested_;

            token.mint(address(loan), extraCollateral);
            loan.postCollateral(0);
        }

        // Sending additional funds (plus 1 too much)
        token.mint(address(loan), principalIncrease_ + 1);

        initialPrincipal     = loan.principal();
        initialDrawableFunds = loan.drawableFunds();

        lender.loan_acceptNewTerms(address(loan), address(refinancer), block.timestamp, data, 0);

        assertEq(loan.principalRequested(),        principalRequested_ + principalIncrease_);
        assertEq(loan.principal(),                 initialPrincipal + principalIncrease_);
        assertEq(loan.drawableFunds(),             initialDrawableFunds + principalIncrease_);
        assertEq(token.balanceOf(address(lender)), 1);
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
        uint256 principalIncrease_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT, MAX_TOKEN_AMOUNT - MIN_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,                principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,              MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       0,                MAX_RATE);  // Giving enough room to increase the interest Rate
        lateFeeRate_        = constrictToRange(lateFeeRate_,        0,                MAX_RATE);
        paymentInterval_    = constrictToRange(paymentInterval_,    1,                MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

        principalIncrease_ = constrictToRange(principalIncrease_, 1,               MIN_TOKEN_AMOUNT);  // If we increase too much we get overflows
        deadline_          = constrictToRange(deadline_,          block.timestamp, type(uint256).max);

        assertEq(loan.principalRequested(), principalRequested_);

        bytes[] memory data = _encodeWithSignatureAndUint("increasePrincipal(uint256)", principalIncrease_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);

        // Increasing the amount without sending it first should fail
        assertTrue(!lender.try_loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0));

        // Since the collateral rate has remained the same, we need to also send more collateral
        uint256 extraCollateral = collateralRequired_ * principalIncrease_ / principalRequested_;

        token.mint(address(loan), extraCollateral);
        loan.postCollateral(0);

        // Sending 1 too little, causes revert
        token.mint(address(loan), principalIncrease_ - 1);

        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);
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
        uint256 paymentsRemaining_,
        uint256 deadline_
    )
        external
    {
        principalRequested_ = constrictToRange(principalRequested_, MIN_TOKEN_AMOUNT,        MAX_TOKEN_AMOUNT - MIN_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 0,                       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    principalRequested_ / 2, principalRequested_);
        gracePeriod_        = constrictToRange(gracePeriod_,        100,                     MAX_TIME);
        interestRate_       = constrictToRange(interestRate_,       10_000,                  MAX_RATE / 2);  // Giving enough room to increase the interest Rate
        paymentInterval_    = constrictToRange(paymentInterval_,    30 days,                 MAX_TIME / 2);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  3,                       MAX_PAYMENTS);

        setUpOngoingLoan(principalRequested_, collateralRequired_, endingPrincipal_, gracePeriod_, interestRate_, paymentInterval_, paymentsRemaining_);

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
        loan.proposeNewTerms(address(refinancer), deadline_, data);

        uint256 currentCollateral = loan.collateral();

        if (newCollateralRequired_ > currentCollateral) {
            token.mint(address(loan), newCollateralRequired_ - currentCollateral);
            loan.postCollateral(0);
        }

        token.mint(address(loan), principalIncrease_);

        uint256 expectedRefinanceInterest = loan.getRefinanceInterest(block.timestamp);

        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

        assertEq(loan.collateralRequired(), newCollateralRequired_);
        assertEq(loan.endingPrincipal(),    newEndingPrincipal_);
        assertEq(loan.gracePeriod(),        newGracePeriod_);
        assertEq(loan.interestRate(),       newInterestRate_);
        assertEq(loan.paymentInterval(),    newPaymentInterval_);
        assertEq(loan.principal(),          currentPrincipal + principalIncrease_);
        assertEq(loan.refinanceInterest(),  expectedRefinanceInterest);
    }

}

contract RefinanceDeadlineTests is BaseRefinanceTest {

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

        setUpOngoingLoan(1e18, 0, 0, 1, 1, paymentInterval_, 2);

        assertEq(loan.paymentInterval(), paymentInterval_);

        deadline_ = constrictToRange(deadline_, block.timestamp, block.timestamp + MAX_TIME);

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", newPaymentInterval_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.warp(deadline_ + 1);

        vm.expectRevert(bytes("MLI:ANT:EXPIRED_COMMITMENT"));
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

        vm.warp(deadline_);

        // Success
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

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

        setUpOngoingLoan(1e18, 0, 0, 1, 1, paymentInterval_, 2);

        deadline_ = constrictToRange(deadline_, block.timestamp, block.timestamp + MAX_TIME);

        assertEq(loan.paymentInterval(), paymentInterval_);

        bytes[] memory data = _encodeWithSignatureAndUint("setPaymentInterval(uint256)", newPaymentInterval_);

        loan.proposeNewTerms(address(refinancer), deadline_, data);

        vm.expectRevert(bytes("MLI:ANT:COMMITMENT_MISMATCH"));
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_ - 1, data, 0);

        // Success
        lender.loan_acceptNewTerms(address(loan), address(refinancer), deadline_, data, 0);

        assertEq(loan.paymentInterval(), newPaymentInterval_);
    }

}

contract RefinanceMiscellaneousTests is BaseRefinanceTest {

    function testFail_refinance_invalidRefinancer() external {
        setUpOngoingLoan(1, 1, 1, 1, 1, 1, 1);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature("setEndingPrincipal(uint256)", 0);

        // Executing refinance
        loan.proposeNewTerms(address(1), block.timestamp, data);

        lender.loan_acceptNewTerms(address(loan), address(1), block.timestamp, data, 0);
    }

}

contract RefinanceInterestAndFeeTests is  TestUtils {

    // Loan Boundaries
    uint256 internal constant MAX_RATE         = 1e18;             // 100 %
    uint256 internal constant MAX_TIME         = 90 days;          // Assumed reasonable upper limit for payment intervals and grace periods
    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant MIN_TOKEN_AMOUNT = 10 ** 6;          // Needed so payments don't round down to zero
    uint256 internal constant MAX_PAYMENTS     = 20;
    uint256 internal constant USD              = 1e6;
    uint256 internal constant WAD              = 1e18;

    ConstructableMapleLoan loan;
    LenderMock             lender;
    MockERC20              token;
    MockFactory            factory;
    Refinancer             refinancer;

    address poolDelegate = address(11);
    address treasury     = address(22);

    function setUp() external {
        lender     = new LenderMock();
        refinancer = new Refinancer();
        factory    = new MockFactory();

        lender.setPoolDelegate(poolDelegate);
    }

    function test_acceptNewTerms_makePayment_withFeesAndRefinanceInterest() external {
        uint256 start = block.timestamp;

        MapleGlobalsMock globals = new MapleGlobalsMock(poolDelegate, treasury, 33, 66);
        factory.setGlobals(address(globals));

        _setUpAndDrawdownLoan({
            principalRequested_: 1_000_000 * USD,
            collateralRequired_: 0,
            endingPrincipal_:    1_000_000 * USD,
            gracePeriod_:        10 days,
            interestRate_:       0.1e18,
            paymentInterval_:    30 days,
            paymentsRemaining_ : 3
        });

        assertEq(loan.principalRequested(), 1_000_000 * USD);
        assertEq(loan.collateralRequired(), 0);
        assertEq(loan.endingPrincipal(),    1_000_000 * USD);
        assertEq(loan.gracePeriod(),        10 days);
        assertEq(loan.interestRate(),       0.1e18);
        assertEq(loan.paymentInterval(),    30 days);
        assertEq(loan.nextPaymentDueDate(), start + 30 days);
        assertEq(loan.paymentsRemaining(),  3);

        assertEq(loan.delegateFee(), 271_232876);                                          // 1m * 0.33% * 30 / 365
        assertEq(loan.delegateFee(), 1_000_000 * USD * 33 * 30 days / 365 days / 10_000);  // 1m * 0.33% * 30 / 365
        assertEq(loan.treasuryFee(), 542_465753);                                          // 1m * 0.66% * 30 / 365
        assertEq(loan.treasuryFee(), 1_000_000 * USD * 66 * 30 days / 365 days / 10_000);  // 1m * 0.66% * 30 / 365

        // Warp to when payment is due
        vm.warp(loan.nextPaymentDueDate());

        // Check details for upcoming payment #1
        ( , uint256 interestPortion, uint256 delegateFeePortion, uint256 treasuryFeePortion ) = loan.getNextPaymentBreakdown();

        assertEq(token.balanceOf(address(loan)),         0);
        assertEq(token.balanceOf(address(poolDelegate)), 0);
        assertEq(token.balanceOf(address(globals)),      0);

        // Make payment #1
        token.mint(address(loan), interestPortion + delegateFeePortion + treasuryFeePortion);  // Interest only payment
        loan.makePayment(0);

        assertEq(interestPortion,    8219178082);
        assertEq(delegateFeePortion, 271_232876);
        assertEq(treasuryFeePortion, 542_465753);

        assertEq(token.balanceOf(address(loan)),         interestPortion);
        assertEq(token.balanceOf(address(poolDelegate)), 271_232876);
        assertEq(token.balanceOf(address(treasury)),      542_465753);

        // Set fees in globals to be different
        globals.setInvestorFee(40);
        globals.setTreasuryFee(60);

        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeWithSignature("setInterestRate(uint256)",      0.12e18);
        data[1] = abi.encodeWithSignature("setPaymentInterval(uint256)",   60 days);
        data[2] = abi.encodeWithSignature("increasePrincipal(uint256)",    1_000_000 * USD);  // Ending principal stays the same so switches to amortized
        data[3] = abi.encodeWithSignature("setPaymentsRemaining(uint256)", 3);  // Ending principal stays the same so switches to amortized

        loan.proposeNewTerms(address(refinancer), start + 40 days, data);

        vm.warp(start + 40 days);  // Warp 10 days into next payment cycle

        token.mint(address(loan), 1_000_000 * USD);

        // Assert that fees aren't changed until acceptNewTerms
        assertEq(loan.delegateFee(), 271_232876);
        assertEq(loan.treasuryFee(), 542_465753);

        // Assert that there is no refinanceInterest until acceptNewTerms
        assertEq(loan.refinanceInterest(), 0);

        lender.loan_acceptNewTerms(address(loan), address(refinancer), start + 40 days, data, 0);

        assertEq(loan.principalRequested(), 2_000_000 * USD);
        assertEq(loan.collateralRequired(), 0);
        assertEq(loan.endingPrincipal(),    1_000_000 * USD);
        assertEq(loan.gracePeriod(),        10 days);
        assertEq(loan.interestRate(),       0.12e18);
        assertEq(loan.paymentInterval(),    60 days);
        assertEq(loan.nextPaymentDueDate(), start + 40 days + 60 days);  // New payment interval from refinance date
        assertEq(loan.paymentsRemaining(),  3);

        uint256 expectedExtraDelegateFee = 1_000_000 * USD * 33 * 10 days / 365 days / 10_000 / 3;  // 1m * 0.33% * 10 / 365 / 3 payments (unpaid estab fee spread over remaining three payments)
        uint256 expectedExtraTreasuryFee = 1_000_000 * USD * 66 * 10 days / 365 days / 10_000 / 3;  // 1m * 0.33% * 10 / 365 / 3 payments (unpaid estab fee spread over remaining three payments)
        uint256 expectedNewDelegateFee   = 2_000_000 * USD * 40 * 60 days / 365 days / 10_000;      // 2m * 0.40% * 60 / 365 (new estab fee with new interval and rate)
        uint256 expectedNewTreasuryFee   = 2_000_000 * USD * 60 * 60 days / 365 days / 10_000;      // 2m * 0.40% * 60 / 365 (new estab fee with new interval and rate)

        assertEq(loan.delegateFee(), expectedNewDelegateFee + expectedExtraDelegateFee);
        assertEq(loan.delegateFee(), 1_345_205479);
        assertEq(loan.treasuryFee(), expectedNewTreasuryFee + expectedExtraTreasuryFee);
        assertEq(loan.treasuryFee(), 2_032_876711);

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
        token = new MockERC20("Test", "TST", 0);

        address[2] memory assets      = [address(token), address(token)];
        uint256[3] memory amounts     = [collateralRequired_, principalRequested_, endingPrincipal_];
        uint256[3] memory termDetails = [gracePeriod_, paymentInterval_, paymentsRemaining_];
        uint256[4] memory rates       = [interestRate_, uint256(0.10e18), uint256(0.15e18), uint256(0)];

        loan = new ConstructableMapleLoan(address(factory), address(this), assets, termDetails, amounts, rates);

        token.mint(address(this), principalRequested_);
        token.approve(address(loan), principalRequested_);
        loan.fundLoan(address(lender), principalRequested_);

        token.mint(address(loan), collateralRequired_);
        loan.postCollateral(0);

        loan.drawdownFunds(principalRequested_, address(1));
    }

    function _encodeWithSignatureAndUint(string memory signature_, uint256 arg_) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature_, arg_);
    }

}
