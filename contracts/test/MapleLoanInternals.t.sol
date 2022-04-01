// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleLoanInternalsHarness } from "./harnesses/MapleLoanInternalsHarness.sol";

import { MockFactory, RevertingERC20 } from "./mocks/Mocks.sol";

import { Refinancer } from "../Refinancer.sol";

contract MapleLoanInternals_AcceptNewTermsTests is TestUtils {

    address internal constant LENDER = address(1111);

    address    internal _defaultBorrower;
    address[2] internal _defaultAssets;
    uint256[3] internal _defaultTermDetails;
    uint256[3] internal _defaultAmounts;
    uint256[4] internal _defaultRates;

    uint256 internal _start;

    MapleLoanInternalsHarness internal _loan;
    Refinancer                internal _refinancer;
    MockERC20                 internal _token0;
    MockERC20                 internal _token1;
    MockFactory               internal _factory;

    function setUp() external {
        _factory    = new MockFactory();
        _loan       = new MapleLoanInternalsHarness();
        _refinancer = new Refinancer();

        // Set _initialize() parameters.
        _token0 = new MockERC20("Token0", "T0", 0);
        _token1 = new MockERC20("Token1", "T1", 0);

        _defaultBorrower    = address(1);
        _defaultAssets      = [address(_token0), address(_token1)];
        _defaultTermDetails = [uint256(1), uint256(30 days), uint256(12)];
        _defaultAmounts     = [uint256(500), uint256(1000), uint256(0)];
        _defaultRates       = [uint256(0.10e18), uint256(7), uint256(8), uint256(9)];

        _token0.mint(address(_loan), _defaultAmounts[0]);

        vm.warp(_start = 1_500_000_000);

        _loan.setFactory(address(_factory));
        _loan.initialize(_defaultBorrower, _defaultAssets, _defaultTermDetails, _defaultAmounts, _defaultRates);
        _loan.setLender(LENDER);
        _loan.setPrincipal(_defaultAmounts[1]);
        _loan.setCollateral(_defaultAmounts[0]);
        _loan.setNextPaymentDueDate(_start + 25 days);  // 5 days into a loan
    }

    function test_acceptNewTerms_commitmentMismatch_emptyCallsArray() external {
        uint256 deadline = block.timestamp + 10 days;

        // Empty calls array in _proposeNewTerms() always resets _refinanceCommitment to bytes32(0).
        // _acceptNewTerms() will never accept a 0-valued _refinanceCommitment, so any call to it should fail.
        bytes[] memory calls = new bytes[](0);

        // Set _refinanceCommitment via _proposeNewTerms() using valid refinancer and empty calls array.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try again with valid refinancer.
        vm.expectRevert("MLI:ANT:COMMITMENT_MISMATCH");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedCalls() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);

        // Add a refinance call.
        bytes memory originalCall = calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        // Set _refinanceCommitment via _proposeNewTerms().
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Mutate the input parameter of the call to something different than proposed.
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(456));

        // Try to accept terms with different calls than proposed.
        vm.expectRevert("MLI:ANT:COMMITMENT_MISMATCH");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        calls[0] = originalCall;

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedRefinancer() external {
        uint256 deadline = block.timestamp + 10 days;
        Refinancer differentRefinancer = new Refinancer();
        bytes[] memory calls = new bytes[](1);

        // Add a refinance call.
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        // Set _refinanceCommitment via _proposeNewTerms() using correct refinancer.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try to accept terms with a different refinancer than proposed.
        vm.expectRevert("MLI:ANT:COMMITMENT_MISMATCH");
        _loan.acceptNewTerms(address(differentRefinancer), deadline, calls);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_commitmentMismatch_mismatchedDeadline() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);

        // Add a refinance call.
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(123));

        // Set _refinanceCommitment via _proposeNewTerms() using correct refinancer.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try to accept terms with a different refinancer than proposed.
        vm.expectRevert("MLI:ANT:COMMITMENT_MISMATCH");
        _loan.acceptNewTerms(address(_refinancer), deadline + 1, calls);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_invalidRefinancer() external {
        uint256 deadline = block.timestamp + 10 days;
        address notARefinancer = address(0);
        bytes[] memory calls = new bytes[](1);

        // Add a refinance call.
        calls[0] = abi.encodeWithSignature("setInterestRate(uint256)", _defaultRates[0] - 1);

        // Set _refinanceCommitment via _proposeNewTerms() using invalid refinancer.
        _loan.proposeNewTerms(notARefinancer, deadline, calls);

        // Try with invalid refinancer.
        vm.expectRevert("MLI:ANT:INVALID_REFINANCER");
        _loan.acceptNewTerms(notARefinancer, deadline, calls);

        // Set _refinanceCommitment via _proposeNewTerms() using valid refinancer.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        // Try again with valid refinancer.
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_afterDeadline() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setEndingPrincipal(uint256)", _defaultAmounts[2] + 1);

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.warp(deadline + 1);

        vm.expectRevert("MLI:ANT:EXPIRED_COMMITMENT");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        vm.warp(deadline);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_callFailed() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);

        // Add a refinance call with invalid ending principal, where new ending principal is larger than principal requested.
        uint256 invalidEndingPrincipal = _defaultAmounts[1] + 1;
        calls[0] = abi.encodeWithSignature("setEndingPrincipal(uint256)", invalidEndingPrincipal);

        // Set _refinanceCommitment via _proposeNewTerms().
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.expectRevert("MLI:ANT:FAILED");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        // Set to half principalRequested passed to _initialize().
        uint256 validEndingPrincipal = _defaultAmounts[1] / 2;
        calls[0] = abi.encodeWithSignature("setEndingPrincipal(uint256)", validEndingPrincipal);

        // Propose new valid terms.
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms_insufficientCollateral() external {
        // Setup state variables for necessary prerequisite state.
        uint256 principal = uint256(1000);
        _loan.setPrincipal(principal);
        _loan.setDrawableFunds(uint256(500));
        _loan.setCollateral(uint256(0));

        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);

        // Add a refinance call with new collateral required amount (fully collateralized principal) which will make current collateral amount insufficient.
        uint256 newCollateralRequired = principal;
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", newCollateralRequired);

        // Set _refinanceCommitment via _proposeNewTerms().
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.expectRevert("MLI:ANT:INSUFFICIENT_COLLATERAL");
        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        _loan.setCollateral(newCollateralRequired);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);
    }

    function test_acceptNewTerms() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);

        // Add a refinance call.
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        // Set _refinanceCommitment via _proposeNewTerms().
        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        _loan.acceptNewTerms(address(_refinancer), deadline, calls);

        // Refinance commitment should be reset after accepting new terms.
        assertEq(_loan.refinanceCommitment(), bytes32(0));
        assertEq(_loan.refinanceInterest(),   1);

        // Check that establishment fees are properly set.
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + _loan.paymentInterval());
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

    function test_claimFunds_transferFail() external {
        // ClaimableFunds is set, but the loan doesn't actually have any tokens, which causes the transfer to fail.
        _loan.setClaimableFunds(1);

        try _loan.claimFunds(1, address(this)) {
            assertTrue(false, "Funds must not be transferred.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:CF:TRANSFER_FAILED");
        }
    }

}

