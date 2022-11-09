// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { IMapleProxyFactory } from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { MapleGlobalsMock, MockLoanManager, MockPoolManager } from "./mocks/Mocks.sol";

import { MapleLoan }            from "../contracts/MapleLoan.sol";
import { MapleLoanFactory }     from "../contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer } from "../contracts/MapleLoanInitializer.sol";
import { MapleLoanFeeManager }  from "../contracts/MapleLoanFeeManager.sol";

contract FeeManagerBase is TestUtils {

    address BORROWER = address(new Address());
    address GOVERNOR = address(new Address());
    address PD       = address(new Address());
    address TREASURY = address(new Address());

    address implementation;
    address initializer;

    MapleGlobalsMock    globals;
    MapleLoanFactory    factory;
    MapleLoanFeeManager feeManager;
    MockERC20           collateralAsset;
    MockERC20           fundsAsset;
    MockLoanManager     loanManager;
    MockPoolManager     poolManager;

    address[2] internal defaultAssets;
    uint256[3] internal defaultTermDetails;
    uint256[3] internal defaultAmounts;
    uint256[4] internal defaultRates;
    uint256[2] internal defaultFees;

    function setUp() public virtual {
        implementation = address(new MapleLoan());
        initializer    = address(new MapleLoanInitializer());

        collateralAsset = new MockERC20("MockCollateral", "MC", 18);
        fundsAsset      = new MockERC20("MockAsset", "MA", 18);
        poolManager     = new MockPoolManager(PD);

        loanManager = new MockLoanManager();
        globals     = new MapleGlobalsMock(GOVERNOR, loanManager.factory());
        factory     = new MapleLoanFactory(address(globals));
        feeManager  = new MapleLoanFeeManager(address(globals));

        loanManager.__setPoolManager(address(poolManager));

        vm.startPrank(GOVERNOR);
        factory.registerImplementation(1, implementation, initializer);
        factory.setDefaultVersion(1);

        globals.setMapleTreasury(TREASURY);
        globals.setValidBorrower(BORROWER,                        true);
        globals.setValidCollateralAsset(address(collateralAsset), true);
        globals.setValidPoolAsset(address(fundsAsset),            true);
        vm.stopPrank();

        defaultAssets      = [address(collateralAsset), address(fundsAsset)];
        defaultTermDetails = [uint256(10 days), uint256(365 days / 12), uint256(3)];
        defaultAmounts     = [uint256(0), uint256(1_000_000e18), uint256(1_000_000e18)];
        defaultRates       = [uint256(0.12e18), uint256(0.02e18), uint256(0), uint256(0.02e18)];
        defaultFees        = [uint256(50_000e18), uint256(500e18)];
    }

    function _createLoan(
        address borrower_,
        address feeManager_,
        address[2] memory assets_,
        uint256[3] memory termDetails_,
        uint256[3] memory amounts_,
        uint256[4] memory rates_,
        uint256[2] memory fees_,
        bytes32 salt_
    )
        internal returns (address loan_)
    {
        loan_ = factory.createInstance({
            arguments_: MapleLoanInitializer(initializer).encodeArguments(borrower_, feeManager_, assets_, termDetails_, amounts_, rates_, fees_),
            salt_:      keccak256(abi.encodePacked(salt_))
        });
    }

    function _fundLoan(address loan_, address lender_, uint256 amount_) internal {
        fundsAsset.mint(address(loan_), amount_);
        vm.prank(lender_);
        MapleLoan(loan_).fundLoan(lender_);
    }

    function _drawdownLoan(address loan_, address borrower_) internal {
        uint256 drawableFunds = MapleLoan(loan_).drawableFunds();
        vm.prank(BORROWER);
        MapleLoan(loan_).drawdownFunds(drawableFunds, borrower_);
    }

}

