// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Hevm, StateManipulations, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }                              from "../../modules/erc20/src/interfaces/IERC20.sol";
import { MockERC20 }                           from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { IMapleLoan } from "../interfaces/IMapleLoan.sol";

import { ConstructableMapleLoan, EmptyContract, LenderMock, ManipulatableMapleLoan, MockFactory, MapleGlobalsMock } from "./mocks/Mocks.sol";

import { Borrower } from "./accounts/Borrower.sol";
import { LoanUser } from "./accounts/LoanUser.sol";

contract MapleLoanTests is StateManipulations, TestUtils {

    ManipulatableMapleLoan loan;
    MapleGlobalsMock       globals;

    bool locked;  // Helper state variable to avoid infinite loops when using the modifier.

    function setUp() external {
        globals = new MapleGlobalsMock(address(this));

        MockFactory factoryMock = new MockFactory();
        factoryMock.setGlobals(address(globals));

        loan = new ManipulatableMapleLoan();

        loan.__setFactory(address(factoryMock));
    }

    modifier assertFailureWhenPaused() {
        if (!locked) {
            locked = true;

            globals.setProtocolPaused(true);

            ( bool success, ) = address(this).call(msg.data);
            assertTrue(!success || failed, "test should have failed when paused");

            globals.setProtocolPaused(false);
        }

        _;

        locked = false;
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

        loan.__setFactory(address(this));

        loan.migrate(mockMigrator, new bytes(0));
    }

    function test_setImplementation_acl() external {
        try loan.setImplementation(address(this)) { assertTrue(false, "Non-factory was able to set implementation"); } catch { }

        loan.__setFactory(address(this));

        loan.setImplementation(address(this));
    }

    function test_drawdownFunds_acl() external assertFailureWhenPaused {
        MockERC20 fundsAsset = new MockERC20("Funds Asset", "FA", 18);

        fundsAsset.mint(address(loan), 1_000_000);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(1_000_000);  // Needed for the getAdditionalCollateralRequiredFor
        loan.__setDrawableFunds(1_000_000);

        try loan.drawdownFunds(1, address(this)) { assertTrue(false, "Non-borrower was able to drawdown"); } catch { }

        loan.__setBorrower(address(this));

        loan.drawdownFunds(1, address(this));
    }

    function test_proposeNewTerms_acl() external assertFailureWhenPaused {
        address mockRefinancer = address(new EmptyContract());
        bytes[] memory data = new bytes[](1);
        data[0] = new bytes(0);

        try loan.proposeNewTerms(mockRefinancer, data) { assertTrue(false, "Non-borrower was able to propose new terms"); } catch { }

        loan.__setBorrower(address(this));

        loan.proposeNewTerms(mockRefinancer, data);
    }

    function test_removeCollateral_acl() external assertFailureWhenPaused {
        MockERC20 collateralAsset = new MockERC20("Collateral Asset", "CA", 18);

        loan.__setPrincipalRequested(1); // Needed for the collateralMaintained check
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setCollateral(1);

        collateralAsset.mint(address(loan), 1);

        try loan.removeCollateral(1, address(this)) { assertTrue(false, "Non-borrower was able to remove collateral"); } catch { }

        loan.__setBorrower(address(this));

        loan.removeCollateral(1, address(this));
    }

    function test_setBorrower_acl() external {
        try loan.setPendingBorrower(address(1)) { assertTrue(false, "Non-borrower was able to set borrower"); } catch { }

        loan.__setBorrower(address(this));

        loan.setPendingBorrower(address(1));
    }

    function test_acceptBorrower_acl() external {
        loan.__setPendingBorrower(address(1));

        try loan.acceptBorrower() { assertTrue(false, "Non-pendingBorrower was able to set borrower"); } catch { }

        loan.__setPendingBorrower(address(this));

        loan.acceptBorrower();
    }

    function test_acceptNewTerms_acl() external assertFailureWhenPaused {
        MockERC20 token = new MockERC20("MockToken", "MA", 18);

        loan.__setPrincipalRequested(1);            // Needed for the collateralMaintained check
        loan.__setCollateralAsset(address(token));  // Needed for the getUnaccountedAmount check
        loan.__setFundsAsset(address(token));       // Needed for the getUnaccountedAmount check

        address mockRefinancer = address(new EmptyContract());
        bytes[] memory data = new bytes[](1);
        data[0] = new bytes(0);
        bytes32 refinanceCommitmentHash = keccak256(abi.encode(mockRefinancer, data));

        loan.__setRefinanceCommitmentHash(refinanceCommitmentHash);

        try loan.acceptNewTerms(mockRefinancer, data, uint256(0)) { assertTrue(false, "Non-lender was able to accept terms"); } catch { }

        loan.__setLender(address(this));

        loan.acceptNewTerms(mockRefinancer, data, uint256(0));
    }

    function test_claimFunds_acl() external assertFailureWhenPaused {
        MockERC20 fundsAsset = new MockERC20("Funds Asset", "FA", 18);

        fundsAsset.mint(address(loan), 200_000);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setClaimableFunds(uint256(200_000));

        try loan.claimFunds(uint256(200_000), address(this)) { assertTrue(false, "Non-lender was able to claim funds"); } catch { }

        loan.__setLender(address(this));

        loan.claimFunds(uint256(200_000), address(this));
    }

    function test_repossess_acl() external assertFailureWhenPaused {
        MockERC20 asset = new MockERC20("Asset", "AST", 18);

        loan.__setNextPaymentDueDate(1);
        loan.__setCollateralAsset(address(asset));
        loan.__setFundsAsset(address(asset));

        hevm.warp(loan.nextPaymentDueDate() + loan.gracePeriod() + 1);

        try loan.repossess(address(this)) {  assertTrue(false, "Non-lender was able to repossess"); } catch { }

        loan.__setLender(address(this));

        loan.repossess(address(this));
    }

    function test_setLender_acl() external {
        try loan.setPendingLender(address(this)) {  assertTrue(false, "Non-lender was able to set lender"); } catch { }

        loan.__setLender(address(this));

        loan.setPendingLender(address(this));
    }

    function test_acceptLender_acl() external {
        loan.__setPendingLender(address(1));

        try loan.acceptLender() { assertTrue(false, "Non-pendingLender was able to set borrower"); } catch { }

        loan.__setPendingLender(address(this));

        loan.acceptLender();
    }

    function test_skim_acl() external assertFailureWhenPaused {
        MockERC20 otherAsset = new MockERC20("OA", "OA", 18);

        otherAsset.mint(address(loan), 1);

        try loan.skim(address(otherAsset), address(this)) { assertTrue(false, "Non-lender or borrower was able to set lender"); } catch { }

        loan.__setLender(address(this));

        assertEq(otherAsset.balanceOf(address(loan)), 1);
        assertEq(otherAsset.balanceOf(address(1)),    0);

        loan.skim(address(otherAsset), address(1));

        assertEq(otherAsset.balanceOf(address(loan)), 0);
        assertEq(otherAsset.balanceOf(address(1)),    1);

        loan.__setLender(address(2));
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

        address newImplementation = address(new ManipulatableMapleLoan());

        try loan.upgrade(1, abi.encode(newImplementation)) { assertTrue(false, "Non-borrower was able to set implementation"); } catch { }

        loan.__setBorrower(address(this));

        loan.upgrade(1, abi.encode(newImplementation));

        assertEq(loan.implementation(), newImplementation);
    }

    /***********************************/
    /*** Loan Transfer-Related Tests ***/
    /***********************************/

    function test_acceptNewTerms_extraFunds() external assertFailureWhenPaused {
        EmptyContract refinancer = new EmptyContract();
        LenderMock    lender     = new LenderMock();
        MockERC20     token      = new MockERC20("FA", "FundsAsset", 0);

        loan.__setFundsAsset(address(token));
        loan.__setLender(address(lender));
        loan.__setPrincipalRequested(1_000_000);  // This is needed so that _getCollateralRequiredFor doesn't divide by zero.

        token.mint(address(loan), 1);

        bytes[] memory calls = new bytes[](0);

        loan.__setRefinanceCommitmentHash(keccak256(abi.encode(address(refinancer), calls)));

        lender.loan_acceptNewTerms(address(loan), address(refinancer), calls, 0);

        assertEq(token.balanceOf(address(loan)),   0);
        assertEq(token.balanceOf(address(lender)), 1);
    }

    function test_acceptNewTerms_pullPattern() external assertFailureWhenPaused {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        loan.__setPrincipalRequested(1);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setLender(address(this));

        address refinancer = address(new EmptyContract());
        bytes[] memory data = new bytes[](1);
        data[0] = new bytes(0);
        loan.__setRefinanceCommitmentHash(keccak256(abi.encode(refinancer, data)));

        fundsAsset.mint(address(this), 1);

        assertEq(fundsAsset.balanceOf(address(this)), 1);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.claimableFunds(),               0);
        assertEq(loan.drawableFunds(),                0);

        try loan.acceptNewTerms(refinancer, data, 1) { assertTrue(false, "Able to accept terms"); } catch { }

        fundsAsset.approve(address(loan), 1);

        loan.acceptNewTerms(refinancer, data, 1);

        // Does not change, since no increase in principal was done in the loan
        // All unaccounted amount goes back to the lender at the end of acceptNewTerms
        assertEq(fundsAsset.balanceOf(address(this)), 1);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.claimableFunds(),               0);
        assertEq(loan.drawableFunds(),                0);
    }

    function test_acceptNewTerms_pushPattern() external assertFailureWhenPaused {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        loan.__setPrincipalRequested(1);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setLender(address(this));

        address refinancer = address(new EmptyContract());
        bytes[] memory data = new bytes[](1);
        data[0] = new bytes(0);
        loan.__setRefinanceCommitmentHash(keccak256(abi.encode(refinancer, data)));

        fundsAsset.mint(address(this), 1);

        assertEq(fundsAsset.balanceOf(address(this)), 1);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.claimableFunds(),               0);
        assertEq(loan.drawableFunds(),                0);

        try loan.acceptNewTerms(refinancer, data, 0) { assertTrue(false, "Able to accept terms"); } catch { }

        fundsAsset.transfer(address(loan), 1);

        loan.acceptNewTerms(refinancer, data, 0);

        // Does not change, since no increase in principal was done in the loan
        // All unaccounted amount goes back to the lender at the end of acceptNewTerms
        assertEq(fundsAsset.balanceOf(address(this)), 1);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.claimableFunds(),               0);
        assertEq(loan.drawableFunds(),                0);
    }

    function test_fundLoan_pullPattern() external assertFailureWhenPaused {
        LenderMock lender     = new LenderMock();
        MockERC20  fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPaymentsRemaining(1);

        fundsAsset.mint(address(this), amount);

        try loan.fundLoan(address(lender), amount) { assertTrue(false, "Able to fund"); } catch { }

        fundsAsset.approve(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(this)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.principal(),                    0);

        loan.fundLoan(address(lender), amount);

        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.principal(),                    amount);
    }

    function test_fundLoan_pushPattern() external assertFailureWhenPaused{
        LenderMock lender     = new LenderMock();
        MockERC20  fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPaymentsRemaining(1);

        // Fails without pushing funds
        try loan.fundLoan(address(lender), uint256(0)) { assertTrue(false, "Able to fund"); } catch { }

        fundsAsset.mint(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.principal(),                    0);

        loan.fundLoan(address(lender), uint256(0));

        assertEq(fundsAsset.balanceOf(address(loan)), amount);
        assertEq(loan.principal(),                    amount);
    }

    function test_fundLoan_pushPatternExtraFundsWhileNotActive() external assertFailureWhenPaused {
        LenderMock lender = new LenderMock();
        MockERC20  token  = new MockERC20("FA", "FundsAsset", 0);

        loan.__setFundsAsset(address(token));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(1_000_000);

        token.mint(address(loan), 1_000_000 + 1);

        loan.fundLoan(address(lender), 0);

        assertEq(token.balanceOf(address(loan)),   1_000_000);
        assertEq(token.balanceOf(address(lender)), 1);
    }

    function test_fundLoan_pushPatternExtraFundsWhileActive() external assertFailureWhenPaused {
        LenderMock lender = new LenderMock();
        MockERC20  token  = new MockERC20("FA", "FundsAsset", 0);

        loan.__setFundsAsset(address(token));
        loan.__setLender(address(lender));
        loan.__setNextPaymentDueDate(1);
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(1_000_000);

        token.mint(address(loan), 1_000_000 + 1);

        loan.fundLoan(address(lender), 0);

        assertEq(token.balanceOf(address(loan)),   0);
        assertEq(token.balanceOf(address(lender)), 1_000_001);
    }

    function test_fundLoan_pullPatternOverFund() external assertFailureWhenPaused {
        LenderMock lender     = new LenderMock();
        MockERC20  fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 principalRequested = 1_000_000;
        uint256 fundAmount         = 2_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(principalRequested);
        loan.__setPaymentsRemaining(1);

        fundsAsset.mint(address(this), fundAmount);

        try loan.fundLoan(address(lender), fundAmount) { assertTrue(false, "Able to fund"); } catch { }

        fundsAsset.approve(address(loan), fundAmount);

        assertEq(fundsAsset.balanceOf(address(this)),   fundAmount);
        assertEq(fundsAsset.balanceOf(address(lender)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),   0);
        assertEq(loan.principal(),                      0);

        loan.fundLoan(address(lender), fundAmount);

        assertEq(fundsAsset.balanceOf(address(this)),   0);
        assertEq(fundsAsset.balanceOf(address(lender)), fundAmount - principalRequested);
        assertEq(fundsAsset.balanceOf(address(loan)),   principalRequested);
        assertEq(loan.principal(),                      principalRequested);
    }

    function test_fundLoan_pushPatternOverFund() external assertFailureWhenPaused {
        LenderMock lender     = new LenderMock();
        MockERC20  fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 principalRequested = 1_000_000;
        uint256 fundAmount         = 2_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(principalRequested);
        loan.__setPaymentsRemaining(1);

        // Fails without pushing funds
        try loan.fundLoan(address(lender), uint256(0)) { assertTrue(false, "Able to fund"); } catch { }

        fundsAsset.mint(address(loan), fundAmount);

        assertEq(fundsAsset.balanceOf(address(lender)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),   fundAmount);
        assertEq(loan.principal(),                      0);

        loan.fundLoan(address(lender), 0);

        assertEq(fundsAsset.balanceOf(address(lender)), fundAmount - principalRequested);
        assertEq(fundsAsset.balanceOf(address(loan)),   principalRequested);
        assertEq(loan.principal(),                      principalRequested);
    }

    function test_fundLoan_pullPatternFundsRedirect() external assertFailureWhenPaused {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;
        address lender = address(1);

        // Loan already funded
        loan.__setNextPaymentDueDate(block.timestamp + 1);
        loan.__setLender(lender);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(1_000_000);
        loan.__setPrincipal(1_000_000);

        fundsAsset.mint(address(this), amount);
        fundsAsset.approve(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(this)),   amount);
        assertEq(fundsAsset.balanceOf(address(lender)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),   0);
        assertEq(loan.claimableFunds(),                 0);
        assertEq(loan.drawableFunds(),                  0);

        loan.fundLoan(address(this), amount);

        // Funds move from sender to lender since no increase in principal was done in the loan
        // All unaccounted amount goes back to the lender at the end of fundLoan
        assertEq(fundsAsset.balanceOf(address(this)),   0);
        assertEq(fundsAsset.balanceOf(address(lender)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)),   0);
        assertEq(loan.claimableFunds(),                 0);
        assertEq(loan.drawableFunds(),                  0);
    }

    function test_fundLoan_pushPatternFundsRedirect() external assertFailureWhenPaused {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 amount = 1_000_000;
        address lender = address(1);

        // Loan already funded
        loan.__setNextPaymentDueDate(block.timestamp + 1);
        loan.__setLender(lender);
        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(1_000_000);
        loan.__setPrincipal(1_000_000);

        fundsAsset.mint(address(loan), amount);

        assertEq(fundsAsset.balanceOf(address(lender)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),   amount);
        assertEq(loan.claimableFunds(),                 0);
        assertEq(loan.drawableFunds(),                  0);

        loan.fundLoan(address(this), 0);

        // Funds move from sender to lender since no increase in principal was done in the loan
        // All unaccounted amount goes back to the lender at the end of fundLoan
        assertEq(fundsAsset.balanceOf(address(lender)), amount);
        assertEq(fundsAsset.balanceOf(address(loan)),   0);
        assertEq(loan.claimableFunds(),                 0);
        assertEq(loan.drawableFunds(),                  0);
    }

    function test_drawdownFunds_withoutAdditionalCollateralRequired() external assertFailureWhenPaused {
        MockERC20 fundsAsset      = new MockERC20("FA", "FA", 18);
        MockERC20 collateralAsset = new MockERC20("CA", "CA", 18);

        uint256 amount = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setCollateralAsset(address(collateralAsset));
        loan.__setPrincipalRequested(amount);
        loan.__setPrincipal(amount);
        loan.__setDrawableFunds(amount);
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

    function test_drawdownFunds_pullPatternForCollateral() external assertFailureWhenPaused {
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

    function test_drawdownFunds_pushPatternForCollateral() external assertFailureWhenPaused {
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

        ( uint256 principal, uint256 interest ) = loan.getEarlyPaymentBreakdown();
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

        ( uint256 principal, uint256 interest ) = loan.getEarlyPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(loan), 1);
        loan.__setDrawableFunds(1);

        fundsAsset.mint(address(user), totalPayment - 1);
        user.erc20_transfer(address(fundsAsset), address(loan), totalPayment - 1);

        // This should fail since it will require 1 from drawableFunds.
        assertTrue(!user.try_loan_closeLoan(address(loan), 0));

        fundsAsset.mint(address(borrower), totalPayment - 1);
        borrower.erc20_transfer(address(fundsAsset), address(loan), totalPayment - 1);

        // This should succeed since it the borrower can use drawableFunds.
        assertTrue(borrower.try_loan_closeLoan(address(loan), 0));
    }

    function test_makePayment_pullPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(startingPrincipal);
        loan.__setPrincipal(startingPrincipal);
        loan.__setEndingPrincipal(uint256(0));
        loan.__setPaymentsRemaining(3);

        ( uint256 principal, uint256 interest ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        fundsAsset.mint(address(this), totalPayment);

        try loan.makePayment(totalPayment) { assertTrue(false, "Able to make payment"); } catch { }

        fundsAsset.approve(address(loan), totalPayment);

        assertEq(fundsAsset.balanceOf(address(this)), totalPayment);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(loan.paymentsRemaining(),            3);
        assertEq(loan.principal(),                    startingPrincipal);

        loan.makePayment(totalPayment);

        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), totalPayment);
        assertEq(loan.paymentsRemaining(),            2);
        assertEq(loan.principal(),                    startingPrincipal - principal);
    }

    function test_makePayment_pushPattern() external {
        MockERC20 fundsAsset = new MockERC20("FA", "FA", 18);

        uint256 startingPrincipal = 1_000_000;

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(startingPrincipal);
        loan.__setPrincipal(startingPrincipal);
        loan.__setEndingPrincipal(uint256(0));
        loan.__setPaymentsRemaining(4);

        ( uint256 principal, uint256 interest ) = loan.getNextPaymentBreakdown();
        uint256 totalPayment = principal + interest;

        try loan.makePayment(0) { assertTrue(false, "Able to make payment"); } catch { }

        fundsAsset.mint(address(loan), totalPayment);

        assertEq(fundsAsset.balanceOf(address(loan)), totalPayment);
        assertEq(loan.paymentsRemaining(),            4);
        assertEq(loan.principal(),                    startingPrincipal);

        loan.makePayment(0);

        assertEq(fundsAsset.balanceOf(address(loan)), totalPayment);
        assertEq(loan.paymentsRemaining(),            3);
        assertEq(loan.principal(),                    startingPrincipal - principal);
    }

    function test_postCollateral_pullPattern() external assertFailureWhenPaused {
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

    function test_postCollateral_pushPattern() external assertFailureWhenPaused {
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

    function test_returnFunds_pullPattern() external assertFailureWhenPaused {
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

    function test_returnFunds_pushPattern() external assertFailureWhenPaused {
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

    /*******************/
    /*** Other Tests ***/
    /*******************/

    function test_superFactory() external {
        assertEq(loan.factory(), loan.superFactory());
    }

}

contract MapleLoanRoleTests is TestUtils {

    Borrower   borrower;
    LenderMock lender;
    MockERC20  token;

    ConstructableMapleLoan loan;

    function setUp() public {
        borrower = new Borrower();
        lender   = new LenderMock();
        token    = new MockERC20("Test", "TST", 0);

        address[2] memory assets      = [address(token),   address(token)];
        uint256[3] memory termDetails = [uint256(10 days), uint256(365 days / 6), uint256(6)];
        uint256[3] memory amounts     = [uint256(300_000), uint256(1_000_000), uint256(0)];
        uint256[4] memory rates       = [uint256(0.12 ether), uint256(0), uint256(0), uint256(0)];

        loan = new ConstructableMapleLoan(address(borrower), assets, termDetails, amounts, rates);

        address globalsMock = address(new MapleGlobalsMock(address(this)));

        MockFactory factoryMock = new MockFactory();
        factoryMock.setGlobals(globalsMock);

        loan.__setFactory(address(factoryMock));
    }

    function test_transferBorrowerRole() public {
        Borrower newBorrower = new Borrower();

        assertEq(loan.pendingBorrower(), address(0));
        assertEq(loan.borrower(),        address(borrower));

        // Only borrower can call setPendingBorrower
        assertTrue(!newBorrower.try_loan_setPendingBorrower(address(loan), address(newBorrower)));
        assertTrue(    borrower.try_loan_setPendingBorrower(address(loan), address(newBorrower)));

        assertEq(loan.pendingBorrower(), address(newBorrower));

        // Pending borrower can't call setPendingBorrower
        assertTrue(!newBorrower.try_loan_setPendingBorrower(address(loan), address(1)));
        assertTrue(    borrower.try_loan_setPendingBorrower(address(loan), address(1)));

        assertEq(loan.pendingBorrower(), address(1));

        // Can be reset if mistake is made
        assertTrue(borrower.try_loan_setPendingBorrower(address(loan), address(newBorrower)));

        assertEq(loan.pendingBorrower(), address(newBorrower));
        assertEq(loan.borrower(),        address(borrower));

        // Pending borrower is the only one who can call acceptBorrower
        assertTrue(  !borrower.try_loan_acceptBorrower(address(loan)));
        assertTrue(newBorrower.try_loan_acceptBorrower(address(loan)));

        // Pending borrower is set to zero
        assertEq(loan.pendingBorrower(), address(0));
        assertEq(loan.borrower(),        address(newBorrower));
    }

    function test_transferLenderRole() public {

        // Fund the loan to set the lender
        token.mint(address(lender), 1_000_000);
        lender.erc20_approve(address(token), address(loan),   1_000_000);
        lender.loan_fundLoan(address(loan),  address(lender), 1_000_000);

        LenderMock newLender = new LenderMock();

        assertEq(loan.pendingLender(), address(0));
        assertEq(loan.lender(),        address(lender));

        // Only lender can call setPendingLender
        assertTrue(!newLender.try_loan_setPendingLender(address(loan), address(newLender)));
        assertTrue(    lender.try_loan_setPendingLender(address(loan), address(newLender)));

        assertEq(loan.pendingLender(), address(newLender));

        // Pending lender can't call setPendingLender
        assertTrue(!newLender.try_loan_setPendingLender(address(loan), address(1)));
        assertTrue(    lender.try_loan_setPendingLender(address(loan), address(1)));

        assertEq(loan.pendingLender(), address(1));

        // Can be reset if mistake is made
        assertTrue(lender.try_loan_setPendingLender(address(loan), address(newLender)));

        assertEq(loan.pendingLender(), address(newLender));
        assertEq(loan.lender(),        address(lender));

        // Pending lender is the only one who can call acceptLender
        assertTrue(  !lender.try_loan_acceptLender(address(loan)));
        assertTrue(newLender.try_loan_acceptLender(address(loan)));

        // Pending lender is set to zero
        assertEq(loan.pendingLender(), address(0));
        assertEq(loan.lender(),        address(newLender));
    }
}
