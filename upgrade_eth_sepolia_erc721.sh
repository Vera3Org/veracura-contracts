#!/usr/bin/env bash

# defines PRIVATE_KEY
[ -f .env.testnet.eth-sepolia ] && source .env.testnet.eth-sepolia

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


# eth-sepolia RPC. One from https://chainlist.org/chain/11155111
RPC_URL="${RPC_URL:-https://1rpc.io/sepolia}"

# request.network fee proxy on eth sepolia (from https://docs.request.network/get-started/smart-contract-addresses#sepolia)
export ETH_FEE_PROXY_ADDRESS="0xe11BF2fDA23bF0A98365e1A4c04A87C9339e8687"
# from https://docs.chain.link/vrf/v2-5/supported-networks#sepolia-testnet
export LINK_ADDRESS=0x779877A7B0D9E8603169DdbD7836e478b4624789
export VRF_WRAPPER_ADDRESS=0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1

export TESTNET_TREASURY_ADDRESS=0x1A5d925a3AE9bE95Afd9CB14B805d320d925dba5
export ADMIN_ADDRESS="$WALLET_ADDRESS"
export DUMMY_0_ADDRESS=0xe198f322E463510deB487170dD299Df9787f5470


forge clean && forge script \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --slow --via-ir \
    --optimize --optimizer-runs 1000 \
    script/UpgradeErc721.sol:Upgrader  \
    $@

    # --verify \
    # --verifier-url="https://api-sepolia.etherscan.io/api" \
    # --etherscan-api-key "$ETHERSCAN_API_KEY" \