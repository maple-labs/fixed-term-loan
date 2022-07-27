// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }                   from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { IMapleProxyFactory }          from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { MapleGlobalsMock, MockLoanManager, MockPoolManager, MockLoan } from "./mocks/Mocks.sol";

import { MapleLoan }            from "../MapleLoan.sol";
import { MapleLoanFactory }     from "../MapleLoanFactory.sol";
import { MapleLoanInitializer } from "../MapleLoanInitializer.sol";
import { MapleLoanFeeManager }  from "../MapleLoanFeeManager.sol";

contract FeeManagerBase is TestUtils {

    address BORROWER = address(new Address());
    address PD       = address(new Address());
    address TREASURY = address(new Address());

    address implementation;
    address initializer;

    MapleGlobalsMock      globals;
    MapleLoanFactory      factory;
    MapleLoanFeeManager   feeManager;
    MockERC20             collateralAsset;
    MockERC20             fundsAsset;
    MockLoanManager       loanManager;
    MockPoolManager       poolManager;

    address[2] internal defaultAssets;
    uint256[3] internal defaultTermDetails;
    uint256[3] internal defaultAmounts;
    uint256[5] internal defaultRates;

    function setUp() public virtual {
        implementation = address(new MapleLoan());
        initializer    = address(new MapleLoanInitializer());

        globals         = new MapleGlobalsMock(address(this));
        factory         = new MapleLoanFactory(address(globals));
        feeManager      = new MapleLoanFeeManager(address(globals));
        collateralAsset = new MockERC20("MockCollateral", "MC", 18);
        fundsAsset      = new MockERC20("MockAsset", "MA", 18);
        poolManager     = new MockPoolManager(PD);
        loanManager     = new MockLoanManager(PD, address(poolManager));

        factory.registerImplementation(1, implementation, initializer);
        factory.setDefaultVersion(1);

        globals.setMapleTreasury(TREASURY);
        globals.setValidBorrower(BORROWER, true);

        defaultAssets      = [address(collateralAsset), address(fundsAsset)];
        defaultTermDetails = [uint256(10 days), uint256(365 days / 12), uint256(3)];
        defaultAmounts     = [uint256(0), uint256(1_000_000e18), uint256(1_000_000e18)];
        defaultRates       = [uint256(0.12e18), uint256(0.02e18), uint256(0), uint256(0.02e18), uint256(0.006e18)];
    }

    function _createLoan(
        address globals_,
        address borrower_,
        address feeManager_,
        uint256 originationFee_,
        address[2] memory assets_,
        uint256[3] memory termDetails_,
        uint256[3] memory amounts_,
        uint256[5] memory rates_,
        bytes32 salt_
    )
        internal returns (address loan_)
    {
        loan_ = factory.createInstance({
            arguments_: MapleLoanInitializer(initializer).encodeArguments(globals_, borrower_, feeManager_, originationFee_, assets_, termDetails_, amounts_, rates_),
            salt_:      keccak256(abi.encodePacked(salt_))
        });
    }

    function _fundLoan(address loan_, address lender_, uint256 amount_) internal {
        fundsAsset.mint(address(loan_), amount_);

        vm.prank(lender_);
        MapleLoan(loan_).fundLoan(lender_);
    }

    function _drawdownLoan(address loan_, address borrower_) internal {
        vm.startPrank(MapleLoan(loan_).borrower());
        MapleLoan(loan_).drawdownFunds(MapleLoan(loan_).drawableFunds(), borrower_);
        vm.stopPrank();
    }

}

