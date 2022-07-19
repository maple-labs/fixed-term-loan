// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }    from "../../modules/erc20/contracts/interfaces/IERC20.sol";
import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { IMapleLoan } from "../interfaces/IMapleLoan.sol";

import { ConstructableMapleLoan, MapleLoanHarness } from "./harnesses/MapleLoanHarnesses.sol";

import { EmptyContract, MapleGlobalsMock, MockFactory, MockFeeManager } from "./mocks/Mocks.sol";

import { Borrower } from "./accounts/Borrower.sol";
import { Governor } from "./accounts/Governor.sol";
import { Lender }   from "./accounts/Lender.sol";
import { LoanUser } from "./accounts/LoanUser.sol";

contract MapleLoanTests is TestUtils {

    MapleLoanHarness loan;

    bool locked;  // Helper state variable to avoid infinite loops when using the modifier.

    function setUp() external {
        MockFactory    factoryMock = new MockFactory();
        MockFeeManager feeManager  = new MockFeeManager();

        loan = new MapleLoanHarness();

        loan.__setFactory(address(factoryMock));
        loan.__setFeeManager(address(feeManager));
    }

    /***********************************/
    /*** Collateral Management Tests ***/
    /***********************************/

    function test_getAdditionalCollateralRequiredFor_varyAmount() external {
        loan.__setPrincipalRequested(1_000_000);
        loan.__setCollateralRequired(800_000);
        loan.__setPrincipal(500_000);
        loan.__setDrawableFunds(1_000_000);

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
        loan.__setPrincipalRequested(1_000_000);
        loan.__setPrincipal(1_000_000);
        loan.__setDrawableFunds(1_000_000);

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
        loan.__setPrincipalRequested(1_000_000);
        loan.__setCollateralRequired(2_400_000);
        loan.__setPrincipal(1_000_000);

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
        loan.__setPrincipalRequested(1_000_000);
        loan.__setCollateralRequired(2_000_000);
        loan.__setDrawableFunds(500_000);

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
        loan.__setPrincipalRequested(1_000_000);
        loan.__setCollateralRequired(800_000);
        loan.__setPrincipal(500_000);

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
        loan.__setPrincipalRequested(1_000_000);
        loan.__setCollateralRequired(2_400_000);
        loan.__setPrincipal(500_000);
        loan.__setCollateral(1_200_000);

        loan.__setDrawableFunds(0);

        assertEq(loan.excessCollateral(), 0);

        loan.__setDrawableFunds(200_000);

        assertEq(loan.excessCollateral(), 480_000);

        loan.__setDrawableFunds(500_000);

        assertEq(loan.excessCollateral(), 1_200_000);
    }

    function test_excessCollateral_varyPrincipal() external {
        loan.__setPrincipalRequested(1_000_000);
        loan.__setCollateralRequired(2_400_000);
        loan.__setCollateral(1_200_000);

        loan.__setPrincipal(1_000_000);

        assertEq(loan.excessCollateral(), 0);

        loan.__setPrincipal(500_000);

        assertEq(loan.excessCollateral(), 0);

        loan.__setPrincipal(200_000);

        assertEq(loan.excessCollateral(), 720_000);

        loan.__setPrincipal(0);

        assertEq(loan.excessCollateral(), 1_200_000);
    }

    /****************************/
    /*** Access Control Tests ***/
    /****************************/

    function test_migrate_acl() external {
        address mockMigrator = address(new EmptyContract());

        try loan.migrate(mockMigrator, new bytes(0)) { assertTrue(false, "Non-factory was able to migrate"); } catch { }

        // TODO: prank
        loan.__setFactory(address(this));

        loan.migrate(mockMigrator, new bytes(0));
    }

    function test_setImplementation_acl() external {
        try loan.setImplementation(address(this)) { assertTrue(false, "Non-factory was able to set implementation"); } catch { }

        // TODO: prank
        loan.__setFactory(address(this));

        loan.setImplementation(address(this));
    }

    function test_drawdownFunds_acl() external {
        MockERC20 fundsAsset = new MockERC20("Funds Asset", "FA", 18);

        fundsAsset.mint(address(loan), 1_000_000);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(1_000_000);  // Needed for the getAdditionalCollateralRequiredFor
        loan.__setDrawableFunds(1_000_000);

        try loan.drawdownFunds(1, address(this)) { assertTrue(false, "Non-borrower was able to drawdown"); } catch { }

        // TODO: prank
        loan.__setBorrower(address(this));

        loan.drawdownFunds(1, address(this));
    }

    function test_proposeNewTerms() external {
        address mockRefinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = new bytes(0);

        // TODO: prank
        loan.__setBorrower(address(this));

        bytes32 refinanceCommitment = loan.proposeNewTerms(mockRefinancer, deadline, calls);

        assertEq(refinanceCommitment, bytes32(0x1981fade01c173d23aff6ce8ca84f8d60963a68b6a89e040daeb2059098ebd87));
    }

    function test_proposeNewTerms_acl() external {
        address mockRefinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = new bytes(0);

        vm.expectRevert("ML:PNT:NOT_BORROWER");
        loan.proposeNewTerms(mockRefinancer, deadline, calls);

        // TODO: prank
        loan.__setBorrower(address(this));

        loan.proposeNewTerms(mockRefinancer, deadline, calls);
    }

    function test_proposeNewTerms_invalidDeadline() external {
        address mockRefinancer = address(new EmptyContract());
        bytes[] memory calls = new bytes[](1);
        calls[0] = new bytes(0);

        // TODO: prank
        loan.__setBorrower(address(this));

        vm.expectRevert("ML:PNT:INVALID_DEADLINE");
        loan.proposeNewTerms(mockRefinancer, block.timestamp - 1, calls);

        loan.proposeNewTerms(mockRefinancer, block.timestamp, calls);
    }

    function test_rejectNewTerms_acl() external {
        address mockRefinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = new bytes(0);

        loan.__setRefinanceCommitment(keccak256(abi.encode(address(mockRefinancer), deadline, calls)));

        vm.expectRevert(bytes("L:RNT:NO_AUTH"));
        loan.rejectNewTerms(mockRefinancer, deadline, calls);

        // TODO: prank
        loan.__setBorrower(address(this));

        loan.rejectNewTerms(mockRefinancer, deadline, calls);

        // Set again
        loan.__setRefinanceCommitment(keccak256(abi.encode(address(mockRefinancer), deadline, calls)));
        loan.__setBorrower(address(1));

        vm.expectRevert(bytes("L:RNT:NO_AUTH"));
        loan.rejectNewTerms(mockRefinancer, deadline, calls);

        // TODO: prank
        loan.__setLender(address(this));

        loan.rejectNewTerms(mockRefinancer, deadline, calls);
    }

    function test_removeCollateral_acl() external {
        MockERC20 collateralAsset = new MockERC20("Collateral Asset", "CA", 18);

        loan.__setPrincipalRequested(1); // Needed for the collateralMaintained check
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setCollateral(1);

        collateralAsset.mint(address(loan), 1);

        try loan.removeCollateral(1, address(this)) { assertTrue(false, "Non-borrower was able to remove collateral"); } catch { }

        // TODO: prank
        loan.__setBorrower(address(this));

        loan.removeCollateral(1, address(this));
    }

    function test_setBorrower_acl() external {
        try loan.setPendingBorrower(address(1)) { assertTrue(false, "Non-borrower was able to set borrower"); } catch { }

        // TODO: prank
        loan.__setBorrower(address(this));

        loan.setPendingBorrower(address(1));
    }

    function test_acceptBorrower_acl() external {
        loan.__setPendingBorrower(address(1));

        try loan.acceptBorrower() { assertTrue(false, "Non-pendingBorrower was able to set borrower"); } catch { }

        // TODO: prank
        loan.__setPendingBorrower(address(this));

        loan.acceptBorrower();
    }

    function test_acceptNewTerms_acl() external {
        MockERC20 token = new MockERC20("MockToken", "MA", 18);

        loan.__setPrincipalRequested(1);            // Needed for the collateralMaintained check
        loan.__setCollateralAsset(address(token));  // Needed for the getUnaccountedAmount check
        loan.__setFundsAsset(address(token));       // Needed for the getUnaccountedAmount check

        loan.__setPaymentInterval(30 days);                       // Needed for establishment fee checks (TODO update)
        loan.__setNextPaymentDueDate(block.timestamp + 25 days);  // Needed for establishment fee checks (TODO update)
        loan.__setPaymentsRemaining(3);                           // Needed for establishment fee checks (TODO update)

        address mockRefinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = new bytes(0);

        loan.__setRefinanceCommitment(keccak256(abi.encode(mockRefinancer, deadline, calls)));

        vm.expectRevert("ML:ANT:NOT_LENDER");
        loan.acceptNewTerms(mockRefinancer, deadline, calls, uint256(0));

        // TODO: prank
        loan.__setLender(address(this));

        loan.acceptNewTerms(mockRefinancer, deadline, calls, uint256(0));
    }

    function test_claimFunds_acl() external {
        MockERC20 fundsAsset = new MockERC20("Funds Asset", "FA", 18);

        fundsAsset.mint(address(loan), 200_000);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setClaimableFunds(uint256(200_000));

        try loan.claimFunds(uint256(200_000), address(this)) { assertTrue(false, "Non-lender was able to claim funds"); } catch { }

        // TODO: prank
        loan.__setLender(address(this));

        loan.claimFunds(uint256(200_000), address(this));
    }

    function test_repossess_acl() external {
        MockERC20 asset = new MockERC20("Asset", "AST", 18);

        loan.__setNextPaymentDueDate(1);
        loan.__setCollateralAsset(address(asset));
        loan.__setFundsAsset(address(asset));

        vm.warp(loan.nextPaymentDueDate() + loan.gracePeriod() + 1);

        try loan.repossess(address(this)) {  assertTrue(false, "Non-lender was able to repossess"); } catch { }

        // TODO: prank
        loan.__setLender(address(this));

        loan.repossess(address(this));
    }

    function test_triggerDefaultWarning_acl() external {
        loan.__setLender(address(1));

        uint256 start = 1 days;  // Non-zero start time.

        vm.warp(start);

        uint256 originalNextPaymentDate = start + 10 days;

        loan.__setNextPaymentDueDate(originalNextPaymentDate);

        uint256 timeToFastForwardTo = start + 5 days;

        vm.warp(timeToFastForwardTo);

        vm.expectRevert("ML:TDW:NOT_LENDER");
        loan.triggerDefaultWarning(block.timestamp);

        loan.__setLender(address(this));
        loan.triggerDefaultWarning(block.timestamp);
    }

    function test_setLender_acl() external {
        try loan.setPendingLender(address(this)) {  assertTrue(false, "Non-lender was able to set lender"); } catch { }

        // TODO: prank
        loan.__setLender(address(this));

        loan.setPendingLender(address(this));
    }

    function test_acceptLender_acl() external {
        loan.__setPendingLender(address(1));

        try loan.acceptLender() { assertTrue(false, "Non-pendingLender was able to set borrower"); } catch { }

        // TODO: prank
        loan.__setPendingLender(address(this));

        loan.acceptLender();
    }

    function test_skim_acl() external {
        MockERC20 otherAsset = new MockERC20("OA", "OA", 18);

        otherAsset.mint(address(loan), 1);

        try loan.skim(address(otherAsset), address(this)) { assertTrue(false, "Non-lender or borrower was able to set lender"); } catch { }

        // TODO: prank
        loan.__setLender(address(this));

        assertEq(otherAsset.balanceOf(address(loan)), 1);
        assertEq(otherAsset.balanceOf(address(1)),    0);

        loan.skim(address(otherAsset), address(1));

        assertEq(otherAsset.balanceOf(address(loan)), 0);
        assertEq(otherAsset.balanceOf(address(1)),    1);

        loan.__setLender(address(2));

        // TODO: prank
        loan.__setBorrower(address(this));

        otherAsset.mint(address(loan), 1);

        assertEq(otherAsset.balanceOf(address(loan)), 1);
        assertEq(otherAsset.balanceOf(address(2)),    0);

        loan.skim(address(otherAsset), address(2));

        assertEq(otherAsset.balanceOf(address(loan)), 0);
        assertEq(otherAsset.balanceOf(address(2)),    1);
    }

    function test_upgrade_acl() external {
        MockFactory factory = new MockFactory();

        loan.__setFactory(address(factory));

        address newImplementation = address(new MapleLoanHarness());

        try loan.upgrade(1, abi.encode(newImplementation)) { assertTrue(false, "Non-borrower was able to set implementation"); } catch { }

        // TODO: prank
        loan.__setBorrower(address(this));

        loan.upgrade(1, abi.encode(newImplementation));

        assertEq(loan.implementation(), newImplementation);
    }

    /***********************************/
    /*** Loan Transfer-Related Tests ***/
    /***********************************/

    function test_acceptNewTerms_pullPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        loan.__setPrincipalRequested(1);
        loan.__setFundsAsset(address(fundsAsset));

        // TODO: prank
        loan.__setLender(address(this));

        loan.__setPaymentInterval(30 days);                       // Needed for establishment fee checks (TODO update)
        loan.__setNextPaymentDueDate(block.timestamp + 25 days);  // Needed for establishment fee checks (TODO update)
        loan.__setPaymentsRemaining(3);                           // Needed for establishment fee checks (TODO update)

        address refinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = new bytes(0);

        loan.__setRefinanceCommitment(keccak256(abi.encode(refinancer, deadline, calls)));

        fundsAsset.mint(address(this), 1);

        assertEq(fundsAsset.balanceOf(address(this)), 1);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.claimableFunds(),               0);
        assertEq(loan.drawableFunds(),                0);

        vm.expectRevert("ML:ANT:TRANSFER_FROM_FAILED");
        loan.acceptNewTerms(refinancer, deadline, calls, 1);

        fundsAsset.approve(address(loan), 1);

        loan.acceptNewTerms(refinancer, deadline, calls, 1);

        // All unaccounted amount is claimable lender at the end of acceptNewTerms
        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), 1);
        assertEq(loan.claimableFunds(),               1);
        assertEq(loan.drawableFunds(),                0);
    }

    function test_acceptNewTerms_pushPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        loan.__setPrincipalRequested(1);
        loan.__setFundsAsset(address(fundsAsset));

        // TODO: prank
        loan.__setLender(address(this));

        loan.__setPaymentInterval(30 days);                       // Needed for establishment fee checks (TODO update)
        loan.__setNextPaymentDueDate(block.timestamp + 25 days);  // Needed for establishment fee checks (TODO update)
        loan.__setPaymentsRemaining(3);                           // Needed for establishment fee checks (TODO update)

        address refinancer = address(new EmptyContract());
        uint256 deadline = block.timestamp + 10 days;
        bytes[] memory calls = new bytes[](1);
        calls[0] = new bytes(0);

        loan.__setRefinanceCommitment(keccak256(abi.encode(refinancer, deadline, calls)));

        fundsAsset.mint(address(this), 1);

        assertEq(fundsAsset.balanceOf(address(this)), 1);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.claimableFunds(),               0);
        assertEq(loan.drawableFunds(),                0);

        fundsAsset.transfer(address(loan), 1);

        loan.acceptNewTerms(refinancer, deadline, calls, 0);

        // All unaccounted amount is claimable lender at the end of acceptNewTerms
        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), 1);
        assertEq(loan.claimableFunds(),               1);
        assertEq(loan.drawableFunds(),                0);
    }

    function test_triggerDefaultWarning() external {
        loan.__setLender(address(this));

        uint256 start = 1 days;  // Non-zero start time.

        vm.warp(start);

        uint256 originalNextPaymentDate = start + 10 days;

        loan.__setNextPaymentDueDate(originalNextPaymentDate);

        // Pool delegate wants to force the loan into the grace period 5 days early.
        uint256 timeToFastForwardTo = start + 5 days;

        vm.warp(timeToFastForwardTo);

        loan.triggerDefaultWarning(timeToFastForwardTo);

        assertEq(loan.nextPaymentDueDate(), timeToFastForwardTo);
    }

    function test_triggerDefaultWarning_pastDueDate() external {
        loan.__setLender(address(this));

        uint256 start = 1 days;  // Non-zero start time.

        vm.warp(start);

        uint256 originalNextPaymentDate = start + 10 days;

        loan.__setNextPaymentDueDate(originalNextPaymentDate);

        // At due date, should not be able to fast forward.
        uint256 timeToFastForwardTo = start + 10 days;

        vm.warp(timeToFastForwardTo);

        vm.expectRevert("ML:TDW:PAST_DUE_DATE");
        loan.triggerDefaultWarning(block.timestamp);

        vm.warp(timeToFastForwardTo - 1);
        loan.triggerDefaultWarning(block.timestamp);
    }

    function test_triggerDefaultWarning_inPast() external {
        loan.__setLender(address(this));

        uint256 start = 1 days;  // Non-zero start time.

        vm.warp(start);

        uint256 originalNextPaymentDate = start + 10 days;

        loan.__setNextPaymentDueDate(originalNextPaymentDate);

        uint256 timeToFastForwardTo = start + 5 days;

        vm.warp(timeToFastForwardTo);

        vm.expectRevert("ML:TDW:IN_PAST");
        loan.triggerDefaultWarning(block.timestamp - 1);

        loan.triggerDefaultWarning(block.timestamp);
    }

    // TODO: test_acceptNewTerms_pullPatternOverFund (since test_acceptNewTerms_pullPattern already overfunds)

    // TODO: test_acceptNewTerms_pushPatternOverFund (since test_acceptNewTerms_pushPattern already overfunds)

    function test_fundLoan_pullPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;
        address lender = address(1111);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPaymentsRemaining(1);

        fundsAsset.mint(address(this), amount);

        try loan.fundLoan(lender, amount) { assertTrue(false, "Able to fund"); } catch { }

        fundsAsset.approve(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(this)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.principal(),                    0);

        loan.fundLoan(lender, amount);

        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.principal(),                    amount);
    }

    function test_fundLoan_pushPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;
        address lender = address(1111);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPaymentsRemaining(1);

        // Fails without pushing funds
        try loan.fundLoan(lender, uint256(0)) { assertTrue(false, "Able to fund"); } catch { }

        fundsAsset.mint(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.principal(),                    0);

        loan.fundLoan(lender, uint256(0));

        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.principal(),                    amount);
    }

    function test_fundLoan_pullPatternOverFund() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 principalRequested = 1_000_000;
        uint256 fundAmount         = 2_000_000;
        address lender             = address(1111);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(principalRequested);
        loan.__setPaymentsRemaining(1);

        fundsAsset.mint(address(this), fundAmount);

        try loan.fundLoan(lender, fundAmount) { assertTrue(false, "Able to fund"); } catch { }

        fundsAsset.approve(address(loan), fundAmount);

        assertEq(fundsAsset.balanceOf(address(this)), fundAmount);
        assertEq(fundsAsset.balanceOf(lender),        0);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.principal(),                    0);

        loan.fundLoan(lender, fundAmount);

        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(lender),        0);
        assertEq(fundsAsset.balanceOf(address(loan)), fundAmount);
        assertEq(loan.principal(),                    principalRequested);
        assertEq(loan.claimableFunds(),               fundAmount - principalRequested);
    }

    function test_fundLoan_pushPatternOverFund() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 principalRequested = 1_000_000;
        uint256 fundAmount         = 2_000_000;
        address lender             = address(1111);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(principalRequested);
        loan.__setPaymentsRemaining(1);

        // Fails without pushing funds
        try loan.fundLoan(lender, uint256(0)) { assertTrue(false, "Able to fund"); } catch { }

        fundsAsset.mint(address(loan), fundAmount);

        assertEq(fundsAsset.balanceOf(lender),        0);
        assertEq(fundsAsset.balanceOf(address(loan)), fundAmount);
        assertEq(loan.principal(),                    0);

        loan.fundLoan(lender, 0);

        assertEq(fundsAsset.balanceOf(lender),        0);
        assertEq(fundsAsset.balanceOf(address(loan)), fundAmount);
        assertEq(loan.principal(),                    principalRequested);
        assertEq(loan.claimableFunds(),               fundAmount - principalRequested);
    }

    function test_drawdownFunds_withoutAdditionalCollateralRequired() external {
        MockERC20 fundsAsset      = new MockERC20("FA", "FA", 18);
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPrincipal(amount);
        loan.__setDrawableFunds(amount);

        // TODO: prank
        loan.__setBorrower(address(this));

        // Send amount to loan
        fundsAsset.mint(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.drawableFunds(),                amount);

        loan.drawdownFunds(amount, address(this));

        assertEq(fundsAsset.balanceOf(address(this)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.drawableFunds(),                0);
    }

    function test_drawdownFunds_pullPatternForCollateral() external {
        MockERC20 fundsAsset      = new MockERC20("FA", "FA", 18);
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 fundsAssetAmount      = 1_000_000;
        uint256 collateralAssetAmount = 300_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setPrincipalRequested(fundsAssetAmount);
        loan.__setCollateralRequired(collateralAssetAmount);
        loan.__setPrincipal(fundsAssetAmount);
        loan.__setDrawableFunds(fundsAssetAmount);
        loan.__setPaymentsRemaining(1);

        // TODO: prank
        loan.__setBorrower(address(this));

        // Send amount to loan
        fundsAsset.mint(address(loan), fundsAssetAmount);
        collateralAsset.mint(address(this), collateralAssetAmount);

        // Fail without approval
        try loan.drawdownFunds(fundsAssetAmount, address(this)) { assertTrue(false, "Able to drawdown"); } catch { }

        collateralAsset.approve(address(loan), collateralAssetAmount);

        assertEq(fundsAsset.balanceOf(address(this)),      0);
        assertEq(fundsAsset.balanceOf(address(loan)),      fundsAssetAmount);
        assertEq(collateralAsset.balanceOf(address(this)), collateralAssetAmount);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(loan.collateral(),                        0);
        assertEq(loan.drawableFunds(),                     fundsAssetAmount);

        loan.drawdownFunds(fundsAssetAmount, address(this));

        assertEq(fundsAsset.balanceOf(address(this)),      fundsAssetAmount);
        assertEq(fundsAsset.balanceOf(address(loan)),      0);
        assertEq(collateralAsset.balanceOf(address(this)), 0);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralAssetAmount);
        assertEq(loan.collateral(),                        collateralAssetAmount);
        assertEq(loan.drawableFunds(),                     0);
    }

    function test_drawdownFunds_pushPatternForCollateral() external {
        MockERC20 fundsAsset      = new MockERC20("FA", "FA", 18);
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 fundsAssetAmount      = 1_000_000;
        uint256 collateralAssetAmount = 300_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setPrincipalRequested(fundsAssetAmount);
        loan.__setCollateralRequired(collateralAssetAmount);
        loan.__setPrincipal(fundsAssetAmount);
        loan.__setDrawableFunds(fundsAssetAmount);
        loan.__setPaymentsRemaining(1);

        // TODO: prank
        loan.__setBorrower(address(this));

        // Send amount to loan
        fundsAsset.mint(address(loan), fundsAssetAmount);

        // Fail without approval
        try loan.drawdownFunds(fundsAssetAmount, address(this)) { assertTrue(false, "Able to drawdown"); } catch { }

        // "Transfer" funds into the loan
        collateralAsset.mint(address(loan), collateralAssetAmount);

        assertEq(fundsAsset.balanceOf(address(this)),      0);
        assertEq(fundsAsset.balanceOf(address(loan)),      fundsAssetAmount);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralAssetAmount);
        assertEq(loan.collateral(),                        0);
        assertEq(loan.drawableFunds(),                     fundsAssetAmount);

        loan.drawdownFunds(fundsAssetAmount, address(this));

        assertEq(fundsAsset.balanceOf(address(this)),      fundsAssetAmount);
        assertEq(fundsAsset.balanceOf(address(loan)),      0);
        assertEq(collateralAsset.balanceOf(address(loan)), collateralAssetAmount);
        assertEq(loan.collateral(),                        collateralAssetAmount);
        assertEq(loan.drawableFunds(),                     0);
    }

    function test_closeLoan_pullPatternAsBorrower() external {
        Borrower  borrower   = new Borrower();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPrincipal(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(borrower), amount);

        assertEq(fundsAsset.balanceOf(address(borrower)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)),     0);
        assertEq(loan.principal(),                        amount);

        assertTrue(!borrower.try_loan_closeLoan(address(loan), amount));

        borrower.erc20_approve(address(fundsAsset), address(loan), amount);

        assertTrue(borrower.try_loan_closeLoan(address(loan), amount));

        assertEq(fundsAsset.balanceOf(address(borrower)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),     amount);
        assertEq(loan.paymentsRemaining(),                0);
        assertEq(loan.principal(),                        0);
    }

    function test_closeLoan_pushPatternAsBorrower() external {
        Borrower  borrower   = new Borrower();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPrincipal(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(borrower), amount);

        assertEq(fundsAsset.balanceOf(address(borrower)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)),     0);
        assertEq(loan.principal(),                        amount);

        assertTrue(!borrower.try_loan_closeLoan(address(loan), 0));

        borrower.erc20_transfer(address(fundsAsset), address(loan), amount);

        assertTrue(borrower.try_loan_closeLoan(address(loan), 0));

        assertEq(fundsAsset.balanceOf(address(borrower)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),     amount);
        assertEq(loan.paymentsRemaining(),                0);
        assertEq(loan.principal(),                        0);
    }

    function test_closeLoan_pullPatternAsNonBorrower() external {
        LoanUser  user       = new LoanUser();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPrincipal(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(user), amount);

        assertEq(fundsAsset.balanceOf(address(user)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.principal(),                    amount);

        assertTrue(!user.try_loan_closeLoan(address(loan), amount));

        user.erc20_approve(address(fundsAsset), address(loan), amount);

        assertTrue(user.try_loan_closeLoan(address(loan), amount));

        assertEq(fundsAsset.balanceOf(address(user)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.paymentsRemaining(),            0);
        assertEq(loan.principal(),                    0);
    }

    function test_closeLoan_pushPatternAsNonBorrower() external {
        LoanUser  user       = new LoanUser();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPrincipal(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        fundsAsset.mint(address(user), amount);

        assertEq(fundsAsset.balanceOf(address(user)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.principal(),                    amount);

        assertTrue(!user.try_loan_closeLoan(address(loan), 0));

        user.erc20_transfer(address(fundsAsset), address(loan), amount);

        assertTrue(user.try_loan_closeLoan(address(loan), 0));

        assertEq(fundsAsset.balanceOf(address(user)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.paymentsRemaining(),            0);
        assertEq(loan.principal(),                    0);
    }

    function test_closeLoan_pullPatternUsingDrawable() external {
        Borrower  borrower   = new Borrower();
        LoanUser  user       = new LoanUser();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPrincipal(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);
        user.erc20_approve(address(fundsAsset), address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        assertTrue(!user.try_loan_closeLoan(address(loan), totalPayment - 1));

        fundsAsset.mint(address(borrower), totalPayment - 1);
        borrower.erc20_approve(address(fundsAsset), address(loan), totalPayment - 1);

        // This should succeed since it the borrower can use drawableFunds.
        assertTrue(borrower.try_loan_closeLoan(address(loan), totalPayment - 1));
    }

    function test_closeLoan_pushPatternUsingDrawable() external {
        Borrower  borrower   = new Borrower();
        LoanUser  user       = new LoanUser();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPrincipal(amount);
        loan.__setNextPaymentDueDate(block.timestamp + 1);

        ( uint256 principal, uint256 interest, ) = loan.getClosingPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);
        user.erc20_transfer(address(fundsAsset), address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        assertTrue(!user.try_loan_closeLoan(address(loan), 0));

        // This should succeed since the borrower can use drawableFunds, and there is already unaccounted amount thanks to the previous user transfer.
        assertTrue(borrower.try_loan_closeLoan(address(loan), 0));
    }

    function test_makePayment_pullPatternAsBorrower() external {
        Borrower  borrower   = new Borrower();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(startingPrincipal);
        loan.__setPrincipal(startingPrincipal);
        loan.__setEndingPrincipal(uint256(0));
        loan.__setPaymentsRemaining(3);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(borrower), totalPayment);

        assertEq(fundsAsset.balanceOf(address(borrower)), totalPayment);
        assertEq(fundsAsset.balanceOf(address(loan)),     0);
        assertEq(loan.paymentsRemaining(),                3);
        assertEq(loan.principal(),                        startingPrincipal);

        assertTrue(!borrower.try_loan_makePayment(address(loan), totalPayment));

        borrower.erc20_approve(address(fundsAsset), address(loan), totalPayment);

        assertTrue(borrower.try_loan_makePayment(address(loan), totalPayment));

        assertEq(fundsAsset.balanceOf(address(borrower)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),     totalPayment);
        assertEq(loan.paymentsRemaining(),                2);
        assertEq(loan.principal(),                        startingPrincipal - principal);
    }

    function test_makePayment_pushPatternAsBorrower() external {
        Borrower  borrower   = new Borrower();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(startingPrincipal);
        loan.__setPrincipal(startingPrincipal);
        loan.__setEndingPrincipal(uint256(0));
        loan.__setPaymentsRemaining(3);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(borrower), totalPayment);

        assertEq(fundsAsset.balanceOf(address(borrower)), totalPayment);
        assertEq(fundsAsset.balanceOf(address(loan)),     0);
        assertEq(loan.paymentsRemaining(),                3);
        assertEq(loan.principal(),                        startingPrincipal);

        assertTrue(!borrower.try_loan_makePayment(address(loan), 0));

        borrower.erc20_transfer(address(fundsAsset), address(loan), totalPayment);

        assertTrue(borrower.try_loan_makePayment(address(loan), 0));

        assertEq(fundsAsset.balanceOf(address(borrower)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),     totalPayment);
        assertEq(loan.paymentsRemaining(),                2);
        assertEq(loan.principal(),                        startingPrincipal - principal);
    }

    function test_makePayment_pullPatternAsNonBorrower() external {
        LoanUser  user       = new LoanUser();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(startingPrincipal);
        loan.__setPrincipal(startingPrincipal);
        loan.__setEndingPrincipal(uint256(0));
        loan.__setPaymentsRemaining(3);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(user), totalPayment);

        assertEq(fundsAsset.balanceOf(address(user)), totalPayment);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.paymentsRemaining(),            3);
        assertEq(loan.principal(),                    startingPrincipal);

        assertTrue(!user.try_loan_makePayment(address(loan), totalPayment));

        user.erc20_approve(address(fundsAsset), address(loan), totalPayment);

        assertTrue(user.try_loan_makePayment(address(loan), totalPayment));

        assertEq(fundsAsset.balanceOf(address(user)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), totalPayment);
        assertEq(loan.paymentsRemaining(),            2);
        assertEq(loan.principal(),                    startingPrincipal - principal);
    }

    function test_makePayment_pushPatternAsNonBorrower() external {
        LoanUser  user       = new LoanUser();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(startingPrincipal);
        loan.__setPrincipal(startingPrincipal);
        loan.__setEndingPrincipal(uint256(0));
        loan.__setPaymentsRemaining(3);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(user), totalPayment);

        assertEq(fundsAsset.balanceOf(address(user)), totalPayment);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.paymentsRemaining(),            3);
        assertEq(loan.principal(),                    startingPrincipal);

        assertTrue(!user.try_loan_makePayment(address(loan), 0));

        user.erc20_transfer(address(fundsAsset), address(loan), totalPayment);

        assertTrue(user.try_loan_makePayment(address(loan), 0));

        assertEq(fundsAsset.balanceOf(address(user)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), totalPayment);
        assertEq(loan.paymentsRemaining(),            2);
        assertEq(loan.principal(),                    startingPrincipal - principal);
    }

    function test_makePayment_pullPatternUsingDrawable() external {
        Borrower  borrower   = new Borrower();
        LoanUser  user       = new LoanUser();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(startingPrincipal);
        loan.__setPrincipal(startingPrincipal);
        loan.__setEndingPrincipal(uint256(0));
        loan.__setPaymentsRemaining(3);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);
        user.erc20_approve(address(fundsAsset), address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        assertTrue(!user.try_loan_makePayment(address(loan), totalPayment - 1));

        fundsAsset.mint(address(borrower), totalPayment - 1);
        borrower.erc20_approve(address(fundsAsset), address(loan), totalPayment - 1);

        // This should succeed since it the borrower can use drawableFunds.
        assertTrue(borrower.try_loan_makePayment(address(loan), totalPayment - 1));
    }

    function test_makePayment_pushPatternUsingDrawable() external {
        Borrower  borrower   = new Borrower();
        LoanUser  user       = new LoanUser();
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setBorrower(address(borrower));
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(startingPrincipal);
        loan.__setPrincipal(startingPrincipal);
        loan.__setEndingPrincipal(uint256(0));
        loan.__setPaymentsRemaining(3);

        ( uint256 principal, uint256 interest, ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);
        user.erc20_transfer(address(fundsAsset), address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        assertTrue(!user.try_loan_makePayment(address(loan), 0));

        // This should succeed since the borrower can use drawableFunds, and there is already unaccounted amount thanks to the previous user transfer.
        assertTrue(borrower.try_loan_makePayment(address(loan), 0));
    }

    function test_postCollateral_pullPattern() external {
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        loan.__setCollateralAsset(address(collateralAsset));

        uint256 amount = 1_000_000;

        collateralAsset.mint(address(this), amount);

        try loan.postCollateral(amount) { assertTrue(false,"Able to post collateral"); } catch { }

        collateralAsset.approve(address(loan), amount);

        assertEq(collateralAsset.balanceOf(address(this)), amount);
        assertEq(collateralAsset.balanceOf(address(loan)), 0);
        assertEq(loan.collateral(),                        0);

        loan.postCollateral(amount);

        assertEq(collateralAsset.balanceOf(address(this)), 0);
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

        fundsAsset.mint(address(this), amount);

        try loan.returnFunds(amount) { assertTrue(false, "Able to return funds"); } catch { }

        fundsAsset.approve(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(this)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.drawableFunds(),                0);

        loan.returnFunds(amount);

        assertEq(fundsAsset.balanceOf(address(this)), 0);
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

}

contract MapleLoanRoleTests is TestUtils {

    ConstructableMapleLoan internal _loan;
    Borrower               internal _borrower;
    Lender                 internal _lender;
    MapleGlobalsMock       internal _globals;
    MockERC20              internal _token;
    MockFactory            internal _factory;
    MockFeeManager         internal _feeManager;

    function setUp() public {
        _borrower   = new Borrower();
        _lender     = new Lender();
        _globals    = new MapleGlobalsMock(address(this));
        _token      = new MockERC20("Token", "T", 0);
        _factory    = new MockFactory();
        _feeManager = new MockFeeManager();

        address[2] memory assets      = [address(_token), address(_token)];
        uint256[3] memory termDetails = [uint256(10 days), uint256(365 days / 6), uint256(6)];
        uint256[3] memory amounts     = [uint256(300_000), uint256(1_000_000), uint256(0)];
        uint256[5] memory rates       = [uint256(0.12e18), uint256(0), uint256(0), uint256(0), uint256(0)];

        _globals.setValidBorrower(address(_borrower), true);

        _loan = new ConstructableMapleLoan(address(_factory), address(_globals), address(_borrower), address(_feeManager), 0, assets, termDetails, amounts, rates);
    }

    function test_transferBorrowerRole() public {
        Borrower newBorrower = new Borrower();

        assertEq(_loan.pendingBorrower(), address(0));
        assertEq(_loan.borrower(),        address(_borrower));

        // Only borrower can call setPendingBorrower
        assertTrue(!newBorrower.try_loan_setPendingBorrower(address(_loan), address(newBorrower)));
        assertTrue(   _borrower.try_loan_setPendingBorrower(address(_loan), address(newBorrower)));

        assertEq(_loan.pendingBorrower(), address(newBorrower));

        // Pending borrower can't call setPendingBorrower
        assertTrue(!newBorrower.try_loan_setPendingBorrower(address(_loan), address(1)));
        assertTrue(   _borrower.try_loan_setPendingBorrower(address(_loan), address(1)));

        assertEq(_loan.pendingBorrower(), address(1));

        // Can be reset if mistake is made
        assertTrue(_borrower.try_loan_setPendingBorrower(address(_loan), address(newBorrower)));

        assertEq(_loan.pendingBorrower(), address(newBorrower));
        assertEq(_loan.borrower(),        address(_borrower));

        // Pending borrower is the only one who can call acceptBorrower
        assertTrue( !_borrower.try_loan_acceptBorrower(address(_loan)));
        assertTrue(newBorrower.try_loan_acceptBorrower(address(_loan)));

        // Pending borrower is set to zero
        assertEq(_loan.pendingBorrower(), address(0));
        assertEq(_loan.borrower(),        address(newBorrower));
    }

    function test_transferLenderRole() public {
        // Fund the _loan to set the lender
        _token.mint(address(_lender), 1_000_000);
        _lender.erc20_approve(address(_token), address(_loan),    1_000_000);
        _lender.loan_fundLoan(address(_loan),   address(_lender), 1_000_000);

        Lender newLender = new Lender();

        assertEq(_loan.pendingLender(), address(0));
        assertEq(_loan.lender(),        address(_lender));

        // Only lender can call setPendingLender
        assertTrue(!newLender.try_loan_setPendingLender(address(_loan), address(newLender)));
        assertTrue(   _lender.try_loan_setPendingLender(address(_loan), address(newLender)));

        assertEq(_loan.pendingLender(), address(newLender));

        // Pending lender can't call setPendingLender
        assertTrue(!newLender.try_loan_setPendingLender(address(_loan), address(1)));
        assertTrue(   _lender.try_loan_setPendingLender(address(_loan), address(1)));

        assertEq(_loan.pendingLender(), address(1));

        // Can be reset if mistake is made
        assertTrue(_lender.try_loan_setPendingLender(address(_loan), address(newLender)));

        assertEq(_loan.pendingLender(), address(newLender));
        assertEq(_loan.lender(),        address(_lender));

        // Pending lender is the only one who can call acceptLender
        assertTrue( !_lender.try_loan_acceptLender(address(_loan)));
        assertTrue(newLender.try_loan_acceptLender(address(_loan)));

        // Pending lender is set to zero
        assertEq(_loan.pendingLender(), address(0));
        assertEq(_loan.lender(),        address(newLender));
    }

}
