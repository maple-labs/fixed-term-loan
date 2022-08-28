// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { MapleLoan } from "../../MapleLoan.sol";

import { IMapleLoan }        from "../../interfaces/IMapleLoan.sol";
import { IMapleLoanFactory } from "../../interfaces/IMapleLoanFactory.sol";

import { Lender } from "../accounts/Lender.sol";

import { ERC20 } from "../../../modules/erc20/contracts/test/mocks/MockERC20.sol";

contract MapleGlobalsMock {

    address public governor;
    address public mapleTreasury;
    address public globalAdmin;

    bool public protocolPaused;

    uint256 public investorFee;
    uint256 public treasuryFee;

    constructor (address governor_, address mapleTreasury_, uint256 investorFee_, uint256 treasuryFee_) {
        governor      = governor_;
        mapleTreasury = mapleTreasury_;
        investorFee   = investorFee_;
        treasuryFee   = treasuryFee_;
    }

    function setProtocolPaused(bool paused_) external {
        protocolPaused = paused_;
    }

    function setInvestorFee(uint256 investorFee_) external {
        investorFee = investorFee_;
    }

    function setTreasuryFee(uint256 treasuryFee_) external {
        treasuryFee = treasuryFee_;
    }

    function setGovernor(address governor_) external {
        governor = governor_;
    }

    function setMapleTreasury(address mapleTreasury_) external {
        mapleTreasury = mapleTreasury_;
    }

    function setGlobalsAdmin(address globalsAdmin_) external {
        globalAdmin = globalsAdmin_;
    }

}

contract ConstructableMapleLoan is MapleLoan {

    constructor(address factory_, address borrower_, address[2] memory assets_, uint256[3] memory termDetails_, uint256[3] memory amounts_,  uint256[4] memory rates_) {
        __setFactory(factory_);
        _initialize(borrower_, assets_, termDetails_, amounts_, rates_);
    }

    function getCollateralRequiredFor(
        uint256 principal_,
        uint256 drawableFunds_,
        uint256 principalRequested_,
        uint256 collateralRequired_
    )
        external pure returns (uint256 collateral_)
    {
        return _getCollateralRequiredFor(principal_, drawableFunds_, principalRequested_, collateralRequired_);
    }

    function __setFactory(address factory_) public {
        _setSlotValue(bytes32(0x7a45a402e4cb6e08ebc196f20f66d5d30e67285a2a8aa80503fa409e727a4af1), bytes32(uint256(uint160(factory_))));
    }

}

contract LenderMock is Lender {

    address public poolDelegate = address(8);

    function setPoolDelegate(address poolDelegate_) external {
        poolDelegate = poolDelegate_;
    }

}

contract ManipulatableMapleLoan is MapleLoan {

    function __setBorrower(address borrower_) external {
        _borrower = borrower_;
    }

    function __setClaimableFunds(uint256 claimableFunds_) external {
        _claimableFunds = claimableFunds_;
    }

    function __setCollateral(uint256 collateral_) external {
        _collateral = collateral_;
    }

    function __setCollateralAsset(address collateralAsset_) external {
        _collateralAsset = collateralAsset_;
    }

    function __setCollateralRequired(uint256 collateralRequired_) external {
        _collateralRequired = collateralRequired_;
    }

    function __setDrawableFunds(uint256 drawableFunds_) external {
        _drawableFunds = drawableFunds_;
    }

    function __setFactory(address factory_) external {
        _setSlotValue(bytes32(0x7a45a402e4cb6e08ebc196f20f66d5d30e67285a2a8aa80503fa409e727a4af1), bytes32(uint256(uint160(factory_))));
    }

    function __setFundsAsset(address fundsAsset_) external {
        _fundsAsset = fundsAsset_;
    }

    function __setEndingPrincipal(uint256 endingPrincipal_) external {
        _endingPrincipal = endingPrincipal_;
    }

    function __setLender(address lender_) external {
        _lender = lender_;
    }

    function __setNextPaymentDueDate(uint256 nextPaymentDueDate_) external {
        _nextPaymentDueDate = nextPaymentDueDate_;
    }

    function __setPaymentInterval(uint256 paymentInterval_) external {
        _paymentInterval = paymentInterval_;
    }

    function __setPaymentsRemaining(uint256 paymentsRemaining_) external {
        _paymentsRemaining = paymentsRemaining_;
    }

    function __setPendingBorrower(address pendingBorrower_) external {
        _pendingBorrower = pendingBorrower_;
    }

    function __setPendingLender(address pendingLender_) external {
        _pendingLender = pendingLender_;
    }

    function __setPrincipal(uint256 principal_) external {
        _principal = principal_;
    }

    function __setPrincipalRequested(uint256 principalRequested_) external {
        _principalRequested = principalRequested_;
    }

    function __setRefinanceCommitmentHash(bytes32 refinanceCommitment_) external {
        _refinanceCommitment = refinanceCommitment_;
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
