#!/usr/bin/env bash
set -eu

HERE=$(dirname "${BASH_SOURCE[0]}")
export PATH="$HERE/../bin:$PATH"

# xc destroy --name xc-test-cs
xc deploy --name xc-test-cs --nodes-count 2
xc status -n xc-test-cs

export XC_NAME=xc-test-cs