contract MapleLoanInternals_CloseLoanTests is TestUtils {

    address internal constant LENDER = address(1111);

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant UNDERFLOW_ERROR_CODE = 17;

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _fundsAsset;
    MockFactory               internal _factory;

    function setUp() external {
        _factory    = new MockFactory();
        _fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        _loan       = new MapleLoanInternalsHarness();

        _loan.setFactory(address(_factory));
        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setLender(LENDER);
    }

    function setupLoan(
        address loan_,
        uint256 principalRequested_,
        uint256 paymentsRemaining_,
        uint256 paymentInterval_,
        uint256 closingRate_,
        uint256 endingPrincipal_
    ) internal {
        MapleLoanInternalsHarness(loan_).setPrincipalRequested(principalRequested_);
        MapleLoanInternalsHarness(loan_).setPrincipal(principalRequested_);
        MapleLoanInternalsHarness(loan_).setDrawableFunds(principalRequested_);

        MapleLoanInternalsHarness(loan_).setPaymentsRemaining(paymentsRemaining_);
        MapleLoanInternalsHarness(loan_).setPaymentInterval(paymentInterval_);
        MapleLoanInternalsHarness(loan_).setClosingRate(closingRate_);
        MapleLoanInternalsHarness(loan_).setEndingPrincipal(endingPrincipal_);
        MapleLoanInternalsHarness(loan_).setNextPaymentDueDate(block.timestamp + paymentInterval_);

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

        ( uint256 principal, uint256 interest ) = _loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 additionalAmount;

        if (expectedPayment > _loan.drawableFunds()) {
            _fundsAsset.mint(address(_loan), additionalAmount = (expectedPayment - _loan.drawableFunds()));
        }

        ( principal, interest ) = _loan.closeLoan();

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

        ( uint256 principal, uint256 interest ) = _loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        _fundsAsset.mint(address(_loan), fundsForPayments);

        ( principal, interest ) = _loan.closeLoan();

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

        ( uint256 principal, uint256 interest ) = _loan.getClosingPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        _fundsAsset.mint(address(_loan), installmentToPay - 1);

        // Try to pay with insufficient amount, should underflow.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", UNDERFLOW_ERROR_CODE));
        _loan.closeLoan();

        // Mint remaining amount.
        _fundsAsset.mint(address(_loan), 1);

        // Pay off loan with exact amount.
        _loan.closeLoan();
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

        try _loan.closeLoan() { assertTrue(false, "Cannot close when late"); } catch { }

        // Returning to being on-time.
        vm.warp(block.timestamp - 2);

        _loan.closeLoan();
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

        _loan.setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest ) = _loan.getClosingPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        _fundsAsset.mint(address(_loan), fundsForPayments);

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);

        ( principal, interest ) = _loan.closeLoan();

        uint256 totalPaid = principal + interest;

        assertEq(totalPaid,                  expectedPayment);
        assertEq(_loan.drawableFunds(),      principalRequested_ + fundsForPayments - totalPaid);
        assertEq(_loan.claimableFunds(),     principal + interest);
        assertEq(_loan.principal(),          0);
        assertEq(_loan.nextPaymentDueDate(), 0);
        assertEq(_loan.paymentsRemaining(),  0);
    }

}

