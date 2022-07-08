// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IGlobalsLike {

    function isBorrower(address account_) external view returns (bool isBorrower_);

}
