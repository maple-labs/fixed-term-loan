#!/usr/bin/env bash
set -e

while getopts t:r:b:v:c: flag
do
    case "${flag}" in
        c) config=${OPTARG};;
    esac
done

export FOUNDRY_PROFILE=$profile
echo Using profile: $FOUNDRY_PROFILE

forge build
