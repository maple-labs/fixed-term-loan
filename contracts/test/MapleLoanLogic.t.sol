// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { ConstructableMapleLoan, MapleLoanHarness } from "./harnesses/MapleLoanHarnesses.sol";

import { MapleGlobalsMock, MockFactory, RevertingERC20, MockFeeManager } from "./mocks/Mocks.sol";

import { Refinancer } from "../Refinancer.sol";

contract MapleLoanLogic_AcceptNewTermsTests is TestUtils {

    address    internal _defaultBorrower;
    address[2] internal _defaultAssets;
    uint256[3] internal _defaultTermDetails;
    uint256[3] internal _defaultAmounts;
    uint256[5] internal _defaultRates;
    uint256[2] internal _defaultFees;

    uint256 internal _start;

    MapleGlobalsMock       internal _globals;
    ConstructableMapleLoan internal _loan;
    Refinancer             internal _refinancer;
    MockERC20              internal _collateralAsset;
    MockERC20              internal _fundsAsset;
    MockFactory            internal _factory;
    MockFeeManager         internal _feeManager;

    function setUp() external {
        _globals    = new MapleGlobalsMock(address(this));
        _factory    = new MockFactory();
        _feeManager = new MockFeeManager();
        _refinancer = new Refinancer();

        // Set _initialize() parameters.
        _collateralAsset = new MockERC20("Token0", "T0", 0);
        _fundsAsset      = new MockERC20("Token1", "T1", 0);

        _defaultBorrower    = address(1);
        _defaultAssets      = [address(_collateralAsset), address(_fundsAsset)];
        _defaultTermDetails = [uint256(1), uint256(30 days), uint256(12)];
        _defaultAmounts     = [uint256(0), uint256(1000), uint256(0)];
        _defaultRates       = [uint256(0.10e18), uint256(7), uint256(8), uint256(9), uint256(0)];
        _defaultFees        = [uint256(0), uint256(0)];

        _globals.setValidBorrower(_defaultBorrower, true);

        _loan = new ConstructableMapleLoan(address(_factory), address(_globals), _defaultBorrower, address(_feeManager), _defaultAssets, _defaultTermDetails, _defaultAmounts, _defaultRates, _defaultFees);

        vm.warp(_start = 1_500_000_000);

        // TODO: prank both
        _loan.__setBorrower(address(this));
        _loan.__setLender(address(this));

        _loan.__setPrincipal(_defaultAmounts[1]);
        _loan.__setDrawableFunds(_defaultAmounts[1]);
        _loan.__setNextPaymentDueDate(_start + 25 days);  // 5 days into a loan

        _fundsAsset.mint(address(_loan), _defaultAmounts[1]);
    }

    function test_acceptNewTerms_commitmentMismatch_emptyCallsArray() external {
        uint256 deadline = block.timestamp + 10 days;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try with empty calls array.
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        _loan.acceptNewTerms(address(_refinancer), deadline, new bytes[](0));

        // Try with correct calls array.
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedCalls() external {
        uint256 deadline = block.timestamp + 10 days;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try with different calls array.
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(456));

        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        // Try with correct calls array.
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedRefinancer() external {
        uint256 deadline = block.timestamp + 10 days;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try with different refinancer.
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        _loan.acceptNewTerms(address(1111), deadline, calls);

        // Try with correct refinancer.
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedDeadline() external {
        uint256 deadline = block.timestamp + 10 days;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try with different deadline.
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        _loan.acceptNewTerms(address(_refinancer), deadline + 1, calls);

        // Try with correct deadline.
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_invalidRefinancer() external {
        uint256 deadline = block.timestamp + 10 days;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        // Set _refinanceCommitment via proposeNewTerms() using invalid refinancer and valid calls array.
        _loan.proposeNewTerms(address(0), deadline, calls);

        // Try with invalid refinancer.
        vm.expectRevert("ML:ANT:INVALID_REFINANCER");
        _loan.acceptNewTerms(address(0), deadline, calls);
    }

    function test_acceptNewTerms_afterDeadline() external {
        uint256 deadline = block.timestamp + 10 days;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        // Set _refinanceCommitment via proposeNewTerms() using valid refinancer and valid calls array.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.warp(deadline + 1);

        // Try after deadline.
        vm.expectRevert("ML:ANT:EXPIRED_COMMITMENT");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        // Try before deadline.
        vm.warp(deadline);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_callFailed() external {
        uint256 deadline = block.timestamp + 10 days;

        bytes[] memory calls = new bytes[](1);

        // Add a refinance call with invalid ending principal, where new ending principal is larger than principal requested.
        calls[0] = abi.encodeWithSignature("setEndingPrincipal(uint256)", _defaultAmounts[1] + 1);

        // Set _refinanceCommitment via proposeNewTerms().
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try with invalid new term.
        vm.expectRevert("ML:ANT:FAILED");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_insufficientCollateral() external {
        // Setup state variables for necessary prerequisite state.
        _loan.__setDrawableFunds(uint256(0));

        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);

        // Add a refinance call with new collateral required amount (fully collateralized principal) which will make current collateral amount insufficient.
        uint256 newCollateralRequired = _defaultAmounts[1];
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", newCollateralRequired);

        // Set _refinanceCommitment via proposeNewTerms().
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try with insufficient collateral.
        vm.expectRevert("ML:ANT:INSUFFICIENT_COLLATERAL");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        // Try with sufficient collateral.
        _loan.__setCollateral(newCollateralRequired);
        _collateralAsset.mint(address(_loan), newCollateralRequired);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", 1);

        // Set _refinanceCommitment via proposeNewTerms().
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

}

contract MapleLoanLogic_BatchClaimFundsTests is TestUtils {

    address lender;

    address[] destinations;

    uint256[] amounts;

    MapleLoanHarness loan;
    MockERC20        asset;

    function setUp() external {
        lender = address(1001);

        loan  = new MapleLoanHarness();
        asset = new MockERC20("Funds Asset", "FA", 0);

        loan.__setFundsAsset(address(asset));
        loan.__setLender(lender);
    }

    function test_batchClaimFunds_notLender() external {
        vm.expectRevert("ML:BCF:NOT_LENDER");
        loan.batchClaimFunds(amounts, destinations);
    }

    function test_batchClaimFunds_noAmounts() external {
        destinations.push(address(1));

        vm.prank(lender);
        vm.expectRevert("ML:BCF:INVALID_LENGTH");
        loan.batchClaimFunds(amounts, destinations);
    }

    function test_batchClaimFunds_noDestinations() external {
        amounts.push(1);

        vm.prank(lender);
        vm.expectRevert("ML:BCF:INVALID_LENGTH");
        loan.batchClaimFunds(amounts, destinations);
    }

    function test_batchClaimFunds_singleDestination() external {
        amounts.push(1);

        destinations.push(address(1));

        vm.prank(lender);
        vm.expectRevert("ML:BCF:INVALID_LENGTH");
        loan.batchClaimFunds(amounts, destinations);
    }

    function test_batchClaimFunds_lengthMismatch() external {
        amounts.push(1);
        amounts.push(2);
        amounts.push(3);

        destinations.push(address(1));
        destinations.push(address(2));

        vm.prank(lender);
        vm.expectRevert("ML:BCF:LENGTH_MISMATCH");
        loan.batchClaimFunds(amounts, destinations);
    }

    function test_batchClaimFunds_failedTransfer() external {
        loan.__setClaimableFunds(2);

        asset.mint(address(loan), 1);

        amounts.push(1);
        amounts.push(1);

        destinations.push(address(1));
        destinations.push(address(2));

        vm.prank(lender);
        vm.expectRevert("ML:BCF:TRANSFER_FAILED");
        loan.batchClaimFunds(amounts, destinations);
    }

    function test_batchClaimFunds_insufficientClaimableFunds() external {
        loan.__setClaimableFunds(1);

        asset.mint(address(loan), 2);

        amounts.push(1);
        amounts.push(1);

        destinations.push(address(1));
        destinations.push(address(2));

        vm.prank(lender);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.batchClaimFunds(amounts, destinations);
    }

    function test_batchClaimFunds_success() external {
        loan.__setClaimableFunds(2);

        asset.mint(address(loan), 2);

        amounts.push(1);
        amounts.push(1);

        destinations.push(address(1));
        destinations.push(address(2));

        assertEq(asset.balanceOf(address(loan)), 2);
        assertEq(asset.balanceOf(address(1)),    0);
        assertEq(asset.balanceOf(address(2)),    0);

        assertEq(loan.claimableFunds(), 2);

        vm.prank(lender);
        loan.batchClaimFunds(amounts, destinations);

        assertEq(asset.balanceOf(address(loan)), 0);
        assertEq(asset.balanceOf(address(1)),    1);
        assertEq(asset.balanceOf(address(2)),    1);

        assertEq(loan.claimableFunds(), 0);
    }

}

contract MapleLoanLogic_ClaimFundsTests is TestUtils {

    MapleLoanHarness internal _loan;
    MockERC20        internal _fundsAsset;

    function setUp() external {
        _fundsAsset = new MockERC20("Funds Asset", "FA", 0);
        _loan       = new MapleLoanHarness();

        _loan.__setFundsAsset(address(_fundsAsset));

        // TODO: prank
        _loan.__setLender(address(this));
    }

    function test_claimFunds(uint256 claimable_, uint256 amountToClaim_) external {
        claimable_     = constrictToRange(claimable_,     1, type(uint256).max);
        amountToClaim_ = constrictToRange(amountToClaim_, 1, claimable_);

        _fundsAsset.mint(address(_loan), claimable_);

        _loan.__setClaimableFunds(claimable_);

        _loan.claimFunds(amountToClaim_, address(this));

        assertEq(_loan.claimableFunds(),                claimable_ - amountToClaim_);
        assertEq(_fundsAsset.balanceOf(address(_loan)), claimable_ - amountToClaim_);
        assertEq(_fundsAsset.balanceOf(address(this)),  amountToClaim_);
    }

    function testFail_claimFunds_insufficientClaimableFunds(uint256 claimable_, uint256 amountToClaim_) external {
        claimable_     = constrictToRange(claimable_,     1,              type(uint256).max / 2);
        amountToClaim_ = constrictToRange(amountToClaim_, claimable_ + 1, type(uint256).max);

        _fundsAsset.mint(address(_loan), claimable_);

        _loan.__setClaimableFunds(claimable_);

        _loan.claimFunds(amountToClaim_, address(this));
    }

    function test_claimFunds_transferFail() external {
        // ClaimableFunds is set, but the loan doesn't actually have any tokens, which causes the transfer to fail.
        _loan.__setClaimableFunds(1);

        vm.expectRevert("ML:CF:TRANSFER_FAILED");
        _loan.claimFunds(1, address(this));
    }

}

contract MapleLoanLogic_CloseLoanTests is TestUtils {

    address internal constant LENDER = address(1111);

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant UNDERFLOW_ERROR_CODE = 17;

    MapleLoanHarness internal _loan;
    MockERC20        internal _fundsAsset;
    MockFactory      internal _factory;
    MockFeeManager   internal _feeManager;

    function setUp() external {
        _factory    = new MockFactory();
        _feeManager = new MockFeeManager();
        _fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        _loan       = new MapleLoanHarness();

        _loan.__setFactory(address(_factory));
        _loan.__setFeeManager(address(_feeManager));
        _loan.__setFundsAsset(address(_fundsAsset));

        // TODO: prank both
        _loan.__setBorrower(address(this));
        _loan.__setLender(LENDER);
    }

    function setupLoan(
        address loan_,
        uint256 principalRequested_,
        uint256 paymentsRemaining_,
        uint256 paymentInterval_,
        uint256 closingRate_,
        uint256 endingPrincipal_
    ) internal {
        MapleLoanHarness(loan_).__setPrincipalRequested(principalRequested_);
        MapleLoanHarness(loan_).__setPrincipal(principalRequested_);
        MapleLoanHarness(loan_).__setDrawableFunds(principalRequested_);

        MapleLoanHarness(loan_).__setPaymentsRemaining(paymentsRemaining_);
        MapleLoanHarness(loan_).__setPaymentInterval(paymentInterval_);
        MapleLoanHarness(loan_).__setClosingRate(closingRate_);
        MapleLoanHarness(loan_).__setEndingPrincipal(endingPrincipal_);
        MapleLoanHarness(loan_).__setNextPaymentDueDate(block.timestamp + paymentInterval_);

        _fundsAsset.mint(address(_loan), principalRequested_);
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

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, endingPrincipal_);

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        ( uint256 principal, uint256 interest, ) = _loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 additionalAmount;

        if (expectedPayment > _loan.drawableFunds()) {
            _fundsAsset.mint(address(_loan), additionalAmount = (expectedPayment - _loan.drawableFunds()));
        }

        ( principal, interest, ) = _loan.closeLoan(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                  expectedPayment);
        assertEq(_loan.drawableFunds(),      principalRequested_ + additionalAmount - totalPaid);
        assertEq(_loan.claimableFunds(),     principal + interest);
        assertEq(_loan.principal(),          0);
        assertEq(_loan.nextPaymentDueDate(), 0);
        assertEq(_loan.paymentsRemaining(),  0);
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

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, endingPrincipal_);

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        ( uint256 principal, uint256 interest, ) = _loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        _fundsAsset.mint(address(_loan), fundsForPayments);

        ( principal, interest, ) = _loan.closeLoan(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                  expectedPayment);
        assertEq(_loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(_loan.claimableFunds(),     principal + interest);
        assertEq(_loan.principal(),          0);
        assertEq(_loan.nextPaymentDueDate(), 0);
        assertEq(_loan.paymentsRemaining(),  0);
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

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, endingPrincipal_);

        // Drawdown all loan funds.
        _loan.drawdownFunds(_loan.drawableFunds(), address(this));

        ( uint256 principal, uint256 interest, ) = _loan.getClosingPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        _fundsAsset.mint(address(_loan), installmentToPay - 1);

        // Try to pay with insufficient amount, should underflow.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", UNDERFLOW_ERROR_CODE));
        _loan.closeLoan(0);

        // Mint remaining amount.
        _fundsAsset.mint(address(_loan), 1);

        // Pay off loan with exact amount.
        _loan.closeLoan(0);
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

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, endingPrincipal_);

        _fundsAsset.mint(address(_loan), MAX_TOKEN_AMOUNT * 1500);

        // Set time such that payment is late.
        vm.warp(block.timestamp + paymentInterval_ + 1);

        try _loan.closeLoan(0) { assertTrue(false, "Cannot close when late"); } catch { }

        // Returning to being on-time.
        vm.warp(block.timestamp - 2);

        _loan.closeLoan(0);
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

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, closingRate_, 0);

        _loan.__setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest, ) = _loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        _fundsAsset.mint(address(_loan), fundsForPayments);

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        ( principal, interest, ) = _loan.closeLoan(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                  expectedPayment);
        assertEq(_loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(_loan.claimableFunds(),     principal + interest);
        assertEq(_loan.principal(),          0);
        assertEq(_loan.nextPaymentDueDate(), 0);
        assertEq(_loan.paymentsRemaining(),  0);
    }

}

contract MapleLoanLogic_CollateralMaintainedTests is TestUtils {

    uint256 internal constant SCALED_ONE       = uint256(10 ** 36);
    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 1e18;

    MapleLoanHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanHarness();
    }

    function test_isCollateralMaintained(uint256 collateral_, uint256 collateralRequired_, uint256 drawableFunds_, uint256 principal_, uint256 principalRequested_) external {
        collateral_         = constrictToRange(collateral_, 0, type(uint256).max);
        collateralRequired_ = constrictToRange(collateralRequired_, 0, type(uint128).max);  // Max chosen since type(uint128).max * type(uint128).max < type(uint256).max.
        drawableFunds_      = constrictToRange(drawableFunds_, 0, type(uint256).max);
        principalRequested_ = constrictToRange(principalRequested_, 1, type(uint128).max);  // Max chosen since type(uint128).max * type(uint128).max < type(uint256).max.
        principal_          = constrictToRange(principal_, 0, principalRequested_);

        _loan.__setCollateral(collateral_);
        _loan.__setCollateralRequired(collateralRequired_);
        _loan.__setDrawableFunds(drawableFunds_);
        _loan.__setPrincipal(principal_);
        _loan.__setPrincipalRequested(principalRequested_);

        uint256 outstandingPrincipal = principal_ > drawableFunds_ ? principal_ - drawableFunds_ : 0;

        bool shouldBeMaintained =
            outstandingPrincipal == 0 ||                                                          // No collateral needed (since no outstanding principal), thus maintained.
            collateral_ >= ((collateralRequired_ * outstandingPrincipal) / principalRequested_);  // collateral_ / collateralRequired_ >= outstandingPrincipal / principalRequested_.

        assertTrue(_loan.__isCollateralMaintained() == shouldBeMaintained);
    }

    // NOTE: Skipping this test because the assertion has more precision than the implementation, causing errors
    function skip_test_isCollateralMaintained_scaledMath(uint256 collateral_, uint256 collateralRequired_, uint256 drawableFunds_, uint256 principal_, uint256 principalRequested_) external {
        collateral_         = constrictToRange(collateral_, 0, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        drawableFunds_      = constrictToRange(drawableFunds_, 0, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        principal_          = constrictToRange(principal_, 0, principalRequested_);

        _loan.__setCollateral(collateral_);
        _loan.__setCollateralRequired(collateralRequired_);
        _loan.__setDrawableFunds(drawableFunds_);
        _loan.__setPrincipal(principal_);
        _loan.__setPrincipalRequested(principalRequested_);

        uint256 outstandingPrincipal = principal_ > drawableFunds_ ? principal_ - drawableFunds_ : 0;
        bool shouldBeMaintained      = ((collateral_ * SCALED_ONE) / collateralRequired_) >= (outstandingPrincipal * SCALED_ONE) / principalRequested_;

        assertTrue(_loan.__isCollateralMaintained() == shouldBeMaintained);
    }

    function test_isCollateralMaintained_edgeCases() external {
        _loan.__setCollateral(50 ether);
        _loan.__setCollateralRequired(100 ether);
        _loan.__setDrawableFunds(100 ether);
        _loan.__setPrincipal(600 ether);
        _loan.__setPrincipalRequested(1000 ether);

        assertEq(_loan.__getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether);

        assertTrue(_loan.__isCollateralMaintained());

        // Set collateral just enough such that collateral is not maintained.
        _loan.__setCollateral(50 ether - 1 wei);

        assertTrue(!_loan.__isCollateralMaintained());

        // Reset collateral and set collateral required just enough such that collateral is not maintained.
        _loan.__setCollateral(50 ether);
        _loan.__setCollateralRequired(100 ether + 2 wei);

        assertEq(_loan.__getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!_loan.__isCollateralMaintained());

        // Reset collateral required and set drawable funds just enough such that collateral is not maintained.
        _loan.__setCollateralRequired(100 ether);
        _loan.__setDrawableFunds(100 ether - 10 wei);

        assertEq(_loan.__getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!_loan.__isCollateralMaintained());

        // Reset drawable funds and set principal just enough such that collateral is not maintained.
        _loan.__setDrawableFunds(100 ether);
        _loan.__setPrincipal(600 ether + 10 wei);

        assertEq(_loan.__getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!_loan.__isCollateralMaintained());

        // Reset principal and set principal requested just enough such that collateral is not maintained.
        _loan.__setPrincipal(600 ether);
        _loan.__setPrincipalRequested(1000 ether - 20 wei);

        assertEq(_loan.__getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!_loan.__isCollateralMaintained());
    }

}

contract MapleLoanLogic_DrawdownFundsTests is TestUtils {

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)

    MockERC20        internal _fundsAsset;
    MapleLoanHarness internal _loan;

    function setUp() external {
        _fundsAsset = new MockERC20("Funds Asset", "FA", 0);
        _loan       = new MapleLoanHarness();

        // TODO: prank
        _loan.__setBorrower(address(this));
        _loan.__setFundsAsset(address(_fundsAsset));
    }

    function setupLoan(address loan_, uint256 principalRequested_) internal {
        MapleLoanHarness(loan_).__setPrincipalRequested(principalRequested_);
        MapleLoanHarness(loan_).__setPrincipal(principalRequested_);
        MapleLoanHarness(loan_).__setDrawableFunds(principalRequested_);
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

        _loan.__setCollateralRequired(collateralRequired_);
        _loan.__setCollateral(collateralRequired_);

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

    function test_drawdownFunds_transferFailed() external {
        // DrawableFunds is set, but the loan doesn't actually have any tokens which causes the transfer to fail.
        _loan.__setDrawableFunds(1);

        try _loan.drawdownFunds(1, address(this)) {
            assertTrue(false, "Funds must not be transferred.");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:DF:TRANSFER_FAILED");
        }
    }

    function test_drawdownFunds_multipleDrawdowns(uint256 collateralRequired_, uint256 principalRequested_, uint256 drawdownAmount_) external {
        // Must have non-zero collateral and principal amounts to cause failure
        collateralRequired_ = constrictToRange(collateralRequired_, 2, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 2, MAX_TOKEN_AMOUNT);
        drawdownAmount_     = constrictToRange(drawdownAmount_,     1, principalRequested_ / 2);

        setupLoan(address(_loan), principalRequested_);

        _loan.__setCollateralRequired(collateralRequired_);
        _loan.__setCollateral(collateralRequired_);

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

        _loan.__setCollateralRequired(collateralRequired_);
        _loan.__setCollateral(collateral_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.drawdownFunds(principalRequested_, address(this));
    }

}

contract MapleLoanLogic_FundLoanTests is TestUtils {

    address internal constant LENDER = address(1111);

    uint256 internal constant MAX_PRINCIPAL = 1_000_000_000 * 1e18;
    uint256 internal constant MIN_PRINCIPAL = 1;

    MapleLoanHarness internal _loan;
    MockERC20        internal _fundsAsset;
    MockFactory      internal _factory;
    MockFeeManager   internal _feeManager;

    function setUp() external {
        _factory    = new MockFactory();
        _feeManager = new MockFeeManager();
        _fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        _loan       = new MapleLoanHarness();

        _loan.__setFactory(address(_factory));
        _loan.__setFeeManager(address(_feeManager));
    }

    function testFail_fundLoan_withInvalidLender() external {
        _loan.fundLoan(address(0));
    }

    function testFail_fundLoan_withoutSendingAsset() external {
        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(1);
        _loan.fundLoan(LENDER);
    }

    function test_fundLoan_fullFunding(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setPaymentInterval(30 days);
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        assertEq(_loan.fundLoan(LENDER),                           principalRequested_);
        assertEq(_loan.lender(),                                   LENDER);
        assertEq(_loan.nextPaymentDueDate(),                       block.timestamp + _loan.paymentInterval());
        assertEq(_loan.principal(),                                principalRequested_);
        assertEq(_loan.drawableFunds(),                            principalRequested_);
        assertEq(_loan.claimableFunds(),                           0);
        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), 0);
    }

    function test_fundLoan_overFunding(uint256 principalRequested_, uint256 extraAmount_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);
        extraAmount_        = constrictToRange(extraAmount_,        MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_ + extraAmount_);

        assertEq(_loan.fundLoan(LENDER),                           principalRequested_);
        assertEq(_loan.lender(),                                   LENDER);
        assertEq(_loan.nextPaymentDueDate(),                       block.timestamp + _loan.paymentInterval());
        assertEq(_loan.principal(),                                principalRequested_);
        assertEq(_loan.drawableFunds(),                            principalRequested_);
        assertEq(_loan.claimableFunds(),                           extraAmount_);
        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), 0);
    }

    function testFail_fundLoan_partialFunding(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_ - 1);

        _loan.fundLoan(LENDER);
    }

    function testFail_fundLoan_doubleFund(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.fundLoan(LENDER);

        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(LENDER);
    }

    function testFail_fundLoan_claimImmediatelyAfterFullFunding(uint256 principalRequested_, uint256 claim_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);
        claim_              = constrictToRange(claim_,              1,             principalRequested_);

        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.fundLoan(LENDER);

        _loan.claimFunds(claim_, address(this));
    }

    function testFail_fundLoan_invalidFundsAsset() external {
        _loan.__setFundsAsset(address(0));
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(1);

        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(LENDER);
    }

    function test_fundLoan_withUnaccountedCollateralAsset() external {
        MockERC20 collateralAsset = new MockERC20("CollateralAsset", "CA", 0);

        _loan.__setCollateralAsset(address(collateralAsset));
        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(1);

        collateralAsset.mint(address(_loan), 1);
        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(LENDER);

        assertEq(_loan.getUnaccountedAmount(address(collateralAsset)), 1);
    }

    function test_fundLoan_nextPaymentDueDateAlreadySet() external {
        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setNextPaymentDueDate(1);
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipalRequested(1);

        _fundsAsset.mint(address(_loan), 1);

        try _loan.fundLoan(LENDER) {
            assertTrue(false, "Next payment due date must not be set.");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:FL:LOAN_ACTIVE");
        }
    }

    function test_fundLoan_noPaymentsRemaining() external {
        _loan.__setFundsAsset(address(_fundsAsset));
        _loan.__setPaymentsRemaining(0);
        _loan.__setPrincipalRequested(1);

        try _loan.fundLoan(LENDER) {
            assertTrue(false, "Number of remaining payments must be greater than zero.");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:FL:LOAN_ACTIVE");
        }
    }

}

