// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IMapleLoanFactory } from "../../interfaces/IMapleLoanFactory.sol";

contract MapleGlobalsMock {

    address public governor;

    mapping(address => bool) public isBorrower;

    constructor (address governor_) {
        governor = governor_;
    }

    function setGovernor(address governor_) external {
        governor = governor_;
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
