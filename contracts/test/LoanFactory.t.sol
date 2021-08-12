// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { SafeMath } from "../../modules/openzeppelin-contracts/contracts/math/SafeMath.sol";
import { DSTest }   from "../../modules/ds-test/src/test.sol";

import { Borrower } from "./accounts/Borrower.sol";
import { Governor } from "./accounts/Governor.sol";

import { ILoan } from "../interfaces/ILoan.sol";

import { LoanFactory } from "../LoanFactory.sol";


contract CollateralLockerFactoryMock {
    
    function newLocker(address asset) external pure returns(address) {
        return address(10);
    }

}

contract FundingLockerFactoryMock {
    
    function newLocker(address asset) external pure returns(address) {
        return address(10);
    }

}

contract GlobalsMock {

    uint256 public constant fundingPeriod      = 10 days;
    uint256 public constant defaultGracePeriod = 10 days;

    bool public protocolPaused;

    address public governor;

    mapping(address => bool) public validCalcs;
    mapping(address => bool) public isValidCollateralAsset;
    mapping(address => bool) public isValidLiquidityAsset;

    mapping(address => mapping(address => bool)) public validSubFactories;

    constructor(address _governor) public {
        governor = _governor;
    }

    function setCalc(address calc, bool valid) external {
        validCalcs[calc] = valid;
    }

    function setCollateralAsset(address asset, bool valid) external {
        isValidCollateralAsset[asset] = valid;
    }

    function setLiquidityAsset(address asset, bool valid) external {
        isValidLiquidityAsset[asset] = valid;
    }

    function setProtocolPause(bool pause) external {
        protocolPaused = pause;
    }

    function setValidSubFactory(address superFactory, address subFactory, bool valid) external {
        validSubFactories[superFactory][subFactory] = valid;
    }

    function isValidSubFactory(address superFactory, address subFactory, uint8 factoryType) external view returns (bool) {
        return validSubFactories[superFactory][subFactory];  // Don't check factoryType in mock
    }

    function isValidCalc(address calc, uint8 calcType) external view returns (bool) {
        return validCalcs[calc];  // Don't check calcType in mock
    }
}

contract LoanFactorySettersTest is DSTest {

    using SafeMath for uint256;

    function test_setGlobals() public {
        Governor    realGov     = new Governor();
        Governor    fakeGov     = new Governor();
        GlobalsMock globals     = new GlobalsMock(address(realGov));
        LoanFactory loanFactory = new LoanFactory(address(globals));

        assertEq(loanFactory.globals(), address(globals));

        assertTrue(!fakeGov.try_loanFactory_setGlobals(address(loanFactory), address(1)));
        assertTrue( realGov.try_loanFactory_setGlobals(address(loanFactory), address(1)));

        assertEq(loanFactory.globals(), address(1));
    }

}

