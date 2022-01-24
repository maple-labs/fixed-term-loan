#!/usr/bin/env bash
set -e

while getopts t:r: flag
do
    case "${flag}" in
        t) test=${OPTARG};;
        r) runs=${OPTARG};
    esac
done

runs=$([ -z "$runs" ] && echo "10" || echo "$runs")

export DAPP_SOLC_VERSION=0.8.7
export DAPP_SRC="contracts"
export PROPTEST_CASES=$runs
export DAPP_TEST_TIMESTAMP=1622400000  # Non-zero timestamp

if [ -z "$test" ]; then match="[contracts/test/*.t.sol]"; else match=$test; fi

forge test --match "$match" -vvv --lib-paths "modules" --contracts "contracts" --optimize --optimize-runs 200
