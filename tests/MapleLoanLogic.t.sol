// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { ConstructableMapleLoan, MapleLoanHarness } from "./harnesses/MapleLoanHarnesses.sol";

import { MapleGlobalsMock, MockFactory, MockFeeManager, MockLoanManager, RevertingERC20 } from "./mocks/Mocks.sol";

import { Refinancer } from "../contracts/Refinancer.sol";

contract MapleLoanLogic_AcceptNewTermsTests is TestUtils {

    address borrower = address(new Address());
    address governor = address(new Address());

    address lender;

    address    defaultBorrower;
    address[2] defaultAssets;
    uint256[3] defaultTermDetails;
    uint256[3] defaultAmounts;
    uint256[4] defaultRates;
    uint256[2] defaultFees;

    uint256 start;

    MapleGlobalsMock       globals;
    ConstructableMapleLoan loan;
    Refinancer             refinancer;
    MockERC20              collateralAsset;
    MockERC20              fundsAsset;
    MockFactory            factory;
    MockFeeManager         feeManager;

    function setUp() external {
        collateralAsset = new MockERC20("Token0", "T0", 0);
        feeManager      = new MockFeeManager();
        fundsAsset      = new MockERC20("Token1", "T1", 0);
        lender          = address(new MockLoanManager());
        globals         = new MapleGlobalsMock(governor, MockLoanManager(lender).factory());
        refinancer      = new Refinancer();

        factory = new MockFactory(address(globals));

        // Set _initialize() parameters.
        defaultBorrower    = address(1);
        defaultAssets      = [address(collateralAsset), address(fundsAsset)];
        defaultTermDetails = [uint256(1), uint256(30 days), uint256(12)];
        defaultAmounts     = [uint256(0), uint256(1000), uint256(0)];
        defaultRates       = [uint256(0.10e18), uint256(7), uint256(8), uint256(9)];
        defaultFees        = [uint256(0), uint256(0)];

        globals.setValidBorrower(defaultBorrower,                 true);
        globals.setValidCollateralAsset(address(collateralAsset), true);
        globals.setValidPoolAsset(address(fundsAsset),            true);

        vm.startPrank(address(factory));
        loan = new ConstructableMapleLoan(address(factory), defaultBorrower, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees);
        vm.stopPrank();

        vm.warp(start = 1_500_000_000);

        loan.__setBorrower(borrower);
        loan.__setDrawableFunds(defaultAmounts[1]);
        loan.__setFactory(address(factory));
        loan.__setLender(lender);
        loan.__setNextPaymentDueDate(start + 25 days);  // 5 days into a loan
        loan.__setPrincipal(defaultAmounts[1]);

        fundsAsset.mint(address(loan), defaultAmounts[1]);
    }

    function test_acceptNewTerms_commitmentMismatch_emptyCallsArray() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", 1);

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        // Try with empty calls array.
        vm.prank(lender);
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        loan.acceptNewTerms(address(refinancer), deadline, new bytes[](0));
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedCalls() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        // Try with different calls array.
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(2));

        vm.prank(lender);
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        loan.acceptNewTerms(address(refinancer), deadline, calls);
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedRefinancer() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        // Try with different refinancer.
        vm.prank(lender);
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        loan.acceptNewTerms(address(1111), deadline, calls);
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedDeadline() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        // Try with different deadline.
        vm.prank(lender);
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        loan.acceptNewTerms(address(refinancer), deadline + 1, calls);
    }

    function test_acceptNewTerms_invalidRefinancer() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        // Set _refinanceCommitment via proposeNewTerms() using invalid refinancer and valid calls array.
        vm.prank(borrower);
        loan.proposeNewTerms(address(0), deadline, calls);

        // Try with invalid refinancer.
        vm.prank(lender);
        vm.expectRevert("ML:ANT:INVALID_REFINANCER");
        loan.acceptNewTerms(address(0), deadline, calls);
    }

    function test_acceptNewTerms_afterDeadline() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        vm.warp(deadline + 1);

        // Try after deadline.
        vm.prank(lender);
        vm.expectRevert("ML:ANT:EXPIRED_COMMITMENT");
        loan.acceptNewTerms(address(refinancer), deadline, calls);
    }

    function test_acceptNewTerms_callFailed() external {
        // Add a refinance call with invalid ending principal, where new ending principal is larger than principal requested.
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setEndingPrincipal(uint256)", defaultAmounts[1] + 1);

        // Set _refinanceCommitment via proposeNewTerms().
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        // Try with invalid new term.
        vm.prank(lender);
        vm.expectRevert("ML:ANT:FAILED");
        loan.acceptNewTerms(address(refinancer), deadline, calls);
    }

    function test_acceptNewTerms_insufficientCollateral() external {
        // Setup state variables for necessary prerequisite state.
        loan.__setDrawableFunds(uint256(0));
        fundsAsset.burn(address(loan), fundsAsset.balanceOf(address(loan)));

        // Add a refinance call with new collateral required amount (fully collateralized principal) which will make current collateral amount insufficient.
        uint256 newCollateralRequired = defaultAmounts[1];
        uint256 deadline              = block.timestamp + 10 days;
        bytes[] memory calls          = new bytes[](1);
        calls[0]                      = abi.encodeWithSignature("setCollateralRequired(uint256)", newCollateralRequired);

        // Set _refinanceCommitment via proposeNewTerms().
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        // Try with insufficient collateral.
        vm.startPrank(lender);
        vm.expectRevert("ML:ANT:INSUFFICIENT_COLLATERAL");
        loan.acceptNewTerms(address(refinancer), deadline, calls);

        // Try with sufficient collateral.
        loan.__setCollateral(newCollateralRequired);
        collateralAsset.mint(address(loan), newCollateralRequired);

        loan.acceptNewTerms(address(refinancer), deadline, calls);
    }

    function test_acceptNewTerms() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", 1);

        // Set _refinanceCommitment via proposeNewTerms().
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        vm.prank(lender);
        loan.acceptNewTerms(address(refinancer), deadline, calls);
    }

}

contract MapleLoanLogic_CloseLoanTests is TestUtils {

    address borrower = address(new Address());
    address governor = address(new Address());

    address lender;

    uint256 constant MAX_TOKEN_AMOUNT     = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 constant UNDERFLOW_ERROR_CODE = 17;

    MapleGlobalsMock globals;
    MapleLoanHarness loan;
    MockERC20        fundsAsset;
    MockFactory      factory;
    MockFeeManager   feeManager;

    function setUp() external {
        feeManager = new MockFeeManager();
        fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        lender     = address(new MockLoanManager());
        globals    = new MapleGlobalsMock(governor, MockLoanManager(lender).factory());
        loan       = new MapleLoanHarness();

        factory = new MockFactory(address(globals));

        loan.__setBorrower(borrower);
        loan.__setFactory(address(factory));
        loan.__setFeeManager(address(feeManager));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setLender(lender);
    }

    function setupLoan(
        address loan_,
        uint256 principalRequested_,
        uint256 paymentsRemaining_,
        uint256 paymentInterval_,
        uint256 closingRate_,
        uint256 endingPrincipal_
    ) internal {
        MapleLoanHarness(loan_).__setClosingRate(closingRate_);
        MapleLoanHarness(loan_).__setDrawableFunds(principalRequested_);
        MapleLoanHarness(loan_).__setEndingPrincipal(endingPrincipal_);
        MapleLoanHarness(loan_).__setNextPaymentDueDate(block.timestamp + paymentInterval_);
        MapleLoanHarness(loan_).__setPaymentInterval(paymentInterval_);
        MapleLoanHarness(loan_).__setPaymentsRemaining(paymentsRemaining_);
        MapleLoanHarness(loan_).__setPrincipal(principalRequested_);
        MapleLoanHarness(loan_).__setPrincipalRequested(principalRequested_);

        fundsAsset.mint(address(loan), principalRequested_);
    }

    function test_closeLoan_withDrawableFunds(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 closingRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,     365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,       120);
        closingRate_        = constrictToRange(closingRate_,        0.01e18, 1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,       principalRequested_);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, endingPrincipal_);

        assertEq(loan.drawableFunds(),      principalRequested_);
        assertEq(loan.principal(),          principalRequested_);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 additionalAmount;

        if (expectedPayment > loan.drawableFunds()) {
            fundsAsset.mint(address(loan), additionalAmount = (expectedPayment - loan.drawableFunds()));
        }

        vm.prank(borrower);
        ( principal, interest, ) = loan.closeLoan(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                 expectedPayment);
        assertEq(loan.drawableFunds(),      principalRequested_ + additionalAmount - totalPaid);
        assertEq(loan.principal(),          0);
        assertEq(loan.nextPaymentDueDate(), 0);
        assertEq(loan.paymentsRemaining(),  0);
    }

    function test_closeLoan(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 closingRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,     365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,       120);
        closingRate_        = constrictToRange(closingRate_,        0.01e18, 1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,       principalRequested_);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, endingPrincipal_);

        assertEq(loan.drawableFunds(),      principalRequested_);
        assertEq(loan.principal(),          principalRequested_);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        fundsAsset.mint(address(loan), fundsForPayments);

        ( principal, interest, ) = loan.closeLoan(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                 expectedPayment);
        assertEq(loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(loan.principal(),          0);
        assertEq(loan.nextPaymentDueDate(), 0);
        assertEq(loan.paymentsRemaining(),  0);
    }

    function test_closeLoan_insufficientAmount(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 closingRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,        365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,          120);
        closingRate_        = constrictToRange(closingRate_,        0.01e18,    1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 10_000_000, MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,          principalRequested_);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, endingPrincipal_);

        // Drawdown all loan funds.
        vm.startPrank(borrower);
        loan.drawdownFunds(loan.drawableFunds(), borrower);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        fundsAsset.mint(address(loan), installmentToPay - 1);

        // Try to pay with insufficient amount, should underflow.
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.closeLoan(0);

        // Mint remaining amount.
        fundsAsset.mint(address(loan), 1);

        // Pay off loan with exact amount.
        loan.closeLoan(0);
    }

    function test_closeLoan_latePayment(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 closingRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,     365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,       120);
        closingRate_        = constrictToRange(closingRate_,        0.01e18, 1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,       MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,       principalRequested_);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, endingPrincipal_);

        fundsAsset.mint(address(loan), MAX_TOKEN_AMOUNT * 1500);

        // Set time such that payment is late.
        vm.warp(block.timestamp + paymentInterval_ + 1);

        vm.expectRevert("ML:CL:PAYMENT_IS_LATE");
        loan.closeLoan(0);

        // Returning to being on-time.
        vm.warp(block.timestamp - 2);

        loan.closeLoan(0);
    }

    function test_closeLoan_withRefinanceInterest(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 closingRate_,
        uint256 principalRequested_,
        uint256 refinanceInterest_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,     365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,       120);
        closingRate_        = constrictToRange(closingRate_,        0.01e18, 1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 100,     MAX_TOKEN_AMOUNT);
        refinanceInterest_  = constrictToRange(refinanceInterest_,  100,     MAX_TOKEN_AMOUNT);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, 0);

        loan.__setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        fundsAsset.mint(address(loan), fundsForPayments);

        assertEq(loan.drawableFunds(),      principalRequested_);
        assertEq(loan.principal(),          principalRequested_);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_);

        ( principal, interest, ) = loan.closeLoan(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                 expectedPayment);
        assertEq(loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(loan.principal(),          0);
        assertEq(loan.nextPaymentDueDate(), 0);
        assertEq(loan.paymentsRemaining(),  0);
    }

    function test_closeLoan_amountSmallerThanFees() external {
        setupLoan(address(loan), 1_000_000, 2, 365 days, 0, 0);

        feeManager.__setDelegateServiceFee(100);
        feeManager.__setPlatformServiceFee(100);
        feeManager.__setServiceFeesToPay(200);

        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getClosingPaymentBreakdown();

        uint256 payment = principal + interest + fees;

        vm.prank(address(loan));
        fundsAsset.approve(address(feeManager), type(uint256).max);

        fundsAsset.mint(borrower, payment);

        vm.startPrank(borrower);
        loan.drawdownFunds(loan.drawableFunds(), borrower);
        fundsAsset.approve(address(loan), payment);
        loan.returnFunds(payment - (fees / 2));
        ( principal, interest, ) = loan.closeLoan(fees / 2);

        assertEq(loan.drawableFunds(), 0);
    }

    function test_closeLoan_noAmount() external {
        setupLoan(address(loan), 1_000_000, 2, 365 days, 0, 0);

        feeManager.__setDelegateServiceFee(100);
        feeManager.__setPlatformServiceFee(100);
        feeManager.__setServiceFeesToPay(200);

        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getClosingPaymentBreakdown();

        uint256 payment = principal + interest + fees;

        vm.prank(address(loan));
        fundsAsset.approve(address(feeManager), type(uint256).max);

        fundsAsset.mint(borrower, payment);

        vm.startPrank(borrower);
        loan.drawdownFunds(loan.drawableFunds(), borrower);
        fundsAsset.approve(address(loan), payment);
        loan.returnFunds(payment);
        ( principal, interest, ) = loan.closeLoan(0);

        assertEq(loan.drawableFunds(), 0);
    }

}

