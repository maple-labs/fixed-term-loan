// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

interface IERC20Details {
    function decimals() external view returns (uint256);
}

interface IUniswapRouterLike {
    function swapExactTokensForTokens(uint256, uint256, address[] calldata, address, uint256) external returns (uint256[] memory);
}

interface ICollateralLockerLike {
    function pull(address, uint256) external;
}

interface IFundingLockerLike {
    function drain() external;
    function pull(address, uint256) external;
}

interface ILateFeeCalcLike {
    function getLateFee(uint256) external view returns (uint256);
}

interface ILiquidityLockerLike {
    function pool() external view returns (address);
}

interface ILockerFactoryLike {
    function newLocker(address) external returns (address);
}

interface ILoanFactoryLike {
    function globals() external view returns (address);
}

interface IMapleGlobals {
    function defaultGracePeriod() external view returns (uint256);
    function defaultUniswapPath(address, address) external view returns (address);
    function fundingPeriod() external view returns (uint256);
    function getLatestPrice(address) external view returns (uint256);
    function governor() external view returns (address);
    function investorFee() external view returns (uint256);
    function isValidCalc(address, uint8) external view returns (bool);
    function isValidCollateralAsset(address) external view returns (bool);
    function isValidLiquidityAsset(address) external view returns (bool);
    function isValidPoolFactory(address) external view returns (bool);
    function isValidSubFactory(address, address, uint8) external view returns (bool);
    function mapleTreasury() external view returns (address);
    function maxSwapSlippage() external view returns (uint256);
    function minLoanEquity() external view returns (uint256);
    function protocolPaused() external view returns (bool);
    function treasuryFee() external view returns (uint256);
}

interface IPoolLike {
    function superFactory() external pure returns (address);
}

interface IPoolFactoryLike {
    function isPool(address) external view returns (bool);
}

interface IPremiumCalcLike {
    function getPremiumPayment(address) external view returns (uint256, uint256, uint256);
}

interface IRepaymentCalcLike {
    function getNextPayment(address) external view returns (uint256, uint256, uint256);
}

