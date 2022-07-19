// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleLoanFactory } from "../../interfaces/IMapleLoanFactory.sol";

contract MapleGlobalsMock {

    address public governor;
    address public mapleTreasury;

    mapping(address => uint256) public adminFeeSplit;
    mapping(address => uint256) public platformOriginationFeeRate;
    mapping(address => uint256) public platformFeeRate;

    mapping(address => bool) public isBorrower;

    constructor (address governor_) {
        governor = governor_;
    }

    function setAdminFeeSplit(address pool_, uint256 fee_) external {
        adminFeeSplit[pool_] = fee_;
    }

    function setGovernor(address governor_) external {
        governor = governor_;
    }

    function setMapleTreasury(address mapleTreasury_) external {
        mapleTreasury = mapleTreasury_;
    }

    function setPlatformFeeRate(address pool_, uint256 feeRate_) external {
        platformFeeRate[pool_] = feeRate_;
    }

    function setPlatformOriginationFeeRate(address pool_, uint256 feeRate_) external {
        platformOriginationFeeRate[pool_] = feeRate_;
    }

    function setValidBorrower(address borrower_, bool isValid_) external {
        isBorrower[borrower_] = isValid_;
    }

}

contract MockFactory {

    address public mapleGlobals;

    function setGlobals(address globals_) external {
        mapleGlobals = globals_;
    }

    function upgradeInstance(uint256 , bytes calldata arguments_) external {
        address implementation = abi.decode(arguments_, (address));

        ( bool success, ) = msg.sender.call(abi.encodeWithSignature("setImplementation(address)", implementation));

        require(success);
    }
}


contract MockFeeManager {

    function payOriginationFees(address asset_, uint256 principalRequested_, uint256 loanTerm_) external returns (uint256 feePaid_) { }

    function payServiceFees(address asset_, uint256 principalRequested_, uint256 interval_) external returns (uint256 feePaid_) { }

    function updateFeeTerms(uint256 platformOriginationFeeRate_, uint256 adminFee_) external { }

    function updatePlatformFeeRate() external {}

    /**********************/
    /*** View Functions ***/
    /**********************/

    function getPaymentServiceFees(
        address loan_,
        uint256 principalRequested_,
        uint256 interval_
    ) public pure returns (uint256 adminFee_, uint256 platformFee_) {
       return (0, 0);
    }

    function platformOriginationFeeRate(address loan_) public pure returns (uint256 platformOriginationFeeRate_) {
        return 0;
    }

}

contract MockLoanManager {

    address public owner;
    address public poolManager;

    constructor(address owner_, address poolManager_) {
        owner       = owner_;
        poolManager = poolManager_;
    }

}

contract MockLoan {

    address public fundsAsset;

    constructor(address fundsAsset_) {
        fundsAsset = fundsAsset_;
    }

}

contract MockPoolManager {

    address public admin;

    constructor(address admin_) {
        admin = admin_;
    }

}

contract SomeAccount {

    function createLoan(address factory_, bytes calldata arguments_, bytes32 salt_) external returns (address loan_) {
        return IMapleLoanFactory(factory_).createInstance(arguments_, salt_);
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

    function transfer(address, uint256) external pure returns (bool) {
        revert();
    }

}
