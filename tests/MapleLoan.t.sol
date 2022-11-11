// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { ConstructableMapleLoan, MapleLoanHarness } from "./harnesses/MapleLoanHarnesses.sol";

import { EmptyContract, MapleGlobalsMock, MockFactory, MockFeeManager, MockLoanManager } from "./mocks/Mocks.sol";

contract MapleLoanTests is TestUtils {

    MapleGlobalsMock globals;
    MapleLoanHarness loan;
    MockFactory      factoryMock;
    MockFeeManager   feeManager;

    address borrower = address(new Address());
    address governor = address(new Address());
    address user     = address(new Address());

    address lender;

    bool locked;  // Helper state variable to avoid infinite loops when using the modifier.

    function setUp() external {
        feeManager = new MockFeeManager();
        lender     = address(new MockLoanManager());
        globals    = new MapleGlobalsMock(governor, MockLoanManager(lender).factory());
        loan       = new MapleLoanHarness();

        factoryMock = new MockFactory(address(globals));

        loan.__setBorrower(borrower);
        loan.__setFactory(address(factoryMock));
        loan.__setFeeManager(address(feeManager));
        loan.__setLender(lender);
    }

    /***********************************/
    /*** Collateral Management Tests ***/
    /***********************************/

    function test_getAdditionalCollateralRequiredFor_varyAmount() external {
        loan.__setCollateralRequired(800_000);
        loan.__setDrawableFunds(1_000_000);
        loan.__setPrincipal(500_000);
        loan.__setPrincipalRequested(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(0),         0);
        assertEq(loan.getAdditionalCollateralRequiredFor(100_000),   0);
        assertEq(loan.getAdditionalCollateralRequiredFor(200_000),   0);
        assertEq(loan.getAdditionalCollateralRequiredFor(300_000),   0);
        assertEq(loan.getAdditionalCollateralRequiredFor(400_000),   0);
        assertEq(loan.getAdditionalCollateralRequiredFor(500_000),   0);
        assertEq(loan.getAdditionalCollateralRequiredFor(600_000),   80_000);
        assertEq(loan.getAdditionalCollateralRequiredFor(700_000),   160_000);
        assertEq(loan.getAdditionalCollateralRequiredFor(800_000),   240_000);
        assertEq(loan.getAdditionalCollateralRequiredFor(900_000),   320_000);
        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 400_000);
    }

    function test_getAdditionalCollateralRequiredFor_varyCollateralRequired() external {
        loan.__setDrawableFunds(1_000_000);
        loan.__setPrincipal(1_000_000);
        loan.__setPrincipalRequested(1_000_000);

        loan.__setCollateralRequired(0);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 0);

        loan.__setCollateralRequired(200_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 200_000);

        loan.__setCollateralRequired(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 1_000_000);

        loan.__setCollateralRequired(2_400_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 2_400_000);
    }

    function test_getAdditionalCollateralRequiredFor_varyDrawableFunds() external {
        loan.__setCollateralRequired(2_400_000);
        loan.__setPrincipal(1_000_000);
        loan.__setPrincipalRequested(1_000_000);

        loan.__setDrawableFunds(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 2_400_000);

        loan.__setDrawableFunds(1_200_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 1_920_000);

        loan.__setDrawableFunds(1_800_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 480_000);

        loan.__setDrawableFunds(2_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 0);

        loan.__setDrawableFunds(3_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 0);
    }

    function test_getAdditionalCollateralRequiredFor_varyPrincipal() external {
        loan.__setCollateralRequired(2_000_000);
        loan.__setDrawableFunds(500_000);
        loan.__setPrincipalRequested(1_000_000);

        loan.__setPrincipal(0);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 0);

        loan.__setPrincipal(200_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 400_000);

        loan.__setPrincipal(500_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 1_000_000);

        loan.__setPrincipal(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 2_000_000);

        loan.__setCollateral(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 1_000_000);
    }

    function test_excessCollateral_varyCollateral() external {
        loan.__setCollateralRequired(800_000);
        loan.__setPrincipal(500_000);
        loan.__setPrincipalRequested(1_000_000);

        loan.__setCollateral(0);

        assertEq(loan.excessCollateral(), 0);

        loan.__setCollateral(200_000);

        assertEq(loan.excessCollateral(), 0);

        loan.__setCollateral(400_000);

        assertEq(loan.excessCollateral(), 0);

        loan.__setCollateral(500_000);

        assertEq(loan.excessCollateral(), 100_000);

        loan.__setCollateral(1_000_000);

        assertEq(loan.excessCollateral(), 600_000);

        loan.__setDrawableFunds(1_000_000);
        loan.__setCollateral(0);

        assertEq(loan.excessCollateral(), 0);

        loan.__setCollateral(1_000_000);

        assertEq(loan.excessCollateral(), 1_000_000);
    }

    function test_excessCollateral_varyDrawableFunds() external {
        loan.__setCollateral(1_200_000);
        loan.__setCollateralRequired(2_400_000);
        loan.__setPrincipal(500_000);
        loan.__setPrincipalRequested(1_000_000);

        loan.__setDrawableFunds(0);

        assertEq(loan.excessCollateral(), 0);

        loan.__setDrawableFunds(200_000);

        assertEq(loan.excessCollateral(), 480_000);

        loan.__setDrawableFunds(500_000);

        assertEq(loan.excessCollateral(), 1_200_000);
    }

    function test_excessCollateral_varyPrincipal() external {
        loan.__setCollateral(1_200_000);
        loan.__setCollateralRequired(2_400_000);
        loan.__setPrincipalRequested(1_000_000);

        loan.__setPrincipal(1_000_000);

        assertEq(loan.excessCollateral(), 0);

        loan.__setPrincipal(500_000);

        assertEq(loan.excessCollateral(), 0);

        loan.__setPrincipal(200_000);

        assertEq(loan.excessCollateral(), 720_000);

        loan.__setPrincipal(0);

        assertEq(loan.excessCollateral(), 1_200_000);
    }

    /******************************************************************************************************************************/
    /*** Access Control Tests                                                                                                   ***/
    /******************************************************************************************************************************/

    function test_migrate_acl() external {
        address mockMigrator = address(new EmptyContract());

        vm.expectRevert("ML:M:NOT_FACTORY");
        loan.migrate(mockMigrator, new bytes(0));

        vm.prank(address(factoryMock));
        loan.migrate(mockMigrator, new bytes(0));
    }

    function test_setImplementation_acl() external {
        address someContract = address(new EmptyContract());

        vm.expectRevert("ML:SI:NOT_FACTORY");
        loan.setImplementation(someContract);

        vm.prank(address(factoryMock));
        loan.setImplementation(someContract);
    }

    function test_drawdownFunds_acl() external {
        MockERC20 fundsAsset = new MockERC20("Funds Asset", "FA", 18);

        fundsAsset.mint(address(loan), 1_000_000);

        loan.__setDrawableFunds(1_000_000);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(1_000_000);  // Needed for the getAdditionalCollateralRequiredFor

        vm.expectRevert("ML:DF:NOT_BORROWER");
        loan.drawdownFunds(1, borrower);

        vm.prank(borrower);
        loan.drawdownFunds(1, borrower);
    }

    function test_proposeNewTerms() external {
        address mockRefinancer = address(new EmptyContract());
        uint256 deadline       = block.timestamp + 10 days;
        bytes[] memory calls   = new bytes[](1);
        calls[0]               = new bytes(0);

        vm.prank(borrower);
        bytes32 refinanceCommitment = loan.proposeNewTerms(mockRefinancer, deadline, calls);

        assertEq(refinanceCommitment, bytes32(0xb1a0103ed081b2a53ee9a14438808f7c8ec6fae3fb454378555ecf243be22723));
    }

    function test_proposeNewTerms_acl() external {
        address mockRefinancer = address(new EmptyContract());
        uint256 deadline       = block.timestamp + 10 days;
        bytes[] memory calls   = new bytes[](1);
        calls[0]               = new bytes(0);

        vm.expectRevert("ML:PNT:NOT_BORROWER");
        loan.proposeNewTerms(mockRefinancer, deadline, calls);

        vm.prank(borrower);
        loan.proposeNewTerms(mockRefinancer, deadline, calls);
    }

    function test_proposeNewTerms_invalidDeadline() external {
        address mockRefinancer = address(new EmptyContract());
        bytes[] memory calls   = new bytes[](1);
        calls[0]               = new bytes(0);

        vm.startPrank(borrower);
        vm.expectRevert("ML:PNT:INVALID_DEADLINE");
        loan.proposeNewTerms(mockRefinancer, block.timestamp - 1, calls);

        loan.proposeNewTerms(mockRefinancer, block.timestamp, calls);
    }

    function test_rejectNewTerms_acl() external {
        address mockRefinancer = address(new EmptyContract());
        uint256 deadline       = block.timestamp + 10 days;
        bytes[] memory calls   = new bytes[](1);
        calls[0]               = new bytes(0);

        loan.__setRefinanceCommitment(keccak256(abi.encode(address(mockRefinancer), deadline, calls)));

        vm.expectRevert("ML:RNT:NO_AUTH");
        loan.rejectNewTerms(mockRefinancer, deadline, calls);

        vm.prank(borrower);
        loan.rejectNewTerms(mockRefinancer, deadline, calls);

        // Set again
        loan.__setRefinanceCommitment(keccak256(abi.encode(address(mockRefinancer), deadline, calls)));

        vm.expectRevert("ML:RNT:NO_AUTH");
        loan.rejectNewTerms(mockRefinancer, deadline, calls);

        vm.prank(lender);
        loan.rejectNewTerms(mockRefinancer, deadline, calls);
    }

    function test_removeCollateral_acl() external {
        MockERC20 collateralAsset = new MockERC20("Collateral Asset", "CA", 18);

        loan.__setCollateral(1);
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setPrincipalRequested(1); // Needed for the collateralMaintained check

        collateralAsset.mint(address(loan), 1);

        vm.expectRevert("ML:RC:NOT_BORROWER");
        loan.removeCollateral(1, borrower);

        vm.prank(borrower);
        loan.removeCollateral(1, borrower);
    }

    function test_setPendingBorrower_acl() external {
        globals.setValidBorrower(address(1), true);

        vm.expectRevert("ML:SPB:NOT_BORROWER");
        loan.setPendingBorrower(address(1));

        vm.prank(borrower);
        loan.setPendingBorrower(address(1));
    }

    function test_acceptBorrower_acl() external {
        loan.__setPendingBorrower(user);

        vm.expectRevert("ML:AB:NOT_PENDING_BORROWER");
        loan.acceptBorrower();

        vm.prank(user);
        loan.acceptBorrower();
    }

    function test_acceptNewTerms_acl() external {
        MockERC20 token = new MockERC20("MockToken", "MA", 18);

        loan.__setCollateralAsset(address(token));                // Needed for the getUnaccountedAmount check
        loan.__setFundsAsset(address(token));                     // Needed for the getUnaccountedAmount check
        loan.__setNextPaymentDueDate(block.timestamp + 25 days);  // Needed for origination fee checks
        loan.__setPaymentInterval(30 days);                       // Needed for origination fee checks
        loan.__setPaymentsRemaining(3);                           // Needed for origination fee checks
        loan.__setPrincipalRequested(1);                          // Needed for the collateralMaintained check

        address mockRefinancer = address(new EmptyContract());
        uint256 deadline       = block.timestamp + 10 days;
        bytes[] memory calls   = new bytes[](1);
        calls[0]               = new bytes(0);

        loan.__setRefinanceCommitment(keccak256(abi.encode(mockRefinancer, deadline, calls)));

        vm.expectRevert("ML:ANT:NOT_LENDER");
        loan.acceptNewTerms(mockRefinancer, deadline, calls);

        vm.prank(lender);
        loan.acceptNewTerms(mockRefinancer, deadline, calls);
    }

    function test_removeLoanImpairment_acl() external {
        loan.__setOriginalNextPaymentDueDate(block.timestamp + 300);

        vm.expectRevert("ML:RLI:NOT_LENDER");
        loan.removeLoanImpairment();

        vm.prank(lender);
        loan.removeLoanImpairment();

        assertEq(loan.nextPaymentDueDate(), block.timestamp + 300);
    }

    function test_repossess_acl() external {
        MockERC20 asset = new MockERC20("Asset", "AST", 18);

        loan.__setCollateralAsset(address(asset));
        loan.__setFundsAsset(address(asset));
        loan.__setNextPaymentDueDate(1);

        vm.warp(loan.nextPaymentDueDate() + loan.gracePeriod() + 1);

        vm.expectRevert("ML:R:NOT_LENDER");
        loan.repossess(lender);

        vm.prank(lender);
        loan.repossess(lender);
    }

    function test_impairLoan_acl() external {
        uint256 start = 1 days;  // Non-zero start time.

        vm.warp(start);

        uint256 originalNextPaymentDate = start + 10 days;

        loan.__setNextPaymentDueDate(originalNextPaymentDate);

        vm.expectRevert("ML:IL:NOT_LENDER");
        loan.impairLoan();

        vm.prank(lender);
        loan.impairLoan();
    }

    function test_setPendingLender_acl() external {
        vm.expectRevert("ML:SPL:NOT_LENDER");
        loan.setPendingLender(governor);

        vm.prank(lender);
        loan.setPendingLender(governor);
    }

    function test_acceptLender_acl() external {
        loan.__setPendingLender(address(1));

        vm.expectRevert("ML:AL:NOT_PENDING_LENDER");
        loan.acceptLender();

        vm.prank(address(1));
        loan.acceptLender();
    }

    function test_upgrade_acl() external {
        MockFactory factory = new MockFactory(address(globals));

        loan.__setFactory(address(factory));

        address securityAdmin    = address(new Address());
        address newImplementation = address(new MapleLoanHarness());

        globals.setSecurityAdmin(securityAdmin);

        vm.expectRevert("ML:U:NOT_SECURITY_ADMIN");
        loan.upgrade(1, abi.encode(newImplementation));

        vm.prank(securityAdmin);
        loan.upgrade(1, abi.encode(newImplementation));

        assertEq(loan.implementation(), newImplementation);
    }

    /******************************************************************************************************************************/
    /*** Loan Transfer-Related Tests                                                                                            ***/
    /******************************************************************************************************************************/

    function test_acceptNewTerms() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setNextPaymentDueDate(block.timestamp + 25 days);  // Needed for origination fee checks
        loan.__setPaymentInterval(30 days);                       // Needed for origination fee checks
        loan.__setPaymentsRemaining(3);                           // Needed for origination fee checks
        loan.__setPrincipal(1);
        loan.__setPrincipalRequested(1);

        address refinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("increasePrincipal(uint256)", 1);

        loan.__setRefinanceCommitment(keccak256(abi.encode(refinancer, deadline, calls)));

        fundsAsset.mint(address(loan), 1);

        // Mock refinancer increasing principal and drawable funds.
        loan.__setDrawableFunds(1);
        loan.__setPrincipal(2);

        vm.prank(lender);
        loan.acceptNewTerms(refinancer, deadline, calls);
    }

    function test_impairLoan() external {
        uint256 start = 1 days;  // Non-zero start time.

        vm.warp(start);

        uint256 originalNextPaymentDate = start + 10 days;

        loan.__setNextPaymentDueDate(originalNextPaymentDate);

        assertEq(loan.originalNextPaymentDueDate(), 0);
        assertEq(loan.nextPaymentDueDate(),         originalNextPaymentDate);

        vm.prank(lender);
        loan.impairLoan();

        assertEq(loan.originalNextPaymentDueDate(), originalNextPaymentDate);
        assertEq(loan.nextPaymentDueDate(),         start);
    }

    function test_impairLoan_lateLoan() external {
        uint256 start = 1 days;  // Non-zero start time.

        uint256 originalNextPaymentDate = start + 10 days;

        loan.__setNextPaymentDueDate(originalNextPaymentDate);

        vm.warp(originalNextPaymentDate + 1 days);

        assertEq(loan.originalNextPaymentDueDate(), 0);
        assertEq(loan.nextPaymentDueDate(),         originalNextPaymentDate);

        vm.prank(lender);
        loan.impairLoan();

        assertEq(loan.originalNextPaymentDueDate(), originalNextPaymentDate);
        assertEq(loan.nextPaymentDueDate(),         originalNextPaymentDate);
    }

    function test_removeLoanImpairment_notImpaired() external {
        vm.prank(lender);
        vm.expectRevert("ML:RLI:NOT_IMPAIRED");
        loan.removeLoanImpairment();
    }

    function test_removeLoanImpairment_pastDate() external {
        vm.warp(1 days);

        loan.__setOriginalNextPaymentDueDate(block.timestamp - 1);

        vm.prank(lender);
        vm.expectRevert("ML:RLI:PAST_DATE");
        loan.removeLoanImpairment();
    }

    function test_removeLoanImpairment_success() external {
        vm.warp(1 days);

        loan.__setNextPaymentDueDate(block.timestamp);
        loan.__setOriginalNextPaymentDueDate(block.timestamp + 1);

        assertEq(loan.nextPaymentDueDate(), block.timestamp);

        vm.prank(lender);
        loan.removeLoanImpairment();

        assertEq(loan.nextPaymentDueDate(), block.timestamp + 1);
    }

    function test_fundLoan_pushPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(amount);

        // Fails without pushing funds
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.fundLoan(lender);

        fundsAsset.mint(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.principal(),                    0);

        loan.fundLoan(lender);

        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.principal(),                    amount);
    }

    // TODO: Add overfund and overfund ANT test failure cases.

    function test_drawdownFunds_withoutAdditionalCollateralRequired() external {
        MockERC20 fundsAsset      = new MockERC20("FA", "FA", 18);
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 amount = 1_000_000;

        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setDrawableFunds(amount);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);

        // Send amount to loan
        fundsAsset.mint(address(loan), amount);

        assertEq(fundsAsset.balanceOf(borrower),      0);
        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.drawableFunds(),                amount);

        vm.prank(borrower);
        loan.drawdownFunds(amount, borrower);

        assertEq(fundsAsset.balanceOf(borrower),      amount);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.drawableFunds(),                0);
    }

    function test_drawdownFunds_pullPatternForCollateral() external {
        MockERC20 fundsAsset      = new MockERC20("FA", "FA", 18);
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 fundsAssetAmount      = 1_000_000;
        uint256 collateralAssetAmount = 300_000;

        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setCollateralRequired(collateralAssetAmount);
        loan.__setDrawableFunds(fundsAssetAmount);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipal(fundsAssetAmount);
        loan.__setPrincipalRequested(fundsAssetAmount);

        vm.startPrank(borrower);

        // Send amount to loan
        fundsAsset.mint(address(loan), fundsAssetAmount);
        collateralAsset.mint(borrower, collateralAssetAmount);

        // Fail without approval
        vm.expectRevert("ML:PC:TRANSFER_FROM_FAILED");
        loan.drawdownFunds(fundsAssetAmount, borrower);

        collateralAsset.approve(address(loan), collateralAssetAmount);

        assertEq(fundsAsset.balanceOf(borrower),           0);
        assertEq(fundsAsset.balanceOf(address(loan)),      fundsAssetAmount);
        assertEq(collateralAsset.balanceOf(borrower),      collateralAssetAmount);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(loan.collateral(),                        0);
        assertEq(loan.drawableFunds(),                     fundsAssetAmount);

        loan.drawdownFunds(fundsAssetAmount, borrower);

        assertEq(fundsAsset.balanceOf(borrower),           fundsAssetAmount);
        assertEq(fundsAsset.balanceOf(address(loan)),      0);
        assertEq(collateralAsset.balanceOf(borrower),      0);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralAssetAmount);
        assertEq(loan.collateral(),                        collateralAssetAmount);
        assertEq(loan.drawableFunds(),                     0);
    }

    function test_drawdownFunds_pushPatternForCollateral() external {
        MockERC20 fundsAsset      = new MockERC20("FA", "FA", 18);
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 fundsAssetAmount      = 1_000_000;
        uint256 collateralAssetAmount = 300_000;

        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setCollateralRequired(collateralAssetAmount);
        loan.__setDrawableFunds(fundsAssetAmount);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipal(fundsAssetAmount);
        loan.__setPrincipalRequested(fundsAssetAmount);

        // Send amount to loan
        fundsAsset.mint(address(loan), fundsAssetAmount);

        // Fail without approval
        vm.startPrank(borrower);
        vm.expectRevert("ML:PC:TRANSFER_FROM_FAILED");
        loan.drawdownFunds(fundsAssetAmount, borrower);

        // "Transfer" funds into the loan
        collateralAsset.mint(address(loan), collateralAssetAmount);

        assertEq(fundsAsset.balanceOf(borrower),           0);
        assertEq(fundsAsset.balanceOf(address(loan)),      fundsAssetAmount);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralAssetAmount);
        assertEq(loan.collateral(),                        0);
        assertEq(loan.drawableFunds(),                     fundsAssetAmount);

        loan.drawdownFunds(fundsAssetAmount, borrower);

        assertEq(fundsAsset.balanceOf(borrower),           fundsAssetAmount);
        assertEq(fundsAsset.balanceOf(address(loan)),      0);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralAssetAmount);
        assertEq(loan.collateral(),                        collateralAssetAmount);
        assertEq(loan.drawableFunds(),                     0);
    }

    function test_closeLoan_pullPatternAsBorrower() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(borrower), amount);

        assertEq(fundsAsset.balanceOf(address(borrower)), amount);
        assertEq(fundsAsset.balanceOf(address(lender)),   0);
        assertEq(loan.principal(),                        amount);

        vm.startPrank(borrower);
        vm.expectRevert("ML:CL:TRANSFER_FROM_FAILED");
        loan.closeLoan(amount);

        fundsAsset.approve(address(loan), amount);

        loan.closeLoan(amount);

        assertEq(fundsAsset.balanceOf(address(borrower)), 0);
        assertEq(fundsAsset.balanceOf(address(lender)),   amount);
        assertEq(loan.paymentsRemaining(),                0);
        assertEq(loan.principal(),                        0);
    }

    function test_closeLoan_pushPatternAsBorrower() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(borrower), amount);

        assertEq(fundsAsset.balanceOf(address(borrower)), amount);
        assertEq(fundsAsset.balanceOf(address(lender)),   0);
        assertEq(loan.principal(),                        amount);

        vm.startPrank(borrower);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.closeLoan(0);

        fundsAsset.transfer(address(loan), amount);

        loan.closeLoan(0);

        assertEq(fundsAsset.balanceOf(address(borrower)), 0);
        assertEq(fundsAsset.balanceOf(address(lender)),   amount);
        assertEq(loan.paymentsRemaining(),                0);
        assertEq(loan.principal(),                        0);
    }

    function test_closeLoan_pullPatternAsNonBorrower() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(user), amount);

        assertEq(fundsAsset.balanceOf(address(user)),   amount);
        assertEq(fundsAsset.balanceOf(address(lender)), 0);
        assertEq(loan.principal(),                      amount);

        vm.startPrank(user);
        vm.expectRevert("ML:CL:TRANSFER_FROM_FAILED");
        loan.closeLoan(amount);

        fundsAsset.approve(address(loan), amount);

        loan.closeLoan(amount);

        assertEq(fundsAsset.balanceOf(address(user)),   0);
        assertEq(fundsAsset.balanceOf(address(lender)), amount);
        assertEq(loan.paymentsRemaining(),              0);
        assertEq(loan.principal(),                      0);
    }

    function test_closeLoan_pushPatternAsNonBorrower() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(user), amount);

        assertEq(fundsAsset.balanceOf(address(user)),   amount);
        assertEq(fundsAsset.balanceOf(address(lender)), 0);
        assertEq(loan.principal(),                      amount);

        vm.startPrank(user);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.closeLoan(0);

        fundsAsset.transfer(address(loan), amount);

        loan.closeLoan(0);

        assertEq(fundsAsset.balanceOf(address(user)),   0);
        assertEq(fundsAsset.balanceOf(address(lender)), amount);
        assertEq(loan.paymentsRemaining(),              0);
        assertEq(loan.principal(),                      0);
    }

    function test_closeLoan_pullPatternUsingDrawable() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);

        vm.startPrank(user);
        fundsAsset.approve(address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        vm.expectRevert("ML:CANNOT_USE_DRAWABLE");
        loan.closeLoan(totalPayment - 1);
        vm.stopPrank();

        fundsAsset.mint(address(borrower), totalPayment - 1);

        vm.startPrank(borrower);
        fundsAsset.approve(address(loan), totalPayment - 1);

        // This should succeed since it the borrower can use drawableFunds.
        loan.closeLoan(totalPayment - 1);
    }

    function test_closeLoan_pushPatternUsingDrawable() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);

        vm.startPrank(user);
        fundsAsset.transfer(address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        vm.expectRevert("ML:CANNOT_USE_DRAWABLE");
        loan.closeLoan(0);
        vm.stopPrank();

        // This should succeed since the borrower can use drawableFunds, and there is already unaccounted amount thanks to the previous user transfer.
        vm.prank(borrower);
        loan.closeLoan(0);
    }

    function test_makePayment_pullPatternAsBorrower() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setEndingPrincipal(uint256(0));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(3);
        loan.__setPrincipal(startingPrincipal);
        loan.__setPrincipalRequested(startingPrincipal);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(borrower), totalPayment);

        assertEq(fundsAsset.balanceOf(address(borrower)), totalPayment);
        assertEq(fundsAsset.balanceOf(address(lender)),   0);
        assertEq(loan.paymentsRemaining(),                3);
        assertEq(loan.principal(),                        startingPrincipal);

        vm.startPrank(borrower);
        vm.expectRevert("ML:MP:TRANSFER_FROM_FAILED");
        loan.makePayment(totalPayment);

        fundsAsset.approve(address(loan), totalPayment);

        loan.makePayment(totalPayment);

        assertEq(fundsAsset.balanceOf(address(borrower)), 0);
        assertEq(fundsAsset.balanceOf(address(lender)),   totalPayment);
        assertEq(loan.paymentsRemaining(),                2);
        assertEq(loan.principal(),                        startingPrincipal - principal);
    }

    function test_makePayment_pushPatternAsBorrower() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setEndingPrincipal(uint256(0));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(3);
        loan.__setPrincipal(startingPrincipal);
        loan.__setPrincipalRequested(startingPrincipal);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(borrower), totalPayment);

        assertEq(fundsAsset.balanceOf(address(borrower)), totalPayment);
        assertEq(fundsAsset.balanceOf(address(lender)),   0);
        assertEq(loan.paymentsRemaining(),                3);
        assertEq(loan.principal(),                        startingPrincipal);

        vm.startPrank(borrower);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.makePayment(0);

        fundsAsset.transfer(address(loan), totalPayment);

        loan.makePayment(0);

        assertEq(fundsAsset.balanceOf(address(borrower)), 0);
        assertEq(fundsAsset.balanceOf(address(lender)),   totalPayment);
        assertEq(loan.paymentsRemaining(),                2);
        assertEq(loan.principal(),                        startingPrincipal - principal);
    }

    function test_makePayment_pullPatternAsNonBorrower() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setEndingPrincipal(uint256(0));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(3);
        loan.__setPrincipal(startingPrincipal);
        loan.__setPrincipalRequested(startingPrincipal);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(user), totalPayment);

        assertEq(fundsAsset.balanceOf(address(user)),   totalPayment);
        assertEq(fundsAsset.balanceOf(address(lender)), 0);
        assertEq(loan.paymentsRemaining(),              3);
        assertEq(loan.principal(),                      startingPrincipal);

        vm.startPrank(user);
        vm.expectRevert("ML:MP:TRANSFER_FROM_FAILED");
        loan.makePayment(totalPayment);

        fundsAsset.approve(address(loan), totalPayment);

        loan.makePayment(totalPayment);

        assertEq(fundsAsset.balanceOf(address(user)),   0);
        assertEq(fundsAsset.balanceOf(address(lender)), totalPayment);
        assertEq(loan.paymentsRemaining(),              2);
        assertEq(loan.principal(),                      startingPrincipal - principal);
    }

    function test_makePayment_pushPatternAsNonBorrower() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setEndingPrincipal(uint256(0));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(3);
        loan.__setPrincipal(startingPrincipal);
        loan.__setPrincipalRequested(startingPrincipal);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(user), totalPayment);

        assertEq(fundsAsset.balanceOf(address(user)),   totalPayment);
        assertEq(fundsAsset.balanceOf(address(lender)), 0);
        assertEq(loan.paymentsRemaining(),              3);
        assertEq(loan.principal(),                      startingPrincipal);

        vm.startPrank(user);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.makePayment(0);

        fundsAsset.transfer(address(loan), totalPayment);

        loan.makePayment(0);

        assertEq(fundsAsset.balanceOf(address(user)),   0);
        assertEq(fundsAsset.balanceOf(address(lender)), totalPayment);
        assertEq(loan.paymentsRemaining(),              2);
        assertEq(loan.principal(),                      startingPrincipal - principal);
    }

    function test_makePayment_pullPatternUsingDrawable() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setEndingPrincipal(uint256(0));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(3);
        loan.__setPrincipal(startingPrincipal);
        loan.__setPrincipalRequested(startingPrincipal);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);

        vm.startPrank(user);
        fundsAsset.approve(address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        vm.expectRevert("ML:CANNOT_USE_DRAWABLE");
        loan.makePayment(totalPayment - 1);
        vm.stopPrank();

        fundsAsset.mint(address(borrower), totalPayment - 1);

        vm.startPrank(borrower);
        fundsAsset.approve(address(loan), totalPayment - 1);

        // This should succeed since it the borrower can use drawableFunds.
        loan.makePayment(totalPayment - 1);
    }

    function test_makePayment_pushPatternUsingDrawable() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setEndingPrincipal(uint256(0));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(3);
        loan.__setPrincipal(startingPrincipal);
        loan.__setPrincipalRequested(startingPrincipal);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);

        vm.startPrank(user);
        fundsAsset.transfer(address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        vm.expectRevert("ML:CANNOT_USE_DRAWABLE");
        loan.makePayment(0);
        vm.stopPrank();

        // This should succeed since the borrower can use drawableFunds, and there is already unaccounted amount thanks to the previous user transfer.
        vm.prank(borrower);
        loan.makePayment(0);
    }

    function test_postCollateral_pullPattern() external {
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        loan.__setCollateralAsset(address(collateralAsset));

        uint256 amount = 1_000_000;

        collateralAsset.mint(borrower, amount);

        vm.startPrank(borrower);
        vm.expectRevert("ML:PC:TRANSFER_FROM_FAILED");
        loan.postCollateral(amount);

        collateralAsset.approve(address(loan), amount);

        assertEq(collateralAsset.balanceOf(borrower),      amount);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(loan.collateral(),                        0);

        loan.postCollateral(amount);

        assertEq(collateralAsset.balanceOf(borrower),      0);
        assertEq(collateralAsset.balanceOf(address(loan)), amount);
        assertEq(loan.collateral(),                        amount);
    }

    function test_postCollateral_pushPattern() external {
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        loan.__setCollateralAsset(address(collateralAsset));

        uint256 amount = 1_000_000;

        collateralAsset.mint(address(loan), amount);

        assertEq(collateralAsset.balanceOf(address(loan)), amount);
        assertEq(loan.collateral(),                        0);

        loan.postCollateral(0);

        assertEq(collateralAsset.balanceOf(address(loan)), amount);
        assertEq(loan.collateral(),                        amount);
    }

    function test_returnFunds_pullPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        loan.__setFundsAsset(address(fundsAsset));

        uint256 amount = 1_000_000;

        fundsAsset.mint(borrower, amount);

        vm.startPrank(borrower);
        vm.expectRevert("ML:RF:TRANSFER_FROM_FAILED");
        loan.returnFunds(amount);

        fundsAsset.approve(address(loan), amount);

        assertEq(fundsAsset.balanceOf(borrower),      amount);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.drawableFunds(),                0);

        loan.returnFunds(amount);

        assertEq(fundsAsset.balanceOf(borrower),      0);
        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.drawableFunds(),                amount);
    }

    function test_returnFunds_pushPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        loan.__setFundsAsset(address(fundsAsset));

        uint256 amount = 1_000_000;

        fundsAsset.mint(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.drawableFunds(),                0);

        loan.returnFunds(0);  // No try catch since returnFunds can pass with zero amount

        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.drawableFunds(),                amount);
    }

    /******************************************************************************************************************************/
    /*** Pause Tests                                                                                                            ***/
    /******************************************************************************************************************************/

    function test_acceptBorrower_failWhenPaused() external {
        // Set up
        address newBorrower = address(new Address());
        loan.__setPendingBorrower(newBorrower);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(address(newBorrower));
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.acceptBorrower();

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(newBorrower);
        loan.acceptBorrower();
    }

    function test_acceptLender_failWhenPaused() external {
        // Set up
        address newLendewr = address(new Address());
        loan.__setPendingLender(newLendewr);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(address(newLendewr));
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.acceptLender();

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(newLendewr);
        loan.acceptLender();
    }

    function test_closeLoan_failWhenPaused() external {
        // Set up
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(loan), amount);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(borrower);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.closeLoan(uint256(0));

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(borrower);
        loan.closeLoan(uint256(0));
    }

    function test_drawdown_failWhenPaused() external {
        // Set up
        MockERC20 fundsAsset      = new MockERC20("FA", "FA", 18);
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 amount = 1_000_000;

        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setDrawableFunds(amount);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipal(amount);
        loan.__setPrincipalRequested(amount);

        // Send amount to loan
        fundsAsset.mint(address(loan), amount);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(borrower);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.drawdownFunds(amount, borrower);

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(borrower);
        loan.drawdownFunds(amount, borrower);
    }

    function test_makePayment_failWhenPaused() external {
        // Set up
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setEndingPrincipal(uint256(0));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPaymentsRemaining(3);
        loan.__setPrincipal(startingPrincipal);
        loan.__setPrincipalRequested(startingPrincipal);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), totalPayment);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(borrower);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.makePayment(0);

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(borrower);
        loan.makePayment(0);
    }

    function test_postCollateral_failWhenPaused() external {
        // Set up
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        loan.__setCollateralAsset(address(collateralAsset));

        uint256 amount = 1_000_000;

        collateralAsset.mint(address(loan), amount);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.postCollateral(0);

        // Success case
        globals.setProtocolPaused(false);

        loan.postCollateral(0);
    }

    function test_proposeNewTerms_failWhenPaused() external {
        // Set up
        address refinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("increasePrincipal(uint256)", 1);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(borrower);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.proposeNewTerms(refinancer, deadline, calls);

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(borrower);
        loan.proposeNewTerms(refinancer, deadline, calls);
    }

    function test_rejectNewTerms_failWhenPaused() external {
        // Set up
        address refinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("increasePrincipal(uint256)", 1);

        loan.__setRefinanceCommitment(keccak256(abi.encode(refinancer, deadline, calls)));

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(borrower);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.rejectNewTerms(refinancer, deadline, calls);

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(borrower);
        loan.rejectNewTerms(refinancer, deadline, calls);
    }

    function test_removeCollateral_failWhenPaused() external {
        // Set up
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 amount = 1_000_000;

        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setCollateral(amount);

        collateralAsset.mint(address(loan), amount);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(borrower);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.removeCollateral(amount, address(borrower));

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(borrower);
        loan.removeCollateral(amount, address(borrower));
    }

    function test_returnFunds_failWhenPaused() external {
        // Set up
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        loan.__setFundsAsset(address(fundsAsset));

        uint256 amount = 1_000_000;

        fundsAsset.mint(address(loan), amount);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.returnFunds(0);

        // Success case
        globals.setProtocolPaused(false);

        loan.returnFunds(0);
    }

    function test_setPendingBorrower_failWhenPaused() external {
        // Set up
        address newBorrower = address(new Address());

        globals.setValidBorrower(newBorrower, true);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(borrower);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.setPendingBorrower(newBorrower);

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(borrower);
        loan.setPendingBorrower(newBorrower);
    }

    function test_skim_failWhenPaused() external {
        // Set up
        MockERC20 asset = new MockERC20("CA", "CA", 18);

        uint256 amount = 1_000_000;

        asset.mint(address(loan), amount);

        // Trigger pause and  assert failure
        globals.setProtocolPaused(true);

        vm.prank(borrower);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.skim(address(asset), address(this));

        // Success case
        globals.setProtocolPaused(false);

        vm.prank(borrower);
        loan.skim(address(asset), address(this));
    }

}