contract MapleLoanLogic_GetCollateralRequiredForTests is TestUtils {

    MapleLoanHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanHarness();
    }

    function test_getCollateralRequiredFor() external {
        // No principal.
        assertEq(_loan.__getCollateralRequiredFor(0, 10_000, 4_000_000, 500_000), 0);

        // No outstanding principal.
        assertEq(_loan.__getCollateralRequiredFor(10_000, 10_000, 4_000_000, 500_000), 0);

        // No collateral required.
        assertEq(_loan.__getCollateralRequiredFor(10_000, 1_000, 4_000_000, 0), 0);

        // 1125 = (500_000 * (10_000 > 1_000 ? 10_000 - 1_000 : 0)) / 4_000_000;
        assertEq(_loan.__getCollateralRequiredFor(10_000, 1_000, 4_000_000, 500_000), 1125);

        // 500_000 = (500_000 * (4_500_000 > 500_000 ? 4_500_000 - 500_000 : 0)) / 4_000_000;
        assertEq(_loan.__getCollateralRequiredFor(4_500_000, 500_000, 4_000_000, 500_000), 500_000);
    }

}

contract MapleLoanLogic_GetClosingPaymentBreakdownTests is TestUtils {
    uint256 private constant SCALED_ONE = uint256(10 ** 18);

    address    internal _defaultBorrower;
    address[2] internal _defaultAssets;
    uint256[3] internal _defaultTermDetails;

    MapleGlobalsMock       internal _globals;
    ConstructableMapleLoan internal _loan;
    MockERC20              internal _token0;
    MockERC20              internal _token1;
    MockFactory            internal _factory;
    MockFeeManager         internal _feeManager;

    function setUp() external {
        _globals    = new MapleGlobalsMock(address(123123));
        _factory    = new MockFactory();
        _feeManager = new MockFeeManager();

        // Set _initialize() parameters.
        _token0 = new MockERC20("Token0", "T0", 0);
        _token1 = new MockERC20("Token1", "T1", 0);

        _defaultBorrower    = address(1);
        _defaultAssets      = [address(_token0), address(_token1)];
        _defaultTermDetails = [uint256(1), uint256(20 days), uint256(3)];

        _globals.setValidBorrower(_defaultBorrower, true);
    }

    function test_getClosingPaymentBreakdown(uint256 principal_, uint256 closingRate_, uint256 refinanceInterest_) external {
        uint256 maxClosingRateForTestCase = 1 * SCALED_ONE; // 100%

        principal_         = constrictToRange(principal_,         1, type(uint256).max / maxClosingRateForTestCase);
        closingRate_       = constrictToRange(closingRate_,       1, maxClosingRateForTestCase);
        refinanceInterest_ = constrictToRange(refinanceInterest_, 1, 1e18 * 1e12);

        // Set principal and closingRate for _initialize().
        uint256[3] memory amounts = [uint256(5), principal_, uint256(0)];
        uint256[5] memory rates   = [uint256(0.05 ether), closingRate_, uint256(0.15 ether), uint256(20), uint256(0)];
        uint256[2] memory fees    = [uint256(0), uint256(0)];

        _loan = new ConstructableMapleLoan(address(_factory), address(_globals), _defaultBorrower, address(_feeManager), _defaultAssets, _defaultTermDetails, amounts, rates, fees);

        _loan.__setPrincipal(amounts[1]);
        _loan.__setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest, ) = _loan.getClosingPaymentBreakdown();

        uint256 expectedPrincipal = amounts[1];
        uint256 expectedInterest  = (expectedPrincipal * rates[1] / SCALED_ONE) + refinanceInterest_;

        assertEq(principal, expectedPrincipal);
        assertEq(interest,  expectedInterest);
    }
}