contract MapleLoanInternals_CollateralMaintainedTests is TestUtils {

    uint256 private constant SCALED_ONE = uint256(10 ** 36);

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 1e18;

    MapleLoanInternalsHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();
    }

    function test_isCollateralMaintained(uint256 collateral_, uint256 collateralRequired_, uint256 drawableFunds_, uint256 principal_, uint256 principalRequested_) external {
        collateral_         = constrictToRange(collateral_, 0, type(uint256).max);
        collateralRequired_ = constrictToRange(collateralRequired_, 0, type(uint128).max);  // Max chosen since type(uint128).max * type(uint128).max < type(uint256).max.
        drawableFunds_      = constrictToRange(drawableFunds_, 0, type(uint256).max);
        principalRequested_ = constrictToRange(principalRequested_, 1, type(uint128).max);  // Max chosen since type(uint128).max * type(uint128).max < type(uint256).max.
        principal_          = constrictToRange(principal_, 0, principalRequested_);

        _loan.setCollateral(collateral_);
        _loan.setCollateralRequired(collateralRequired_);
        _loan.setDrawableFunds(drawableFunds_);
        _loan.setPrincipal(principal_);
        _loan.setPrincipalRequested(principalRequested_);

        uint256 outstandingPrincipal = principal_ > drawableFunds_ ? principal_ - drawableFunds_ : 0;

        bool shouldBeMaintained =
            outstandingPrincipal == 0 ||                                                          // No collateral needed (since no outstanding principal), thus maintained.
            collateral_ >= ((collateralRequired_ * outstandingPrincipal) / principalRequested_);  // collateral_ / collateralRequired_ >= outstandingPrincipal / principalRequested_.

        assertTrue(_loan.isCollateralMaintained() == shouldBeMaintained);
    }

    // NOTE: Skipping this test because the assertion has more precision than the implementation, causing errors
    function skip_test_isCollateralMaintained_scaledMath(uint256 collateral_, uint256 collateralRequired_, uint256 drawableFunds_, uint256 principal_, uint256 principalRequested_) external {
        collateral_         = constrictToRange(collateral_, 0, MAX_TOKEN_AMOUNT);
        collateralRequired_ = constrictToRange(collateralRequired_, 1, MAX_TOKEN_AMOUNT);
        drawableFunds_      = constrictToRange(drawableFunds_, 0, MAX_TOKEN_AMOUNT);
        principalRequested_ = constrictToRange(principalRequested_, 1, MAX_TOKEN_AMOUNT);
        principal_          = constrictToRange(principal_, 0, principalRequested_);

        _loan.setCollateral(collateral_);
        _loan.setCollateralRequired(collateralRequired_);
        _loan.setDrawableFunds(drawableFunds_);
        _loan.setPrincipal(principal_);
        _loan.setPrincipalRequested(principalRequested_);

        uint256 outstandingPrincipal = principal_ > drawableFunds_ ? principal_ - drawableFunds_ : 0;
        bool shouldBeMaintained      = ((collateral_ * SCALED_ONE) / collateralRequired_) >= (outstandingPrincipal * SCALED_ONE) / principalRequested_;

        assertTrue(_loan.isCollateralMaintained() == shouldBeMaintained);
    }

    function test_isCollateralMaintained_edgeCases() external {
        _loan.setCollateral(50 ether);
        _loan.setCollateralRequired(100 ether);
        _loan.setDrawableFunds(100 ether);
        _loan.setPrincipal(600 ether);
        _loan.setPrincipalRequested(1000 ether);

        assertEq(_loan.getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether);

        assertTrue(_loan.isCollateralMaintained());

        // Set collateral just enough such that collateral is not maintained.
        _loan.setCollateral(50 ether - 1 wei);

        assertTrue(!_loan.isCollateralMaintained());

        // Reset collateral and set collateral required just enough such that collateral is not maintained.
        _loan.setCollateral(50 ether);
        _loan.setCollateralRequired(100 ether + 2 wei);

        assertEq(_loan.getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!_loan.isCollateralMaintained());

        // Reset collateral required and set drawable funds just enough such that collateral is not maintained.
        _loan.setCollateralRequired(100 ether);
        _loan.setDrawableFunds(100 ether - 10 wei);

        assertEq(_loan.getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!_loan.isCollateralMaintained());

        // Reset drawable funds and set principal just enough such that collateral is not maintained.
        _loan.setDrawableFunds(100 ether);
        _loan.setPrincipal(600 ether + 10 wei);

        assertEq(_loan.getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!_loan.isCollateralMaintained());

        // Reset principal and set principal requested just enough such that collateral is not maintained.
        _loan.setPrincipal(600 ether);
        _loan.setPrincipalRequested(1000 ether - 20 wei);

        assertEq(_loan.getCollateralRequiredFor(_loan.principal(), _loan.drawableFunds(), _loan.principalRequested(), _loan.collateralRequired()), 50 ether + 1 wei);

        assertTrue(!_loan.isCollateralMaintained());
    }

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

    function test_drawdownFunds_transferFailed() external {
        // DrawableFunds is set, but the loan doesn't actually have any tokens which causes the transfer to fail.
        _loan.setDrawableFunds(1);

        try _loan.drawdownFunds(1, address(this)) {
            assertTrue(false, "Funds must not be transferred.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:DF:TRANSFER_FAILED");
        }
    }

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

