// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { Hevm, StateManipulations, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }                              from "../../modules/erc20/src/interfaces/IERC20.sol";
import { MockERC20 }                           from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { IMapleLoan } from "../interfaces/IMapleLoan.sol";

import { ConstructableMapleLoan, EmptyContract, ManipulatableMapleLoan, LenderMock } from "./mocks/Mocks.sol";

import { Borrower } from "./accounts/Borrower.sol";

contract MapleLoanTests is StateManipulations, TestUtils {

    ManipulatableMapleLoan loan;

    function setUp() external {
        loan = new ManipulatableMapleLoan();
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

    function test_drawdownFunds_acl() external {
        MockERC20 fundsAsset = new MockERC20("Funds Asset", "FA", 18);

        fundsAsset.mint(address(loan), 1_000_000);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setPrincipalRequested(1_000_000);  // Needed for the getAdditionalCollateralRequiredFor
        loan.__setDrawableFunds(1_000_000);

        try loan.drawdownFunds(1, address(this)) { assertTrue(false, "Non-borrower was able to drawdown"); } catch { }

        loan.__setBorrower(address(this));

        loan.drawdownFunds(1, address(this));
    }

    function test_proposeNewTerms_acl() external {
        address mockRefinancer = address(new EmptyContract());
        bytes[] memory data = new bytes[](1);
        data[0] = new bytes(0);

        try loan.proposeNewTerms(mockRefinancer, data) { assertTrue(false, "Non-borrower was able to propose new terms"); } catch { }

        loan.__setBorrower(address(this));

        loan.proposeNewTerms(mockRefinancer, data);
    }

    function test_removeCollateral_acl() external {
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

    function test_acceptNewTerms_acl() external {
        MockERC20 token = new MockERC20("MockToken", "MA", 18);

        loan.__setPrincipalRequested(1);            // Needed for the collateralMaintained check
        loan.__setCollateralAsset(address(token));  // Needed for the getUnaccountedAmount check
        loan.__setFundsAsset(address(token));       // Needed for the getUnaccountedAmount check

        address mockRefinancer = address(new EmptyContract());
        bytes[] memory data = new bytes[](1);
        data[0] = new bytes(0);
        bytes32 refinanceCommitmentHash = keccak256(abi.encode(mockRefinancer, data));

        loan.__setRefinanceCommitmentHash(refinanceCommitmentHash);

        try loan.acceptNewTerms(mockRefinancer, data, uint(0)) { assertTrue(false, "Non-lender was able to accept terms"); } catch { }

        loan.__setLender(address(this));

        loan.acceptNewTerms(mockRefinancer, data, uint(0));
    }

    function test_claimFunds_acl() external {
        MockERC20 fundsAsset = new MockERC20("Funds Asset", "FA", 18);

        fundsAsset.mint(address(loan), 200_000);

        loan.__setFundsAsset(address(fundsAsset));
        loan.__setClaimableFunds(uint256(200_000));

        try loan.claimFunds(uint256(200_000), address(this)) { assertTrue(false, "Non-lender was able to claim funds"); } catch { }

        loan.__setLender(address(this));

        loan.claimFunds(uint256(200_000), address(this));
    }

    function test_repossess_acl() external {
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

    /***********************/
    /*** Fund Loan Tests ***/
    /***********************/

    function test_fundLoan_extraFundsWhileNotActive() external {
        LenderMock             lender = new LenderMock();
        ManipulatableMapleLoan loan   = new ManipulatableMapleLoan();
        MockERC20              token  = new MockERC20("FA", "FundsAsset", 0);

        loan.__setFundsAsset(address(token));
        loan.__setPaymentsRemaining(1);
        loan.__setPrincipalRequested(1_000_000);

        token.mint(address(loan), 1_000_000 + 1);

        loan.fundLoan(address(lender), 0);

        assertEq(token.balanceOf(address(loan)),   1_000_000);
        assertEq(token.balanceOf(address(lender)), 1);
    }

    function test_fundLoan_extraFundsWhileActive() external {
        LenderMock             lender = new LenderMock();
        ManipulatableMapleLoan loan   = new ManipulatableMapleLoan();
        MockERC20              token  = new MockERC20("FA", "FundsAsset", 0);

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

    function test_acceptNewTerms_extraFunds() external {
        LenderMock             lender     = new LenderMock();
        ManipulatableMapleLoan loan       = new ManipulatableMapleLoan();
        MockERC20              token      = new MockERC20("FA", "FundsAsset", 0);
        EmptyContract          refinancer = new EmptyContract();

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

    // TODO: test_upgrade_acl (can mock factory)
    // TODO: test_skim_acl
    // TODO: test closeLoan with and without pulling funds
    // TODO: test drawdownFunds with and without pulling funds
    // TODO: test drawdownFunds with and without additional collateral required (with and without some unaccounted amount already in the loan)
    // TODO: test makePayment with and without pulling funds
    // TODO: test postCollateral with and without pulling funds
    // TODO: test returnFunds with and without pulling funds
    // TODO: test acceptNewTerms with and without pulling funds
    // TODO: test fundLoan with and without pulling funds
    // TODO: test fundLoan asset redirection if loan is active
    // TODO: test that skim cannot be used on collateralAsset or fundsAsset
    // TODO: test that skim fails on transfer fail
    // TODO: test that superFactory returns factory

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