contract MapleLoanLogic_GetInstallmentTests is TestUtils {

    MapleLoanHarness internal _loan;

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 1e18;
    uint256 internal constant MIN_TOKEN_AMOUNT = 1;

    function setUp() external {
        _loan = new MapleLoanHarness();
    }

    function test_getInstallment_withFixtures() external {
        ( uint256 principalAmount, uint256 interestAmount ) = _loan.__getInstallment(1_000_000, 0, 0.12 ether, 365 days / 12, 12);

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

        _loan.__getInstallment(principal_, endingPrincipal_, interestRate_, paymentInterval_, totalPayments_);

        assertTrue(true);
    }

    function test_getInstallment_edgeCases() external {
        uint256 principalAmount_;
        uint256 interestAmount_;

        // 100,000% APY charged all at once in one payment
        ( principalAmount_, interestAmount_ ) = _loan.__getInstallment(MAX_TOKEN_AMOUNT, 0, 1000.00 ether, 365 days, 1);

        assertEq(principalAmount_, 1000000000000000000000000000000);
        assertEq(interestAmount_,  1000000000000000000000000000000000);

        // A payment a day for 30 years (10950 payments) at 100% APY
        ( principalAmount_, interestAmount_ ) = _loan.__getInstallment(MAX_TOKEN_AMOUNT, 0, 1.00 ether, 1 days, 10950);

        assertEq(principalAmount_, 267108596355467);
        assertEq(interestAmount_,  2739726027397260000000000000);
    }

    // TODO: test where `raisedRate <= SCALED_ONE`?

}

