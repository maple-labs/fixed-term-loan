// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { IERC20 } from "../../../modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ERC20User {

    function erc20_approve(address token, address account, uint256 amount) external {
        IERC20(token).approve(account, amount);
    }

    function erc20_transfer(address token, address account, uint256 amount) external {
        IERC20(token).transfer(account, amount);
    }

}
