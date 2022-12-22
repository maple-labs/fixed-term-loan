// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20 } from "../modules/erc20/contracts/interfaces/IERC20.sol";

import { IMapleFeeManagerLike } from "./interfaces/Interfaces.sol";
import { IMapleLoanV4Migrator } from "./interfaces/IMapleLoanV4Migrator.sol";

import { MapleLoanStorage } from "./MapleLoanStorage.sol";

/// @title DebtLockerV4Migrator is intended to initialize the storage of a DebtLocker proxy.
contract MapleLoanV4Migrator is IMapleLoanV4Migrator, MapleLoanStorage {

    function encodeArguments(address feeManager_) external pure override returns (bytes memory encodedArguments_) {
        return abi.encode(feeManager_);
    }

    function decodeArguments(bytes calldata encodedArguments_) public pure override returns (address feeManager_) {
        ( feeManager_ ) = abi.decode(encodedArguments_, (address));
    }

    fallback() external {

        // Taking the feeManager_ address as argument for now
        // but ideally this would be hardcoded in the debtLocker migrator registered in the factory.
        ( address feeManager_ ) = decodeArguments(msg.data);

        _feeManager = feeManager_;

        IMapleFeeManagerLike(feeManager_).updateDelegateFeeTerms(0, __deprecated_delegateFee);
        IMapleFeeManagerLike(feeManager_).updatePlatformServiceFee(_principalRequested, _paymentInterval);

        IERC20(_fundsAsset).approve(_feeManager, type(uint256).max);
    }

}