contract MapleLoanRoleTests is TestUtils {

    address lender;

    address borrower = address(new Address());
    address governor = address(new Address());

    ConstructableMapleLoan loan;
    MapleGlobalsMock       globals;
    MockERC20              token;
    MockFactory            factory;
    MockFeeManager         feeManager;

    function setUp() public {
        lender     = address(new MockLoanManager());
        globals    = new MapleGlobalsMock(governor, MockLoanManager(lender).factory());
        feeManager = new MockFeeManager();
        token      = new MockERC20("Token", "T", 0);

        factory = new MockFactory(address(globals));

        address[2] memory assets      = [address(token), address(token)];
        uint256[3] memory termDetails = [uint256(10 days), uint256(365 days / 6), uint256(6)];
        uint256[3] memory amounts     = [uint256(300_000), uint256(1_000_000), uint256(0)];
        uint256[4] memory rates       = [uint256(0.12e18), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        globals.setValidBorrower(borrower,              true);
        globals.setValidCollateralAsset(address(token), true);
        globals.setValidPoolAsset(address(token),       true);

        vm.prank(address(factory));
        loan = new ConstructableMapleLoan(address(factory), borrower, address(feeManager), assets, termDetails, amounts, rates, fees);
    }

    function test_transferBorrowerRole_failIfInvalidBorrower() public {
        address newBorrower = address(new Address());

        vm.prank(address(borrower));
        vm.expectRevert("ML:SPB:INVALID_BORROWER");
        loan.setPendingBorrower(address(newBorrower));
    }

    function test_transferBorrowerRole() public {
        address newBorrower = address(new Address());

        // Set addresse used in this test case as valid borrowers.
        globals.setValidBorrower(address(newBorrower), true);
        globals.setValidBorrower(address(1),           true);

        assertEq(loan.pendingBorrower(), address(0));
        assertEq(loan.borrower(),        borrower);

        // Only borrower can call setPendingBorrower
        vm.prank(newBorrower);
        vm.expectRevert("ML:SPB:NOT_BORROWER");
        loan.setPendingBorrower(newBorrower);

        vm.prank(borrower);
        loan.setPendingBorrower(newBorrower);

        assertEq(loan.pendingBorrower(), newBorrower);

        // Pending borrower can't call setPendingBorrower
        vm.prank(newBorrower);
        vm.expectRevert("ML:SPB:NOT_BORROWER");
        loan.setPendingBorrower(address(1));

        vm.prank(borrower);
        loan.setPendingBorrower(address(1));

        assertEq(loan.pendingBorrower(), address(1));

        // Can be reset if mistake is made
        vm.prank(borrower);
        loan.setPendingBorrower(newBorrower);

        assertEq(loan.pendingBorrower(), newBorrower);
        assertEq(loan.borrower(),        borrower);

        // Pending borrower is the only one who can call acceptBorrower
        vm.prank(borrower);
        vm.expectRevert("ML:AB:NOT_PENDING_BORROWER");
        loan.acceptBorrower();

        vm.prank(newBorrower);
        loan.acceptBorrower();

        // Pending borrower is set to zero
        assertEq(loan.pendingBorrower(), address(0));
        assertEq(loan.borrower(),        newBorrower);
    }

    function test_transferLenderRole() public {
        // Fund the loan to set the lender
        token.mint(address(loan), 1_000_000);

        vm.prank(lender);
        loan.fundLoan(lender);

        address newLender = address(new Address());

        assertEq(loan.pendingLender(), address(0));
        assertEq(loan.lender(),        lender);

        // Only lender can call setPendingLender
        vm.prank(newLender);
        vm.expectRevert("ML:SPL:NOT_LENDER");
        loan.setPendingLender(newLender);

        vm.prank(lender);
        loan.setPendingLender(newLender);

        assertEq(loan.pendingLender(), newLender);

        // Pending lender can't call setPendingLender
        vm.prank(newLender);
        vm.expectRevert("ML:SPL:NOT_LENDER");
        loan.setPendingLender(address(1));

        vm.prank(lender);
        loan.setPendingLender(address(1));

        assertEq(loan.pendingLender(), address(1));

        // Can be reset if mistake is made
        vm.prank(lender);
        loan.setPendingLender(newLender);

        assertEq(loan.pendingLender(), newLender);
        assertEq(loan.lender(),        lender);

        // Pending lender is the only one who can call acceptLender
        vm.prank(lender);
        vm.expectRevert("ML:AL:NOT_PENDING_LENDER");
        loan.acceptLender();

        vm.prank(newLender);
        loan.acceptLender();

        // Pending lender is set to zero
        assertEq(loan.pendingLender(), address(0));
        assertEq(loan.lender(),        newLender);
    }

}