contract MapleLoanInternals_FundLoanTests is TestUtils {

    address internal constant LENDER = address(1111);

    uint256 internal constant MAX_PRINCIPAL = 1_000_000_000 * 1e18;
    uint256 internal constant MIN_PRINCIPAL = 1;

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _fundsAsset;
    MockFactory               internal _factory;

    function setUp() external {
        _factory    = new MockFactory();
        _fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        _loan       = new MapleLoanInternalsHarness();

        _loan.setFactory(address(_factory));
    }

    function testFail_fundLoan_withInvalidLender() external {
        _loan.fundLoan(address(0));
    }

    function testFail_fundLoan_withoutSendingAsset() external {
        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(1);
        _loan.fundLoan(LENDER);
    }

    function test_fundLoan_fullFunding(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentInterval(30 days);
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(principalRequested_);

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

        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_ + extraAmount_);

        assertEq(_loan.fundLoan(LENDER),                           principalRequested_);
        assertEq(_loan.lender(),                                   LENDER);
        assertEq(_loan.nextPaymentDueDate(),                       block.timestamp + _loan.paymentInterval());
        assertEq(_loan.principal(),                                principalRequested_);
        assertEq(_loan.drawableFunds(),                            principalRequested_);
        assertEq(_loan.claimableFunds(),                           0);
        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), extraAmount_);
    }

    function testFail_fundLoan_partialFunding(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_ - 1);

        _loan.fundLoan(LENDER);
    }

    function testFail_fundLoan_doubleFund(uint256 principalRequested_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);

        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.fundLoan(LENDER);

        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(LENDER);
    }

    function testFail_fundLoan_claimImmediatelyAfterFullFunding(uint256 principalRequested_, uint256 claim_) external {
        principalRequested_ = constrictToRange(principalRequested_, MIN_PRINCIPAL, MAX_PRINCIPAL);
        claim_              = constrictToRange(claim_,              1,             principalRequested_);

        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(principalRequested_);

        _fundsAsset.mint(address(_loan), principalRequested_);

        _loan.fundLoan(LENDER);

        _loan.claimFunds(claim_, address(this));
    }

    function testFail_fundLoan_invalidFundsAsset() external {
        _loan.setFundsAsset(address(0));
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(1);

        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(LENDER);
    }

    function test_fundLoan_withUnaccountedCollateralAsset() external {
        MockERC20 collateralAsset = new MockERC20("CollateralAsset", "CA", 0);

        _loan.setCollateralAsset(address(collateralAsset));
        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(1);

        collateralAsset.mint(address(_loan), 1);
        _fundsAsset.mint(address(_loan), 1);

        _loan.fundLoan(LENDER);

        assertEq(_loan.getUnaccountedAmount(address(collateralAsset)), 1);
    }

    function test_fundLoan_nextPaymentDueDateAlreadySet() external {
        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setNextPaymentDueDate(1);
        _loan.setPaymentsRemaining(1);
        _loan.setPrincipalRequested(1);

        _fundsAsset.mint(address(_loan), 1);

        try _loan.fundLoan(LENDER) {
            assertTrue(false, "Next payment due date must not be set.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:FL:LOAN_ACTIVE");
        }
    }

    function test_fundLoan_noPaymentsRemaining() external {
        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setPaymentsRemaining(0);
        _loan.setPrincipalRequested(1);

        try _loan.fundLoan(LENDER) {
            assertTrue(false, "Number of remaining payments must be greater than zero.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:FL:LOAN_ACTIVE");
        }
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

contract MapleLoanInternals_GetClosingPaymentBreakdownTests is TestUtils {
    uint256 private constant SCALED_ONE = uint256(10 ** 18);

    address    internal _defaultBorrower;
    address[2] internal _defaultAssets;
    uint256[3] internal _defaultTermDetails;

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _token0;
    MockERC20                 internal _token1;
    MockFactory               internal _factory;

    function setUp() external {
        _factory = new MockFactory();
        _loan    = new MapleLoanInternalsHarness();

        // Set _initialize() parameters.
        _token0 = new MockERC20("Token0", "T0", 0);
        _token1 = new MockERC20("Token1", "T1", 0);

        _defaultBorrower    = address(1);
        _defaultAssets      = [address(_token0), address(_token1)];
        _defaultTermDetails = [uint256(1), uint256(20 days), uint256(3)];

        _loan.setFactory(address(_factory));
    }

    function test_getClosingPaymentBreakdown(uint256 principal_, uint256 closingRate_, uint256 refinanceInterest_) external {
        uint256 maxClosingRateForTestCase = 1 * SCALED_ONE; // 100%

        principal_         = constrictToRange(principal_,         1, type(uint256).max / maxClosingRateForTestCase);
        closingRate_       = constrictToRange(closingRate_,       1, maxClosingRateForTestCase);
        refinanceInterest_ = constrictToRange(refinanceInterest_, 1, 1e18 * 1e12);

        // Set principal and closingRate for _initialize().
        uint256[3] memory amounts = [uint256(5), principal_, uint256(0)];
        uint256[4] memory rates   = [uint256(0.05 ether), closingRate_, uint256(0.15 ether), uint256(20)];

        _loan.initialize(_defaultBorrower, _defaultAssets, _defaultTermDetails, amounts, rates);
        _loan.setPrincipal(amounts[1]);
        _loan.setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest ) = _loan.getClosingPaymentBreakdown();

        uint256 expectedPrincipal = amounts[1];
        uint256 expectedInterest  = (expectedPrincipal * rates[1] / SCALED_ONE) + refinanceInterest_;

        assertEq(principal, expectedPrincipal);
        assertEq(interest,  expectedInterest);
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
        totalPayments_   = constrictToRange(totalPayments_,   1,                50);

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

contract MapleLoanInternals_GetNextPaymentBreakdownTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();
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

        _loan.setNextPaymentDueDate(nextPaymentDueDate_);
        _loan.setPaymentInterval(paymentInterval);
        _loan.setPrincipal(principal_);
        _loan.setEndingPrincipal(endingPrincipal_);
        _loan.setPaymentsRemaining(paymentsRemaining_);
        _loan.setInterestRate(interestRate_);
        _loan.setLateFeeRate(lateFeeRate_);
        _loan.setLateInterestPremium(lateInterestPremium_);
        _loan.setRefinanceInterest(refinanceInterest_);

        ( uint256 expectedPrincipal, uint256 expectedInterest ) = _loan.getPaymentBreakdown(
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

        ( uint256 actualPrincipal, uint256 actualInterest ) = _loan.getNextPaymentBreakdown();

        assertEq(actualPrincipal,   expectedPrincipal);
        assertEq(actualInterest,    expectedInterest + refinanceInterest_);
    }

}

contract MapleLoanInternals_GetPaymentBreakdownTests is TestUtils {

    address internal _loan;

    function setUp() external {
        _loan = address(new MapleLoanInternalsHarness());
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

contract MapleLoanInternals_GetUnaccountedAmountTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _collateralAsset;
    MockERC20                 internal _fundsAsset;
    MockERC20                 internal _token;

    function setUp() external {
        _collateralAsset = new MockERC20("Collateral Asset", "CA", 18);
        _fundsAsset      = new MockERC20("Funds Asset", "FA", 6);
        _loan            = new MapleLoanInternalsHarness();
        _token           = new MockERC20("Token", "T", 18);

        _loan.setCollateralAsset(address(_collateralAsset));
        _loan.setFundsAsset(address(_fundsAsset));
    }

    function test_getUnaccountedAmount_randomToken() external {
        assertEq(_loan.getUnaccountedAmount(address(_token)), 0);

        _token.mint(address(_loan), 100);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 100);

        _loan.setDrawableFunds(10);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 100);  // No change

        _loan.setDrawableFunds(0);
        _loan.setClaimableFunds(10);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 100);  // No change

        _loan.setDrawableFunds(0);
        _loan.setCollateral(10);

        assertEq(_loan.getUnaccountedAmount(address(_token)), 100);  // No change

        _token.mint(address(_loan), type(uint256).max - 100);

        assertEq(_loan.getUnaccountedAmount(address(_token)), type(uint256).max);
    }

    function test_getUnaccountedAmount_withDrawableFunds(uint256 balance_, uint256 drawableFunds_) external {
        drawableFunds_ = constrictToRange(drawableFunds_, 0, balance_);

        _fundsAsset.mint(address(_loan), balance_);

        _loan.setDrawableFunds(drawableFunds_);

        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), balance_ - drawableFunds_);
    }

    function test_getUnaccountedAmount_withClaimableFunds(uint256 balance_, uint256 claimableFunds_) external {
        claimableFunds_ = constrictToRange(claimableFunds_, 0, balance_);

        _fundsAsset.mint(address(_loan), balance_);

        _loan.setClaimableFunds(claimableFunds_);

        assertEq(_loan.getUnaccountedAmount(address(_fundsAsset)), balance_ - claimableFunds_);
    }

    function test_getUnaccountedAmount_withCollateral(uint256 balance_, uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 0, balance_);

        _collateralAsset.mint(address(_loan), balance_);

        _loan.setCollateral(collateral_);

        assertEq(_loan.getUnaccountedAmount(address(_collateralAsset)), balance_ - collateral_);
    }

    function test_getUnaccountedAmount_complex(uint256 balance_, uint256 claimableFunds_, uint256 collateral_, uint256 drawableFunds_) external {
        MockERC20 token = new MockERC20("Token", "T", 0);

        _loan.setFundsAsset(address(token));
        _loan.setCollateralAsset(address(token));

        balance_        = constrictToRange(balance_,        128, type(uint256).max);
        claimableFunds_ = constrictToRange(claimableFunds_, 0, balance_ >> 2);
        collateral_     = constrictToRange(collateral_,     0, balance_ >> 2);
        drawableFunds_  = constrictToRange(drawableFunds_,  0, balance_ >> 2);

        token.mint(address(_loan), balance_);

        _loan.setClaimableFunds(claimableFunds_);
        _loan.setDrawableFunds(drawableFunds_);
        _loan.setCollateral(collateral_);

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

        _loan.setDrawableFunds(drawableFunds);

        _fundsAsset.mint(address(_loan), drawableFunds - 1);

        try _loan.getUnaccountedAmount(address(_fundsAsset)) { assertTrue(false, "Did not underflow"); } catch {}

        _fundsAsset.mint(address(_loan), 1);  // Mint just enough to not underflow

        _loan.getUnaccountedAmount(address(_fundsAsset));
    }

    function test_getUnaccountedAmount_newFundsLtClaimableFunds(uint256 claimableFunds) external {
        claimableFunds = constrictToRange(claimableFunds, 1, type(uint256).max);

        _loan.setClaimableFunds(claimableFunds);

        _fundsAsset.mint(address(_loan), claimableFunds - 1);

        try _loan.getUnaccountedAmount(address(_fundsAsset)) { assertTrue(false, "Did not underflow"); } catch {}

        _fundsAsset.mint(address(_loan), 1);  // Mint just enough to not underflow

        _loan.getUnaccountedAmount(address(_fundsAsset));
    }

    function test_getUnaccountedAmount_newFundsLtCollateral(uint256 collateral) external {
        collateral = constrictToRange(collateral, 1, type(uint256).max);

        _loan.setCollateral(collateral);

        _collateralAsset.mint(address(_loan), collateral - 1);

        try _loan.getUnaccountedAmount(address(_collateralAsset)) { assertTrue(false, "Did not underflow"); } catch {}

        _collateralAsset.mint(address(_loan), 1);  // Mint just enough to not underflow

        _loan.getUnaccountedAmount(address(_collateralAsset));
    }

    function test_getUnaccountedAmount_drawableFunds(uint256 drawableFunds, uint256 newFunds) external {
        drawableFunds = constrictToRange(drawableFunds, 1,             type(uint256).max / 2);
        newFunds      = constrictToRange(newFunds,      drawableFunds, type(uint256).max - drawableFunds);

        _loan.setDrawableFunds(drawableFunds);

        _fundsAsset.mint(address(_loan), newFunds);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_fundsAsset));

        assertEq(unaccountedAmount, newFunds - drawableFunds);
    }

    function test_getUnaccountedAmount_claimableFunds(uint256 claimableFunds, uint256 newFunds) external {
        claimableFunds = constrictToRange(claimableFunds, 1,              type(uint256).max / 2);
        newFunds       = constrictToRange(newFunds,       claimableFunds, type(uint256).max - claimableFunds);

        _loan.setClaimableFunds(claimableFunds);

        _fundsAsset.mint(address(_loan), newFunds);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_fundsAsset));

        assertEq(unaccountedAmount, newFunds - claimableFunds);
    }

    function test_getUnaccountedAmount_collateral(uint256 collateral, uint256 newCollateral) external {
        collateral    = constrictToRange(collateral,    1,          type(uint256).max / 2);
        newCollateral = constrictToRange(newCollateral, collateral, type(uint256).max - collateral);

        _loan.setCollateral(collateral);

        _collateralAsset.mint(address(_loan), newCollateral);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_collateralAsset));

        assertEq(unaccountedAmount, newCollateral - collateral);
    }

    function test_getUnaccountedAmount_drawableFundsAndClaimableFunds(uint256 drawableFunds, uint256 claimableFunds, uint256 newFunds) external {
        drawableFunds  = constrictToRange(drawableFunds,  1,                              type(uint256).max / 4);
        claimableFunds = constrictToRange(claimableFunds, 1,                              type(uint256).max / 4);
        newFunds       = constrictToRange(newFunds,       drawableFunds + claimableFunds, type(uint256).max - (drawableFunds + claimableFunds));

        _loan.setDrawableFunds(drawableFunds);
        _loan.setClaimableFunds(claimableFunds);

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

        _loan.setDrawableFunds(drawableFunds);
        _loan.setClaimableFunds(claimableFunds);
        _loan.setCollateral(collateral);

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
        _loan.setCollateralAsset(address(_fundsAsset));

        drawableFunds  = constrictToRange(drawableFunds,  1, type(uint256).max / 6);  // Sum of maxes must be less than half of type(uint256).max
        claimableFunds = constrictToRange(claimableFunds, 1, type(uint256).max / 6);
        collateral     = constrictToRange(collateral,     1, type(uint256).max / 6);

        newFunds = constrictToRange(
            newFunds,
            drawableFunds + claimableFunds + collateral,
            type(uint256).max - (drawableFunds + claimableFunds + collateral)
        );

        _loan.setDrawableFunds(drawableFunds);
        _loan.setClaimableFunds(claimableFunds);
        _loan.setCollateral(collateral);

        _fundsAsset.mint(address(_loan), newFunds);

        uint256 unaccountedAmount = _loan.getUnaccountedAmount(address(_fundsAsset));

        assertEq(unaccountedAmount, newFunds - drawableFunds - claimableFunds - collateral);
    }

}