contract PayClosingFeesTests is FeeManagerBase {

    MapleLoan loan;

    function setUp() public override {
        super.setUp();

        loan = MapleLoan(_createLoan(address(globals), BORROWER, address(feeManager), 0, defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, "salt"));

        globals.setPlatformFeeRate(address(poolManager), 0.003e18);  // 0.3%
        globals.setAdminFeeSplit(address(poolManager),   0.100e18);  // 10%

        _fundLoan(address(loan), address(loanManager), loan.principalRequested());
        _drawdownLoan(address(loan), BORROWER);
    }

    function test_payClosingServiceFees_insufficientFunds_treasury() external {
        uint256 adminFee    = 1500e18;  // 1m * 0.6% / 12 * 3 = 1500
        uint256 platformFee = 750e18;   // 1m * 0.3% / 12 * 3 = 750

        uint256 treasuryFee = (adminFee / 10) + platformFee;  // 10% of pool delegate fee goes to treasury

        fundsAsset.mint(address(this),    treasuryFee - 1);
        fundsAsset.approve(address(loan), treasuryFee - 1);

        vm.expectRevert("MLFM:PSF:TREASURY_TRANSFER");
        loan.closeLoan(treasuryFee - 1);
    }

    function test_payClosingServiceFees_insufficientFunds_poolDelegate() external {
        uint256 adminFee    = 1500e18;  // 1m * 0.6% / 12 * 3 = 1500
        uint256 platformFee = 750e18;   // 1m * 0.3% / 12 * 3 = 750

        fundsAsset.mint(address(this),    platformFee + adminFee - 1);
        fundsAsset.approve(address(loan), platformFee + adminFee - 1);

        vm.expectRevert("MLFM:PSF:PD_TRANSFER");
        loan.closeLoan(platformFee + adminFee - 1);
    }

    function test_payClosingServiceFees() external {
        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getClosingPaymentBreakdown();

        assertEq(principal, 1_000_000e18);
        assertEq(interest,  20_000e18);
        assertEq(fees,      2_250e18);  // 1m * (0.3% + 0.6%) / 12 * 3 = 1000 + 750

        fundsAsset.mint(address(this),    1_022_250e18);  // 1m + 20k + 2.25k = 1_022_250
        fundsAsset.approve(address(loan), 1_022_250e18);  // 1m + 20k + 2.25k = 1_022_250

        assertEq(fundsAsset.balanceOf(address(this)), 1_022_250e18);  // 1m + 20k + 2.25k = 1_022_250
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(fundsAsset.balanceOf(PD),            0);
        assertEq(fundsAsset.balanceOf(TREASURY),      0);

        loan.closeLoan(1_022_250e18);

        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), 1_020_000e18);  // Principal + interest
        assertEq(fundsAsset.balanceOf(PD),            1_350e18);      // 90% admin fee
        assertEq(fundsAsset.balanceOf(TREASURY),      900e18);        // Platform fee + 10% admin fee
    }

}

contract PayOriginationFeesTests is FeeManagerBase {

    MapleLoan loan;

    function setUp() public override {
        super.setUp();

        loan = MapleLoan(_createLoan(address(globals), BORROWER, address(feeManager), 50_000e18, defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, "salt"));

        globals.setPlatformOriginationFeeRate(address(poolManager), 0.003e18);  // 0.3%
    }

    function test_payOriginationFees_insufficientFunds_treasury() external {
        fundsAsset.mint(address(loan), 750e18 - 1);  // 1m * 0.3% / 12 * 3 = 750

        vm.prank(address(loanManager));
        vm.expectRevert("MLFM:POF:TREASURY_TRANSFER");
        loan.fundLoan(address(loanManager));
    }

    function test_payOriginationFees_insufficientFunds_poolDelegate() external {
        fundsAsset.mint(address(loan), 50_750e18 - 1);  // 50k + (1m * 0.3% / 12 * 3) = 50_750

        vm.prank(address(loanManager));
        vm.expectRevert("MLFM:POF:PD_TRANSFER");
        loan.fundLoan(address(loanManager));
    }

    function test_payOriginationFees() external {
        fundsAsset.mint(address(loan), 1_000_000e18);  // 1m + 50k + (1m * 0.3% / 12 * 3) = 1_050_750

        assertEq(fundsAsset.balanceOf(address(loan)), 1_000_000e18);
        assertEq(fundsAsset.balanceOf(PD),            0);
        assertEq(fundsAsset.balanceOf(TREASURY),      0);

        vm.prank(address(loanManager));
        loan.fundLoan(address(loanManager));

        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), 949_250e18);  // Principal - origination fees
        assertEq(fundsAsset.balanceOf(PD),            50_000e18);   // 50k origination fee to PD
        assertEq(fundsAsset.balanceOf(TREASURY),      750e18);      // (1m * 0.3% / 12 * 3) = 750 to treasury
    }

}

contract PayServiceFeesTests is FeeManagerBase {

    MapleLoan loan;

    function setUp() public override {
        super.setUp();

        loan = MapleLoan(_createLoan(address(globals), BORROWER, address(feeManager), 0, defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, "salt"));

        globals.setPlatformFeeRate(address(poolManager), 0.003e18);  // 0.3%
        globals.setAdminFeeSplit(address(poolManager),   0.100e18);  // 10%

        _fundLoan(address(loan), address(loanManager), loan.principalRequested());
        _drawdownLoan(address(loan), BORROWER);
    }

    function test_payServiceFees_insufficientFunds_treasury() external {
        uint256 platformFee = 250e18;  // 1m * 0.3% / 12 = 250
        uint256 adminFee    = 500e18;  // 1m * 0.6% / 12 = 500

        uint256 treasuryFee = platformFee + adminFee / 10;  // 10% of pool delegate fee goes to treasury

        fundsAsset.mint(address(this),    treasuryFee - 1);
        fundsAsset.approve(address(loan), treasuryFee - 1);

        vm.expectRevert("MLFM:PSF:TREASURY_TRANSFER");
        loan.makePayment(treasuryFee - 1);
    }

    function test_payServiceFees_insufficientFunds_poolDelegate() external {
        uint256 platformFee = 250e18;  // 1m * 0.3% / 12 = 250
        uint256 adminFee    = 500e18;  // 1m * 0.6% / 12 = 500

        fundsAsset.mint(address(this),    platformFee + adminFee - 1);
        fundsAsset.approve(address(loan), platformFee + adminFee - 1);

        vm.expectRevert("MLFM:PSF:PD_TRANSFER");
        loan.makePayment(platformFee + adminFee - 1);
    }

    function test_payServiceFees() external {
        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getNextPaymentBreakdown();

        assertEq(principal, 0);
        assertEq(interest,  10_000e18);
        assertEq(fees,      750e18);  // 1m * (0.3% + 0.6%) / 12 = 250 + 500

        fundsAsset.mint(address(this),    10_750e18);
        fundsAsset.approve(address(loan), 10_750e18);

        assertEq(fundsAsset.balanceOf(address(this)), 10_750e18);
        assertEq(fundsAsset.balanceOf(address(loan)), 0);
        assertEq(fundsAsset.balanceOf(PD),            0);
        assertEq(fundsAsset.balanceOf(TREASURY),      0);

        loan.makePayment(10_750e18);

        assertEq(fundsAsset.balanceOf(address(this)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)), 10_000e18);  // Interest
        assertEq(fundsAsset.balanceOf(PD),            450e18);     // 90% admin fee
        assertEq(fundsAsset.balanceOf(TREASURY),      300e18);     // Platform fee + 10% admin fee
    }

}