contract MapleLoanLogic_CollateralMaintainedTests is TestUtils {

    uint256 constant SCALED_ONE       = uint256(10 ** 36);
    uint256 constant MAX_TOKEN_AMOUNT = 1e12 * 1e18;

    MapleLoanHarness loan;

    function setUp() external {
        loan = new MapleLoanHarness();
    }

    function test_isCollateralMaintained(uint256 collateral_, uint256 collateralRequired_, uint256 drawableFunds_, uint256 principal_, uint256 principalRequested_) external {
        collateral_         = constrictToRange(collateral_,         0, type(uint256).max);
        collateralRequired_ = constrictToRange(collateralRequired_, 0, type(uint128).max);  // Max chosen since type(uint128).max * type(uint128).max < type(uint256).max.
        drawableFunds_      = constrictToRange(drawableFunds_,      0, type(uint256).max);
        principalRequested_ = constrictToRange(principalRequested_, 1, type(uint128).max);  // Max chosen since type(uint128).max * type(uint128).max < type(uint256).max.
        principal_          = constrictToRange(principal_,          0, principalRequested_);

        loan.__setCollateral(collateral_);
        loan.__setCollateralRequired(collateralRequired_);
        loan.__setDrawableFunds(drawableFunds_);
        loan.__setPrincipal(principal_);
        loan.__setPrincipalRequested(principalRequested_);

        uint256 outstandingPrincipal = principal_ > drawableFunds_ ? principal_ - drawableFunds_ : 0;

        bool shouldBeMaintained =
            outstandingPrincipal == 0 ||                                                                                      // No collateral needed (since no outstanding principal), thus maintained.
            collateral_ >= (((collateralRequired_ * outstandingPrincipal) + principalRequested_ - 1) / principalRequested_);  // collateral_ / collateralRequired_ >= outstandingPrincipal / principalRequested_.

        assertTrue(loan.__isCollateralMaintained() == shouldBeMaintained);
    }

    // NOTE: Skipping this test because the assertion has more precision than the implementation, causing errors
    function skip_test_isCollateralMaintained_scaledMath(uint256 collateral_, uint256 collateralRequired_, uint256 drawableFunds_, uint256 principal_, uint256 principalRequested_) external {
        collateral_         = constrictToRange(collateral_,         0, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        drawableFunds_      = constrictToRange(drawableFunds_,      0, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        principal_          = constrictToRange(principal_,          0, principalRequested_);

        loan.__setCollateral(collateral_);
        loan.__setCollateralRequired(collateralRequired_);
        loan.__setDrawableFunds(drawableFunds_);
        loan.__setPrincipal(principal_);
        loan.__setPrincipalRequested(principalRequested_);

        uint256 outstandingPrincipal = principal_ > drawableFunds_ ? principal_ - drawableFunds_ : 0;
        bool shouldBeMaintained      = ((collateral_ * SCALED_ONE) / collateralRequired_) >= (outstandingPrincipal * SCALED_ONE) / principalRequested_;

        assertTrue(loan.__isCollateralMaintained() == shouldBeMaintained);
    }

    function test_isCollateralMaintained_edgeCases() external {
        loan.__setCollateral(50 ether);
        loan.__setCollateralRequired(100 ether);
        loan.__setDrawableFunds(100 ether);
        loan.__setPrincipal(600 ether);
        loan.__setPrincipalRequested(1000 ether);

        assertEq(loan.__getCollateralRequiredFor(loan.principal(), loan.drawableFunds(), loan.principalRequested(), loan.collateralRequired()), 50 ether);

        assertTrue(loan.__isCollateralMaintained());

        // Set collateral just enough such that collateral is not maintained.
        loan.__setCollateral(50 ether - 1 wei);

        assertTrue(!loan.__isCollateralMaintained());

        // Reset collateral and set collateral required just enough such that collateral is not maintained.
        loan.__setCollateral(50 ether);
        loan.__setCollateralRequired(100 ether + 2 wei);

        assertEq(loan.__getCollateralRequiredFor(loan.principal(), loan.drawableFunds(), loan.principalRequested(), loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!loan.__isCollateralMaintained());

        // Reset collateral required and set drawable funds just enough such that collateral is not maintained.
        loan.__setCollateralRequired(100 ether);
        loan.__setDrawableFunds(100 ether - 10 wei);

        assertEq(loan.__getCollateralRequiredFor(loan.principal(), loan.drawableFunds(), loan.principalRequested(), loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!loan.__isCollateralMaintained());

        // Reset drawable funds and set principal just enough such that collateral is not maintained.
        loan.__setDrawableFunds(100 ether);
        loan.__setPrincipal(600 ether + 10 wei);

        assertEq(loan.__getCollateralRequiredFor(loan.principal(), loan.drawableFunds(), loan.principalRequested(), loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!loan.__isCollateralMaintained());

        // Reset principal and set principal requested just enough such that collateral is not maintained.
        loan.__setPrincipal(600 ether);
        loan.__setPrincipalRequested(1000 ether - 20 wei);

        assertEq(loan.__getCollateralRequiredFor(loan.principal(), loan.drawableFunds(), loan.principalRequested(), loan.collateralRequired()), 50 ether + 2 wei);

        assertTrue(!loan.__isCollateralMaintained());
    }

    function test_isCollateralMaintained_roundUp() external {
        loan.__setCollateralRequired(100 ether);
        loan.__setPrincipal(500 ether + 1);
        loan.__setPrincipalRequested(1000 ether);

        assertEq(loan.__getCollateralRequiredFor(loan.principal(), loan.drawableFunds(), loan.principalRequested(), loan.collateralRequired()), 50 ether + 1);
    }

}

contract MapleLoanLogic_DrawdownFundsTests is TestUtils {

    uint256 constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)

    MapleGlobalsMock globals;
    MapleLoanHarness loan;
    MockERC20        collateralAsset;
    MockERC20        fundsAsset;
    MockFactory      factory;

    address borrower = address(new Address());

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        globals         = new MapleGlobalsMock(address(0), address(0));
        factory         = new MockFactory(address(globals));
        fundsAsset      = new MockERC20("Funds Asset", "FA", 0);
        loan            = new MapleLoanHarness();

        loan.__setBorrower(borrower);
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setFactory(address(factory));
        loan.__setFundsAsset(address(fundsAsset));
    }

    function test_drawdownFunds_withoutPostedCollateral(uint256 principalRequested_, uint256 drawdownAmount_) external {
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        drawdownAmount_     = constrictToRange(drawdownAmount_,     1, principalRequested_);

        loan.__setDrawableFunds(principalRequested_);
        loan.__setPrincipal(principalRequested_);
        loan.__setPrincipalRequested(principalRequested_);

        fundsAsset.mint(address(loan), principalRequested_);

        vm.prank(borrower);
        loan.drawdownFunds(drawdownAmount_, borrower);

        assertEq(loan.drawableFunds(),                principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(borrower),      drawdownAmount_);
    }

    function test_drawdownFunds_postedCollateral(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        // Must have non-zero collateral and principal amounts to cause failure
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        drawdownAmount_     = constrictToRange(drawdownAmount_,     1, principalRequested_);

        loan.__setCollateral(collateralRequired_);
        loan.__setCollateralRequired(collateralRequired_);
        loan.__setDrawableFunds(principalRequested_);
        loan.__setPrincipal(principalRequested_);
        loan.__setPrincipalRequested(principalRequested_);

        collateralAsset.mint(address(loan), collateralRequired_);
        fundsAsset.mint(address(loan), principalRequested_);

        vm.prank(borrower);
        loan.drawdownFunds(drawdownAmount_, borrower);

        assertEq(loan.drawableFunds(),                principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(borrower),      drawdownAmount_);
    }

    function test_drawdownFunds_insufficientDrawableFunds(uint256 principalRequested_, uint256 extraAmount_) external {
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        extraAmount_        = constrictToRange(extraAmount_,        1, MAX_TOKEN_AMOUNT);

        loan.__setDrawableFunds(principalRequested_);
        loan.__setPrincipal(principalRequested_);
        loan.__setPrincipalRequested(principalRequested_);

        fundsAsset.mint(address(loan), principalRequested_);

        vm.prank(borrower);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.drawdownFunds(principalRequested_ + extraAmount_, borrower);
    }

    function test_drawdownFunds_transferFailed() external {
        // DrawableFunds is set, but the loan doesn't actually have any tokens which causes the transfer to fail.
        loan.__setDrawableFunds(1);

        vm.prank(borrower);
        vm.expectRevert("ML:DF:TRANSFER_FAILED");
        loan.drawdownFunds(1, borrower);
    }

    function test_drawdownFunds_multipleDrawdowns(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        // Must have non-zero collateral and principal amounts to cause failure
        collateralRequired_ = constrictToRange(collateralRequired_, 2, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 2, MAX_TOKEN_AMOUNT);
        drawdownAmount_     = constrictToRange(drawdownAmount_,     1, principalRequested_ / 2);

        loan.__setCollateral(collateralRequired_);
        loan.__setCollateralRequired(collateralRequired_);
        loan.__setDrawableFunds(principalRequested_);
        loan.__setPrincipal(principalRequested_);
        loan.__setPrincipalRequested(principalRequested_);

        collateralAsset.mint(address(loan), collateralRequired_);
        fundsAsset.mint(address(loan), principalRequested_);

        vm.prank(borrower);
        loan.drawdownFunds(drawdownAmount_, borrower);

        assertEq(loan.drawableFunds(),                principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(address(loan)), principalRequested_ - drawdownAmount_);
        assertEq(fundsAsset.balanceOf(borrower),      drawdownAmount_);

        vm.prank(borrower);
        loan.drawdownFunds(principalRequested_ - drawdownAmount_, borrower);

        assertEq(loan.drawableFunds(),                0);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(fundsAsset.balanceOf(borrower),      principalRequested_);
    }

    function test_drawdownFunds_collateralNotMaintained(uint256 collateralRequired_, uint256 principalRequested_, uint256 collateral_) external {
        // Must have non-zero collateral and principal amounts to cause failure
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        collateral_         = constrictToRange(collateral_,         0, collateralRequired_ - 1);

        loan.__setCollateral(collateral_);
        loan.__setCollateralRequired(collateralRequired_);
        loan.__setDrawableFunds(principalRequested_);
        loan.__setPrincipal(principalRequested_);
        loan.__setPrincipalRequested(principalRequested_);

        collateralAsset.mint(address(loan), collateral_);
        fundsAsset.mint(address(loan), principalRequested_);

        vm.expectRevert("ML:PC:TRANSFER_FROM_FAILED");
        vm.prank(borrower);
        loan.drawdownFunds(principalRequested_, borrower);
    }

}

contract MapleLoanLogic_FundLoanTests is TestUtils {

    uint256 constant MAX_PRINCIPAL = 1_000_000_000 * 1e18;
    uint256 constant MIN_PRINCIPAL = 1;

    address lender;

    MapleGlobalsMock globals;
    MapleLoanHarness loan;
    MockERC20        fundsAsset;
    MockFactory      factory;
    MockFeeManager   feeManager;

    address governor = address(new Address());

    function setUp() external {
        feeManager = new MockFeeManager();
        fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        lender     = address(new MockLoanManager());
        globals    = new MapleGlobalsMock(governor, MockLoanManager(lender).factory());
        loan       = new MapleLoanHarness();

        factory = new MockFactory(address(globals));

        loan.__setFactory(address(factory));
        loan.__setFeeManager(address(feeManager));
    }

    function test_fundLoan_withInvalidLender() external {
        vm.expectRevert("ML:FL:INVALID_LENDER");
        loan.fundLoan(address(0));
    }

    function test_fundLoan_withoutSendingAsset() external {
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(1);

        vm.expectRevert(ARITHMETIC_ERROR);
        loan.fundLoan(lender);
    }

    function test_fundLoan_fullFunding(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentInterval(30 days);
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(principalRequested_);

        fundsAsset.mint(address(loan), principalRequested_);

        assertEq(loan.fundLoan(lender),                          principalRequested_);
        assertEq(loan.lender(),                                  lender);
        assertEq(loan.nextPaymentDueDate(),                      block.timestamp + loan.paymentInterval());
        assertEq(loan.principal(),                               principalRequested_);
        assertEq(loan.drawableFunds(),                           principalRequested_);
        assertEq(loan.getUnaccountedAmount(address(fundsAsset)), 0);
    }

    function test_fundLoan_partialFunding(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(principalRequested_);

        fundsAsset.mint(address(loan), principalRequested_ - 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        loan.fundLoan(lender);
    }

    function test_fundLoan_doubleFund(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(principalRequested_);

        fundsAsset.mint(address(loan), principalRequested_);

        loan.fundLoan(lender);

        fundsAsset.mint(address(loan), 1);

        vm.expectRevert("ML:FL:LOAN_ACTIVE");
        loan.fundLoan(lender);
    }

    function test_fundLoan_invalidFundsAsset() external {
        loan.__setFundsAsset(address(new MockERC20("SomeAsset", "SA", 0)));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(1);

        fundsAsset.mint(address(loan), 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        loan.fundLoan(lender);
    }

    function test_fundLoan_withUnaccountedCollateralAsset() external {
        MockERC20 collateralAsset = new MockERC20("CollateralAsset", "CA", 0);

        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(1);

        collateralAsset.mint(address(loan), 1);
        fundsAsset.mint(address(loan), 1);

        loan.fundLoan(lender);

        assertEq(loan.getUnaccountedAmount(address(collateralAsset)), 1);
    }

    function test_fundLoan_nextPaymentDueDateAlreadySet() external {
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setNextPaymentDueDate(1);
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(1);

        fundsAsset.mint(address(loan), 1);

        vm.expectRevert("ML:FL:LOAN_ACTIVE");
        loan.fundLoan(lender);
    }

    function test_fundLoan_noPaymentsRemaining() external {
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(0);
        loan.__setPrincipalRequested(1);

        vm.expectRevert("ML:FL:LOAN_ACTIVE");
        loan.fundLoan(lender);
    }

    function test_fundLoan_approveFail() external {
        loan.__setFundsAsset(address(new RevertingERC20()));
        loan.__setNextPaymentDueDate(0);
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(1);

        vm.expectRevert("ML:FL:APPROVE_FAIL");
        loan.fundLoan(address(lender));
    }

}

contract MapleLoanLogic_GetCollateralRequiredForTests is TestUtils {

    MapleLoanHarness internal loan;

    function setUp() external {
        loan = new MapleLoanHarness();
    }

    function test_getCollateralRequiredFor() external {
        // No principal.
        assertEq(loan.__getCollateralRequiredFor(0, 10_000, 4_000_000, 500_000), 0);

        // No outstanding principal.
        assertEq(loan.__getCollateralRequiredFor(10_000, 10_000, 4_000_000, 500_000), 0);

        // No collateral required.
        assertEq(loan.__getCollateralRequiredFor(10_000, 1_000, 4_000_000, 0), 0);

        // 1125 = (500_000 * (10_000 > 1_000 ? 10_000 - 1_000 : 0)) / 4_000_000;
        assertEq(loan.__getCollateralRequiredFor(10_000, 1_000, 4_000_000, 500_000), 1125);

        // 500_000 = (500_000 * (4_500_000 > 500_000 ? 4_500_000 - 500_000 : 0)) / 4_000_000;
        assertEq(loan.__getCollateralRequiredFor(4_500_000, 500_000, 4_000_000, 500_000), 500_000);
    }

}

contract MapleLoanLogic_GetClosingPaymentBreakdownTests is TestUtils {
    uint256 private constant SCALED_ONE = uint256(10 ** 18);

    address    defaultBorrower;
    address[2] defaultAssets;
    uint256[3] defaultTermDetails;

    MapleGlobalsMock       globals;
    ConstructableMapleLoan loan;
    MockERC20              token1;
    MockERC20              token2;
    MockFactory            factory;
    MockFeeManager         feeManager;

    address governor = address(new Address());

    function setUp() external {
        globals    = new MapleGlobalsMock(governor, address(0));
        feeManager = new MockFeeManager();
        token1     = new MockERC20("Token0", "T0", 0);
        token2     = new MockERC20("Token1", "T1", 0);

        factory = new MockFactory(address(globals));

        // Set _initialize() parameters.
        defaultBorrower    = address(1);
        defaultAssets      = [address(token1), address(token2)];
        defaultTermDetails = [uint256(1), uint256(20 days), uint256(3)];

        globals.setValidBorrower(defaultBorrower,        true);
        globals.setValidCollateralAsset(address(token1), true);
        globals.setValidPoolAsset(address(token2),       true);
    }

    function test_getClosingPaymentBreakdown(uint256 principal_, uint256 closingRate_, uint256 refinanceInterest_) external {
        uint256 maxClosingRateForTestCase = 1 * SCALED_ONE;  // 100%

        principal_         = constrictToRange(principal_,         1, type(uint256).max / maxClosingRateForTestCase);
        closingRate_       = constrictToRange(closingRate_,       1, maxClosingRateForTestCase);
        refinanceInterest_ = constrictToRange(refinanceInterest_, 1, 1e18 * 1e12);

        // Set principal and closingRate for _initialize().
        uint256[3] memory amounts = [uint256(5), principal_, uint256(0)];
        uint256[4] memory rates   = [uint256(0.05 ether), closingRate_, uint256(0.15 ether), uint256(20)];
        uint256[2] memory fees    = [uint256(0), uint256(0)];

        vm.startPrank(address(factory));
        loan = new ConstructableMapleLoan(address(factory), defaultBorrower, address(feeManager), defaultAssets, defaultTermDetails, amounts, rates, fees);
        vm.stopPrank();

        loan.__setPrincipal(amounts[1]);
        loan.__setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();

        uint256 expectedPrincipal = amounts[1];
        uint256 expectedInterest  = (expectedPrincipal * rates[1] / SCALED_ONE) + refinanceInterest_;

        assertEq(principal, expectedPrincipal);
        assertEq(interest,  expectedInterest);
    }
}

contract MapleLoanLogic_GetInstallmentTests is TestUtils {

    MapleLoanHarness loan;

    uint256 constant MAX_TOKEN_AMOUNT = 1e12 * 1e18;
    uint256 constant MIN_TOKEN_AMOUNT = 1;

    function setUp() external {
        loan = new MapleLoanHarness();
    }

    function test_getInstallment_withFixtures() external {
        ( uint256 principalAmount, uint256 interestAmount ) = loan.__getInstallment(1_000_000, 0, 0.12 ether, 365 days / 12, 12);

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
        totalPayments_   = constrictToRange(totalPayments_,   1,                50);

        loan.__getInstallment(principal_, endingPrincipal_, interestRate_, paymentInterval_, totalPayments_);

        assertTrue(true);
    }

    function test_getInstallment_edgeCases() external {
        uint256 principalAmount_;
        uint256 interestAmount_;

        // 100,000% APY charged all at once in one payment
        ( principalAmount_, interestAmount_ ) = loan.__getInstallment(MAX_TOKEN_AMOUNT, 0, 1000.00 ether, 365 days, 1);

        assertEq(principalAmount_, 1e30);
        assertEq(interestAmount_,  1000e30);

        // A payment a day for 30 years (10950 payments) at 100% APY
        ( principalAmount_, interestAmount_ ) = loan.__getInstallment(MAX_TOKEN_AMOUNT, 0, 1.00 ether, 1 days, 10950);

        assertEq(principalAmount_, 267108596355467);
        assertEq(interestAmount_,  2739726027397260000000000000);
    }

    // TODO: test where `raisedRate <= SCALED_ONE`?

}

contract MapleLoanLogic_GetInterestTests is TestUtils {

    MapleLoanHarness internal loan;

    function setUp() external {
        loan = new MapleLoanHarness();
    }

    function test_getInterest() external {
        assertEq(loan.__getInterest(1_000_000, 0.12e18, 365 days / 12), 10_000);  // 12% APY on 1M
        assertEq(loan.__getInterest(10_000,    1.20e18, 365 days / 12), 1_000);   // 120% APY on 10k
    }

}

contract MapleLoanLogic_GetNextPaymentBreakdownTests is TestUtils {

    MapleLoanHarness internal loan;

    function setUp() external {
        loan = new MapleLoanHarness();
    }

    function test_getNextPaymentBreakdown(
        uint256 nextPaymentDueDate_,
        uint256 termLength_,
        uint256 principal_,
        uint256 endingPrincipal_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 lateFeeRate_,
        uint256 lateInterestPremium_,
        uint256 refinanceInterest_
    )
        external
    {
        nextPaymentDueDate_  = constrictToRange(nextPaymentDueDate_,  block.timestamp - 365 days, block.timestamp + 365 days);
        termLength_          = constrictToRange(termLength_,          1 days,                     15 * 365 days);
        principal_           = constrictToRange(principal_,           1,                          1e12 * 1e18);
        endingPrincipal_     = constrictToRange(endingPrincipal_,     0,                          principal_);
        paymentsRemaining_   = constrictToRange(paymentsRemaining_,   1,                          100);
        interestRate_        = constrictToRange(interestRate_,        0,                          1.00e18);
        lateFeeRate_         = constrictToRange(lateFeeRate_,         interestRate_,              1.00e18);
        lateInterestPremium_ = constrictToRange(lateInterestPremium_, interestRate_,              1.00e18);
        refinanceInterest_   = constrictToRange(refinanceInterest_,   0,                          1e12 * 1e18);

        uint256 paymentInterval = termLength_ / paymentsRemaining_;

        loan.__setNextPaymentDueDate(nextPaymentDueDate_);
        loan.__setPaymentInterval(paymentInterval);
        loan.__setPrincipal(principal_);
        loan.__setEndingPrincipal(endingPrincipal_);
        loan.__setPaymentsRemaining(paymentsRemaining_);
        loan.__setInterestRate(interestRate_);
        loan.__setLateFeeRate(lateFeeRate_);
        loan.__setLateInterestPremium(lateInterestPremium_);
        loan.__setRefinanceInterest(refinanceInterest_);
        loan.__setFeeManager(address(new MockFeeManager()));

        ( uint256 expectedPrincipal, uint256 expectedInterest ) = loan.__getPaymentBreakdown(
            block.timestamp,
            nextPaymentDueDate_,
            paymentInterval,
            principal_,
            endingPrincipal_,
            paymentsRemaining_,
            interestRate_,
            lateFeeRate_,
            lateInterestPremium_
        );

        ( uint256 actualPrincipal, uint256 actualInterest, ) = loan.getNextPaymentBreakdown();

        assertEq(actualPrincipal, expectedPrincipal);
        assertEq(actualInterest,  expectedInterest);  // Refinance interest included in payment breakdown
    }

}

contract MapleLoanLogic_GetPaymentBreakdownTests is TestUtils {

    address internal loan;
    address internal feeManager;

    function setUp() external {
        loan = address(new MapleLoanHarness());

        feeManager = address(new MockFeeManager());

        MapleLoanHarness(loan).__setFeeManager(feeManager);
    }

    function _getPaymentBreakdownWith(
        address loan_,
        uint256 currentTime_,
        uint256 nextPaymentDueDate_
    )
     internal view
        returns (
            uint256 totalPrincipalAmount,
            uint256 totalInterestFees
        )
    {
        ( totalPrincipalAmount, totalInterestFees ) = MapleLoanHarness(loan_).__getPaymentBreakdown(
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

    function test_getPaymentBreakdown_onePaymentOnePeriodBeforeDue() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            loan,
            10_000_000 - 30 days,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    9_863);  // 1_000_000 * 0.12 * 30/365 = 9_863
    }

    function test_getPaymentBreakdown_onePaymentOneSecondBeforeDue() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            loan,
            10_000_000 - 1,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    9_863);
    }

    function test_getPaymentBreakdown_onePaymentOnePeriodLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            loan,
            10_000_000 + 30 days,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    23_013);  // 9_863 + (1_000_000 * 0.16 * (1 * 30/365)) = 9_863 + 13_150
    }

    function test_getPaymentBreakdown_onePaymentTwoPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            loan,
            10_000_000 + (2 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    36_164);  // 9_863 + (1_000_000 * 0.16 * (2 * 30/365)) = 9_863 + 26_301
    }

    function test_getPaymentBreakdown_onePaymentThreePeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            loan,
            10_000_000 + (3 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    49_315);  // 9_863 + (1_000_000 * 0.16 * (3 * 30/365)) = 9_863 + 39_452
    }

    function test_getPaymentBreakdown_onePaymentFourPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            loan,
            10_000_000 + (4 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    62_465);  // 9_863 + (1_000_000 * 0.16 * (4 * 30/365)) = 9_863 + 52_602
    }

}

