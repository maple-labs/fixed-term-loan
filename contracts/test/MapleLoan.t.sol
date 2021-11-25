// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { Hevm, StateManipulations, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { IERC20 }                              from "../../modules/erc20/src/interfaces/IERC20.sol";
import { MockERC20 }                           from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { IMapleLoan } from "../interfaces/IMapleLoan.sol";

import { ManipulatableMapleLoan, LenderMock } from "./mocks/Mocks.sol";

import { Borrower } from "./accounts/Borrower.sol";

contract MapleLoanTests is StateManipulations, TestUtils {

    /***********************************/
    /*** Collateral Management Tests ***/
    /***********************************/

    function test_getAdditionalCollateralRequiredFor_varyAmount() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(800_000);
        loan.setPrincipal(500_000);
        loan.setDrawableFunds(1_000_000);

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
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setPrincipal(1_000_000);
        loan.setDrawableFunds(1_000_000);

        loan.setCollateralRequired(0);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 0);

        loan.setCollateralRequired(200_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 200_000);

        loan.setCollateralRequired(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 1_000_000);

        loan.setCollateralRequired(2_400_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 2_400_000);
    }

    function test_getAdditionalCollateralRequiredFor_varyDrawableFunds() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(2_400_000);
        loan.setPrincipal(1_000_000);

        loan.setDrawableFunds(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 2_400_000);

        loan.setDrawableFunds(1_200_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 1_920_000);

        loan.setDrawableFunds(1_800_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 480_000);

        loan.setDrawableFunds(2_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 0);

        loan.setDrawableFunds(3_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(1_000_000), 0);
    }

    function test_getAdditionalCollateralRequiredFor_varyPrincipal() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(2_000_000);
        loan.setDrawableFunds(500_000);

        loan.setPrincipal(0);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 0);

        loan.setPrincipal(200_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 400_000);

        loan.setPrincipal(500_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 1_000_000);

        loan.setPrincipal(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 2_000_000);

        loan.setCollateral(1_000_000);

        assertEq(loan.getAdditionalCollateralRequiredFor(500_000), 1_000_000);
    }

    function test_excessCollateral_varyCollateral() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(800_000);
        loan.setPrincipal(500_000);

        loan.setCollateral(0);

        assertEq(loan.excessCollateral(), 0);

        loan.setCollateral(200_000);

        assertEq(loan.excessCollateral(), 0);

        loan.setCollateral(400_000);

        assertEq(loan.excessCollateral(), 0);

        loan.setCollateral(500_000);

        assertEq(loan.excessCollateral(), 100_000);

        loan.setCollateral(1_000_000);

        assertEq(loan.excessCollateral(), 600_000);

        loan.setDrawableFunds(1_000_000);
        loan.setCollateral(0);

        assertEq(loan.excessCollateral(), 0);

        loan.setCollateral(1_000_000);

        assertEq(loan.excessCollateral(), 1_000_000);
    }

    function test_excessCollateral_varyDrawableFunds() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(2_400_000);
        loan.setPrincipal(500_000);
        loan.setCollateral(1_200_000);

        loan.setDrawableFunds(0);

        assertEq(loan.excessCollateral(), 0);

        loan.setDrawableFunds(200_000);

        assertEq(loan.excessCollateral(), 480_000);

        loan.setDrawableFunds(500_000);

        assertEq(loan.excessCollateral(), 1_200_000);
    }

    function test_excessCollateral_varyPrincipal() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(2_400_000);
        loan.setCollateral(1_200_000);

        loan.setPrincipal(1_000_000);

        assertEq(loan.excessCollateral(), 0);

        loan.setPrincipal(500_000);

        assertEq(loan.excessCollateral(), 0);

        loan.setPrincipal(200_000);

        assertEq(loan.excessCollateral(), 720_000);

        loan.setPrincipal(0);

        assertEq(loan.excessCollateral(), 1_200_000);
    }

    /****************************/
    /*** Access Control Tests ***/
    /****************************/

    function test_acl_factory_migrate() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        try loan.migrate(address(0), new bytes(0)) { assertTrue(false, "Non-factory was able to migrate"); } catch { }

        loan.setFactorySlot(address(this));

        loan.migrate(address(0), new bytes(0));
    }

    function test_acl_factory_setImplementation() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        try loan.setImplementation(address(this)) { assertTrue(false, "Non-factory was able to set implementation"); } catch { }

        loan.setFactorySlot(address(this));

        loan.setImplementation(address(this));
    }

    function test_acl_factory_drawdownFunds() external {
        ManipulatableMapleLoan loan       = new ManipulatableMapleLoan();
        MockERC20              fundsAsset = new MockERC20("Funds Asset", "FA", 18);

        fundsAsset.mint(address(loan), 1_000_000);

        loan.setFundsAsset(address(fundsAsset));
        loan.setPrincipalRequested(1_000_000);  // Needed for the getAdditionalCollateralRequiredFor
        loan.setDrawableFunds(1_000_000);

        try loan.drawdownFunds(1, address(this)) { assertTrue(false, "Non-borrower was able to drawdown"); } catch { }

        loan.setBorrowerSlot(address(this));

        loan.drawdownFunds(1, address(this));
    }

    function test_acl_borrower_proposeNewTerms() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        address refinancer = address(1);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSignature("increasePrincipal(uint256)", uint256(1));

        try loan.proposeNewTerms(refinancer, data) { assertTrue(false, "Non-borrower was able to propose new terms"); } catch { }

        loan.setBorrowerSlot(address(this));

        loan.proposeNewTerms(refinancer, data);
    }

    function test_acl_borrower_removeCollateral() external {
        ManipulatableMapleLoan loan            = new ManipulatableMapleLoan();
        MockERC20              collateralAsset = new MockERC20("Collateral Asset", "CA", 18);

        loan.setPrincipalRequested(1); // Needed for the collateralMaintained check
        loan.setCollateralAsset(address(collateralAsset));
        loan.setCollateral(1);

        collateralAsset.mint(address(loan), 1);

        try loan.removeCollateral(1, address(this)) { assertTrue(false, "Non-borrower was able to remove collateral"); } catch { }

        loan.setBorrowerSlot(address(this));

        loan.removeCollateral(1, address(this));
    }

    function test_acl_borrower_setBorrower() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        try loan.setBorrower(address(1)) { assertTrue(false, "Non-borrower was able to set borrower"); } catch { }

        loan.setBorrowerSlot(address(this));

        loan.setBorrower(address(1));
    }

    function test_acl_lender_acceptNewTerms() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1);  // Needed for the collateralMaintained check

        address refinancer = address(1);
        bytes[] memory data = new bytes[](1);
        data[0] = new bytes(0);
        bytes32 commitment = keccak256(abi.encode(refinancer, data));
        
        loan.setCommintmentHash(commitment);

        try loan.acceptNewTerms(refinancer, data, uint(0)) { assertTrue(false, "Non-lender was able to accept terms"); } catch { }

        loan.setLenderSlot(address(this));

        loan.acceptNewTerms(refinancer, data, uint(0));
    }

    function test_acl_lender_claimFunds() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setClaimableFunds(uint256(200_000));

        try loan.claimFunds(uint256(200_000), address(this)) { assertTrue(false, "Non-lender was able to claim funds"); } catch { }

        loan.setLenderSlot(address(this));

        loan.claimFunds(uint256(200_000), address(this));
    }

    function test_acl_lender_repossess() external {
        ManipulatableMapleLoan loan  = new ManipulatableMapleLoan();
        MockERC20              asset = new MockERC20("Asset", "AST", 18);

        loan.setNextPaymentDueDate(1);
        loan.setCollateralAsset(address(asset));
        loan.setFundsAsset(address(asset));
        
        hevm.warp(loan.nextPaymentDueDate() + loan.gracePeriod() + 1);

        try loan.repossess(address(this)) {  assertTrue(false, "Non-lender was able to reposses"); } catch { }

        loan.setLenderSlot(address(this));

        loan.repossess(address(this));
    }

    function test_acl_lender_setLender() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        try loan.setLender(address(this)) {  assertTrue(false, "Non-lender was able to set lender"); } catch { }

        loan.setLenderSlot(address(this));

        loan.setLender(address(this));
    }

    // TODO: test_acl_borrower_upgrade (can mock factory)
    // TODO: test_acl_borrower_skim
    // TODO: test_acl_lender_skim

}
