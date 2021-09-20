// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { DSTest }    from "../../modules/ds-test/src/test.sol";
import { IERC20 }    from "../../modules/erc20/src/interfaces/IERC20.sol";
import { MockERC20 } from "../../modules/erc20/src/test/mocks/MockERC20.sol";

import { Borrower } from "./accounts/Borrower.sol";
import { Lender }   from "./accounts/Lender.sol";

import { MapleLoan } from "./../MapleLoan.sol";

interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
}

contract ConstructableMapleLoan is MapleLoan {

    constructor(address borrower_, address[2] memory assets_, uint256[6] memory parameters_, uint256[2] memory amounts_) {
        _initialize(borrower_, assets_, parameters_, amounts_);
    }

}

contract MapleLoanTest is DSTest {

    Hevm hevm;

    constructor() {
        hevm = Hevm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
    }

    function test_story_fullyAmortized() external {
        MockERC20 token    = new MockERC20("Test", "TST", 0);
        Borrower  borrower = new Borrower();
        Lender    lender   = new Lender();

        token.mint(address(borrower), 1_000_000);
        token.mint(address(lender),   1_000_000);

        address[2] memory assets = [address(token), address(token)];

        uint256[6] memory parameters = [
            uint256(0),
            uint256(10 days),
            uint256(120_000),
            uint256(100_000),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [uint256(300_000), uint256(1_000_000)];

        ConstructableMapleLoan loan = new ConstructableMapleLoan(address(borrower), assets, parameters, requests);

        lender.erc20_transfer(address(token), address(loan), 1_000_000);
        assertTrue(lender.try_loan_lend(address(loan), address(lender)), "Cannot lend");

        assertEq(loan.drawableFunds(), 1_000_000, "Different drawable funds");

        borrower.erc20_transfer(address(token), address(loan), 300_000);
        assertTrue(borrower.try_loan_postCollateral(address(loan)), "Cannot post");

        assertTrue(borrower.try_loan_drawdownFunds(address(loan), 1_000_000, address(borrower)), "Cannot drawdown");

        assertEq(loan.drawableFunds(), 0, "Different drawable funds");

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion, uint256 lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         158_527,   "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(lateFeesPortion,          0,         "Different late fees");
        assertEq(loan.paymentsRemaining(), 6,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #1 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #1
        borrower.erc20_transfer(address(token), address(loan), 178_527);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment #2
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         161_697, "Different principal");
        assertEq(interestPortion,          16_829,  "Different interest");
        assertEq(lateFeesPortion,          0,       "Different late fees");
        assertEq(loan.paymentsRemaining(), 5,       "Different payments remaining");
        assertEq(loan.principal(),         841_473, "Different payments remaining");

        // Warp to 1 second before payment #2 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #2
        borrower.erc20_transfer(address(token), address(loan), 178_526);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment #3
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         164_930, "Different principal");
        assertEq(interestPortion,          13_595,  "Different interest");
        assertEq(lateFeesPortion,          0,       "Different late fees");
        assertEq(loan.paymentsRemaining(), 4,       "Different payments remaining");
        assertEq(loan.principal(),         679_776, "Different payments remaining");

        // Warp to 1 second before payment #3 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #3
        borrower.erc20_transfer(address(token), address(loan), 178_525);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Remove some collateral
        assertTrue(borrower.try_loan_removeCollateral(address(loan), 145_546, address(borrower)), "Cannot remove collateral");
        assertEq(loan.collateral(), 154_454, "Different collateral");

        // Check details for upcoming payment #4
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         168_229, "Different principal");
        assertEq(interestPortion,          10_296,  "Different interest");
        assertEq(lateFeesPortion,          0,       "Different late fees");
        assertEq(loan.paymentsRemaining(), 3,       "Different payments remaining");
        assertEq(loan.principal(),         514_846, "Different payments remaining");

        // Warp to 1 second before payment #4 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #4
        borrower.erc20_transfer(address(token), address(loan), 178_525);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Return some funds and remove some collateral
        borrower.erc20_transfer(address(token), address(loan), 150_000);
        assertTrue(borrower.try_loan_returnFunds(address(loan)), "Cannot return funds");
        assertEq(loan.drawableFunds(), 150_000, "Different drawable funds");
        assertTrue(borrower.try_loan_removeCollateral(address(loan), 85_059, address(borrower)), "Cannot remove collateral");
        assertEq(loan.collateral(), 69_395, "Different collateral");

        // Claim loan proceeds thus far
        assertTrue(lender.try_loan_claimFunds(address(loan), 714103, address(lender)), "Cannot claim funds");

        // Check details for upcoming payment #5
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         171_592, "Different principal");
        assertEq(interestPortion,          6_932,   "Different interest");
        assertEq(lateFeesPortion,          0,       "Different late fees");
        assertEq(loan.paymentsRemaining(), 2,       "Different payments remaining");
        assertEq(loan.principal(),         346_617, "Different payments remaining");

        // Warp to 1 second before payment #5 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #5
        borrower.erc20_transfer(address(token), address(loan), 178_524);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment #6
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         175_025, "Different principal");
        assertEq(interestPortion,          3_500,   "Different interest");
        assertEq(lateFeesPortion,          0,       "Different late fees");
        assertEq(loan.paymentsRemaining(), 1,       "Different payments remaining");
        assertEq(loan.principal(),         175_025, "Different payments remaining");

        // Warp to 1 second before payment #6 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #6
        borrower.erc20_transfer(address(token), address(loan), 178_525);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment which should not be necessary
        assertEq(loan.paymentsRemaining(), 0, "Different payments remaining");
        assertEq(loan.principal(),         0, "Different payments remaining");

        // Remove rest of available funds and collateral
        assertTrue(borrower.try_loan_drawdownFunds(address(loan), 150_000, address(borrower)), "Cannot drawdown");
        assertTrue(borrower.try_loan_removeCollateral(address(loan), 69_395, address(borrower)), "Cannot remove collateral");
        assertEq(loan.collateral(), 0, "Different collateral");

        // Claim remaining loan proceeds
        assertTrue(lender.try_loan_claimFunds(address(loan), 357_049, address(lender)), "Cannot remove collateral");
    }

    function test_story_interestOnly() external {
        MockERC20 token    = new MockERC20("Test", "TST", 0);
        Borrower  borrower = new Borrower();
        Lender    lender   = new Lender();

        token.mint(address(borrower), 1_000_000);
        token.mint(address(lender),   1_000_000);

        address[2] memory assets = [address(token), address(token)];

        uint256[6] memory parameters = [
            uint256(1_000_000),
            uint256(10 days),
            uint256(120_000),
            uint256(100_000),
            uint256(365 days / 6),
            uint256(6)
        ];

        uint256[2] memory requests = [uint256(300_000), uint256(1_000_000)];

        ConstructableMapleLoan loan = new ConstructableMapleLoan(address(borrower), assets, parameters, requests);

        lender.erc20_transfer(address(token), address(loan), 1_000_000);
        assertTrue(lender.try_loan_lend(address(loan), address(lender)), "Cannot lend");

        assertEq(loan.drawableFunds(), 1_000_000, "Different drawable funds");

        borrower.erc20_transfer(address(token), address(loan), 300_000);
        assertTrue(borrower.try_loan_postCollateral(address(loan)), "Cannot post");

        assertTrue(borrower.try_loan_drawdownFunds(address(loan), 1_000_000, address(borrower)), "Cannot drawdown");

        assertEq(loan.drawableFunds(), 0, "Different drawable funds");

        // Check details for upcoming payment #1
        ( uint256 principalPortion, uint256 interestPortion, uint256 lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(lateFeesPortion,          0,         "Different late fees");
        assertEq(loan.paymentsRemaining(), 6,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #1 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #1
        borrower.erc20_transfer(address(token), address(loan), 20_000);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment #2
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(lateFeesPortion,          0,         "Different late fees");
        assertEq(loan.paymentsRemaining(), 5,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #2 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #2
        borrower.erc20_transfer(address(token), address(loan), 20_000);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment #3
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(lateFeesPortion,          0,         "Different late fees");
        assertEq(loan.paymentsRemaining(), 4,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #3 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #3
        borrower.erc20_transfer(address(token), address(loan), 20_000);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment #4
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(lateFeesPortion,          0,         "Different late fees");
        assertEq(loan.paymentsRemaining(), 3,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #4 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #4
        borrower.erc20_transfer(address(token), address(loan), 20_000);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Return some funds and remove some collateral
        borrower.erc20_transfer(address(token), address(loan), 500_000);
        assertTrue(borrower.try_loan_returnFunds(address(loan)), "Cannot return funds");
        assertEq(loan.drawableFunds(), 500_000, "Different drawable funds");
        assertTrue(borrower.try_loan_removeCollateral(address(loan), 150_000, address(borrower)), "Cannot remove collateral");
        assertEq(loan.collateral(), 150_000, "Different collateral");

        // Claim loan proceeds thus far
        assertTrue(lender.try_loan_claimFunds(address(loan), 80000, address(lender)), "Cannot claim funds");

        // Check details for upcoming payment #5
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         0,         "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(lateFeesPortion,          0,         "Different late fees");
        assertEq(loan.paymentsRemaining(), 2,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #5 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #5
        borrower.erc20_transfer(address(token), address(loan), 20_000);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment #6
        ( principalPortion, interestPortion, lateFeesPortion ) = loan.getNextPaymentsBreakDown(1);

        assertEq(principalPortion,         1_000_000, "Different principal");
        assertEq(interestPortion,          20_000,    "Different interest");
        assertEq(lateFeesPortion,          0,         "Different late fees");
        assertEq(loan.paymentsRemaining(), 1,         "Different payments remaining");
        assertEq(loan.principal(),         1_000_000, "Different payments remaining");

        // Warp to 1 second before payment #6 becomes late
        hevm.warp(loan.nextPaymentDueDate() - 1);

        // Make payment #6
        borrower.erc20_transfer(address(token), address(loan), 1_020_000);
        assertTrue(borrower.try_loan_makePayment(address(loan)), "Cannot pay");

        // Check details for upcoming payment which should not be necessary
        assertEq(loan.paymentsRemaining(), 0, "Different payments remaining");
        assertEq(loan.principal(),         0, "Different payments remaining");

        // Remove rest of available funds and collateral
        assertTrue(borrower.try_loan_drawdownFunds(address(loan), 150_000, address(borrower)), "Cannot drawdown");
        assertTrue(borrower.try_loan_removeCollateral(address(loan), 150_000, address(borrower)), "Cannot remove collateral");
        assertEq(loan.collateral(), 0, "Different collateral");

        // Claim remaining loan proceeds
        assertTrue(lender.try_loan_claimFunds(address(loan), 1_040_000, address(lender)), "Cannot remove collateral");
    }

}
