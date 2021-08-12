// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.11;

import { ILoanFactory } from "../../interfaces/ILoanFactory.sol"; 

contract Borrower {

    /************************/
    /*** Direct Functions ***/
    /************************/
    function loanFactory_createLoan(
        address loanFactory,
        address liquidityAsset,
        address collateralAsset,
        address flFactory,
        address clFactory,
        uint256[5] memory specs,
        address[3] memory calcs
    ) external {
        ILoanFactory(loanFactory).createLoan(liquidityAsset, collateralAsset, flFactory, clFactory, specs, calcs); 
    }

    /*********************/
    /*** Try Functions ***/
    /*********************/
    function try_loanFactory_createLoan(
        address loanFactory,
        address liquidityAsset,
        address collateralAsset,
        address flFactory,
        address clFactory,
        uint256[5] memory specs,
        address[3] memory calcs
    ) 
        external returns (bool ok) 
    {
        string memory sig = "createLoan(address,address,address,address,uint256[5],address[3])";
        (ok,) = loanFactory.call(
            abi.encodeWithSignature(sig, liquidityAsset, collateralAsset, flFactory, clFactory, specs, calcs)
        );
    }

}
