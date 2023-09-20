// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ProxiedInternals } from "../modules/maple-proxy-factory/modules/proxy-factory/contracts/ProxiedInternals.sol";

import { MapleLoanStorage } from "./MapleLoanStorage.sol";

/// @title MapleLoanV502Migrator is to update the factory address for each deployed loan.
contract MapleLoanV502Migrator is ProxiedInternals, MapleLoanStorage  {
    fallback() external {
        ( address factory_ ) = abi.decode(msg.data, (address));

        _setFactory(factory_);
    }

}
