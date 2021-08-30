// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { ERC20 }     from "../../../modules/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 }    from "../../../modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "../../../modules/openzeppelin-contracts/contracts/token/ERC20/SafeERC20.sol";

import { ILoan } from "../../interfaces/ILoan.sol";

/*****************/
/*** Factories ***/
/*****************/

contract CollateralLockerFactoryMock {

    function newLocker(address asset) external returns (address) {
        return address(new CollateralLockerMock(asset));
    }

}

contract FundingLockerFactoryMock {

    function newLocker(address asset) external returns (address) {
        return address(new FundingLockerMock(asset));
    }

}

/***************/
/*** Lockers ***/
/***************/

contract CollateralLockerMock {

    using SafeERC20 for IERC20;

    IERC20 liquidityAsset;

    constructor(address asset) public {
        liquidityAsset = IERC20(asset);
    }

    function pull(address dst, uint256 amt) external {
        liquidityAsset.safeTransfer(dst, amt);
    }

}

contract FundingLockerMock {

    using SafeERC20 for IERC20;

    IERC20 liquidityAsset;

    constructor(address asset) public {
        liquidityAsset = IERC20(asset);
    }

    function pull(address dst, uint256 amt) external {
        liquidityAsset.safeTransfer(dst, amt);
    }

}

/***************/
/*** Globals ***/
/***************/

contract GlobalsMock {

    bool public protocolPaused;

    address public governor;
    address public mapleTreasury = address(2);

    uint256 public constant defaultGracePeriod = 10 days;
    uint256 public constant fundingPeriod      = 10 days;

    uint256 public investorFee     = 50;
    uint256 public treasuryFee     = 50;
    uint256 public maxSwapSlippage = 10_000;
    uint256 public minLoanEquity   = 2000;

    mapping(address => mapping(uint8 => bool)) public isValidCalc;

    mapping(address => mapping(address => mapping(uint8 => bool))) public isValidSubFactory;

    mapping(address => mapping(address => address)) public defaultUniswapPath;

    mapping(address => bool) public isValidCollateralAsset;
    mapping(address => bool) public isValidLiquidityAsset;
    mapping(address => bool) public isValidPoolFactory;

    mapping(address => uint256) public latestPrice;

    constructor(address _governor) public {
        governor = _governor;
    }

    function setProtocolPause(bool pause) external {
        protocolPaused = pause;
    }

    function setCalcValidity(address calc, uint8 calcType, bool valid) external {
        isValidCalc[calc][calcType] = valid;
    }

    function setCollateralAssetValidity(address asset, bool valid) external {
        isValidCollateralAsset[asset] = valid;
    }

    function setLiquidityAssetValidity(address asset, bool valid) external {
        isValidLiquidityAsset[asset] = valid;
    }

    function setSubFactoryValidity(address superFactory, address subFactory, uint8 factoryType, bool valid) external {
        isValidSubFactory[superFactory][subFactory][factoryType] = valid;
    }

    function setPoolFactoryValidity(address poolFactory, bool valid) external {
        isValidPoolFactory[poolFactory] = valid;
    }

    function setLatestPrice(address asset, uint256 value) external {
        latestPrice[asset] = value;
    }

    function getLatestPrice(address asset) external view returns (uint256) {
        return latestPrice[asset];
    }

    function setDefaultUniswapPath(address from, address to, address mid) external{
        defaultUniswapPath[from][to] = mid;
    }

    function setInvestorFee(uint256 basisPoints) external returns (uint256) {
        investorFee = basisPoints;
    }

    function setTreasuryFee(uint256 basisPoints) external returns (uint256) {
        treasuryFee = basisPoints;
    }

}

/***************/
/*** Tokens ***/
/***************/

contract MintableToken is ERC20 {

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) public {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

}
