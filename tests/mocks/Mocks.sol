// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleLoanFactory } from "../../contracts/interfaces/IMapleLoanFactory.sol";

contract MapleGlobalsMock {

    address public governor;
    address public mapleTreasury;
    address public securityAdmin;

    bool public protocolPaused;

    mapping(bytes32 => mapping(address => bool)) public isFactory;

    mapping(address => uint256) public platformOriginationFeeRate;
    mapping(address => uint256) public platformServiceFeeRate;

    mapping(address => bool) public isBorrower;
    mapping(address => bool) public isCollateralAsset;

    constructor (address governor_, address loanManagerFactory_) {
        governor = governor_;
        isFactory["LOAN_MANAGER"][loanManagerFactory_] = true;
    }

    function setGovernor(address governor_) external {
        governor = governor_;
    }

    function setMapleTreasury(address mapleTreasury_) external {
        mapleTreasury = mapleTreasury_;
    }

    function setSecurityAdmin(address securityAdmin_) external {
        securityAdmin = securityAdmin_;
    }

    function setPlatformServiceFeeRate(address poolManager_, uint256 feeRate_) external {
        platformServiceFeeRate[poolManager_] = feeRate_;
    }

    function setPlatformOriginationFeeRate(address poolManager_, uint256 feeRate_) external {
        platformOriginationFeeRate[poolManager_] = feeRate_;
    }

    function setProtocolPaused(bool paused_) external {
        protocolPaused = paused_;
    }

    function setValidBorrower(address borrower_, bool isValid_) external {
        isBorrower[borrower_] = isValid_;
    }

    function setValidCollateralAsset(address collateralAsset_, bool isValid_) external {
        isCollateralAsset[collateralAsset_] = isValid_;
    }

}

contract MockFactory {

    address public mapleGlobals;

    constructor(address mapleGlobals_) {
        mapleGlobals = mapleGlobals_;
    }

    function setGlobals(address globals_) external {
        mapleGlobals = globals_;
    }

    function upgradeInstance(uint256 , bytes calldata arguments_) external {
        address implementation = abi.decode(arguments_, (address));

        ( bool success, ) = msg.sender.call(abi.encodeWithSignature("setImplementation(address)", implementation));

        require(success);
    }

}

contract MockLoanManagerFactory {

    function isInstance(address) external pure returns (bool) {
        return true;
    }

}

contract MockFeeManager {

    function payOriginationFees(address asset_, uint256 principalRequested_) external returns (uint256 feePaid_) { }

    function payServiceFees(address asset_, uint256 paymentsRemaining_) external returns (uint256 feePaid_) { }

    function updateDelegateFeeTerms(uint256 delegateOriginationFee_, uint256 delegateServiceFee_) external { }

    function updatePlatformServiceFee(uint256 principalRequested_, uint256 paymentInterval_) external {}

    function updateRefinanceServiceFees(uint256 principalRequested_, uint256 timeSinceLastDueDate_) external  {}

    /**********************/
    /*** View Functions ***/
    /**********************/

    function delegateServiceFee(address) public pure returns (uint256 platformServiceFee_) {
        return 0;
    }

    function platformServiceFee(address) public pure returns (uint256 platformServiceFee_) {
        return 0;
    }

    function getServiceFeesForPeriod(address, uint256) external pure returns (uint256 serviceFee_) {
        return 0;
    }

    function getServiceFees(address, uint256) external pure returns (uint256 serviceFees_) {
        return 0;
    }

    function getServiceFeeBreakdown(address, uint256) external pure
        returns (
            uint256 delegateServiceFee_,
            uint256 delegateRefinanceFee_,
            uint256 platformServiceFee_,
            uint256 platformRefinanceFee_
        )
    {
        // TODO: Make settable values
        delegateServiceFee_   = 0;
        platformServiceFee_   = 0;
        delegateRefinanceFee_ = 0;
        platformRefinanceFee_ = 0;
    }

}

contract MockLoanManager {

    address public factory;
    address public poolManager;

    constructor() {
        factory     = address(new MockLoanManagerFactory());
        poolManager = address(new MockPoolManager(address(1)));
    }

    function __setPoolManager(address poolManager_) external {
        poolManager = poolManager_;
    }

    function claim(uint256 principal_, uint256 interest_, uint256 previousPaymentDueDate_, uint256 nextPaymentDueDate_) external { }

}

contract MockPoolManager {

    address public poolDelegate;

    constructor(address poolDelegate_) {
        poolDelegate = poolDelegate_;
    }

}

contract EmptyContract {

    fallback() external { }

}

contract RevertingERC20 {

    mapping(address => uint256) public balanceOf;

    function mint(address to_, uint256 value_) external {
        balanceOf[to_] += value_;
    }

    function approve(address, uint256) external returns (bool) {
        revert();
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert();
    }

}
