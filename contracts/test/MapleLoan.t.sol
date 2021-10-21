// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { IERC20 }    from "../../modules/erc20/src/interfaces/IERC20.sol";
import { MockERC20 } from "../../modules/erc20/src/test/mocks/MockERC20.sol";
import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { IMapleLoan } from "../interfaces/IMapleLoan.sol";

import { ManipulatableMapleLoan, LenderMock } from "./mocks/Mocks.sol";

import { Borrower } from "./accounts/Borrower.sol";

contract MapleLoanTests is TestUtils {

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

    function test_getRemovableCollateral_varyCollateral() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(800_000);
        loan.setPrincipal(500_000);

        loan.setCollateral(0);

        assertEq(loan.getRemovableCollateral(), 0);

        loan.setCollateral(200_000);

        assertEq(loan.getRemovableCollateral(), 0);

        loan.setCollateral(400_000);

        assertEq(loan.getRemovableCollateral(), 0);

        loan.setCollateral(500_000);

        assertEq(loan.getRemovableCollateral(), 100_000);

        loan.setCollateral(1_000_000);

        assertEq(loan.getRemovableCollateral(), 600_000);

        loan.setDrawableFunds(1_000_000);
        loan.setCollateral(0);

        assertEq(loan.getRemovableCollateral(), 0);

        loan.setCollateral(1_000_000);

        assertEq(loan.getRemovableCollateral(), 1_000_000);
    }

    function test_getRemovableCollateral_varyDrawableFunds() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(2_400_000);
        loan.setPrincipal(500_000);
        loan.setCollateral(1_200_000);

        loan.setDrawableFunds(0);

        assertEq(loan.getRemovableCollateral(), 0);

        loan.setDrawableFunds(200_000);

        assertEq(loan.getRemovableCollateral(), 480_000);

        loan.setDrawableFunds(500_000);

        assertEq(loan.getRemovableCollateral(), 1_200_000);
    }

    function test_getRemovableCollateral_varyPrincipal() external {
        ManipulatableMapleLoan loan = new ManipulatableMapleLoan();

        loan.setPrincipalRequested(1_000_000);
        loan.setCollateralRequired(2_400_000);
        loan.setCollateral(1_200_000);

        loan.setPrincipal(1_000_000);

        assertEq(loan.getRemovableCollateral(), 0);

        loan.setPrincipal(500_000);

        assertEq(loan.getRemovableCollateral(), 0);

        loan.setPrincipal(200_000);

        assertEq(loan.getRemovableCollateral(), 720_000);

        loan.setPrincipal(0);

        assertEq(loan.getRemovableCollateral(), 1_200_000);
    }

}