contract MapleLoanLogic_GetPeriodicInterestRateTests is TestUtils {

    MapleLoanHarness internal loan;

    function setUp() external {
        loan = new MapleLoanHarness();
    }

    function test_getPeriodicInterestRate() external {
        assertEq(loan.__getPeriodicInterestRate(0.12 ether, 365 days),      0.12 ether);  // 12%
        assertEq(loan.__getPeriodicInterestRate(0.12 ether, 365 days / 12), 0.01 ether);  // 1%
    }

}

contract MapleLoanLogic_GetUnaccountedAmountTests is TestUtils {

    MapleLoanHarness internal loan;
    MockERC20        internal collateralAsset;
    MockERC20        internal fundsAsset;
    MockERC20        internal token;

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 18);
        fundsAsset      = new MockERC20("Funds Asset", "FA", 6);
        loan            = new MapleLoanHarness();
        token           = new MockERC20("Token", "T", 18);

        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setFundsAsset(address(fundsAsset));
    }

    function test_getUnaccountedAmount_randomToken() external {
        assertEq(loan.getUnaccountedAmount(address(token)), 0);

        token.mint(address(loan), 100);

        assertEq(loan.getUnaccountedAmount(address(token)), 100);

        loan.__setDrawableFunds(10);

        assertEq(loan.getUnaccountedAmount(address(token)), 100);  // No change

        loan.__setDrawableFunds(0);

        assertEq(loan.getUnaccountedAmount(address(token)), 100);  // No change

        loan.__setDrawableFunds(0);
        loan.__setCollateral(10);

        assertEq(loan.getUnaccountedAmount(address(token)), 100);  // No change

        token.mint(address(loan), type(uint256).max - 100);

        assertEq(loan.getUnaccountedAmount(address(token)), type(uint256).max);
    }

    function test_getUnaccountedAmount_withDrawableFunds(uint256 balance_, uint256 drawableFunds_) external {
        drawableFunds_ = constrictToRange(drawableFunds_, 0, balance_);

        fundsAsset.mint(address(loan), balance_);

        loan.__setDrawableFunds(drawableFunds_);

        assertEq(loan.getUnaccountedAmount(address(fundsAsset)), balance_ - drawableFunds_);
    }

    function test_getUnaccountedAmount_withCollateral(uint256 balance_, uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 0, balance_);

        collateralAsset.mint(address(loan), balance_);

        loan.__setCollateral(collateral_);

        assertEq(loan.getUnaccountedAmount(address(collateralAsset)), balance_ - collateral_);
    }

    function test_getUnaccountedAmount_complex(uint256 balance_, uint256 collateral_, uint256 drawableFunds_) external {
        MockERC20 zeroDecToken = new MockERC20("Token", "T", 0);

        loan.__setFundsAsset(address(zeroDecToken));
        loan.__setCollateralAsset(address(zeroDecToken));

        balance_        = constrictToRange(balance_,        128, type(uint256).max);
        collateral_     = constrictToRange(collateral_,     0, balance_ >> 2);
        drawableFunds_  = constrictToRange(drawableFunds_,  0, balance_ >> 2);

        zeroDecToken.mint(address(loan), balance_);

        loan.__setDrawableFunds(drawableFunds_);
        loan.__setCollateral(collateral_);

        assertEq(loan.getUnaccountedAmount(address(zeroDecToken)), balance_ - collateral_ - drawableFunds_);
    }

    function test_getUnaccountedAmount_collateralAsset() external {
        assertEq(loan.getUnaccountedAmount(address(collateralAsset)), 0);

        collateralAsset.mint(address(loan), 1);

        assertEq(loan.getUnaccountedAmount(address(collateralAsset)), 1);

        collateralAsset.mint(address(loan), type(uint256).max - 1);

        assertEq(loan.getUnaccountedAmount(address(collateralAsset)), type(uint256).max);
    }

    function test_getUnaccountedAmount_fundsAsset() external {
        assertEq(loan.getUnaccountedAmount(address(fundsAsset)), 0);

        fundsAsset.mint(address(loan), 1);

        assertEq(loan.getUnaccountedAmount(address(fundsAsset)), 1);

        fundsAsset.mint(address(loan), type(uint256).max - 1);

        assertEq(loan.getUnaccountedAmount(address(fundsAsset)), type(uint256).max);
    }

    function test_getUnaccountedAmount_newFundsLtDrawableFunds(uint256 drawableFunds) external {
        drawableFunds = constrictToRange(drawableFunds, 1, type(uint256).max);

        loan.__setDrawableFunds(drawableFunds);

        fundsAsset.mint(address(loan), drawableFunds - 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        loan.getUnaccountedAmount(address(fundsAsset));

        fundsAsset.mint(address(loan), 1);  // Mint just enough to not underflow

        loan.getUnaccountedAmount(address(fundsAsset));
    }

    function test_getUnaccountedAmount_newFundsLtCollateral(uint256 collateral) external {
        collateral = constrictToRange(collateral, 1, type(uint256).max);

        loan.__setCollateral(collateral);

        collateralAsset.mint(address(loan), collateral - 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        loan.getUnaccountedAmount(address(collateralAsset));

        collateralAsset.mint(address(loan), 1);  // Mint just enough to not underflow

        loan.getUnaccountedAmount(address(collateralAsset));
    }

    function test_getUnaccountedAmount_drawableFunds(uint256 drawableFunds, uint256 newFunds) external {
        drawableFunds = constrictToRange(drawableFunds, 1,             type(uint256).max / 2);
        newFunds      = constrictToRange(newFunds,      drawableFunds, type(uint256).max - drawableFunds);

        loan.__setDrawableFunds(drawableFunds);

        fundsAsset.mint(address(loan), newFunds);

        uint256 unaccountedAmount = loan.getUnaccountedAmount(address(fundsAsset));

        assertEq(unaccountedAmount, newFunds - drawableFunds);
    }

    function test_getUnaccountedAmount_collateral(uint256 collateral, uint256 newCollateral) external {
        collateral    = constrictToRange(collateral,    1,          type(uint256).max / 2);
        newCollateral = constrictToRange(newCollateral, collateral, type(uint256).max - collateral);

        loan.__setCollateral(collateral);

        collateralAsset.mint(address(loan), newCollateral);

        uint256 unaccountedAmount = loan.getUnaccountedAmount(address(collateralAsset));

        assertEq(unaccountedAmount, newCollateral - collateral);
    }

    function test_getUnaccountedAmount_drawableFundsAndAndCollateral(
        uint256 drawableFunds,
        uint256 collateral,
        uint256 newFunds,
        uint256 newCollateral
    )
        external
    {
        drawableFunds  = constrictToRange(drawableFunds,  1,             type(uint256).max / 4);
        collateral     = constrictToRange(collateral,     1,             type(uint256).max / 2);
        newFunds       = constrictToRange(newFunds,       drawableFunds, type(uint256).max - drawableFunds);
        newCollateral  = constrictToRange(newCollateral,  collateral,    type(uint256).max - collateral);

        loan.__setDrawableFunds(drawableFunds);
        loan.__setCollateral(collateral);

        fundsAsset.mint(address(loan), newFunds);
        collateralAsset.mint(address(loan), newCollateral);

        uint256 unaccountedAmountFundsAsset      = loan.getUnaccountedAmount(address(fundsAsset));
        uint256 unaccountedAmountCollateralAsset = loan.getUnaccountedAmount(address(collateralAsset));

        assertEq(unaccountedAmountFundsAsset,      newFunds - drawableFunds);
        assertEq(unaccountedAmountCollateralAsset, newCollateral - collateral);
    }

    function test_getUnaccountedAmount_drawableFundsAndAndCollateral_fundsAssetEqCollateralAsset(
        uint256 drawableFunds,
        uint256 collateral,
        uint256 newFunds
    )
        external
    {
        loan.__setCollateralAsset(address(fundsAsset));

        drawableFunds  = constrictToRange(drawableFunds,  1, type(uint256).max / 6);  // Sum of maxes must be less than half of type(uint256).max
        collateral     = constrictToRange(collateral,     1, type(uint256).max / 6);

        newFunds = constrictToRange(
            newFunds,
            drawableFunds + collateral,
            type(uint256).max - (drawableFunds + collateral)
        );

        loan.__setDrawableFunds(drawableFunds);
        loan.__setCollateral(collateral);

        fundsAsset.mint(address(loan), newFunds);

        uint256 unaccountedAmount = loan.getUnaccountedAmount(address(fundsAsset));

        assertEq(unaccountedAmount, newFunds - drawableFunds - collateral);
    }

}

contract MapleLoanLogic_InitializeTests is TestUtils {

    address    defaultBorrower;
    address[2] defaultAssets;
    uint256[3] defaultTermDetails;
    uint256[3] defaultAmounts;
    uint256[4] defaultRates;
    uint256[2] defaultFees;

    MapleGlobalsMock       globals;
    ConstructableMapleLoan loan;
    MockERC20              token1;
    MockERC20              token2;
    MockFactory            factory;
    MockFeeManager         feeManager;

    address governor = address(new Address());

    function setUp() external {
        feeManager = new MockFeeManager();
        globals    = new MapleGlobalsMock(governor, address(0));
        token1     = new MockERC20("Token0", "T0", 0);
        token2     = new MockERC20("Token1", "T1", 0);

        factory = new MockFactory(address(globals));

        // Happy path dummy arguments to pass to initialize().
        defaultBorrower    = address(new Address());
        defaultAssets      = [address(token1), address(token2)];
        defaultTermDetails = [uint256(1), uint256(20 days), uint256(3)];
        defaultAmounts     = [uint256(5), uint256(4_000_000), uint256(0)];
        defaultRates       = [uint256(6), uint256(7), uint256(8), uint256(9)];
        defaultFees        = [uint256(0), uint256(0)];

        globals.setValidBorrower(defaultBorrower,        true);
        globals.setValidCollateralAsset(address(token1), true);
        globals.setValidPoolAsset(address(token2),       true);
    }

    function test_initialize() external {
        // Call initialize() with all happy path arguments, should not revert().
        vm.startPrank(address(factory));
        loan = new ConstructableMapleLoan(address(factory), defaultBorrower, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees);
        vm.stopPrank();

        assertEq(loan.collateralAsset(), defaultAssets[0]);
        assertEq(loan.fundsAsset(),      defaultAssets[1]);

        assertEq(loan.gracePeriod(),       defaultTermDetails[0]);
        assertEq(loan.paymentInterval(),   defaultTermDetails[1]);
        assertEq(loan.paymentsRemaining(), defaultTermDetails[2]);

        assertEq(loan.collateralRequired(), defaultAmounts[0]);
        assertEq(loan.principalRequested(), defaultAmounts[1]);
        assertEq(loan.endingPrincipal(),    defaultAmounts[2]);

        assertEq(loan.interestRate(),        defaultRates[0]);
        assertEq(loan.closingRate(),         defaultRates[1]);
        assertEq(loan.lateFeeRate(),         defaultRates[2]);
        assertEq(loan.lateInterestPremium(), defaultRates[3]);
    }

    function test_initialize_invalidPrincipal() external {
        uint256[3] memory amounts;

        // Set principal requested to invalid amount.
        amounts[1] = 0;

        // Call initialize, expecting to revert with correct error message.
        vm.expectRevert("MLI:I:INVALID_PRINCIPAL");
        vm.startPrank(address(factory));
        new ConstructableMapleLoan(address(factory), defaultBorrower, address(feeManager), defaultAssets, defaultTermDetails, amounts, defaultRates, defaultFees);
    }

    function test_initialize_invalidEndingPrincipal() external {
        uint256[3] memory amounts;

        // Set ending principal to invalid amount.
        amounts[1] = 12;
        amounts[2] = 24;

        // Call initialize(), expecting to revert with correct error message.
        vm.expectRevert("MLI:I:INVALID_ENDING_PRINCIPAL");
        vm.startPrank(address(factory));
        new ConstructableMapleLoan(address(factory), defaultBorrower, address(feeManager), defaultAssets, defaultTermDetails, amounts, defaultRates, defaultFees);
    }

    function test_initialize_invalidPaymentInterval() external {
        uint256[3] memory termDetails = defaultTermDetails;

        termDetails[1] = 0;

        // Call initialize(), expecting to revert with correct error message.
        vm.expectRevert("MLI:I:INVALID_PAYMENT_INTERVAL");
        vm.startPrank(address(factory));
        new ConstructableMapleLoan(address(factory), defaultBorrower, address(feeManager), defaultAssets, termDetails, defaultAmounts, defaultRates, defaultFees);
    }

    function test_initialize_invalidPaymentsRemaining() external {
        uint256[3] memory termDetails = defaultTermDetails;

        termDetails[2] = 0;

        // Call initialize(), expecting to revert with correct error message.
        vm.expectRevert("MLI:I:INVALID_PAYMENTS_REMAINING");
        vm.startPrank(address(factory));
        new ConstructableMapleLoan(address(factory), defaultBorrower, address(feeManager), defaultAssets, termDetails, defaultAmounts, defaultRates, defaultFees);
    }

    function test_initialize_zeroBorrower() external {
        // Call initialize, expecting to revert with correct error message.
        vm.expectRevert("MLI:I:ZERO_BORROWER");
        vm.startPrank(address(factory));
        new ConstructableMapleLoan(address(factory), address(0), address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees);
    }

    function test_initialize_invalidBorrower() external {
        // Call initialize, expecting to revert with correct error message.
        vm.expectRevert("MLI:I:INVALID_BORROWER");
        vm.startPrank(address(factory));
        new ConstructableMapleLoan(address(factory), address(1234), address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees);
    }

}

contract MapleLoanLogic_MakePaymentTests is TestUtils {

    uint256 constant MAX_TOKEN_AMOUNT     = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 constant UNDERFLOW_ERROR_CODE = 17;

    address borrower = address(new Address());
    address governor = address(new Address());

    address lender;

    MapleGlobalsMock globals;
    MapleLoanHarness loan;
    MockERC20        fundsAsset;
    MockFactory      factory;
    MockFeeManager   feeManager;

    function setUp() external {
        feeManager = new MockFeeManager();
        fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        lender     = address(new MockLoanManager());
        globals    = new MapleGlobalsMock(governor, MockLoanManager(lender).factory());
        loan       = new MapleLoanHarness();

        factory = new MockFactory(address(globals));

        loan.__setBorrower(borrower);
        loan.__setFactory(address(factory));
        loan.__setFeeManager(address(feeManager));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setLender(lender);
    }

    function setupLoan(
        address loan_,
        uint256 principalRequested_,
        uint256 paymentsRemaining_,
        uint256 paymentInterval_,
        uint256 interestRate_,
        uint256 endingPrincipal_
    ) internal {
        MapleLoanHarness(loan_).__setDrawableFunds(principalRequested_);
        MapleLoanHarness(loan_).__setEndingPrincipal(endingPrincipal_);
        MapleLoanHarness(loan_).__setInterestRate(interestRate_);
        MapleLoanHarness(loan_).__setNextPaymentDueDate(block.timestamp + paymentInterval_);
        MapleLoanHarness(loan_).__setPaymentInterval(paymentInterval_);
        MapleLoanHarness(loan_).__setPaymentsRemaining(paymentsRemaining_);
        MapleLoanHarness(loan_).__setPrincipalRequested(principalRequested_);
        MapleLoanHarness(loan_).__setPrincipal(principalRequested_);

        fundsAsset.mint(address(loan), principalRequested_);
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
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  2,   50);
        interestRate_       = constrictToRange(interestRate_,       0,   1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_);

        assertEq(loan.drawableFunds(),      principalRequested_);
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_);
        assertEq(loan.principal(),          principalRequested_);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 additionalAmount;

        if (expectedPayment > loan.drawableFunds()) {
            fundsAsset.mint(address(loan), additionalAmount = (expectedPayment - loan.drawableFunds()));
        }

        vm.prank(borrower);
        ( principal, interest, ) = loan.makePayment(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                 expectedPayment);
        assertEq(loan.drawableFunds(),      principalRequested_ + additionalAmount - totalPaid);
        assertEq(loan.principal(),          principalRequested_ - principal);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + (2 * paymentInterval_));
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_ - 1);
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
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  2,   50);
        interestRate_       = constrictToRange(interestRate_,       0,   1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_);

        assertEq(loan.drawableFunds(),      principalRequested_);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_);
        assertEq(loan.principal(),          principalRequested_);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        fundsAsset.mint(address(loan), fundsForPayments);

        ( principal, interest, ) = loan.makePayment(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                 expectedPayment);
        assertEq(loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(loan.principal(),          principalRequested_ - principal);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + (2 * paymentInterval_));
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_ - 1);
    }

    function test_makePayment_insufficientAmount(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100,        365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  1,          50);
        interestRate_       = constrictToRange(interestRate_,       1,          1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 10_000_000, MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,          principalRequested_);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_);

        // Drawdown all loan funds.
        vm.startPrank(borrower);
        loan.drawdownFunds(loan.drawableFunds(), borrower);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        vm.assume(installmentToPay > 0);

        fundsAsset.mint(address(loan), installmentToPay - 1);

        // Try to pay with insufficient amount, should underflow.
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.makePayment(0);

        // Mint remaining amount.
        fundsAsset.mint(address(loan), 1);

        // Pay off loan with exact amount.
        loan.makePayment(0);
    }

    function test_makePayment_lastPaymentClearsLoan(
        uint256 paymentInterval_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 endingPrincipal_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100, 365 days);
        interestRate_       = constrictToRange(interestRate_,       0,   1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);

        // Test last payment.
        setupLoan(address(loan), principalRequested_, 1, paymentInterval_, interestRate_, endingPrincipal_);

        // Drawdown all loan funds.
        vm.startPrank(borrower);
        loan.drawdownFunds(loan.drawableFunds(), borrower);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        fundsAsset.mint(address(loan), installmentToPay);

        // Last payment should pay off the principal.
        assertEq(loan.paymentsRemaining(), 1);
        assertEq(principal,                 loan.principal());

        // Pay off rest of loan, expecting loan accounting to be reset.
        ( principal, interest, ) = loan.makePayment(0);

        uint256 actualInstallmentAmount = principal + interest;

        assertEq(principal,               principalRequested_);
        assertEq(actualInstallmentAmount, installmentToPay);
        assertEq(loan.drawableFunds(),   0);

        // Make sure loan accounting is cleared from _clearLoanAccounting().
        assertEq(loan.gracePeriod(),         0);
        assertEq(loan.paymentInterval(),     0);
        assertEq(loan.interestRate(),        0);
        assertEq(loan.closingRate(),         0);
        assertEq(loan.lateFeeRate(),         0);
        assertEq(loan.lateInterestPremium(), 0);
        assertEq(loan.endingPrincipal(),     0);
        assertEq(loan.nextPaymentDueDate(),  0);
        assertEq(loan.paymentsRemaining(),   0);
        assertEq(loan.principal(),           0);
    }

    function test_makePayment_withRefinanceInterest(
        uint256 paymentInterval_,
        uint256 paymentsRemaining_,
        uint256 interestRate_,
        uint256 principalRequested_,
        uint256 refinanceInterest_
    )
        external
    {
        paymentInterval_    = constrictToRange(paymentInterval_,    100, 365 days);
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  2,   50);
        interestRate_       = constrictToRange(interestRate_,       0,   1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 100, MAX_TOKEN_AMOUNT);
        refinanceInterest_  = constrictToRange(refinanceInterest_,  100, MAX_TOKEN_AMOUNT);

        setupLoan(address(loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, 0);

        loan.__setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        fundsAsset.mint(address(loan), fundsForPayments);

        assertEq(loan.drawableFunds(),      principalRequested_);
        assertEq(loan.principal(),          principalRequested_);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_);
        assertEq(loan.refinanceInterest(),  refinanceInterest_);

        ( principal, interest, ) = loan.makePayment(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                 expectedPayment);
        assertEq(loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(loan.principal(),          principalRequested_ - principal);
        assertEq(loan.nextPaymentDueDate(), block.timestamp + (2 * paymentInterval_));
        assertEq(loan.paymentsRemaining(),  paymentsRemaining_ - 1);
        assertEq(loan.refinanceInterest(),  0);
    }

    function test_makePayment_amountSmallerThanFees() external {
        setupLoan(address(loan), 1_000_000, 2, 365 days, 0, 0);

        feeManager.__setDelegateServiceFee(100);
        feeManager.__setPlatformServiceFee(100);
        feeManager.__setServiceFeesToPay(200);

        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getNextPaymentBreakdown();

        uint256 payment = principal + interest + fees;

        vm.prank(address(loan));
        fundsAsset.approve(address(feeManager), type(uint256).max);

        fundsAsset.mint(borrower, payment);

        vm.startPrank(borrower);
        loan.drawdownFunds(loan.drawableFunds(), borrower);
        fundsAsset.approve(address(loan), payment);
        loan.returnFunds(payment - (fees / 2));
        ( principal, interest, ) = loan.makePayment(fees / 2);

        assertEq(loan.drawableFunds(), 0);
    }

    function test_makePayment_noAmount() external {
        setupLoan(address(loan), 1_000_000, 2, 365 days, 0, 0);

        feeManager.__setDelegateServiceFee(100);
        feeManager.__setPlatformServiceFee(100);
        feeManager.__setServiceFeesToPay(200);

        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getNextPaymentBreakdown();

        uint256 payment = principal + interest + fees;

        vm.prank(address(loan));
        fundsAsset.approve(address(feeManager), type(uint256).max);

        fundsAsset.mint(borrower, payment);

        vm.startPrank(borrower);
        loan.drawdownFunds(loan.drawableFunds(), borrower);
        fundsAsset.approve(address(loan), payment);
        loan.returnFunds(payment);
        ( principal, interest, ) = loan.makePayment(0);

        assertEq(loan.drawableFunds(), 0);
    }

}

