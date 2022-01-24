# MapleLoan

![Foundry CI](https://github.com/maple-labs/loan/actions/workflows/push-to-main.yml/badge.svg) [![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

**DISCLAIMER: This code has NOT been externally audited and is actively being developed. Please do not use in production without taking the appropriate steps to ensure maximum security.**

This repo contains a set of contracts to facilitate on-chain Loans between Maple Finance Pools and institutional borrowers. These contracts contain logic to:
1. Deploy new Loans.
2. Perform Loan funding.
3. Draw down funds.
4. Manage collateral.
5. Calculate payment amounts and schedules (can handle amortized and interest-only payment structures).
6. Perform repossessions of collateral and remaining funds in a defaulted Loan.
7. Claim interest and principal from Loans.
8. Perform refinancing operations when a lender and borrower agree to new terms.
9. Upgrade Loan logic using upgradeability patterns.

### Dependencies/Inheritance
The `MapleLoan` contract is deployed using the `MapleProxyFactory`, which can be found in the modules or on GitHub [here](https://github.com/maple-labs/maple-proxy-factory).

`MapleProxyFactory` inherits from the generic `ProxyFactory` contract which can be found [here](https://github.com/maple-labs/proxy-factory).

## Testing and Development
#### Setup
```sh
git clone git@github.com:maple-labs/loan.git
cd loan
dapp update
```
#### Running Tests
- To run all tests: `make test` (runs `./test.sh`)
- To run a specific test function: `./test.sh -t <test_name>` (e.g., `./test.sh -t test_fundLoan`)
- To run tests with a specified number of fuzz runs: `./test.sh -r <runs>` (e.g., `./test.sh -t test_makePayments -r 10000`)

This project was built using [Foundry](https://github.com/gakonst/Foundry).

## Roles and Permissions
- **Governor**: Controls all implementation-related logic in the MapleLoanFactory, allowing for new versions of Loans to be deployed from the same factory and upgrade paths between versions to be allowed.
- **Borrower**: Account that is declared on instantiation of the Loan and has the ability to draw down funds and manage collateral. It should be noted that payments can be made from any account on behalf of a borrower.
- **Lender**: Account that is declared on Loan funding. Has the ability to claim all interest and principal that accrues from payments. Also has the ability to repossess a Loan once it is in default.

## Technical Documentation
For more in-depth technical documentation about these contracts, please refer to the GitHub [wiki](https://github.com/maple-labs/loan/wiki).

## Audit Reports
| Auditor | Report link |
|---|---|
| Trail of Bits | [ToB - Dec 28, 2021](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-core/files/7847684/Maple.Finance.-.Final.Report_v3.pdf) |
| Code 4rena | [C4 - Jan 5, 2022](https://code4rena.com/reports/2021-12-maple/) |

## About Maple
[Maple Finance](https://maple.finance) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

For all technical documentation related to the currently deployed Maple protocol, please refer to the maple-core GitHub [wiki](https://github.com/maple-labs/maple-core/wiki).

---

<p align="center">
  <img src="https://user-images.githubusercontent.com/44272939/116272804-33e78d00-a74f-11eb-97ab-77b7e13dc663.png" height="100" />
</p>