contract PayClosingFeesTests is FeeManagerBase {

    MapleLoan loan;

    function setUp() public override {
        super.setUp();

        loan = MapleLoan(_createLoan(BORROWER, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees, "salt"));

        globals.setPlatformServiceFeeRate(address(poolManager), 3000);  // 0.3%

        _fundLoan(address(loan), address(loanManager), loan.principalRequested());

        _drawdownLoan(address(loan), BORROWER);
    }

    function test_payClosingServiceFees_insufficientFunds_poolDelegate() external {
        uint256 delegateServiceFee = 1500e18;  // 500 * 3 = 1500

        fundsAsset.mint(BORROWER, delegateServiceFee - 1);

        vm.startPrank(BORROWER);

        fundsAsset.approve(address(loan), delegateServiceFee - 1);

        vm.expectRevert("MLFM:PSF:PD_TRANSFER");
        loan.closeLoan(delegateServiceFee - 1);
    }

    function test_payClosingServiceFees_insufficientFunds_treasury() external {
        uint256 delegateServiceFee = 1500e18;  // 500 * 3 = 1500
        uint256 platformServiceFee = 750e18;   // 1m * 0.3% / 12 * 3 = 750

        fundsAsset.mint(BORROWER, delegateServiceFee + platformServiceFee - 1);

        vm.startPrank(BORROWER);

        fundsAsset.approve(address(loan), delegateServiceFee + platformServiceFee - 1);

        vm.expectRevert("MLFM:PSF:TREASURY_TRANSFER");
        loan.closeLoan(delegateServiceFee + platformServiceFee - 1);
    }

    function test_payClosingServiceFees() external {
        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getClosingPaymentBreakdown();

        assertEq(principal, 1_000_000e18);
        assertEq(interest,  20_000e18);
        assertEq(fees,      2_250e18);  // 1m * (0.3% + 0.6%) / 12 * 3 = 1000 + 750

        fundsAsset.mint(BORROWER, 72_250e18);  // 1m + 20k + 2.25k = 1_022_250 = 950k + 72.25k

        vm.startPrank(BORROWER);

        fundsAsset.approve(address(loan), 1_022_250e18);  // 1m + 20k + 2.25k = 1_022_250

        assertEq(fundsAsset.balanceOf(BORROWER),             1_022_250e18);  // 1m + 20k + 2.25k + = 1_022_250
        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(PD),                   50_000e18);  // Origination fees
        assertEq(fundsAsset.balanceOf(TREASURY),             0);

        loan.closeLoan(1_022_250e18);

        assertEq(fundsAsset.balanceOf(BORROWER),             0);
        assertEq(fundsAsset.balanceOf(address(loanManager)), 1_020_000e18);  // Principal + interest
        assertEq(fundsAsset.balanceOf(PD),                   50_000e18 + 1_500e18);
        assertEq(fundsAsset.balanceOf(TREASURY),             750e18);
    }

}

contract PayOriginationFeesTests is FeeManagerBase {

    MapleLoan loan;

    uint256 originationFee = 50_000e18;

    function setUp() public override {
        super.setUp();

        loan = MapleLoan(_createLoan(BORROWER, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees, "salt"));

        globals.setPlatformOriginationFeeRate(address(poolManager), 3000);  // 0.3%
    }

    function test_payOriginationFees_insufficientFunds_poolDelegate() external {
        fundsAsset.mint(address(loan), 50_00e18 - 1);

        vm.prank(address(loanManager));
        vm.expectRevert("MLFM:POF:PD_TRANSFER");
        loan.fundLoan(address(loanManager));
    }

    function test_payOriginationFees_insufficientFunds_treasury() external {
        fundsAsset.mint(address(loan), 50_750e18 - 1);  // 50k + (1m * 0.3% / 12 * 3) = 50_750

        vm.prank(address(loanManager));
        vm.expectRevert("MLFM:POF:TREASURY_TRANSFER");
        loan.fundLoan(address(loanManager));
    }

    function test_payOriginationFees_zeroTreasury() external {
        vm.prank(GOVERNOR);
        globals.setMapleTreasury(address(0));

        fundsAsset.mint(address(loan), 1_000_000e18);  // 1m + 50k + (1m * 0.3% = 3_000) = 1_053_000

        vm.prank(address(loanManager));
        vm.expectRevert("MLFM:TT:ZERO_DESTINATION");
        loan.fundLoan(address(loanManager));
    }

    function test_payOriginationFees() external {
        fundsAsset.mint(address(loan), 1_000_000e18);  // 1m + 50k + (1m * 0.3% = 3_000) = 1_053_000

        assertEq(fundsAsset.balanceOf(address(loan)), 1_000_000e18);
        assertEq(fundsAsset.balanceOf(PD),            0);
        assertEq(fundsAsset.balanceOf(TREASURY),      0);

        vm.prank(address(loanManager));
        loan.fundLoan(address(loanManager));

        assertEq(fundsAsset.balanceOf(address(loan)), 949_250e18);  // Principal - both origination fees
        assertEq(fundsAsset.balanceOf(PD),            50_000e18);   // 50k origination fee to PD
        assertEq(fundsAsset.balanceOf(TREASURY),      750e18);      // (1m * 0.3% / 12 * 3) = 750 to treasury
    }

}