contract MapleLoanLogic_GetInterestTests is TestUtils {

    MapleLoanHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanHarness();
    }

    function test_getInterest() external {
        assertEq(_loan.__getInterest(1_000_000, 0.12e18, 365 days / 12), 10_000);  // 12% APY on 1M
        assertEq(_loan.__getInterest(10_000,    1.20e18, 365 days / 12), 1_000);   // 120% APY on 10k
    }

}

contract MapleLoanLogic_GetNextPaymentBreakdownTests is TestUtils {

    MapleLoanHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanHarness();
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

        _loan.__setNextPaymentDueDate(nextPaymentDueDate_);
        _loan.__setPaymentInterval(paymentInterval);
        _loan.__setPrincipal(principal_);
        _loan.__setEndingPrincipal(endingPrincipal_);
        _loan.__setPaymentsRemaining(paymentsRemaining_);
        _loan.__setInterestRate(interestRate_);
        _loan.__setLateFeeRate(lateFeeRate_);
        _loan.__setLateInterestPremium(lateInterestPremium_);
        _loan.__setRefinanceInterest(refinanceInterest_);
        _loan.__setFeeManager(address(new MockFeeManager()));

        ( uint256 expectedPrincipal, uint256 expectedInterest ) = _loan.__getPaymentBreakdown(
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

        ( uint256 actualPrincipal, uint256 actualInterest,  ) = _loan.getNextPaymentBreakdown();

        assertEq(actualPrincipal, expectedPrincipal);
        assertEq(actualInterest,  expectedInterest + refinanceInterest_);
    }

}

contract MapleLoanLogic_GetPaymentBreakdownTests is TestUtils {

    address internal _loan;

    function setUp() external {
        _loan = address(new MapleLoanHarness());
    }

    function _getPaymentBreakdownWith(
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
            _loan,
            10_000_000 - 30 days,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,     9_863);  // 1_000_000 * 0.12 * 30/365 = 9_863
    }

    function test_getPaymentBreakdown_onePaymentOneSecondBeforeDue() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            _loan,
            10_000_000 - 1,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,     9_863);
    }

    function test_getPaymentBreakdown_onePaymentOnePeriodLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            _loan,
            10_000_000 + 30 days,
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    23_013);  // 9_863 + (1_000_000 * 0.16 * (1 * 30/365)) = 9_863 + 13_150
    }

    function test_getPaymentBreakdown_onePaymentTwoPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            _loan,
            10_000_000 + (2 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    36_164);  // 9_863 + (1_000_000 * 0.16 * (2 * 30/365)) = 9_863 + 26_301
    }

    function test_getPaymentBreakdown_onePaymentThreePeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            _loan,
            10_000_000 + (3 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    49_315);  // 9_863 + (1_000_000 * 0.16 * (3 * 30/365)) = 9_863 + 39_452
    }

    function test_getPaymentBreakdown_onePaymentFourPeriodsLate() external {
        ( uint256 principalAmount, uint256 interestFees ) = _getPaymentBreakdownWith(
            _loan,
            10_000_000 + (4 * 30 days),
            10_000_000
        );

        assertEq(principalAmount, 78_908);
        assertEq(interestFees,    62_465);  // 9_863 + (1_000_000 * 0.16 * (4 * 30/365)) = 9_863 + 52_602
    }

}

contract MapleLoanLogic_GetPeriodicInterestRateTests is TestUtils {

    MapleLoanHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanHarness();
    }

    function test_getPeriodicInterestRate() external {
        assertEq(_loan.__getPeriodicInterestRate(0.12 ether, 365 days),      0.12 ether);  // 12%
        assertEq(_loan.__getPeriodicInterestRate(0.12 ether, 365 days / 12), 0.01 ether);  // 1%
    }

}

