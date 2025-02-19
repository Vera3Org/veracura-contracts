#!/usr/bin/env bash

# defines PRIVATE_KEY
[ -f .env.mainnet.base ] && source .env.mainnet.base

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


# eth-sepolia RPC. One from https://chainlist.org/chain/8453
RPC_URL="${RPC_URL:-https://base.llamarpc.com}"

# request.network fee proxy on base mainnet (from https://docs.request.network/get-started/smart-contract-addresses#base)
export ETH_FEE_PROXY_ADDRESS="0xd9C3889eB8DA6ce449bfFE3cd194d08A436e96f2"
# from https://docs.chain.link/vrf/v2-5/supported-networks#base-mainnet
export LINK_ADDRESS=0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196
export VRF_WRAPPER_ADDRESS=0xb0407dbe851f8318bd31404A49e658143C982F23

# safe address
export MAINNET_TREASURY_ADDRESS=${MAINNET_TREASURY_ADDRESS}
export ADMIN_ADDRESS="$WALLET_ADDRESS"

export OPERATOR_ADDRESS=0x76c413ce90c54353356bd85a0167d5a729783bf9



forge clean && forge script \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --slow --via-ir \
    --optimize --optimizer-runs 1000 \
    script/DeployASC.sol:DeployASC  \
    --compute-units-per-second 20 \
    --ffi \
    --verify \
    --verifier-url="https://api.basescan.org/api" \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    $@