contract PayServiceFeesTests is FeeManagerBase {

    MapleLoan loan;

    uint256 platformServiceFeeRate = 3000;  // 0.3%

    function setUp() public override {
        super.setUp();

        loan = MapleLoan(_createLoan(BORROWER, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees, "salt"));

        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);

        _fundLoan(address(loan), address(loanManager), loan.principalRequested());
        _drawdownLoan(address(loan), BORROWER);
    }

    function test_payServiceFees_insufficientFunds_poolDelegate() external {
        uint256 platformServiceFee = 250e18;  // 1m * 0.3% / 12 = 250

        fundsAsset.mint(BORROWER, platformServiceFee - 1);

        vm.startPrank(BORROWER);

        fundsAsset.approve(address(loan), platformServiceFee - 1);

        vm.expectRevert("MLFM:PSF:PD_TRANSFER");
        loan.makePayment(platformServiceFee - 1);
    }

    function test_payServiceFees_insufficientFunds_treasury() external {
        uint256 platformServiceFee = 250e18;  // 1m * 0.3% / 12 = 250
        uint256 delegateServiceFee = 500e18;  // 500 = 500

        fundsAsset.mint(BORROWER, delegateServiceFee + platformServiceFee - 1);

        vm.startPrank(BORROWER);

        fundsAsset.approve(address(loan), delegateServiceFee + platformServiceFee - 1);

        vm.expectRevert("MLFM:PSF:TREASURY_TRANSFER");
        loan.makePayment(delegateServiceFee + platformServiceFee - 1);
    }

    function test_payServiceFees_zeroTreasury() external {
        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getNextPaymentBreakdown();

        assertEq(principal, 0);
        assertEq(interest,  10_000e18);
        assertEq(fees,      750e18);     // 1m * (0.3% + 0.6%) / 12 = 250 + 500

        vm.prank(GOVERNOR);
        globals.setMapleTreasury(address(0));

        vm.startPrank(BORROWER);

        fundsAsset.approve(address(loan), 10_750e18);

        vm.expectRevert("MLFM:TT:ZERO_DESTINATION");
        loan.makePayment(10_750e18);
    }

    function test_payServiceFees() external {
        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getNextPaymentBreakdown();

        assertEq(principal, 0);
        assertEq(interest,  10_000e18);
        assertEq(fees,      750e18);     // 1m * (0.3% + 0.6%) / 12 = 250 + 500

        vm.startPrank(BORROWER);

        fundsAsset.approve(address(loan), 10_750e18);

        assertEq(fundsAsset.balanceOf(BORROWER),             950_000e18);
        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(PD),                   50_000e18);  // Origination fees
        assertEq(fundsAsset.balanceOf(TREASURY),             0);

        loan.makePayment(10_750e18);

        assertEq(fundsAsset.balanceOf(BORROWER),             939_250e18);          // 950k - 10.75k
        assertEq(fundsAsset.balanceOf(address(loanManager)), 10_000e18);           // Interest
        assertEq(fundsAsset.balanceOf(PD),                   50_000e18 + 500e18);
        assertEq(fundsAsset.balanceOf(TREASURY),             250e18);
    }

}

contract UpdatePlatformServiceFeeTests is FeeManagerBase {

    function test_updatePlatformServiceFee() external {
        address loan1 = _createLoan(BORROWER, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees, "salt1");
        address loan2 = _createLoan(BORROWER, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees, "salt2");

        _fundLoan(loan1, address(loanManager), 1_000_000e18);
        _fundLoan(loan2, address(loanManager), 1_000_000e18);

        assertEq(feeManager.platformServiceFee(loan1), 0);
        assertEq(feeManager.platformServiceFee(loan2), 0);

        globals.setPlatformServiceFeeRate(address(poolManager), 3000);  // 0.3%

        vm.prank(loan1);
        feeManager.updatePlatformServiceFee(1_000_000e18, 365 days / 12);

        assertEq(feeManager.platformServiceFee(loan1), 250e18);  // Updated from globals (1m * 0.3% / 12)
        assertEq(feeManager.platformServiceFee(loan2), 0);       // Unchanged from globals

        globals.setPlatformServiceFeeRate(address(poolManager), 6000);  // 0.6%

        vm.prank(loan2);
        feeManager.updatePlatformServiceFee(1_000_000e18, 365 days / 12);

        assertEq(feeManager.platformServiceFee(loan1), 250e18);  // Unchanged from globals
        assertEq(feeManager.platformServiceFee(loan2), 500e18);  // Updated from globals (1m * 0.6% / 12)
    }

}