contract MapleLoanInternals_InitializeTests is TestUtils {

    address    internal _defaultBorrower;
    address[2] internal _defaultAssets;
    uint256[3] internal _defaultTermDetails;
    uint256[3] internal _defaultAmounts;
    uint256[4] internal _defaultRates;

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _token0;
    MockERC20                 internal _token1;
    MockFactory               internal _factory;

    function setUp() external {
        _factory = new MockFactory();
        _loan    = new MapleLoanInternalsHarness();
        _token0  = new MockERC20("Token0", "T0", 0);
        _token1  = new MockERC20("Token1", "T1", 0);

        _loan.setFactory(address(_factory));

        // Happy path dummy arguments to pass to initialize().
        _defaultBorrower    = address(1);
        _defaultAssets      = [address(_token0), address(_token1)];
        _defaultTermDetails = [uint256(1), uint256(20 days), uint256(3)];
        _defaultAmounts     = [uint256(5), uint256(4_000_000), uint256(0)];
        _defaultRates       = [uint256(6), uint256(7), uint256(8), uint256(9)];
    }

    function test_initialize_x() external {
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
        assertEq(_loan.closingRate(),         _defaultRates[1]);
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

contract MapleLoanInternals_MakePaymentTests is TestUtils {

    address internal constant LENDER = address(1111);

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e12 * 10 ** 18;  // 1 trillion of a token with 18 decimals (assumed reasonable upper limit for token amounts)
    uint256 internal constant UNDERFLOW_ERROR_CODE = 17;

    MapleLoanInternalsHarness internal _loan;
    MockERC20                 internal _fundsAsset;
    MockFactory               internal _factory;

    function setUp() external {
        _factory    = new MockFactory();
        _fundsAsset = new MockERC20("FundsAsset", "FA", 0);
        _loan       = new MapleLoanInternalsHarness();

        _loan.setFactory(address(_factory));
        _loan.setFundsAsset(address(_fundsAsset));
        _loan.setLender(LENDER);
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

        ( uint256 principal, uint256 interest ) = _loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 additionalAmount;

        if (expectedPayment > _loan.drawableFunds()) {
            _fundsAsset.mint(address(_loan), additionalAmount = (expectedPayment - _loan.drawableFunds()));
        }

        ( principal, interest ) = _loan.makePayment();

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

        ( uint256 principal, uint256 interest ) = _loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        _fundsAsset.mint(address(_loan), fundsForPayments);

        ( principal, interest ) = _loan.makePayment();

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

        ( uint256 principal, uint256 interest ) = _loan.getNextPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        _fundsAsset.mint(address(_loan), installmentToPay - 1);

        // Try to pay with insufficient amount, should underflow.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", UNDERFLOW_ERROR_CODE));
        _loan.makePayment();

        // Mint remaining amount.
        _fundsAsset.mint(address(_loan), 1);

        // Pay off loan with exact amount.
        _loan.makePayment();
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

        ( uint256 principal, uint256 interest ) = _loan.getNextPaymentBreakdown();

        uint256 installmentToPay = principal + interest;

        _fundsAsset.mint(address(_loan), installmentToPay);

        // Last payment should pay off the principal.
        assertEq(_loan.paymentsRemaining(), 1);
        assertEq(principal,                 _loan.principal());

        // Pay off rest of loan, expecting loan accounting to be reset.
        ( principal, interest ) = _loan.makePayment();

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

        _loan.setRefinanceInterest(refinanceInterest_);

        ( uint256 principal, uint256 interest ) = _loan.getNextPaymentBreakdown();

        uint256 expectedPayment = principal + interest;

        uint256 fundsForPayments = MAX_TOKEN_AMOUNT * 1500;

        _fundsAsset.mint(address(_loan), fundsForPayments);

        assertEq(_loan.drawableFunds(),      principalRequested_);
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.principal(),          principalRequested_);
        assertEq(_loan.nextPaymentDueDate(), block.timestamp + paymentInterval_);
        assertEq(_loan.paymentsRemaining(),  paymentsRemaining_);
        assertEq(_loan.refinanceInterest(),  refinanceInterest_);

        ( principal, interest ) = _loan.makePayment();

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

contract MapleLoanInternals_ProposeNewTermsTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;

    function setUp() external {
        _loan = new MapleLoanInternalsHarness();
    }

    function test_proposeNewTerms(address refinancer_, uint256 deadline_, uint256 newCollateralRequired_, uint256 newEndingPrincipal_, uint256 newInterestRate_) external {
        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", newCollateralRequired_);
        data[1] = abi.encodeWithSignature("setEndingPrincipal(uint256)",    newEndingPrincipal_);
        data[2] = abi.encodeWithSignature("setInterestRate(uint256)",       newInterestRate_);

        bytes32 proposedRefinanceCommitment = _loan.proposeNewTerms(refinancer_, deadline_, data);
        assertEq(proposedRefinanceCommitment, keccak256(abi.encode(refinancer_, deadline_, data)));
        assertEq(_loan.refinanceCommitment(), keccak256(abi.encode(refinancer_, deadline_, data)));
    }

    function test_proposeNewTerms_emptyArray(address refinancer_, uint256 deadline_) external {
        bytes[] memory data = new bytes[](0);

        bytes32 proposedRefinanceCommitment = _loan.proposeNewTerms(refinancer_, deadline_, data);

        assertEq(proposedRefinanceCommitment, bytes32(0));
        assertEq(_loan.refinanceCommitment(), bytes32(0));
    }
}

contract MapleLoanInternals_RejectNewTermsTests is TestUtils {

    MapleLoanInternalsHarness internal _loan;
    Refinancer                internal _refinancer;

    function setUp() external {
        _loan       = new MapleLoanInternalsHarness();
        _refinancer = new Refinancer();
    }

    function test_rejectNewTerms_commitmentMismatch_emptyCallsArray() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.expectRevert("MLI:RNT:COMMITMENT_MISMATCH");
        _loan.rejectNewTerms(address(_refinancer), deadline, new bytes[](0));

        _loan.rejectNewTerms(address(_refinancer), deadline, calls);
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedRefinancer() external {
        Refinancer anotherRefinancer = new Refinancer();
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.expectRevert("MLI:RNT:COMMITMENT_MISMATCH");
        _loan.rejectNewTerms(address(anotherRefinancer), deadline, calls);

        _loan.rejectNewTerms(address(_refinancer), deadline, calls);
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedDeadline() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        vm.expectRevert("MLI:RNT:COMMITMENT_MISMATCH");
        _loan.rejectNewTerms(address(_refinancer), deadline + 1, calls);

        _loan.rejectNewTerms(address(_refinancer), deadline, calls);
    }

    function test_rejectNewTerms_commitmentMismatch_mismatchedCalls() external {
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        bytes memory originalCall = calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(0));

        _loan.proposeNewTerms(address(_refinancer), deadline, calls);

        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", uint256(100));

        vm.expectRevert("MLI:RNT:COMMITMENT_MISMATCH");
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

        _loan.setPrincipalRequested(principalRequested_);
        _loan.setPrincipal(principal_);
        _loan.setDrawableFunds(drawableFunds_);
        _loan.setCollateralRequired(collateralRequired_);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral();
        _loan.removeCollateral(collateral_, address(this));

        assertEq(_loan.collateral(),                         0);
        assertEq(_collateralAsset.balanceOf(address(_loan)), 0);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateral_);
    }

    function test_removeCollateral_fullAmount_noPrincipal(uint256 collateralRequired_) external {
        collateralRequired_ = constrictToRange(collateralRequired_, 1, type(uint256).max);

        _loan.setPrincipal(0);
        _loan.setCollateralRequired(collateralRequired_);

        _collateralAsset.mint(address(_loan), collateralRequired_);

        _loan.postCollateral();
        _loan.removeCollateral(collateralRequired_, address(this));

        assertEq(_loan.collateral(),                         0);
        assertEq(_collateralAsset.balanceOf(address(_loan)), 0);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateralRequired_);
    }

    function test_removeCollateral_partialAmountWithEncumbrances(uint256 collateralRequired_, uint256 collateral_) external {
        collateralRequired_ = constrictToRange(collateralRequired_, 1,                       type(uint256).max - 1);
        collateral_         = constrictToRange(collateral_,         collateralRequired_ + 1, type(uint256).max);

        _loan.setPrincipal(1);
        _loan.setCollateralRequired(collateralRequired_);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral();

        try _loan.removeCollateral(collateral_ - collateralRequired_ + 1, address(this)) {
            assertTrue(false, "Collateral must not be removed.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:RC:INSUFFICIENT_COLLATERAL");
        }

        _loan.removeCollateral(collateral_ - collateralRequired_, address(this));

        assertEq(_loan.collateral(),                         collateralRequired_);
        assertEq(_collateralAsset.balanceOf(address(_loan)), collateralRequired_);
        assertEq(_collateralAsset.balanceOf(address(this)),  collateral_ - collateralRequired_);
    }

    function test_removeCollateral_cannotRemoveAnyAmountWithEncumbrances() external {
        _loan.setPrincipal(1);
        _loan.setCollateralRequired(1000);

        _collateralAsset.mint(address(_loan), 1000);

        _loan.postCollateral();

        try _loan.removeCollateral(1, address(this)) {
            assertTrue(false, "No collateral can be removed.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:RC:INSUFFICIENT_COLLATERAL");
        }
    }

    function test_removeCollateral_cannotRemoveFullAmountWithEncumbrances(uint256 collateral_) external {
        collateral_ = constrictToRange(collateral_, 1, type(uint256).max);

        _loan.setPrincipal(1);
        _loan.setCollateralRequired(1);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral();

        try _loan.removeCollateral(collateral_, address(this)) {
            assertTrue(false, "Full collateral must not be removed.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:RC:INSUFFICIENT_COLLATERAL");
        }
    }

    function test_removeCollateral_cannotRemovePartialAmountWithEncumbrances(uint256 collateral_, uint256 collateralRemoved_) external {
        collateral_        = constrictToRange(collateral_,        2, type(uint256).max);
        collateralRemoved_ = constrictToRange(collateralRemoved_, 1, collateral_ - 1);

        _loan.setPrincipal(1);
        _loan.setCollateralRequired(collateral_);

        _collateralAsset.mint(address(_loan), collateral_);

        _loan.postCollateral();

        try _loan.removeCollateral(collateralRemoved_, address(this)) {
            assertTrue(false, "Partial collateral must not be removed.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:RC:INSUFFICIENT_COLLATERAL");
        }
    }

    function test_removeCollateral_transferFailed() external {
        RevertingERC20 collateralAsset = new RevertingERC20();

        _loan.setCollateralAsset(address(collateralAsset));

        collateralAsset.mint(address(_loan), 1);

        _loan.postCollateral();

        try _loan.removeCollateral(1, address(this)) {
            assertTrue(false, "Collateral must not be transferred.");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:RC:TRANSFER_FAILED");
        }
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

    function test_repossess_fundsTransferFailed() external {
        RevertingERC20 token = new RevertingERC20();

        _loan.setNextPaymentDueDate(block.timestamp - 11);
        _loan.setFundsAsset(address(token));

        token.mint(address(_loan), 1);

        try _loan.repossess(address(this)) {
            assertTrue(false, "Able to repossess");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:R:F_TRANSFER_FAILED");
        }
    }

    function test_repossess_collateralTransferFailed() external {
        RevertingERC20 token = new RevertingERC20();

        _loan.setNextPaymentDueDate(block.timestamp - 11);
        _loan.setCollateralAsset(address(token));

        token.mint(address(_loan), 1);

        try _loan.repossess(address(this)) {
            assertTrue(false, "Able to repossess");
        } catch Error(string memory reason) {
            assertEq(reason, "MLI:R:C_TRANSFER_FAILED");
        }
    }

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