contract MapleLoanLogic_GetUnaccountedAmountTests is TestUtils {

    MapleLoanHarness internal _loan;
    MockERC20        internal _collateralAsset;
    MockERC20        internal _fundsAsset;
    MockERC20        internal _token;

    function setUp() external {
        _collateralAsset = new MockERC20("Collateral Asset", "CA", 18);
        _fundsAsset      = new MockERC20("Funds Asset", "FA", 6);
        _loan            = new MapleLoanHarness();
        _token           = new MockERC20("Token", "T", 18);

        _loan.__setCollateralAsset(address(_collateralAsset));
        _loan.__setFundsAsset(address(_fundsAsset));
    }

    function test_getUnaccountedAmount_randomToken() external {
        assertEq(_loan.getUnaccountedAmount(address(_token)), 0);

        _token.mint(address(_loan), 100);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 100);

        _loan.__setDrawableFunds(10);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 100);  // No change

        _loan.__setDrawableFunds(0);
        _loan.__setClaimableFunds(10);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 100);  // No change

        _loan.__setDrawableFunds(0);
        _loan.__setCollateral(10);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 100);  // No change

        _token.mint(address(_loan), type(uint256).max - 100);

        assertEq(_loan.getUnaccountedAmount(address(_token)), type(uint256).max);
    }

    function test_getUnaccountedAmount_withDrawableFunds(uint256 balance_, uint256 drawableFunds_) external {
        drawableFunds_ = constrictToRange(drawableFunds_, 0, balance_);

        _fundsAsset.mint(address(_loan), balance_);

        _loan.__setDrawableFunds(drawableFunds_);

        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), balance_ - drawableFunds_);
    }

    function test_getUnaccountedAmount_withClaimableFunds(uint256 balance_, uint256 claimableFunds_) external {
        claimableFunds_ = constrictToRange(claimableFunds_, 0, balance_);

        _fundsAsset.mint(address(_loan), balance_);

        _loan.__setClaimableFunds(claimableFunds_);

        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), balance_ - claimableFunds_);
    }

    function test_getUnaccountedAmount_withCollateral(uint256 balance_, uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 0, balance_);

        _collateralAsset.mint(address(_loan), balance_);

        _loan.__setCollateral(collateral_);

        assertEq(_loan.getUnaccountedAmount(address(_collateralAsset)), balance_ - collateral_);
    }

    function test_getUnaccountedAmount_complex(uint256 balance_, uint256 claimableFunds_, uint256 collateral_, uint256 drawableFunds_) external {
        MockERC20 token = new MockERC20("Token", "T", 0);

        _loan.__setFundsAsset(address(token));
        _loan.__setCollateralAsset(address(token));

        balance_        = constrictToRange(balance_,        128, type(uint256).max);
        claimableFunds_ = constrictToRange(claimableFunds_, 0, balance_ >> 2);
        collateral_     = constrictToRange(collateral_,     0, balance_ >> 2);
        drawableFunds_  = constrictToRange(drawableFunds_,  0, balance_ >> 2);

        token.mint(address(_loan), balance_);

        _loan.__setClaimableFunds(claimableFunds_);
        _loan.__setDrawableFunds(drawableFunds_);
        _loan.__setCollateral(collateral_);

        assertEq(_loan.getUnaccountedAmount(address(token)), balance_ - claimableFunds_ - collateral_ - drawableFunds_);
    }

    function test_getUnaccountedAmount_collateralAsset() external {
        assertEq(_loan.getUnaccountedAmount(address(_collateralAsset)), 0);

        _collateralAsset.mint(address(_loan), 1);

        assertEq(_loan.getUnaccountedAmount(address(_collateralAsset)), 1);

        _collateralAsset.mint(address(_loan), type(uint256).max - 1);

        assertEq(_loan.getUnaccountedAmount(address(_collateralAsset)), type(uint256).max);
    }

    function test_getUnaccountedAmount_fundsAsset() external {
        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), 0);

        _fundsAsset.mint(address(_loan), 1);

        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), 1);

        _fundsAsset.mint(address(_loan), type(uint256).max - 1);

        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), type(uint256).max);
    }

    function test_getUnaccountedAmount_newFundsLtDrawableFunds(uint256 drawableFunds) external {
        drawableFunds = constrictToRange(drawableFunds, 1, type(uint256).max);

        _loan.__setDrawableFunds(drawableFunds);

        _fundsAsset.mint(address(_loan), drawableFunds - 1);

        try _loan.getUnaccountedAmount(address(_fundsAsset)) { assertTrue(false, "Did not underflow"); } catch {}

        _fundsAsset.mint(address(_loan), 1);  // Mint just enough to not underflow

        _loan.getUnaccountedAmount(address(_fundsAsset));
    }

    function test_getUnaccountedAmount_newFundsLtClaimableFunds(uint256 claimableFunds) external {
        claimableFunds = constrictToRange(claimableFunds, 1, type(uint256).max);

        _loan.__setClaimableFunds(claimableFunds);

        _fundsAsset.mint(address(_loan), claimableFunds - 1);

        try _loan.getUnaccountedAmount(address(_fundsAsset)) { assertTrue(false, "Did not underflow"); } catch {}

        _fundsAsset.mint(address(_loan), 1);  // Mint just enough to not underflow

        _loan.getUnaccountedAmount(address(_fundsAsset));
    }

    function test_getUnaccountedAmount_newFundsLtCollateral(uint256 collateral) external {
        collateral = constrictToRange(collateral, 1, type(uint256).max);

        _loan.__setCollateral(collateral);

        _collateralAsset.mint(address(_loan), collateral - 1);

        try _loan.getUnaccountedAmount(address(_collateralAsset)) { assertTrue(false, "Did not underflow"); } catch {}

        _collateralAsset.mint(address(_loan), 1);  // Mint just enough to not underflow

        _loan.getUnaccountedAmount(address(_collateralAsset));
    }

    function test_getUnaccountedAmount_drawableFunds(uint256 drawableFunds, uint256 newFunds) external {
        drawableFunds = constrictToRange(drawableFunds, 1,             type(uint256).max / 2);
        newFunds      = constrictToRange(newFunds,      drawableFunds, type(uint256).max - drawableFunds);

        _loan.__setDrawableFunds(drawableFunds);

        _fundsAsset.mint(address(_loan), newFunds);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_fundsAsset));

        assertEq(unaccountedAmount, newFunds - drawableFunds);
    }

    function test_getUnaccountedAmount_claimableFunds(uint256 claimableFunds, uint256 newFunds) external {
        claimableFunds = constrictToRange(claimableFunds, 1,              type(uint256).max / 2);
        newFunds       = constrictToRange(newFunds,       claimableFunds, type(uint256).max - claimableFunds);

        _loan.__setClaimableFunds(claimableFunds);

        _fundsAsset.mint(address(_loan), newFunds);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_fundsAsset));

        assertEq(unaccountedAmount, newFunds - claimableFunds);
    }

    function test_getUnaccountedAmount_collateral(uint256 collateral, uint256 newCollateral) external {
        collateral    = constrictToRange(collateral,    1,          type(uint256).max / 2);
        newCollateral = constrictToRange(newCollateral, collateral, type(uint256).max - collateral);

        _loan.__setCollateral(collateral);

        _collateralAsset.mint(address(_loan), newCollateral);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_collateralAsset));

        assertEq(unaccountedAmount, newCollateral - collateral);
    }

    function test_getUnaccountedAmount_drawableFundsAndClaimableFunds(uint256 drawableFunds, uint256 claimableFunds, uint256 newFunds) external {
        drawableFunds  = constrictToRange(drawableFunds,  1,                              type(uint256).max / 4);
        claimableFunds = constrictToRange(claimableFunds, 1,                              type(uint256).max / 4);
        newFunds       = constrictToRange(newFunds,       drawableFunds + claimableFunds, type(uint256).max - (drawableFunds + claimableFunds));

        _loan.__setDrawableFunds(drawableFunds);
        _loan.__setClaimableFunds(claimableFunds);

        _fundsAsset.mint(address(_loan), newFunds);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_fundsAsset));

        assertEq(unaccountedAmount, newFunds - drawableFunds - claimableFunds);
    }

    function test_getUnaccountedAmount_drawableFundsAndClaimableFundsAndCollateral(
        uint256 drawableFunds,
        uint256 claimableFunds,
        uint256 collateral,
        uint256 newFunds,
        uint256 newCollateral
    )
        external
    {
        drawableFunds  = constrictToRange(drawableFunds,  1,                              type(uint256).max / 4);
        claimableFunds = constrictToRange(claimableFunds, 1,                              type(uint256).max / 4);
        collateral     = constrictToRange(collateral,     1,                              type(uint256).max / 2);
        newFunds       = constrictToRange(newFunds,       drawableFunds + claimableFunds, type(uint256).max - (drawableFunds + claimableFunds));
        newCollateral  = constrictToRange(newCollateral,  collateral,                     type(uint256).max - collateral);

        _loan.__setDrawableFunds(drawableFunds);
        _loan.__setClaimableFunds(claimableFunds);
        _loan.__setCollateral(collateral);

        _fundsAsset.mint(address(_loan), newFunds);
        _collateralAsset.mint(address(_loan), newCollateral);

        uint256 unaccountedAmount_fundsAsset      = _loan.getUnaccountedAmount(address(_fundsAsset));
        uint256 unaccountedAmount_collateralAsset = _loan.getUnaccountedAmount(address(_collateralAsset));

        assertEq(unaccountedAmount_fundsAsset,      newFunds - drawableFunds - claimableFunds);
        assertEq(unaccountedAmount_collateralAsset, newCollateral - collateral);
    }

    function test_getUnaccountedAmount_drawableFundsAndClaimableFundsAndCollateral_fundsAssetEqCollateralAsset(
        uint256 drawableFunds,
        uint256 claimableFunds,
        uint256 collateral,
        uint256 newFunds
    )
        external
    {
        _loan.__setCollateralAsset(address(_fundsAsset));

        drawableFunds  = constrictToRange(drawableFunds,  1, type(uint256).max / 6);  // Sum of maxes must be less than half of type(uint256).max
        claimableFunds = constrictToRange(claimableFunds, 1, type(uint256).max / 6);
        collateral     = constrictToRange(collateral,     1, type(uint256).max / 6);

        newFunds = constrictToRange(
            newFunds,
            drawableFunds + claimableFunds + collateral,
            type(uint256).max - (drawableFunds + claimableFunds + collateral)
        );

        _loan.__setDrawableFunds(drawableFunds);
        _loan.__setClaimableFunds(claimableFunds);
        _loan.__setCollateral(collateral);

        _fundsAsset.mint(address(_loan), newFunds);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_fundsAsset));

        assertEq(unaccountedAmount, newFunds - drawableFunds - claimableFunds - collateral);
    }

}

