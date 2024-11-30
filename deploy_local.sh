#!/usr/bin/env bash

# defines PRIVATE_KEY
[ -f .env ] && source .env

[ -z "$PRIVATE_KEY" ] && {
    echo 'No variable PRIVATE_KEY in the environment.'
    echo 'Either export the variable with the command
        export PRIVATE_KEY=someprivatekeyfromanvil'
    echo 'or create a .env file containing PRIVATE_KEY=someprivatekeyfromanvil'
    exit 1
}


# base sepolia
# RPC_URL="https://base-sepolia.blockpi.network/v1/rpc/public"

# local
RPC_URL="http://127.0.0.1:8545"

# request.network fee proxy on base sepolia (deployed manually)
FEE_PROXY_ADDRESS="0xA52672A2aC57263d599284a75585Cc7771363A05"

# taken from https://docs.chain.link/vrf/v2-5/supported-networks#base-sepolia-testnet
LINK_BASE_SEPOLIA=0xE4aB69C077896252FAFBD49EFD26B5D171A32410
VRF_WRAPPER_BASE_SEPOLIA=0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed\

# dummy address corresponding to dummy private key
TESTNET_TREASURY_ADDRESS="0x90F79bf6EB2c4f870365E785982E1f101E93b906"

forge clean && forge script \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --optimize --optimizer-runs 1000 \
    script/DeployASC.sol:DeployASC  \
    --broadcast