contract MapleLoanLogic_PostCollateralTests is TestUtils {

    uint256 constant MAX_COLLATERAL = type(uint256).max - 1;
    uint256 constant MIN_COLLATERAL = 0;

    MapleGlobalsMock globals;
    MapleLoanHarness loan;
    MockERC20        collateralAsset;
    MockFactory      factory;


    function setUp() external {
        loan            = new MapleLoanHarness();
        collateralAsset = new MockERC20("CollateralAsset", "CA", 0);
        globals         = new MapleGlobalsMock(address(0), address(0));
        factory         = new MockFactory(address(globals));

        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setFactory(address(factory));
    }

    function test_postCollateral_invalidCollateralAsset() external {
        loan.__setCollateralAsset(address(new MockERC20("SomeAsset", "SA", 0)));

        collateralAsset.mint(address(loan), 1);

        vm.expectRevert("ML:PC:TRANSFER_FROM_FAILED");
        loan.postCollateral(1);
    }

    function test_postCollateral_once(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL);

        collateralAsset.mint(address(loan), collateral_);

        assertEq(loan.postCollateral(0), collateral_);
        assertEq(loan.collateral(),      collateral_);
    }

    function test_postCollateral_multiple(uint256 collateral_, uint256 posts_) external {
        posts_      = constrictToRange(posts_,      2,              10);
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL / posts_);

        for (uint256 i = 1; i <= posts_; ++i) {
            collateralAsset.mint(address(loan), collateral_);

            assertEq(loan.postCollateral(0), collateral_);
            assertEq(loan.collateral(),      collateral_ * i);
        }
    }

    function test_postCollateral_withUnaccountedFundsAsset() external {
        MockERC20 fundsAsset = new MockERC20("FundsAsset", "FA", 0);

        loan.__setFundsAsset(address(fundsAsset));

        fundsAsset.mint(address(loan), 1);
        collateralAsset.mint(address(loan), 1);

        loan.postCollateral(0);

        assertEq(loan.getUnaccountedAmount(address(fundsAsset)), 1);
    }

}