contract LoanFactoryCreateTest is DSTest {

    using SafeMath for uint256;

    Borrower    borrower; 
    GlobalsMock globals;   
    LoanFactory loanFactory;

    address clFactoryMock;
    address flFactoryMock;
    address governorMock;
    address collateralAssetMock; 
    address liquidityAssetMock; 
    address repaymentCalcMock; 
    address premiumCalcMock; 
    address lateFeeCalcMock; 

    address[3] calcs;

    function setUp() public {
        governorMock = address(1);

        collateralAssetMock = address(2);
        liquidityAssetMock  = address(3);

        repaymentCalcMock = address(4);
        premiumCalcMock   = address(5);
        lateFeeCalcMock   = address(6);

        collateralAssetMock = address(7);
        liquidityAssetMock  = address(8);

        clFactoryMock = address(new CollateralLockerFactoryMock());
        flFactoryMock = address(new FundingLockerFactoryMock());

        borrower    = new Borrower();
        globals     = new GlobalsMock(governorMock);
        loanFactory = new LoanFactory(address(globals));

        globals.setValidSubFactory(address(loanFactory), clFactoryMock, true);
        globals.setValidSubFactory(address(loanFactory), flFactoryMock, true);
        
        globals.setCalc(repaymentCalcMock, true);
        globals.setCalc(premiumCalcMock,   true);
        globals.setCalc(lateFeeCalcMock,   true);

        globals.setCollateralAsset(collateralAssetMock, true);
        globals.setLiquidityAsset(liquidityAssetMock,  true);

        calcs = [repaymentCalcMock, premiumCalcMock, lateFeeCalcMock];
    }

    function isAbleToCreateLoan(uint256[5] memory specs) internal returns (bool) {
        return borrower.try_loanFactory_createLoan(address(loanFactory), liquidityAssetMock, collateralAssetMock, flFactoryMock, clFactoryMock, specs, calcs);
    }

    // TODO: setLoanFactoryAdmin
    // TODO: pause/global pause

    // function test_createLoan_pauses() public {
    //     uint256[5] memory specs = [10, 10, 2, uint256(10_000_000), 30];

    //     globals.setProtocolPause(true);

    //     assertTrue(!isAbleToCreateLoan(specs));

    //     globals.setProtocolPause(false);
    //     loanFactory.pause();
    // }

    function test_createLoanWithInvalidSubFactories() public {
        uint256[5] memory specs = [10, 10, 2, uint256(10_000_000), 30];

        globals.setValidSubFactory(address(loanFactory), clFactoryMock, false);

        assertTrue(!globals.isValidSubFactory(address(loanFactory), clFactoryMock, 0));
        assertTrue( globals.isValidSubFactory(address(loanFactory), flFactoryMock, 2));

        assertTrue(!isAbleToCreateLoan(specs));

        globals.setValidSubFactory(address(loanFactory), clFactoryMock, true);
        globals.setValidSubFactory(address(loanFactory), flFactoryMock, false);

        assertTrue( globals.isValidSubFactory(address(loanFactory), clFactoryMock, 0));
        assertTrue(!globals.isValidSubFactory(address(loanFactory), flFactoryMock, 2));

        assertTrue(!isAbleToCreateLoan(specs));

        globals.setValidSubFactory(address(loanFactory), flFactoryMock, true);

        assertTrue(globals.isValidSubFactory(address(loanFactory), clFactoryMock, 0));
        assertTrue(globals.isValidSubFactory(address(loanFactory), flFactoryMock, 2));

        assertTrue(isAbleToCreateLoan(specs));
    }

    function test_createLoanWithInvalidCalcs() public {
        uint256[5] memory specs = [10, 10, 2, uint256(10_000_000), 30];

        globals.setCalc(repaymentCalcMock, false);

        assertTrue(!globals.isValidCalc(repaymentCalcMock, 10));
        assertTrue( globals.isValidCalc(premiumCalcMock,   11));
        assertTrue( globals.isValidCalc(lateFeeCalcMock,   12));

        assertTrue(!isAbleToCreateLoan(specs));

        globals.setCalc(repaymentCalcMock, true);
        globals.setCalc(premiumCalcMock,   false);

        assertTrue( globals.isValidCalc(repaymentCalcMock, 10));
        assertTrue(!globals.isValidCalc(premiumCalcMock,   11));
        assertTrue( globals.isValidCalc(lateFeeCalcMock,   12));

        assertTrue(!isAbleToCreateLoan(specs));

        globals.setCalc(premiumCalcMock, true);
        globals.setCalc(lateFeeCalcMock, false);

        assertTrue( globals.isValidCalc(repaymentCalcMock, 10));
        assertTrue( globals.isValidCalc(premiumCalcMock,   11));
        assertTrue(!globals.isValidCalc(lateFeeCalcMock,   12));

        assertTrue(!isAbleToCreateLoan(specs));

        globals.setCalc(lateFeeCalcMock, true);

        assertTrue(globals.isValidCalc(repaymentCalcMock, 10));
        assertTrue(globals.isValidCalc(premiumCalcMock,   11));
        assertTrue(globals.isValidCalc(lateFeeCalcMock,   12));

        assertTrue(isAbleToCreateLoan(specs));
    }

    function test_createLoanWithInvalidAssets() public {
        uint256[5] memory specs = [10, 10, 2, uint256(10_000_000), 30];

        globals.setCollateralAsset(collateralAssetMock, false);

        assertTrue(!globals.isValidCollateralAsset(collateralAssetMock));
        assertTrue( globals.isValidLiquidityAsset(liquidityAssetMock));

        assertTrue(!isAbleToCreateLoan(specs));

        globals.setLiquidityAsset(liquidityAssetMock,   false);
        globals.setCollateralAsset(collateralAssetMock, true);

        assertTrue( globals.isValidCollateralAsset(collateralAssetMock));
        assertTrue(!globals.isValidLiquidityAsset(liquidityAssetMock));

        assertTrue(!isAbleToCreateLoan(specs));

        globals.setLiquidityAsset(liquidityAssetMock, true);

        assertTrue(globals.isValidCollateralAsset(collateralAssetMock));
        assertTrue(globals.isValidLiquidityAsset(liquidityAssetMock));

        assertTrue(isAbleToCreateLoan(specs));
    }

    function test_createLoanWithInvalidSpecs() public {
        // Fails because of error - ERR_PAYMENT_INTERVAL_DAYS_EQUALS_ZERO
        uint256[5] memory specs = [10, 10, 0, uint256(10_000_000), 30];
        assertTrue(!isAbleToCreateLoan(specs));  

        // Fails because of error - ERR_INVALID_TERM_AND_PAYMENT_INTERVAL_DIVISION
        specs = [10, 19, 2, uint256(10_000_000), 30];
        assertTrue(!isAbleToCreateLoan(specs));  

        // Fails because of error - ERR_REQUEST_AMT_EQUALS_ZERO
        specs = [uint256(10), 10, 2, uint256(0), 30];
        assertTrue(!isAbleToCreateLoan(specs)); 

        // Should be successfully created
        specs = [10, 10, 2, uint256(10_000_000), 30];
        assertTrue(isAbleToCreateLoan(specs)); 
    }

    function test_createLoan() public {
        uint256[5] memory specs = [10, 10, 2, uint256(10_000_000), 30];

        assertEq(loanFactory.loansCreated(), 0);

        assertTrue(isAbleToCreateLoan(specs)); 

        assertEq(loanFactory.loansCreated(), 1);

        address loanAddress = loanFactory.loans(0);

        assertTrue(loanAddress != address(0));
        assertTrue(loanFactory.isLoan(loanAddress));  // Confirms that borth `loans` and `isLoan` mappings were added to correctly
    }

}
