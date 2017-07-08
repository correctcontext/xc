#!/usr/bin/env bash
set -eu

# nix-build
(
  cd src
  cabal build
)
export XC_DEBUG_BUILD_PATH=tmp
export XC_INFRA=./../kubenix2/backend/virsh/bin/virsh 
export XC_NAME=test1 
export XC_SSH_PRIVATE_KEY_PATH=~/.ssh/public/id_rsa
# --infra ./../kubenix2/backend/virsh/bin/virsh --name test1 --nodes-count 3 --ssh-private-key-path ~/.ssh/public/id_rsa
./src/dist/build/xc/xc "$@"