contract MapleLoanLogic_ProposeNewTermsTests is TestUtils {

    MapleGlobalsMock globals;
    MockFactory      factory;
    MapleLoanHarness loan;

    address borrower = address(new Address());

    function setUp() external {
        globals = new MapleGlobalsMock(address(0), address(0));
        factory = new MockFactory(address(globals));
        loan    = new MapleLoanHarness();

        loan.__setBorrower(borrower);
        loan.__setFactory(address(factory));
    }

    function test_proposeNewTerms(address refinancer_, uint256 deadline_, uint256 newCollateralRequired_, uint256 newEndingPrincipal_, uint256 newInterestRate_) external {
        deadline_ = block.timestamp + constrictToRange(deadline_, 1, 2000 days);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", newCollateralRequired_);
        data[1] = abi.encodeWithSignature("setEndingPrincipal(uint256)",    newEndingPrincipal_);
        data[2] = abi.encodeWithSignature("setInterestRate(uint256)",       newInterestRate_);

        vm.prank(borrower);
        bytes32 proposedRefinanceCommitment = loan.proposeNewTerms(refinancer_, deadline_, data);

        assertEq(proposedRefinanceCommitment, keccak256(abi.encode(refinancer_, deadline_, data)));
        assertEq(loan.refinanceCommitment(), keccak256(abi.encode(refinancer_, deadline_, data)));
    }

    function test_proposeNewTerms_emptyArray(address refinancer_, uint256 deadline_) external {
        deadline_ = block.timestamp + constrictToRange(deadline_, 1, 2000 days);

        bytes[] memory data = new bytes[](0);

        vm.prank(borrower);
        bytes32 proposedRefinanceCommitment = loan.proposeNewTerms(refinancer_, deadline_, data);

        assertEq(proposedRefinanceCommitment, bytes32(0));
        assertEq(loan.refinanceCommitment(), bytes32(0));
    }
}

