set -e

source .env.mainnet.base

[ -z "$PRIVATE_KEY" ] && {
    echo no PRIVATE_KEY variable in environment.
    exit 1
}

[ -z "$WALLET_ADDRESS" ] && {
    echo no WALLET_ADDRESS variable in environment.
    exit 1
}

[ -z "$AMBASSADOR_ADDRESS" ] && {
    echo no AMBASSADOR_ADDRESS variable in environment.
    exit 1
}

# eth-sepolia RPC. One from https://chainlist.org/chain/8453
RPC_URL="${RPC_URL:-https://base-mainnet.public.blastapi.io}"

forge script \
    --via-ir \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --optimize --optimizer-runs 1000 \
    script/AddAmbassador.sol:AddAmbassador \
    --compute-units-per-second 15 \
    --slow \
    $@
