// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan }            from "../contracts/MapleLoan.sol";
import { MapleLoanFactory }     from "../contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer } from "../contracts/MapleLoanInitializer.sol";

import { MockFeeManager, MockGlobals, MockLoanManager, MockLoanManagerFactory, MockLoanFactory } from "./mocks/Mocks.sol";

import { Proxy } from "../modules/maple-proxy-factory/modules/proxy-factory/contracts/Proxy.sol";

contract MapleLoanFactoryTest is TestUtils {

    MockLoanFactory        internal oldFactory;
    MapleLoanFactory       internal factory;
    MockFeeManager         internal feeManager;
    MockGlobals            internal globals;
    MockLoanManager        internal lender;
    MockLoanManagerFactory internal loanManagerFactory;

    address internal governor      = address(new Address());
    address internal securityAdmin = address(new Address());

    address internal implementation;
    address internal initializer;

    function setUp() external {
        lender             = new MockLoanManager();
        loanManagerFactory = MockLoanManagerFactory(lender.factory());
        feeManager         = new MockFeeManager();
        globals            = new MockGlobals(governor);
        implementation     = address(new MapleLoan());
        initializer        = address(new MapleLoanInitializer());

        oldFactory = new MockLoanFactory();
        factory    = new MapleLoanFactory(address(globals), address(oldFactory));

        lender.__setFundsAsset(address(1));

        lender.__setFundsAsset(address(1));

        globals.setValidBorrower(address(1),        true);
        globals.setValidCollateralAsset(address(1), true);
        globals.setValidPoolAsset(address(1),       true);

        globals.__setIsInstanceOf(true);
        globals.__setCanDeploy(true);

        vm.startPrank(governor);
        factory.registerImplementation(1, implementation, initializer);
        factory.setDefaultVersion(1);
        vm.stopPrank();
    }

    function test_createInstance_invalidPoolAsset() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        bytes32 salt = keccak256(abi.encodePacked("salt"));

        globals.setValidPoolAsset(address(1), false);
        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(arguments, salt);

        globals.setValidPoolAsset(address(1), true);
        factory.createInstance(arguments, salt);
    }

    function test_createInstance_invalidCollateralAsset() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        bytes32 salt = keccak256(abi.encodePacked("salt"));

        globals.setValidCollateralAsset(address(1), false);
        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(arguments, salt);

        globals.setValidCollateralAsset(address(1), true);
        factory.createInstance(arguments, salt);
    }

    function test_createInstance_zeroLender() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(0),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(arguments, "SALT");

        arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        factory.createInstance(arguments, "SALT");
    }

    function test_createInstance_differentFundsAsset() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        lender.__setFundsAsset(address(2));

        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(arguments, "SALT");

        lender.__setFundsAsset(address(1));

        factory.createInstance(arguments, "SALT");
    }

    function test_createInstance_invalidFactory() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        globals.__setIsInstanceOf(false);

        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(arguments, "SALT");

        globals.__setIsInstanceOf(true);

        factory.createInstance(arguments, "SALT");
    }

    function test_createInstance_invalidInstance() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        loanManagerFactory.__setIsInstance(false);

        vm.expectRevert("MPF:CI:FAILED");
        factory.createInstance(arguments, "SALT");

        loanManagerFactory.__setIsInstance(true);

        factory.createInstance(arguments, "SALT");
    }

    function testFail_createInstance_saltAndArgumentsCollision() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        bytes32 salt = keccak256(abi.encodePacked("salt"));

        factory.createInstance(arguments, salt);

        // TODO: use vm.expectRevert() without arguments when it is available.
        factory.createInstance(arguments, salt);
    }

    function test_createInstance_invalidCaller() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        globals.__setCanDeploy(false);

        vm.expectRevert("MLF:CI:CANNOT_DEPLOY");
        factory.createInstance(arguments, "SALT");

        globals.__setCanDeploy(true);

        factory.createInstance(arguments, "SALT");
    }

    function test_createInstance(bytes32 salt_) external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        address loan = factory.createInstance(arguments, salt_);

        address expectedAddress = address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(factory),
                keccak256(abi.encodePacked(arguments, salt_)),
                keccak256(abi.encodePacked(type(Proxy).creationCode, abi.encode(address(factory), address(0))))
            )
        ))));

        // TODO: Change back to hardcoded address once IPFS hashes can be removed on compilation in Foundry.
        assertEq(loan, expectedAddress);

        assertTrue(!oldFactory.isLoan(address(1)));
        assertTrue( factory.isLoan(loan));
    }

    function test_isLoan_withOldFactory() external {
        address[2] memory assets      = [address(1), address(1)];
        uint256[3] memory termDetails = [uint256(12 hours), uint256(1), uint256(1)];
        uint256[3] memory amounts     = [uint256(1), uint256(1), uint256(0)];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256[2] memory fees        = [uint256(0), uint256(0)];

        bytes memory arguments = MapleLoanInitializer(initializer).encodeArguments(
            address(1),
            address(lender),
            address(feeManager),
            assets,
            termDetails,
            amounts,
            rates,
            fees
        );

        // Assert current factory points to the correct old loan factory
        assertEq(factory.oldFactory(), address(oldFactory));

        address oldLoan = address(new Address());

        oldFactory.__setIsLoan(oldLoan, true);

        assertTrue(oldFactory.isLoan(oldLoan));
        assertTrue(factory.isLoan(oldLoan));

        address loan1 = factory.createInstance(arguments, keccak256(abi.encodePacked("salt1")));
        address loan2 = factory.createInstance(arguments, keccak256(abi.encodePacked("salt2")));

        assertTrue(!oldFactory.isLoan(loan1));
        assertTrue( factory.isLoan(loan1));
        assertTrue( factory.isLoan(loan2));
        assertTrue( factory.isLoan(oldLoan));
    }

}