contract UpdatePlatformFeeRateTests is FeeManagerBase {

    function test_updatePlaformFeeRate() external {
        address loan1 = _createLoan(address(globals), BORROWER, address(feeManager), 0, defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, "salt1");
        address loan2 = _createLoan(address(globals), BORROWER, address(feeManager), 0, defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, "salt2");

        _fundLoan(loan1, address(loanManager), 1_000_000e18);
        _fundLoan(loan2, address(loanManager), 1_000_000e18);

        ( , uint256 platformFeeRate1 ) = feeManager.rateInfo(loan1);
        ( , uint256 platformFeeRate2 ) = feeManager.rateInfo(loan2);

        assertEq(platformFeeRate1, 0);
        assertEq(platformFeeRate2, 0);

        globals.setPlatformFeeRate(address(poolManager), 0.003e18);  // 0.3%

        vm.prank(loan1);
        feeManager.updatePlatformFeeRate();

        ( , platformFeeRate1 ) = feeManager.rateInfo(loan1);
        ( , platformFeeRate2 ) = feeManager.rateInfo(loan2);

        assertEq(platformFeeRate1, 0.003e18);  // Updated from globals
        assertEq(platformFeeRate2, 0);         // Unchanged from globals

        globals.setPlatformFeeRate(address(poolManager), 0.006e18);  // 0.6%

        vm.prank(loan2);
        feeManager.updatePlatformFeeRate();

        ( , platformFeeRate1 ) = feeManager.rateInfo(loan1);
        ( , platformFeeRate2 ) = feeManager.rateInfo(loan2);

        assertEq(platformFeeRate1, 0.003e18);  // Unchanged from globals
        assertEq(platformFeeRate2, 0.006e18);  // Updated from globals
    }

}

contract UpdateFeeTerms_SetterTests is FeeManagerBase {

    function test_updateFeeTerms_gtHundredPercent() external {
        vm.expectRevert("MLFM:UF:ABOVE_MAX_FEE");
        feeManager.updateFeeTerms(50_000e18, 1e18 + 1);
    }

    function test_updateFeeTerms() external {

        ( uint256 adminFeeRate, ) = feeManager.rateInfo(address(this));

        assertEq(feeManager.adminOriginationFee(address(this)), 0);
        assertEq(adminFeeRate,                                  0);

        feeManager.updateFeeTerms(50_000e18, 1e18);

        ( adminFeeRate, ) = feeManager.rateInfo(address(this));

        assertEq(feeManager.adminOriginationFee(address(this)), 50_000e18);
        assertEq(adminFeeRate,                                  1e18);
    }

}

/*****************************/
/*** Getter Function Tests ***/
/*****************************/

contract GetPaymentServiceFeesTests is FeeManagerBase {

    function test_getPaymentServiceFees() external {
        MapleLoan loan = MapleLoan(_createLoan(address(globals), BORROWER, address(feeManager), 0, defaultAssets, defaultTermDetails, defaultAmounts, defaultRates, "salt"));

        globals.setPlatformFeeRate(address(poolManager), 0.003e18);  // 0.3%

        _fundLoan(address(loan), address(loanManager), 1_000_000e18);
        _drawdownLoan(address(loan), BORROWER);

        ( uint256 adminFee_, uint256 platformFee_ ) = feeManager.getPaymentServiceFees(address(loan), 1_000_000e18, 365 days / 12);

        assertEq(adminFee_,    500e18);  // 1m * 0.6% / 12 = 500
        assertEq(platformFee_, 250e18);  // 1m * 0.3% / 12 = 250
    }

}