contract MapleLoanLogic_RejectNewTermsTests is TestUtils {

    MapleGlobalsMock globals;
    MapleLoanHarness loan;
    MockFactory      factory;
    Refinancer       refinancer;

    address borrower = address(new Address());

    function setUp() external {
        globals    = new MapleGlobalsMock(address(0), address(0));
        factory    = new MockFactory(address(globals));
        loan       = new MapleLoanHarness();
        refinancer = new Refinancer();

        loan.__setBorrower(borrower);
        loan.__setFactory(address(factory));
    }

    function test_rejectNewTerms_commitmentMismatch_emptyCallsArray() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        vm.expectRevert("ML:RNT:COMMITMENT_MISMATCH");
        loan.rejectNewTerms(address(refinancer), deadline, new bytes[](0));
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedRefinancer() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        address anotherRefinancer = address(new Refinancer());
        vm.expectRevert("ML:RNT:COMMITMENT_MISMATCH");
        loan.rejectNewTerms(anotherRefinancer, deadline, calls);
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedDeadline() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        vm.expectRevert("ML:RNT:COMMITMENT_MISMATCH");
        loan.rejectNewTerms(address(refinancer), deadline + 1, calls);
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedCalls() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(2));

        vm.expectRevert("ML:RNT:COMMITMENT_MISMATCH");
        loan.rejectNewTerms(address(refinancer), deadline, calls);
    }

    function test_rejectNewTerms() external {
        uint256 deadline     = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(1));

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, calls);

        assertEq(loan.refinanceCommitment(), keccak256(abi.encode(address(refinancer), deadline, calls)));

        loan.rejectNewTerms(address(refinancer), deadline, calls);

        assertEq(loan.refinanceCommitment(), bytes32(0));
    }

}

