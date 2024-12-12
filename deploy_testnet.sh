#!/usr/bin/env bash

# defines PRIVATE_KEY
[ -f .env.testnet ] && source .env.testnet

([ -z "$PRIVATE_KEY" ] || [ -z "$WALLET_ADDRESS" ] ) && {
    echo 'No variable PRIVATE_KEY or WALLET_ADDRESS in the environment.'
    echo 'Either export the variable with the command
        export PRIVATE_KEY=some_private_key_from_anvil
        export WALLET_ADDRESS=corresponding_address_from_anvil
        '
    echo 'or create a .env file containing PRIVATE_KEY=someprivatekeyfromanvil'
    echo 'generate a random key with openssl rand -hex 32'
    exit 1
}


# base sepolia
RPC_URL="https://base-sepolia.blockpi.network/v1/rpc/public"

# request.network fee proxy on base sepolia (deployed manually)
FEE_PROXY_ADDRESS="0xA52672A2aC57263d599284a75585Cc7771363A05"

# taken from https://docs.chain.link/vrf/v2-5/supported-networks#base-sepolia-testnet
LINK_BASE_SEPOLIA=0xE4aB69C077896252FAFBD49EFD26B5D171A32410
VRF_WRAPPER_BASE_SEPOLIA=0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed\

# dummy address corresponding to dummy private key
TESTNET_TREASURY_ADDRESS="$WALLET_ADDRESS"

forge clean && forge script \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL \
    --optimize --optimizer-runs 1000 \
    script/DeployASC.sol:DeployASC  \
    --verify \
    --verifier=blockscout \
    --verifier-url="https://base-sepolia.blockscout.com/api" \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    --broadcast $@
