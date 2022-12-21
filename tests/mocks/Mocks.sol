// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20 } from "../../modules/erc20/contracts/interfaces/IERC20.sol";

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
    mapping(address => bool) public isPoolAsset;

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

    function setValidPoolAsset(address poolAsset_, bool isValid_) external {
        isPoolAsset[poolAsset_] = isValid_;
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

    uint256 internal _delegateServiceFee;
    uint256 internal _platformServiceFee;
    uint256 internal _delegateRefinanceFee;
    uint256 internal _platformRefinanceFee;
    uint256 internal _serviceFeesToPay;

    function payOriginationFees(address asset_, uint256 principalRequested_) external returns (uint256 feePaid_) { }

    function payServiceFees(address asset_, uint256 paymentsRemaining_) external returns (uint256 feePaid_) {
        if (_serviceFeesToPay == 0) return 0;

        IERC20(asset_).transferFrom(msg.sender, address(this), feePaid_ = _serviceFeesToPay);
    }

    function updateDelegateFeeTerms(uint256 delegateOriginationFee_, uint256 delegateServiceFee_) external { }

    function updatePlatformServiceFee(uint256 principalRequested_, uint256 paymentInterval_) external { }

    function updateRefinanceServiceFees(uint256 principalRequested_, uint256 timeSinceLastDueDate_) external { }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function delegateServiceFee(address) public view returns (uint256 delegateServiceFee_) {
        delegateServiceFee_ = _delegateServiceFee;
    }

    function platformServiceFee(address) public view returns (uint256 platformServiceFee_) {
        platformServiceFee_ = _platformServiceFee;
    }

    function delegateRefinanceFee(address) public view returns (uint256 delegateRefinanceFee_) {
        delegateRefinanceFee_ = _delegateRefinanceFee;
    }

    function platformRefinanceFee(address) public view returns (uint256 platformRefinanceFee_) {
        platformRefinanceFee_ = _platformRefinanceFee;
    }

    function getServiceFeesForPeriod(address, uint256) external pure returns (uint256 serviceFee_) {
        return 0;
    }

    function getServiceFees(address, uint256) external pure returns (uint256 serviceFees_) {
        return 0;
    }

    function getServiceFeeBreakdown(address, uint256) external view
        returns (
            uint256 delegateServiceFee_,
            uint256 delegateRefinanceFee_,
            uint256 platformServiceFee_,
            uint256 platformRefinanceFee_
        )
    {
        delegateServiceFee_   = _delegateServiceFee;
        platformServiceFee_   = _platformServiceFee;
        delegateRefinanceFee_ = _delegateRefinanceFee;
        platformRefinanceFee_ = _platformRefinanceFee;
    }

    function __setDelegateServiceFee(uint256 delegateServiceFee_) external {
        _delegateServiceFee = delegateServiceFee_;
    }

    function __setPlatformServiceFee(uint256 platformServiceFee_) external {
        _platformServiceFee = platformServiceFee_;
    }

    function __setDelegateRefinanceFee(uint256 delegateRefinanceFee_) external {
        _delegateRefinanceFee = delegateRefinanceFee_;
    }

    function __setPlatformRefinanceFee(uint256 platformRefinanceFee_) external {
        _platformRefinanceFee = platformRefinanceFee_;
    }

    function __setServiceFeesToPay(uint256 serviceFeesToPay_) external {
        _serviceFeesToPay = serviceFeesToPay_;
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
