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

    mapping(address => uint256) public override delegateOriginationFee;
    mapping(address => uint256) public override delegateServiceFee;
    mapping(address => uint256) public override platformServiceFee;

    constructor(address globals_) {
        globals = globals_;
    }

    /*************************/
    /*** Payment Functions ***/
    /*************************/

    function payOriginationFees(address asset_, uint256 principalRequested_) external override returns (uint256 feePaid_) {
        uint256 delegateOriginationFee_ = delegateOriginationFee[msg.sender];
        uint256 platformOriginationFee_ = _getPlatformOriginationFee(msg.sender, principalRequested_);

        // Send origination fee to treasury, with remainder to poolDelegate.
        _transferTo(asset_, _getPoolDelegate(msg.sender), delegateOriginationFee_, "MLFM:POF:PD_TRANSFER");
        _transferTo(asset_, _getTreasury(),               platformOriginationFee_, "MLFM:POF:TREASURY_TRANSFER");

        feePaid_ = delegateOriginationFee_ + platformOriginationFee_;
    }

    function payServiceFees(address asset_, uint256 numberOfPayments_) external override returns (uint256 feePaid_) {
        uint256 delegateServiceFee_ = delegateServiceFee[msg.sender] * numberOfPayments_;
        uint256 platformServiceFee_ = platformServiceFee[msg.sender] * numberOfPayments_;

        feePaid_ = delegateServiceFee_ + platformServiceFee_;

        _transferTo(asset_, _getPoolDelegate(msg.sender), delegateServiceFee_, "MLFM:PSF:PD_TRANSFER");
        _transferTo(asset_, _getTreasury(),               platformServiceFee_, "MLFM:PSF:TREASURY_TRANSFER");

        emit ServiceFeesPaid(msg.sender, delegateServiceFee_, platformServiceFee_);
    }

    /****************************/
    /*** Fee Update Functions ***/
    /****************************/

    function updateDelegateFeeTerms(uint256 delegateOriginationFee_, uint256 delegateServiceFee_) external override {
        delegateOriginationFee[msg.sender] = delegateOriginationFee_;
        delegateServiceFee[msg.sender]     = delegateServiceFee_;

        emit FeeTermsUpdated(msg.sender, delegateOriginationFee_, delegateServiceFee_);
    }

    function updatePlatformServiceFee(uint256 principalRequested_, uint256 paymentInterval_) external override {
        uint256 platformServiceFeeRate_ = IGlobalsLike(globals).platformServiceFeeRate(_getPoolManager(msg.sender));
        uint256 platformServiceFee_     = principalRequested_ * platformServiceFeeRate_ * paymentInterval_ / 365 days / HUNDRED_PERCENT;

        platformServiceFee[msg.sender] = platformServiceFee_;

        emit PlatformServiceFeeUpdated(msg.sender, platformServiceFee_);
    }

    /*******************************/
    /*** Internal View Functions ***/
    /*******************************/

    function _getAsset(address loan_) internal view returns (address asset_) {
        return ILoanLike(loan_).fundsAsset();
    }

    function _getPlatformOriginationFee(address loan_, uint256 principalRequested_) internal view returns (uint256 platformOriginationFee_) {
        uint256 platformOriginationFeeRate_ = IGlobalsLike(globals).platformOriginationFeeRate(_getPoolManager(loan_));
        uint256 loanTermLength_             = ILoanLike(loan_).paymentInterval() * ILoanLike(loan_).paymentsRemaining();

        platformOriginationFee_ = platformOriginationFeeRate_ * principalRequested_ * loanTermLength_ / 365 days / HUNDRED_PERCENT;
    }

    function _getPoolManager(address loan_) internal view returns (address pool_) {
        return ILoanManagerLike(ILoanLike(loan_).lender()).poolManager();
    }

    function _getPoolDelegate(address loan_) internal view returns (address poolDelegate_) {
        return IPoolManagerLike(_getPoolManager(loan_)).poolDelegate();
    }

    function _getTreasury() internal view returns (address mapleTreasury_) {
        return IGlobalsLike(globals).mapleTreasury();
    }

    /*********************************/
    /*** Internal Helper Functions ***/
    /*********************************/

    // TODO: Investigate removing this function if gas is significantly reduced.
    function _transferTo(address asset_, address destination_, uint256 amount_, string memory errorMessage_) internal {
        require(ERC20Helper.transferFrom(asset_, msg.sender, destination_, amount_), errorMessage_);
    }

}