contract MapleLoanLogic_InitializeTests is TestUtils {

    address    internal _defaultBorrower;
    address[2] internal _defaultAssets;
    uint256[3] internal _defaultTermDetails;
    uint256[3] internal _defaultAmounts;
    uint256[5] internal _defaultRates;
    uint256[2] internal _defaultFees;

    MapleGlobalsMock       internal _globals;
    ConstructableMapleLoan internal _loan;
    MockERC20              internal _token0;
    MockERC20              internal _token1;
    MockFactory            internal _factory;
    MockFeeManager         internal _feeManager;

    function setUp() external {
        _globals = new MapleGlobalsMock(address(this));
        _factory    = new MockFactory();
        _feeManager = new MockFeeManager();
        _token0     = new MockERC20("Token0", "T0", 0);
        _token1     = new MockERC20("Token1", "T1", 0);

        // Happy path dummy arguments to pass to initialize().
        _defaultBorrower    = address(1);
        _defaultAssets      = [address(_token0), address(_token1)];
        _defaultTermDetails = [uint256(1), uint256(20 days), uint256(3)];
        _defaultAmounts     = [uint256(5), uint256(4_000_000), uint256(0)];
        _defaultRates       = [uint256(6), uint256(7), uint256(8), uint256(9), uint256(0)];
        _defaultFees        = [uint256(0), uint256(0)];

        _globals.setValidBorrower(_defaultBorrower, true);
    }

    function test_initialize() external {
        // Call initialize() with all happy path arguments, should not revert().
        _loan = new ConstructableMapleLoan(address(_factory), address(_globals), _defaultBorrower, address(_feeManager), _defaultAssets, _defaultTermDetails, _defaultAmounts, _defaultRates, _defaultFees);

        assertEq(_loan.collateralAsset(),     _defaultAssets[0]);
        assertEq(_loan.fundsAsset(),          _defaultAssets[1]);

        assertEq(_loan.gracePeriod(),         _defaultTermDetails[0]);
        assertEq(_loan.paymentInterval(),     _defaultTermDetails[1]);
        assertEq(_loan.paymentsRemaining(),   _defaultTermDetails[2]);

        assertEq(_loan.collateralRequired(),  _defaultAmounts[0]);
        assertEq(_loan.principalRequested(),  _defaultAmounts[1]);
        assertEq(_loan.endingPrincipal(),     _defaultAmounts[2]);

        assertEq(_loan.interestRate(),        _defaultRates[0]);
        assertEq(_loan.closingRate(),         _defaultRates[1]);
        assertEq(_loan.lateFeeRate(),         _defaultRates[2]);
        assertEq(_loan.lateInterestPremium(), _defaultRates[3]);
    }

    function test_initialize_invalidPrincipal() external {
        uint256[3] memory amounts;

        // Set principal requested to invalid amount.
        amounts[1] = 0;

        // Call initialize, expecting to revert with correct error message.
        try new ConstructableMapleLoan(address(_factory), address(_globals), _defaultBorrower, address(_feeManager), _defaultAssets, _defaultTermDetails, amounts, _defaultRates, _defaultFees) {
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
        try new ConstructableMapleLoan(address(_factory), address(_globals), _defaultBorrower, address(_feeManager), _defaultAssets, _defaultTermDetails, amounts, _defaultRates, _defaultFees) {
            assertTrue(false, "Ending principal needs to be less than or equal to principal requested.");
        }
        catch Error(string memory reason) {
            assertEq(reason, "MLI:I:INVALID_ENDING_PRINCIPAL");
        }
    }

    // TODO: Do try/catch sweep
    function test_initialize_zeroBorrower() external {
        // Call initialize, expecting to revert with correct error message.
        try new ConstructableMapleLoan(address(_globals), address(_factory), address(0), address(_feeManager), _defaultAssets, _defaultTermDetails, _defaultAmounts, _defaultRates, _defaultFees) {
            assertTrue(false, "Borrow cannot be address(0).");
        }
        catch Error(string memory reason) {
            assertEq(reason, "MLI:I:ZERO_BORROWER");
        }
    }

    function test_initialize_invalidBorrower() external {
        // Call initialize, expecting to revert with correct error message.
        try new ConstructableMapleLoan(address(_factory), address(_globals), address(1234), address(_feeManager), _defaultAssets, _defaultTermDetails, _defaultAmounts, _defaultRates, _defaultFees) {
            assertTrue(false, "Borrow cannot be address(0).");
        }
        catch Error(string memory reason) {
            assertEq(reason, "MLI:I:INVALID_BORROWER");
        }
    }

}

contract MapleLoanLogic_MakePaymentTests is TestUtils {

    address internal constant LENDER = address(1111);

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant UNDERFLOW_ERROR_CODE = 17;

    MapleLoanHarness internal _loan;
    MockERC20        internal _fundsAsset;
    MockFactory      internal _factory;
    MockFeeManager   internal _feeManager;

    function setUp() external {
        _factory    = new MockFactory();
        _feeManager = new MockFeeManager();
        _fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        _loan       = new MapleLoanHarness();

        _loan.__setFactory(address(_factory));
        _loan.__setFeeManager(address(_feeManager));
        _loan.__setFundsAsset(address(_fundsAsset));

        // TODO: prank
        _loan.__setBorrower(address(this));
        _loan.__setLender(LENDER);
    }

    function setupLoan(
        address loan_,
        uint256 principalRequested_,
        uint256 paymentsRemaining_,
        uint256 paymentInterval_,
        uint256 interestRate_,
        uint256 endingPrincipal_
    ) internal {
        MapleLoanHarness(loan_).__setPrincipalRequested(principalRequested_);
        MapleLoanHarness(loan_).__setPrincipal(principalRequested_);
        MapleLoanHarness(loan_).__setDrawableFunds(principalRequested_);

        MapleLoanHarness(loan_).__setPaymentsRemaining(paymentsRemaining_);
        MapleLoanHarness(loan_).__setPaymentInterval(paymentInterval_);
        MapleLoanHarness(loan_).__setInterestRate(interestRate_);
        MapleLoanHarness(loan_).__setEndingPrincipal(endingPrincipal_);
        MapleLoanHarness(loan_).__setNextPaymentDueDate(block.timestamp + paymentInterval_);

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
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  2,   50);
        interestRate_       = constrictToRange(interestRate_,       0,   1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_);

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        ( uint256 principal, uint256 interest,  ) = _loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 additionalAmount;

        if (expectedPayment > _loan.drawableFunds()) {
            _fundsAsset.mint(address(_loan), additionalAmount = (expectedPayment - _loan.drawableFunds()));
        }

        ( principal, interest,  ) = _loan.makePayment(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                  expectedPayment);
        assertEq(_loan.drawableFunds(),      principalRequested_ + additionalAmount - totalPaid);
        assertEq(_loan.claimableFunds(),     principal + interest);
        assertEq(_loan.principal(),          principalRequested_ - principal);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + (2 * paymentInterval_));
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
        paymentsRemaining_  = constrictToRange(paymentsRemaining_,  2,   50);
        interestRate_       = constrictToRange(interestRate_,       0,   1.00e18);
        principalRequested_ = constrictToRange(principalRequested_, 1,   MAX_TOKEN_AMOUNT);
        endingPrincipal_    = constrictToRange(endingPrincipal_,    0,   principalRequested_);

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_);

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        ( uint256 principal, uint256 interest, ) = _loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        _fundsAsset.mint(address(_loan), fundsForPayments);

        ( principal, interest, ) = _loan.makePayment(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                  expectedPayment);
        assertEq(_loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(_loan.claimableFunds(),     principal + interest);
        assertEq(_loan.principal(),          principalRequested_ - principal);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + (2 * paymentInterval_));
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_ - 1);
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

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, endingPrincipal_);

        // Drawdown all loan funds.
        _loan.drawdownFunds(_loan.drawableFunds(), address(this));

        ( uint256 principal, uint256 interest, ) = _loan.getNextPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        vm.assume(installmentToPay > 0);

        _fundsAsset.mint(address(_loan), installmentToPay - 1);

        // Try to pay with insufficient amount, should underflow.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", UNDERFLOW_ERROR_CODE));
        _loan.makePayment(0);

        // Mint remaining amount.
        _fundsAsset.mint(address(_loan), 1);

        // Pay off loan with exact amount.
        _loan.makePayment(0);
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
        setupLoan(address(_loan), principalRequested_, 1, paymentInterval_, interestRate_, endingPrincipal_);

        // Drawdown all loan funds.
        _loan.drawdownFunds(_loan.drawableFunds(), address(this));

        ( uint256 principal, uint256 interest, ) = _loan.getNextPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        _fundsAsset.mint(address(_loan), installmentToPay);

        // Last payment should pay off the principal.
        assertEq(_loan.paymentsRemaining(), 1);
        assertEq(principal,                 _loan.principal());

        // Pay off rest of loan, expecting loan accounting to be reset.
        ( principal, interest, ) = _loan.makePayment(0);

        uint256 actualInstallmentAmount = principal + interest;

        assertEq(principal,               principalRequested_);
        assertEq(actualInstallmentAmount, installmentToPay);
        assertEq(_loan.drawableFunds(),   0);
        assertEq(_loan.claimableFunds(),  principal + interest);

        // Make sure loan accounting is cleared from _clearLoanAccounting().
        assertEq(_loan.gracePeriod(),         0);
        assertEq(_loan.paymentInterval(),     0);
        assertEq(_loan.interestRate(),        0);
        assertEq(_loan.closingRate(),         0);
        assertEq(_loan.lateFeeRate(),         0);
        assertEq(_loan.lateInterestPremium(), 0);
        assertEq(_loan.endingPrincipal(),     0);
        assertEq(_loan.nextPaymentDueDate(),  0);
        assertEq(_loan.paymentsRemaining(),   0);
        assertEq(_loan.principal(),           0);
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

        setupLoan(address(_loan), principalRequested_, paymentsRemaining_, paymentInterval_, interestRate_, 0);

        _loan.__setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest, ) = _loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        _fundsAsset.mint(address(_loan), fundsForPayments);

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);
        assertEq(_loan.refinanceInterest(),  refinanceInterest_);

        ( principal, interest, ) = _loan.makePayment(0);

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                  expectedPayment);
        assertEq(_loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(_loan.claimableFunds(),     principal + interest);
        assertEq(_loan.principal(),          principalRequested_ - principal);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + (2 * paymentInterval_));
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_ - 1);
        assertEq(_loan.refinanceInterest(),  0);
    }

}