contract UpdateFeeTerms_SetterTests is FeeManagerBase {

    function test_updateDelegateFeeTerms() external {
        address someContract = address(new Address());

        assertEq(feeManager.delegateOriginationFee(someContract), 0);
        assertEq(feeManager.delegateServiceFee(someContract),     0);

        vm.prank(someContract);
        feeManager.updateDelegateFeeTerms(50_000e18, 1000e18);

        assertEq(feeManager.delegateOriginationFee(someContract), 50_000e18);
        assertEq(feeManager.delegateServiceFee(someContract),     1000e18);
    }

}

contract FeeManager_Getters is FeeManagerBase {

    function setUp() public override {
        super.setUp();
    }

    function test_getDelegateServiceFeesForPeriod() external {
        defaultTermDetails = [uint256(10 days), uint256(10 days), uint256(3)];
        address loan1      = _createLoan(BORROWER, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees, "salt1");


        vm.prank(loan1);
        feeManager.updateDelegateFeeTerms(50_000e18, 1000e18);

        // The loan interval is 10 days. So this tests should return the proportional amount
        assertEq(feeManager.getDelegateServiceFeesForPeriod(loan1, 0 days),  0);
        assertEq(feeManager.getDelegateServiceFeesForPeriod(loan1, 1 days),  100e18);   // 10% of the full fee
        assertEq(feeManager.getDelegateServiceFeesForPeriod(loan1, 5 days),  500e18);   // 50% of the full fee
        assertEq(feeManager.getDelegateServiceFeesForPeriod(loan1, 10 days), 1000e18);  // 100% of the full fee
        assertEq(feeManager.getDelegateServiceFeesForPeriod(loan1, 11 days), 1100e18);  // 110% of the full fee
        assertEq(feeManager.getDelegateServiceFeesForPeriod(loan1, 15 days), 1500e18);  // 150% of the full fee
        assertEq(feeManager.getDelegateServiceFeesForPeriod(loan1, 20 days), 2000e18);  // 200% of the full fee
    }

    function test_getPlatformServiceFeeForPeriod() external {
        defaultTermDetails = [uint256(10 days), uint256(365 days), uint256(3)];
        address loan1      = _createLoan(BORROWER, address(feeManager), defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, defaultFees, "salt1");

        _fundLoan(loan1, address(loanManager), 1_000_000e18);

        globals.setPlatformServiceFeeRate(address(poolManager), 1_0000);

        vm.prank(loan1);
        feeManager.updatePlatformServiceFee(1_000_000e18, 365 days);

        // The loan interval is 10 days. So this tests should return the proportional amount
        assertEq(feeManager.getPlatformServiceFeeForPeriod(loan1, 1_000_000e18, 0 days),  0);
        assertEq(feeManager.getPlatformServiceFeeForPeriod(loan1, 1_000_000e18, 365 days / 10), 1_000e18);   // 10% of the full fee (1_000_000 * 0.001 / 10)
        assertEq(feeManager.getPlatformServiceFeeForPeriod(loan1, 1_000_000e18, 365 days / 2 ), 5_000e18);   // 50% of the full fee
        assertEq(feeManager.getPlatformServiceFeeForPeriod(loan1, 1_000_000e18, 365 days),      10_000e18);  // 100% of the full fee
        assertEq(feeManager.getPlatformServiceFeeForPeriod(loan1, 1_000_000e18, 365 days * 2),  20_000e18);  // 200% of the full fee
        assertEq(feeManager.getPlatformServiceFeeForPeriod(loan1, 1_000_000e18, 365 days * 3),  30_000e18);  // 300% of the full fee
    }

}
