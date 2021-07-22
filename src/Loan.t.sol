pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./Loan.sol";

contract LoanTest is DSTest {
    Loan loan;

    function setUp() public {
        loan = new Loan();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
