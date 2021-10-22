// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ERC20Helper }  from "../modules/erc20-helper/src/ERC20Helper.sol";
import { MapleProxied } from "../modules/maple-proxy-factory/contracts/MapleProxied.sol";

import { IMapleLoan } from "./interfaces/IMapleLoan.sol";

contract MapleBorrowerInternals is MapleProxied {

    address internal _owner;
    address internal _pendingOwner;

    /*************************/
    /*** General Functions ***/
    /*************************/

    function _initialize(address owner_) internal {
        _owner = owner_;
    }

    /*************************/
    /*** Ownable Functions ***/
    /*************************/

    modifier onlyOwner() {
        require(msg.sender == _owner, "MBI:NOT_OWNER");
        _;
    }

    /************************/
    /*** Borrow Functions ***/
    /************************/

    function _drawdownFunds(address loan_, uint256 amount_, address destination_) internal {
        _postCollateralForDrawdown(loan_, amount_);
        IMapleLoan(loan_).drawdownFunds(amount_, destination_);
    }

    function _makePayments(address loan_, uint256 numberOfPayments_) internal {
        ( uint256 principal, uint256 interest, uint256 fees ) = IMapleLoan(loan_).getNextPaymentsBreakDown(numberOfPayments_);

        uint256 total         = principal + interest + fees;
        uint256 drawableFunds = IMapleLoan(loan_).drawableFunds();

        require(
            total <= drawableFunds || ERC20Helper.transferFrom(IMapleLoan(loan_).fundsAsset(), msg.sender, loan_, total - drawableFunds),
            "MBI:MP:TRANSFER_FAILED"
        );

        IMapleLoan(loan_).makePayments(numberOfPayments_, uint256(0));
    }

    function _makePaymentsWithCutoff(address loan_, uint256 cutoffDate_) internal returns (bool hasPaymentsWithinCutoff_) {
        uint256 nextPaymentDueDate = IMapleLoan(loan_).nextPaymentDueDate();

        if (nextPaymentDueDate > cutoffDate_) return false;

        uint256 paymentToMake     = 1 + ((cutoffDate_ - nextPaymentDueDate) / IMapleLoan(loan_).paymentInterval());
        uint256 paymentsRemaining = IMapleLoan(loan_).paymentsRemaining();

        _makePayments(loan_, paymentToMake < paymentsRemaining ? paymentToMake : paymentsRemaining);

        return true;
    }

    function _postCollateral(address loan_, uint256 amount_) internal {
        require(ERC20Helper.transferFrom(IMapleLoan(loan_).collateralAsset(), msg.sender, loan_, amount_), "MBI:PC:TRANSFER_FAILED");

        IMapleLoan(loan_).postCollateral(uint256(0));
    }

    function _postCollateralForDrawdown(address loan_, uint256 drawdownAmount_) internal returns (bool additionalCollateralNecessary_) {
        uint256 collateral = IMapleLoan(loan_).getAdditionalCollateralRequiredFor(drawdownAmount_);

        if (collateral == uint256(0)) return false;

        _postCollateral(loan_, collateral);

        return true;
    }

    function _proposeNewTerms(address loan_, address refinancer_, bytes[] calldata calls_) internal {
        IMapleLoan(loan_).proposeNewTerms(refinancer_, calls_);
    }

    function _removeAvailableCollateral(address loan_, address destination_) internal returns (bool hasRemovableCollateral_) {
        uint256 collateral = IMapleLoan(loan_).getRemovableCollateral();

        if (collateral == uint256(0)) return false;

        _removeCollateral(loan_, collateral, destination_);

        return true;
    }

    function _removeCollateral(address loan_, uint256 amount_, address destination_) internal {
        IMapleLoan(loan_).removeCollateral(amount_, destination_);
    }

    function _returnFunds(address loan_, uint256 amount_) internal {
        require(ERC20Helper.transferFrom(IMapleLoan(loan_).fundsAsset(), msg.sender, loan_, amount_), "MBI:RF:TRANSFER_FAILED");

        IMapleLoan(loan_).returnFunds(uint256(0));
    }

    function _returnFundsAndRemoveCollateral(address loan_, uint256 amount_, address destination_) internal returns (bool hasRemovableCollateral_) {
        _returnFunds(loan_, amount_);

        return _removeAvailableCollateral(loan_, destination_);
    }

    function _setBorrower(address loan_, address borrower_) internal {
        IMapleLoan(loan_).setBorrower(borrower_);
    }

    function _upgradeLoan(address loans_, uint256 toVersions_, bytes calldata arguments_) internal {
        IMapleLoan(loans_).upgrade(toVersions_, arguments_);
    }

}