contract MapleLoanLogic_PostCollateralTests is TestUtils {

    uint256 internal constant MAX_COLLATERAL = type(uint256).max - 1;
    uint256 internal constant MIN_COLLATERAL = 0;

    MapleLoanHarness internal _loan;
    MockERC20        internal _collateralAsset;

    function setUp() external {
        _loan            = new MapleLoanHarness();
        _collateralAsset = new MockERC20("CollateralAsset", "CA", 0);

        _loan.__setCollateralAsset(address(_collateralAsset));
    }

    function testFail_postCollateral_invalidCollateralAsset() external {
        _loan.__setCollateralAsset(address(0));

        _collateralAsset.mint(address(_loan), 1);

        _loan.postCollateral(0);
    }

    function test_postCollateral_once(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL);

        _collateralAsset.mint(address(_loan), collateral_);

        assertEq(_loan.postCollateral(0), collateral_);
        assertEq(_loan.collateral(),      collateral_);
    }

    function test_postCollateral_multiple(uint256 collateral_, uint256 posts_) external {
        posts_      = constrictToRange(posts_,      2,              10);
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL / posts_);

        for (uint256 i = 1; i <= posts_; ++i) {
            _collateralAsset.mint(address(_loan), collateral_);

            assertEq(_loan.postCollateral(0), collateral_);
            assertEq(_loan.collateral(),      collateral_ * i);
        }
    }

    function test_postCollateral_withUnaccountedFundsAsset() external {
        MockERC20 fundsAsset = new MockERC20("FundsAsset", "FA", 0);

        _loan.__setFundsAsset(address(fundsAsset));

        fundsAsset.mint(address(_loan), 1);
        _collateralAsset.mint(address(_loan), 1);

        _loan.postCollateral(0);

        assertEq(_loan.getUnaccountedAmount(address(fundsAsset)), 1);
    }

}

contract MapleLoanLogic_ProposeNewTermsTests is TestUtils {

    MapleLoanHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanHarness();

        // TODO: prank
        _loan.__setBorrower(address(this));
    }

    function test_proposeNewTerms(address refinancer_, uint256 deadline_, uint256 newCollateralRequired_, uint256 newEndingPrincipal_, uint256 newInterestRate_) external {
        deadline_ = block.timestamp + constrictToRange(deadline_, 1, 2000 days);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", newCollateralRequired_);
        data[1] = abi.encodeWithSignature("setEndingPrincipal(uint256)",    newEndingPrincipal_);
        data[2] = abi.encodeWithSignature("setInterestRate(uint256)",       newInterestRate_);

        bytes32 proposedRefinanceCommitment = _loan.proposeNewTerms(refinancer_, deadline_, data);

        assertEq(proposedRefinanceCommitment, keccak256(abi.encode(refinancer_, deadline_, data)));
        assertEq(_loan.refinanceCommitment(), keccak256(abi.encode(refinancer_, deadline_, data)));
    }

    function test_proposeNewTerms_emptyArray(address refinancer_, uint256 deadline_) external {
        deadline_ = block.timestamp + constrictToRange(deadline_, 1, 2000 days);

        bytes[] memory data = new bytes[](0);

        bytes32 proposedRefinanceCommitment = _loan.proposeNewTerms(refinancer_, deadline_, data);

        assertEq(proposedRefinanceCommitment, bytes32(0));
        assertEq(_loan.refinanceCommitment(), bytes32(0));
    }
}

contract MapleLoanLogic_RejectNewTermsTests is TestUtils {

    MapleLoanHarness internal _loan;
    Refinancer       internal _refinancer;

    function setUp() external {
        _loan       = new MapleLoanHarness();
        _refinancer = new Refinancer();

        // TODO: prank
        _loan.__setBorrower(address(this));
    }

    function test_rejectNewTerms_commitmentMismatch_emptyCallsArray() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.expectRevert("ML:RNT:COMMITMENT_MISMATCH");
        _loan.rejectNewTerms(address(_refinancer), deadline, new bytes[](0));

        _loan.rejectNewTerms(address(_refinancer), deadline, calls);
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedRefinancer() external {
        Refinancer anotherRefinancer = new Refinancer();
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.expectRevert("ML:RNT:COMMITMENT_MISMATCH");
        _loan.rejectNewTerms(address(anotherRefinancer), deadline, calls);

        _loan.rejectNewTerms(address(_refinancer), deadline, calls);
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedDeadline() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.expectRevert("ML:RNT:COMMITMENT_MISMATCH");
        _loan.rejectNewTerms(address(_refinancer), deadline + 1, calls);

        _loan.rejectNewTerms(address(_refinancer), deadline, calls);
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedCalls() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        bytes memory originalCall = calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(100));

        vm.expectRevert("ML:RNT:COMMITMENT_MISMATCH");
        _loan.rejectNewTerms(address(_refinancer), deadline, calls);

        calls[0] = originalCall;

        _loan.rejectNewTerms(address(_refinancer), deadline, calls);
    }

    function test_rejectNewTerms_success() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        assertEq(_loan.refinanceCommitment(), keccak256(abi.encode(address(_refinancer), deadline, calls)));

        _loan.rejectNewTerms(address(_refinancer), deadline, calls);

        assertEq(_loan.refinanceCommitment(), bytes32(0));
    }

}

contract MapleLoanLogic_RemoveCollateralTests is TestUtils {

    uint256 internal constant MAX_COLLATERAL = type(uint256).max - 1;
    uint256 internal constant MIN_COLLATERAL = 0;

    uint256 internal constant MAX_PRINCIPAL = type(uint256).max - 1;
    uint256 internal constant MIN_PRINCIPAL = 1;

    MapleLoanHarness internal _loan;
    MockERC20        internal _collateralAsset;

    function setUp() external {
        _collateralAsset = new MockERC20("CollateralAsset", "CA", 0);
        _loan            = new MapleLoanHarness();

        // TODO: prank
        _loan.__setBorrower(address(this));
        _loan.__setCollateralAsset(address(_collateralAsset));
        _loan.__setPrincipalRequested(1);
    }

    function test_removeCollateral_fullAmountWithNoEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, MAX_COLLATERAL);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral(0);

        _loan.removeCollateral(collateral_, address(this));

        assertEq(_loan.collateral(),                         0);
        assertEq(_collateralAsset.balanceOf(address(_loan)), 0);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateral_);
    }

    function test_removeCollateral_partialAmountWithNoEncumbrances(uint256 collateral_, uint256 removedAmount_) external {
        collateral_    = constrictToRange(collateral_,    2, MAX_COLLATERAL);
        removedAmount_ = constrictToRange(removedAmount_, 1, collateral_);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral(0);

        _loan.removeCollateral(removedAmount_, address(this));

        assertEq(_loan.collateral(),                         collateral_ - removedAmount_);
        assertEq(_collateralAsset.balanceOf(address(_loan)), collateral_ - removedAmount_);
        assertEq(_collateralAsset.balanceOf(address(this)),  removedAmount_);
    }

    function testFail_removeCollateral_insufficientCollateralWithNoEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, MIN_COLLATERAL, MAX_COLLATERAL);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral(0);

        _loan.removeCollateral(collateral_ + 1, address(this));
    }

    function test_removeCollateral_sameAssetAsFundingAsset(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, MAX_COLLATERAL);

        _loan.__setFundsAsset(address(_collateralAsset));

        _collateralAsset.mint(address(_loan), 1);

        _loan.__setClaimableFunds(1);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral(0);

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

        _loan.__setPrincipalRequested(principalRequested_);
        _loan.__setPrincipal(principal_);
        _loan.__setDrawableFunds(drawableFunds_);
        _loan.__setCollateralRequired(collateralRequired_);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral(0);
        _loan.removeCollateral(collateral_, address(this));

        assertEq(_loan.collateral(),                         0);
        assertEq(_collateralAsset.balanceOf(address(_loan)), 0);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateral_);
    }

    function test_removeCollateral_fullAmount_noPrincipal(uint256 collateralRequired_) external {
        collateralRequired_ = constrictToRange(collateralRequired_, 1, type(uint256).max);

        _loan.__setPrincipal(0);
        _loan.__setCollateralRequired(collateralRequired_);

        _collateralAsset.mint(address(_loan), collateralRequired_);

        _loan.postCollateral(0);
        _loan.removeCollateral(collateralRequired_, address(this));

        assertEq(_loan.collateral(),                         0);
        assertEq(_collateralAsset.balanceOf(address(_loan)), 0);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateralRequired_);
    }

    function test_removeCollateral_partialAmountWithEncumbrances(uint256 collateralRequired_, uint256 collateral_) external {
        collateralRequired_ = constrictToRange(collateralRequired_, 1,                       type(uint256).max - 1);
        collateral_         = constrictToRange(collateral_,         collateralRequired_ + 1, type(uint256).max);

        _loan.__setPrincipal(1);
        _loan.__setCollateralRequired(collateralRequired_);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral(0);

        try _loan.removeCollateral(collateral_ - collateralRequired_ + 1, address(this)) {
            assertTrue(false, "Collateral must not be removed.");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:RC:INSUFFICIENT_COLLATERAL");
        }

        _loan.removeCollateral(collateral_ - collateralRequired_, address(this));

        assertEq(_loan.collateral(),                         collateralRequired_);
        assertEq(_collateralAsset.balanceOf(address(_loan)), collateralRequired_);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateral_ - collateralRequired_);
    }

    function test_removeCollateral_cannotRemoveAnyAmountWithEncumbrances() external {
        _loan.__setPrincipal(1);
        _loan.__setCollateralRequired(1000);

        _collateralAsset.mint(address(_loan), 1000);

        _loan.postCollateral(0);

        try _loan.removeCollateral(1, address(this)) {
            assertTrue(false, "No collateral can be removed.");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:RC:INSUFFICIENT_COLLATERAL");
        }
    }

    function test_removeCollateral_cannotRemoveFullAmountWithEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, type(uint256).max);

        _loan.__setPrincipal(1);
        _loan.__setCollateralRequired(1);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral(0);

        try _loan.removeCollateral(collateral_, address(this)) {
            assertTrue(false, "Full collateral must not be removed.");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:RC:INSUFFICIENT_COLLATERAL");
        }
    }

    function test_removeCollateral_cannotRemovePartialAmountWithEncumbrances(uint256 collateral_, uint256 collateralRemoved_) external {
        collateral_        = constrictToRange(collateral_,        2, type(uint256).max);
        collateralRemoved_ = constrictToRange(collateralRemoved_, 1, collateral_ - 1);

        _loan.__setPrincipal(1);
        _loan.__setCollateralRequired(collateral_);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral(0);

        try _loan.removeCollateral(collateralRemoved_, address(this)) {
            assertTrue(false, "Partial collateral must not be removed.");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:RC:INSUFFICIENT_COLLATERAL");
        }
    }

    function test_removeCollateral_transferFailed() external {
        RevertingERC20 collateralAsset = new RevertingERC20();

        _loan.__setCollateralAsset(address(collateralAsset));

        collateralAsset.mint(address(_loan), 1);

        _loan.postCollateral(0);

        try _loan.removeCollateral(1, address(this)) {
            assertTrue(false, "Collateral must not be transferred.");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:RC:TRANSFER_FAILED");
        }
    }

}

