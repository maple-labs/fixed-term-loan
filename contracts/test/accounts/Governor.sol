// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleLoanFactory } from "../../interfaces/IMapleLoanFactory.sol";

contract Governor {

    /************************/
    /*** Direct Functions ***/
    /************************/

    function mapleLoanFactory_disableUpgradePath(address factory_, uint256 fromVersion_, uint256 toVersion_) external {
        IMapleLoanFactory(factory_).disableUpgradePath(fromVersion_, toVersion_);
    }

    function mapleLoanFactory_enableUpgradePath(address factory_, uint256 fromVersion_, uint256 toVersion_, address migrator_) external {
        IMapleLoanFactory(factory_).enableUpgradePath(fromVersion_, toVersion_, migrator_);
    }

    function mapleLoanFactory_registerImplementation(
        address factory_,
        uint256 version_,
        address implementationAddress_,
        address initializer_
    ) external {
        IMapleLoanFactory(factory_).registerImplementation(version_, implementationAddress_, initializer_);
    }

    function mapleLoanFactory_setDefaultVersion(address factory_, uint256 version_) external {
        IMapleLoanFactory(factory_).setDefaultVersion(version_);
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/

    function try_mapleLoanFactory_disableUpgradePath(address factory_, uint256 fromVersion_,uint256 toVersion_) external returns (bool ok_) {
        ( ok_, ) = factory_.call(abi.encodeWithSelector(IMapleLoanFactory.disableUpgradePath.selector, fromVersion_, toVersion_));
    }

    function try_mapleLoanFactory_enableUpgradePath(
        address factory_,
        uint256 fromVersion_,
        uint256 toVersion_,
        address migrator_
    ) external returns (bool ok_) {
        ( ok_, ) = factory_.call(abi.encodeWithSelector(IMapleLoanFactory.enableUpgradePath.selector, fromVersion_, toVersion_, migrator_));
    }

    function try_mapleLoanFactory_registerImplementation(
        address factory_,
        uint256 version_,
        address implementationAddress_,
        address initializer_
    ) external returns (bool ok_) {
        ( ok_, ) = factory_.call(
            abi.encodeWithSelector(IMapleLoanFactory.registerImplementation.selector, version_, implementationAddress_, initializer_)
        );
    }

    function try_mapleLoanFactory_setDefaultVersion(address factory_, uint256 version_) external returns (bool ok_) {
        ( ok_, ) = factory_.call(abi.encodeWithSelector(IMapleLoanFactory.setDefaultVersion.selector, version_));
    }

}