contract MapleLoanLogic_RemoveCollateralTests is TestUtils {

    uint256 constant MAX_COLLATERAL = type(uint256).max - 1;
    uint256 constant MIN_COLLATERAL = 0;

    uint256 constant MAX_PRINCIPAL = type(uint256).max - 1;
    uint256 constant MIN_PRINCIPAL = 1;

    MapleGlobalsMock globals;
    MockFactory      factory;
    MapleLoanHarness loan;
    MockERC20        collateralAsset;

    address borrower = address(new Address());

    function setUp() external {
        collateralAsset = new MockERC20("CollateralAsset", "CA", 0);
        globals         = new MapleGlobalsMock(address(0), address(0));
        factory         = new MockFactory(address(globals));
        loan            = new MapleLoanHarness();

        loan.__setBorrower(borrower);
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setFactory(address(factory));
        loan.__setPrincipalRequested(1);
    }

    function test_removeCollateral_fullAmountWithNoEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, MAX_COLLATERAL);

        collateralAsset.mint(address(loan), collateral_);

        loan.postCollateral(0);

        vm.prank(borrower);
        loan.removeCollateral(collateral_, borrower);

        assertEq(loan.collateral(),                        0);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(collateralAsset.balanceOf(borrower),      collateral_);
    }

    function test_removeCollateral_partialAmountWithNoEncumbrances(uint256 collateral_, uint256 removedAmount_) external {
        collateral_    = constrictToRange(collateral_,    2, MAX_COLLATERAL);
        removedAmount_ = constrictToRange(removedAmount_, 1, collateral_);

        collateralAsset.mint(address(loan), collateral_);

        loan.postCollateral(0);

        vm.prank(borrower);
        loan.removeCollateral(removedAmount_, borrower);

        assertEq(loan.collateral(),                        collateral_ - removedAmount_);
        assertEq(collateralAsset.balanceOf(address(loan)), collateral_ - removedAmount_);
        assertEq(collateralAsset.balanceOf(borrower),      removedAmount_);
    }

    function test_removeCollateral_insufficientCollateralWithNoEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL);

        collateralAsset.mint(address(loan), collateral_);

        loan.postCollateral(0);

        vm.prank(borrower);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.removeCollateral(collateral_ + 1, borrower);
    }

    function test_removeCollateral_sameAssetAsFundingAsset(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, MAX_COLLATERAL);

        loan.__setFundsAsset(address(collateralAsset));

        collateralAsset.mint(address(loan), collateral_);

        loan.postCollateral(0);

        assertEq(loan.collateral(),                        collateral_);
        assertEq(collateralAsset.balanceOf(address(loan)), collateral_);
        assertEq(collateralAsset.balanceOf(borrower),      0);

        vm.prank(borrower);
        loan.removeCollateral(collateral_, borrower);

        assertEq(loan.collateral(),                        0);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(collateralAsset.balanceOf(borrower),      collateral_);
    }

    function test_removeCollateral_fullAmount_drawableFundsGtPrincipal(
        uint256 collateralRequired_,
        uint256 principalRequested_,
        uint256 principal_,
        uint256 drawableFunds_,
        uint256 collateral_
    )
        external
    {
        collateralRequired_ = constrictToRange(collateralRequired_, 1,          type(uint256).max);
        principalRequested_ = constrictToRange(principalRequested_, 1,          type(uint256).max);
        principal_          = constrictToRange(principal_,          0,          principalRequested_);
        drawableFunds_      = constrictToRange(drawableFunds_,      principal_, type(uint256).max);
        collateral_         = constrictToRange(collateral_,         1,          type(uint256).max);

        loan.__setPrincipalRequested(principalRequested_);
        loan.__setPrincipal(principal_);
        loan.__setDrawableFunds(drawableFunds_);
        loan.__setCollateralRequired(collateralRequired_);

        collateralAsset.mint(address(loan), collateral_);

        loan.postCollateral(0);

        vm.prank(borrower);
        loan.removeCollateral(collateral_, borrower);

        assertEq(loan.collateral(),                        0);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(collateralAsset.balanceOf(borrower),      collateral_);
    }

    function test_removeCollateral_fullAmount_noPrincipal(uint256 collateralRequired_) external {
        collateralRequired_ = constrictToRange(collateralRequired_, 1, type(uint256).max);

        loan.__setPrincipal(0);
        loan.__setCollateralRequired(collateralRequired_);

        collateralAsset.mint(address(loan), collateralRequired_);

        loan.postCollateral(0);

        vm.prank(borrower);
        loan.removeCollateral(collateralRequired_, borrower);

        assertEq(loan.collateral(),                        0);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(collateralAsset.balanceOf(borrower),      collateralRequired_);
    }

    function test_removeCollateral_partialAmountWithEncumbrances(uint256 collateralRequired_, uint256 collateral_) external {
        collateralRequired_ = constrictToRange(collateralRequired_, 1,                       type(uint256).max - 1);
        collateral_         = constrictToRange(collateral_,         collateralRequired_ + 1, type(uint256).max);

        loan.__setPrincipal(1);
        loan.__setCollateralRequired(collateralRequired_);

        collateralAsset.mint(address(loan), collateral_);

        loan.postCollateral(0);

        vm.startPrank(borrower);
        vm.expectRevert("ML:RC:INSUFFICIENT_COLLATERAL");
        loan.removeCollateral(collateral_ - collateralRequired_ + 1, borrower);

        loan.removeCollateral(collateral_ - collateralRequired_, borrower);
        vm.stopPrank();

        assertEq(loan.collateral(),                        collateralRequired_);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralRequired_);
        assertEq(collateralAsset.balanceOf(borrower),      collateral_ - collateralRequired_);
    }

    function test_removeCollateral_cannotRemoveAnyAmountWithEncumbrances() external {
        loan.__setPrincipal(1);
        loan.__setCollateralRequired(1000);

        collateralAsset.mint(address(loan), 1000);

        loan.postCollateral(0);

        vm.prank(borrower);
        vm.expectRevert("ML:RC:INSUFFICIENT_COLLATERAL");
        loan.removeCollateral(1, borrower);
    }

    function test_removeCollateral_cannotRemoveFullAmountWithEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, type(uint256).max);

        loan.__setPrincipal(1);
        loan.__setCollateralRequired(1);

        collateralAsset.mint(address(loan), collateral_);

        loan.postCollateral(0);

        vm.prank(borrower);
        vm.expectRevert("ML:RC:INSUFFICIENT_COLLATERAL");
        loan.removeCollateral(collateral_, borrower);
    }

    function test_removeCollateral_cannotRemovePartialAmountWithEncumbrances(uint256 collateral_, uint256 collateralRemoved_) external {
        collateral_        = constrictToRange(collateral_,        2, type(uint256).max - 1);
        collateralRemoved_ = constrictToRange(collateralRemoved_, 1, collateral_ - 1);

        loan.__setPrincipal(1);
        loan.__setCollateralRequired(collateral_);

        collateralAsset.mint(address(loan), collateral_);

        loan.postCollateral(0);

        vm.prank(borrower);
        vm.expectRevert("ML:RC:INSUFFICIENT_COLLATERAL");
        loan.removeCollateral(collateralRemoved_, borrower);
    }

    function test_removeCollateral_transferFailed() external {
        RevertingERC20 revertingAsset = new RevertingERC20();

        loan.__setCollateralAsset(address(revertingAsset));

        revertingAsset.mint(address(loan), 1);

        loan.postCollateral(0);

        vm.prank(borrower);
        vm.expectRevert("ML:RC:TRANSFER_FAILED");
        loan.removeCollateral(1, borrower);
    }

}

