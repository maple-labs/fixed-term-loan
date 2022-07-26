// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { IERC20 }      from "../modules/erc20/contracts/interfaces/IERC20.sol";
import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import {
    IGlobalsLike,
    ILoanLike,
    ILoanManagerLike,
    IPoolManagerLike
} from "./interfaces/Interfaces.sol";

import { IMapleLoanFeeManager } from "./interfaces/IMapleLoanFeeManager.sol";

contract MapleLoanFeeManager is IMapleLoanFeeManager {

    uint256 internal constant HUNDRED_PERCENT = 1e18;

    address public override globals;

    mapping(address => RateInfo) public          rateInfo;  // TODO: Override
    mapping(address => uint256)  public override adminOriginationFee;

    // NOTE: Can pack struct type(uint120).max > 1e24, which is greater than the max percentages used (1e18 for 100%).
    struct RateInfo {
        uint120 adminFeeRate;     // Admin fee annualized percentage rate.
        uint120 platformFeeRate;  // Platform fee annualized percentage rate.
    }

    constructor(address globals_) {
        globals = globals_;
    }

    /**************************/
    /*** Mutating Functions ***/
    /**************************/

    function payOriginationFees(address asset_, uint256 principalRequested_, uint256 loanTerm_) external override returns (uint256 feePaid_) {
        uint256 adminOriginationFee_ = adminOriginationFee[msg.sender];

        uint256 treasuryOriginationFee_ = _getFeeForInterval({
            principal_:     principalRequested_,
            annualFeeRate_: IGlobalsLike(globals).platformOriginationFeeRate(_getPoolManager(msg.sender)),
            interval_:      loanTerm_
        });

        // Send origination fee to treasury, with remainder to poolDelegate.
        _transferTo(asset_, _getTreasury(),               treasuryOriginationFee_, "MLFM:POF:TREASURY_TRANSFER");
        _transferTo(asset_, _getPoolDelegate(msg.sender), adminOriginationFee_,    "MLFM:POF:PD_TRANSFER");

        feePaid_ = adminOriginationFee_ + treasuryOriginationFee_;
    }

    /// @dev Called during `makePayment`
    function payServiceFees(address asset_, uint256 principalRequested_, uint256 interval_) external override returns (uint256 feePaid_) {
        ( uint256 adminFee_, uint256 platformFee_ ) = getPaymentServiceFees(msg.sender, principalRequested_, interval_);

        feePaid_ = adminFee_ + platformFee_;

        _payServiceFees(asset_, adminFee_, platformFee_);
    }

    function updatePlatformFeeRate() external override {
        rateInfo[msg.sender].platformFeeRate = uint120(IGlobalsLike(globals).platformFeeRate(_getPoolManager(msg.sender)));
    }

    /// @dev Used by loan (`msg.sender`) to configure fee structure
    // TODO: ACL and events
    function updateFeeTerms(uint256 adminOriginationFee_, uint256 adminFeeRate_) external override {
        require(adminFeeRate_ <= HUNDRED_PERCENT, "MLFM:UF:ABOVE_MAX_FEE");

        adminOriginationFee[msg.sender] = adminOriginationFee_;

        rateInfo[msg.sender].adminFeeRate = uint120(adminFeeRate_);
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    // Pass loan params
    function getPaymentServiceFees(
        address loan_,
        uint256 principalRequested_,
        uint256 interval_
    )
        public view override returns (uint256 adminFee_, uint256 platformFee_)
    {
        RateInfo memory rateInfo_ = rateInfo[loan_];

        adminFee_    = _getFeeForInterval(principalRequested_, uint256(rateInfo_.adminFeeRate),    interval_);
        platformFee_ = _getFeeForInterval(principalRequested_, uint256(rateInfo_.platformFeeRate), interval_);
    }

    /*******************************/
    /*** Internal View Functions ***/
    /*******************************/

    function _getAsset(address loan_) internal view returns (address asset_) {
        return ILoanLike(loan_).fundsAsset();
    }

    function _getFeeForInterval(uint256 principal_, uint256 annualFeeRate_, uint256 interval_) internal pure returns (uint256 fee_) {
        // Convert annual fee rate to annualized fee based on principal and interval.
        fee_ = principal_ * annualFeeRate_ * interval_ / 365 days / HUNDRED_PERCENT;
    }

    function _getPoolManager(address loan_) internal view returns (address pool_) {
        return ILoanManagerLike(ILoanLike(loan_).lender()).poolManager();
    }

    function _getPoolDelegate(address loan_) internal view returns (address poolDelegate_) {
        return IPoolManagerLike(_getPoolManager(loan_)).admin();
    }

    function _getTreasury() internal view returns (address mapleTreasury_) {
        return IGlobalsLike(globals).mapleTreasury();
    }

    /*********************************/
    /*** Internal Helper Functions ***/
    /*********************************/

    // NOTE: `msg.sender` is the loan.
    function _payServiceFees(address asset_, uint256 adminFee_, uint256 platformFee_) internal {
        uint256 treasuryAdminFee_ = adminFee_ * IGlobalsLike(globals).adminFeeSplit(_getPoolManager(msg.sender)) / HUNDRED_PERCENT;

        // Send platform fee and admin fee split to treasury, remainder of admin fee to pool delegate.
        _transferTo(asset_, _getTreasury(),               platformFee_ + treasuryAdminFee_, "MLFM:PSF:TREASURY_TRANSFER");
        _transferTo(asset_, _getPoolDelegate(msg.sender), adminFee_    - treasuryAdminFee_, "MLFM:PSF:PD_TRANSFER");
    }

    // TODO: Investigate removing this function if gas is significantly reduced.
    function _transferTo(address asset_, address destination_, uint256 amount_, string memory errorMessage_) internal {
        require(ERC20Helper.transferFrom(asset_, msg.sender, destination_, amount_), errorMessage_);
    }

}