contract MapleLoanLogic_RepossessTests is TestUtils {

    MapleLoanHarness internal _loan;
    MockERC20        internal _collateralAsset;
    MockERC20        internal _fundsAsset;

    function setUp() external {
        _collateralAsset = new MockERC20("Collateral Asset", "CA", 0);
        _fundsAsset      = new MockERC20("Funds Asset",      "FA", 0);
        _loan            = new MapleLoanHarness();

        _loan.__setCollateralAsset(address(_collateralAsset));
        _loan.__setFundsAsset(address(_fundsAsset));

        _loan.__setDrawableFunds(1);
        _loan.__setClaimableFunds(1);
        _loan.__setCollateral(1);

        // TODO: prank
        _loan.__setLender(address(this));
        _loan.__setPaymentsRemaining(1);
        _loan.__setPrincipal(1);
        _loan.__setGracePeriod(10);

        _fundsAsset.mint(address(_loan), 2);
        _collateralAsset.mint(address(_loan), 1);
    }

    function test_repossess() external {
        _loan.__setNextPaymentDueDate(block.timestamp - 11);

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
        _loan.__setNextPaymentDueDate(block.timestamp + 1);
        _loan.repossess(address(this));
    }

    function testFail_repossess_onPaymentDue() external {
        _loan.__setNextPaymentDueDate(block.timestamp);
        _loan.repossess(address(this));
    }

    function testFail_repossess_withinGracePeriod() external {
        _loan.__setNextPaymentDueDate(block.timestamp - 5);
        _loan.repossess(address(this));
    }

    function testFail_repossess_onGracePeriod() external {
        _loan.__setNextPaymentDueDate(block.timestamp - 10);
        _loan.repossess(address(this));
    }

    function test_repossess_fundsTransferFailed() external {
        RevertingERC20 token = new RevertingERC20();

        _loan.__setNextPaymentDueDate(block.timestamp - 11);
        _loan.__setFundsAsset(address(token));

        token.mint(address(_loan), 1);

        try _loan.repossess(address(this)) {
            assertTrue(false, "Able to repossess");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:R:F_TRANSFER_FAILED");
        }
    }

    function test_repossess_collateralTransferFailed() external {
        RevertingERC20 token = new RevertingERC20();

        _loan.__setNextPaymentDueDate(block.timestamp - 11);
        _loan.__setCollateralAsset(address(token));

        token.mint(address(_loan), 1);

        try _loan.repossess(address(this)) {
            assertTrue(false, "Able to repossess");
        } catch Error(string memory reason) {
            assertEq(reason, "ML:R:C_TRANSFER_FAILED");
        }
    }

}

contract MapleLoanLogic_ReturnFundsTests is TestUtils {

    MapleLoanHarness internal _loan;
    MockERC20        internal _fundsAsset;

    function setUp() external {
        _fundsAsset = new MockERC20("Funds Asset", "FA", 0);
        _loan       = new MapleLoanHarness();

        _loan.__setFundsAsset(address(_fundsAsset));
    }

    function test_returnFunds(uint256 fundsToReturn_) external {
        fundsToReturn_ = constrictToRange(fundsToReturn_, 0, type(uint256).max >> 3);

        assertEq(_loan.returnFunds(0), 0);
        assertEq(_loan.drawableFunds(), 0);

        _fundsAsset.mint(address(_loan), fundsToReturn_);

        assertEq(_loan.returnFunds(0),  fundsToReturn_);
        assertEq(_loan.drawableFunds(), fundsToReturn_);

        _fundsAsset.mint(address(_loan), fundsToReturn_);

        assertEq(_loan.returnFunds(0),  fundsToReturn_);
        assertEq(_loan.drawableFunds(), 2 * fundsToReturn_);
    }

    function test_returnFunds_collateralAsset() external {
        MockERC20 _collateralAsset = new MockERC20("Collateral Asset", "CA", 0);

        _loan.__setCollateralAsset(address(_collateralAsset));

        assertEq(_loan.returnFunds(0),  0);
        assertEq(_loan.drawableFunds(), 0);

        _collateralAsset.mint(address(_loan), 1);

        assertEq(_loan.returnFunds(0),  0);
        assertEq(_loan.drawableFunds(), 0);
    }

}

contract MapleLoanLogic_ScaledExponentTests is TestUtils {

    MapleLoanHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanHarness();
    }

    function test_scaledExponent_setOne() external {
        assertEq(_loan.__scaledExponent(10_000, 0, 10_000), 10_000);
        assertEq(_loan.__scaledExponent(10_000, 1, 10_000), 10_000);
        assertEq(_loan.__scaledExponent(10_000, 2, 10_000), 10_000);
        assertEq(_loan.__scaledExponent(10_000, 3, 10_000), 10_000);

        assertEq(_loan.__scaledExponent(20_000, 0, 10_000), 10_000);
        assertEq(_loan.__scaledExponent(20_000, 1, 10_000), 20_000);
        assertEq(_loan.__scaledExponent(20_000, 2, 10_000), 40_000);
        assertEq(_loan.__scaledExponent(20_000, 3, 10_000), 80_000);

        assertEq(_loan.__scaledExponent(10_100, 0, 10_000), 10_000);
        assertEq(_loan.__scaledExponent(10_100, 1, 10_000), 10_100);
        assertEq(_loan.__scaledExponent(10_100, 2, 10_000), 10_201);
        assertEq(_loan.__scaledExponent(10_100, 3, 10_000), 10_303);
    }

    function test_scaledExponent_setTwo() external {
        assertEq(_loan.__scaledExponent(12340, 18, 10), 440223147468745562613840184469885558370587691142634536960);
        assertEq(_loan.__scaledExponent(12340, 19, 10), 543235363976432024265478787635838779029305210870011018608640);

        assertEq(_loan.__scaledExponent(uint256(2 * 10_000 * 100), 100, uint256(10_000 * 100)), uint256(1267650600228229401496703205376 * 10_000 * 100));
        assertEq(_loan.__scaledExponent(uint256(2 * 10_000 * 100), 120, uint256(10_000 * 100)), uint256(1329227995784915872903807060280344576 * 10_000 * 100));
        assertEq(_loan.__scaledExponent(uint256(2 * 10_000 * 100), 140, uint256(10_000 * 100)), uint256(1393796574908163946345982392040522594123776 * 10_000 * 100));
        assertEq(_loan.__scaledExponent(uint256(2 * 10_000 * 100), 160, uint256(10_000 * 100)), uint256(1461501637330902918203684832716283019655932542976 * 10_000 * 100));
        assertEq(_loan.__scaledExponent(uint256(2 * 10_000 * 100), 168, uint256(10_000 * 100)), uint256(374144419156711147060143317175368453031918731001856 * 10_000 * 100));
        assertEq(_loan.__scaledExponent(uint256(2 * 10_000 * 100), 180, uint256(10_000 * 100)), uint256(1532495540865888858358347027150309183618739122183602176 * 10_000 * 100));
        assertEq(_loan.__scaledExponent(uint256(2 * 10_000 * 100), 200, uint256(10_000 * 100)), uint256(1606938044258990275541962092341162602522202993782792835301376 * 10_000 * 100));
        assertEq(_loan.__scaledExponent(uint256(2 * 10_000 * 100), 216, uint256(10_000 * 100)), uint256(105312291668557186697918027683670432318895095400549111254310977536 * 10_000 * 100));
    }

}