contract MapleLoanLogic_RepossessTests is TestUtils {

    address lender;

    MapleGlobalsMock globals;
    MockFactory      factory;
    MapleLoanHarness loan;
    MockERC20        collateralAsset;
    MockERC20        fundsAsset;

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        globals         = new MapleGlobalsMock(address(0), address(0));
        factory         = new MockFactory(address(globals));
        fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        lender          = address(new MockLoanManager());
        loan            = new MapleLoanHarness();

        loan.__setCollateral(1);
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setDrawableFunds(1);
        loan.__setFactory(address(factory));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setGracePeriod(10);
        loan.__setLender(lender);
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipal(1);

        fundsAsset.mint(address(loan), 2);
        collateralAsset.mint(address(loan), 1);
    }

    function test_repossess() external {
        loan.__setNextPaymentDueDate(block.timestamp - 11);

        vm.prank(lender);
        loan.repossess(lender);

        assertEq(loan.drawableFunds(),              0);
        assertEq(loan.collateral(),                 0);
        assertEq(loan.nextPaymentDueDate(),         0);
        assertEq(loan.paymentsRemaining(),          0);
        assertEq(loan.principal(),                  0);
        assertEq(collateralAsset.balanceOf(lender), 1);
        assertEq(fundsAsset.balanceOf(lender),      2);
    }

    function test_repossess_beforePaymentDue() external {
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        vm.prank(lender);
        vm.expectRevert("ML:R:NOT_IN_DEFAULT");
        loan.repossess(lender);
    }

    function test_repossess_onPaymentDue() external {
        loan.__setNextPaymentDueDate(block.timestamp);

        vm.prank(lender);
        vm.expectRevert("ML:R:NOT_IN_DEFAULT");
        loan.repossess(lender);
    }

    function test_repossess_withinGracePeriod() external {
        loan.__setNextPaymentDueDate(block.timestamp - 5);

        vm.prank(lender);
        vm.expectRevert("ML:R:NOT_IN_DEFAULT");
        loan.repossess(lender);
    }

    function test_repossess_onGracePeriod() external {
        loan.__setNextPaymentDueDate(block.timestamp - 10);

        vm.prank(lender);
        vm.expectRevert("ML:R:NOT_IN_DEFAULT");
        loan.repossess(lender);
    }

    function test_repossess_fundsTransferFailed() external {
        RevertingERC20 token = new RevertingERC20();

        loan.__setNextPaymentDueDate(block.timestamp - 11);
        loan.__setFundsAsset(address(token));

        token.mint(address(loan), 1);

        vm.prank(lender);
        vm.expectRevert("ML:R:F_TRANSFER_FAILED");
        loan.repossess(lender);
    }

    function test_repossess_collateralTransferFailed() external {
        RevertingERC20 token = new RevertingERC20();

        loan.__setNextPaymentDueDate(block.timestamp - 11);
        loan.__setCollateralAsset(address(token));

        token.mint(address(loan), 1);

        vm.prank(lender);
        vm.expectRevert("ML:R:C_TRANSFER_FAILED");
        loan.repossess(lender);
    }

}

contract MapleLoanLogic_ReturnFundsTests is TestUtils {

    MapleGlobalsMock globals;
    MockFactory      factory;
    MapleLoanHarness internal loan;
    MockERC20        internal fundsAsset;

    function setUp() external {
        globals    = new MapleGlobalsMock(address(0), address(0));
        factory    = new MockFactory(address(globals));
        fundsAsset = new MockERC20("Funds Asset", "FA", 0);
        loan       = new MapleLoanHarness();

        loan.__setFactory(address(factory));
        loan.__setFundsAsset(address(fundsAsset));
    }

    function test_returnFunds(uint256 fundsToReturn_) external {
        fundsToReturn_ = constrictToRange(fundsToReturn_, 0, type(uint256).max >> 3);

        assertEq(loan.returnFunds(0),  0);
        assertEq(loan.drawableFunds(), 0);

        fundsAsset.mint(address(loan), fundsToReturn_);

        assertEq(loan.returnFunds(0),  fundsToReturn_);
        assertEq(loan.drawableFunds(), fundsToReturn_);

        fundsAsset.mint(address(loan), fundsToReturn_);

        assertEq(loan.returnFunds(0),  fundsToReturn_);
        assertEq(loan.drawableFunds(), 2 * fundsToReturn_);
    }

    function test_returnFundscollateralAsset() external {
        MockERC20 collateralAsset = new MockERC20("Collateral Asset", "CA", 0);

        loan.__setCollateralAsset(address(collateralAsset));

        assertEq(loan.returnFunds(0),  0);
        assertEq(loan.drawableFunds(), 0);

        collateralAsset.mint(address(loan), 1);

        assertEq(loan.returnFunds(0),  0);
        assertEq(loan.drawableFunds(), 0);
    }

}

contract MapleLoanLogic_ScaledExponentTests is TestUtils {

    MapleLoanHarness internal loan;

    function setUp() external {
        loan = new MapleLoanHarness();
    }

    function test_scaledExponent_setOne() external {
        assertEq(loan.__scaledExponent(10_000, 0, 10_000), 10_000);
        assertEq(loan.__scaledExponent(10_000, 1, 10_000), 10_000);
        assertEq(loan.__scaledExponent(10_000, 2, 10_000), 10_000);
        assertEq(loan.__scaledExponent(10_000, 3, 10_000), 10_000);

        assertEq(loan.__scaledExponent(20_000, 0, 10_000), 10_000);
        assertEq(loan.__scaledExponent(20_000, 1, 10_000), 20_000);
        assertEq(loan.__scaledExponent(20_000, 2, 10_000), 40_000);
        assertEq(loan.__scaledExponent(20_000, 3, 10_000), 80_000);

        assertEq(loan.__scaledExponent(10_100, 0, 10_000), 10_000);
        assertEq(loan.__scaledExponent(10_100, 1, 10_000), 10_100);
        assertEq(loan.__scaledExponent(10_100, 2, 10_000), 10_201);
        assertEq(loan.__scaledExponent(10_100, 3, 10_000), 10_303);
    }

    function test_scaledExponent_setTwo() external {
        assertEq(loan.__scaledExponent(12340, 18, 10), 440223147468745562613840184469885558370587691142634536960);
        assertEq(loan.__scaledExponent(12340, 19, 10), 543235363976432024265478787635838779029305210870011018608640);

        assertEq(loan.__scaledExponent(uint256(2 * 10_000 * 100), 100, uint256(10_000 * 100)), uint256(1267650600228229401496703205376 * 10_000 * 100));
        assertEq(loan.__scaledExponent(uint256(2 * 10_000 * 100), 120, uint256(10_000 * 100)), uint256(1329227995784915872903807060280344576 * 10_000 * 100));
        assertEq(loan.__scaledExponent(uint256(2 * 10_000 * 100), 140, uint256(10_000 * 100)), uint256(1393796574908163946345982392040522594123776 * 10_000 * 100));
        assertEq(loan.__scaledExponent(uint256(2 * 10_000 * 100), 160, uint256(10_000 * 100)), uint256(1461501637330902918203684832716283019655932542976 * 10_000 * 100));
        assertEq(loan.__scaledExponent(uint256(2 * 10_000 * 100), 168, uint256(10_000 * 100)), uint256(374144419156711147060143317175368453031918731001856 * 10_000 * 100));
        assertEq(loan.__scaledExponent(uint256(2 * 10_000 * 100), 180, uint256(10_000 * 100)), uint256(1532495540865888858358347027150309183618739122183602176 * 10_000 * 100));
        assertEq(loan.__scaledExponent(uint256(2 * 10_000 * 100), 200, uint256(10_000 * 100)), uint256(1606938044258990275541962092341162602522202993782792835301376 * 10_000 * 100));
        assertEq(loan.__scaledExponent(uint256(2 * 10_000 * 100), 216, uint256(10_000 * 100)), uint256(105312291668557186697918027683670432318895095400549111254310977536 * 10_000 * 100));
    }

}

contract MapleLoanLogic_SkimTests is TestUtils {

    MapleGlobalsMock globals;
    MapleLoanHarness loan;
    MockERC20        collateralAsset;
    MockERC20        fundsAsset;
    MockFactory      factory;

    address user = address(new Address());

    function setUp() external {
        collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        globals         = new MapleGlobalsMock(address(0), address(0));
        factory         = new MockFactory(address(globals));
        fundsAsset      = new MockERC20("Funds Asset", "FA", 0);
        loan            = new MapleLoanHarness();

        loan.__setCollateral(1);
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setDrawableFunds(1);
        loan.__setFactory(address(factory));
        loan.__setFundsAsset(address(fundsAsset));

        collateralAsset.mint(address(loan), 1);
        fundsAsset.mint(address(loan), 1);
    }

    function test_skimcollateralAsset() external {
        collateralAsset.mint(address(loan), 1);

        assertEq(collateralAsset.balanceOf(address(loan)), 2);
        assertEq(collateralAsset.balanceOf(user),          0);

        loan.skim(address(collateralAsset), user);

        assertEq(collateralAsset.balanceOf(address(loan)), 1);
        assertEq(collateralAsset.balanceOf(user),          1);
    }

    function test_skimfundsAsset() external {
        fundsAsset.mint(address(loan), 1);

        assertEq(fundsAsset.balanceOf(address(loan)), 2);
        assertEq(fundsAsset.balanceOf(user),          0);

        loan.skim(address(fundsAsset), user);

        assertEq(fundsAsset.balanceOf(address(loan)), 1);
        assertEq(fundsAsset.balanceOf(user),          1);
    }

    function test_skim_otherAsset() external {
        MockERC20 otherAsset = new MockERC20("Other Asset", "OA", 18);

        otherAsset.mint(address(loan), 1);

        assertEq(otherAsset.balanceOf(address(loan)), 1);
        assertEq(otherAsset.balanceOf(user),          0);

        loan.skim(address(otherAsset), user);

        assertEq(otherAsset.balanceOf(address(loan)), 0);
        assertEq(otherAsset.balanceOf(user),          1);
    }

}
