#!/usr/bin/env bash
set -euo pipefail
#export SHELLOPTS

cmd=my-xc-virsh

HERE=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
export PATH="$HERE/../bin:$PATH"

uu::prefix-output() {
  sed -e "s/^/${1:-}/"
}

trap "$cmd destroy -n my-stuff --debug |& uu::prefix-output '[TEST][tearing down] '" EXIT INT
$cmd destroy --name my-stuff |& uu::prefix-output "[TEST][setting up, cleaning] "
if [ ! -f ~/.cache/xc-testing-ssh-key.pem ];then
  ssh-keygen -N "" -b 1024 -f ~/.cache/xc-testing-ssh-key.pem
fi

{
$cmd deploy \
  --name my-stuff \
  --nodes-count 2 \
  --nix-expression-path $HERE/my-nodes.nix \
  --ssh-private-key-path ~/.cache/xc-testing-ssh-key.pem

# let's use ENV variant
export MY_XC_NAME=my-stuff
export MY_XC_NIX_EXPRESSION_PATH=$HERE/my-nodes.nix
export MY_XC_SSH_PRIVATE_KEY_PATH=~/.cache/xc-testing-ssh-key.pem


$cmd deploy
$cmd list
$cmd list-nodes-ids
} |& uu::prefix-output "[TEST][running-tests] "
