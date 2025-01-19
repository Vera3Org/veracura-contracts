#!/bin/bash

set -e

# defines ETHERSCAN_API_KEY, RPC_URL
[ -f .env.testnet.eth-sepolia ] && source .env.testnet.eth-sepolia

DEPLOYMENTS_FILE=broadcast/DeployASC.sol/11155111/run-1737316105.json
#SOLIDITY_VERSION="v0.8.26+commit.8a97fa7a"
export VERIFIER_URL="https://api-sepolia.etherscan.io/api"

jq -c '.transactions[]' "$DEPLOYMENTS_FILE" | while read -r line ; do

    printf "\n---------------------------\n\n"

    name=$(echo "$line" | jq -r .contractName)
    address=$(echo "$line" | jq -r .contractAddress)
    tx_type=$(echo "$line" | jq -r .transactionType)

    if [ "$tx_type" != 'CREATE' ] ; then
        echo "skipping $name because tx type \"$tx_type\" != \"CREATE\""
        continue
    fi
    if [ -z "$name" ] ; then
        echo "skipping empty contract name..."
        continue
    fi

    echo "verifying contract $name at $address ..."

    if [ "$name" = "ASC721Manager" ] ; then
        ( set -x
        forge verify-contract \
            "$address" \
            src/ASC721Manager.sol:ASC721Manager \
            --rpc-url "$RPC_URL" \
            --guess-constructor-args \
            --optimizer-runs 1000 \
            --verifier=etherscan \
            --verifier-url="$VERIFIER_URL" \
            --verifier-api-key "$ETHERSCAN_API_KEY" \
            --watch #--compiler-version "$SOLIDITY_VERSION"
        )
    elif [ "$name" = "AnimalSocialClubERC721" ] ; then
        ( set -x
        forge verify-contract \
            "$address" \
            src/AnimalSocialClubERC721.sol:AnimalSocialClubERC721 \
            --guess-constructor-args \
            --rpc-url "$RPC_URL" \
            --optimizer-runs 1000 \
            --verifier=etherscan \
            --verifier-url="$VERIFIER_URL" \
            --verifier-api-key "$ETHERSCAN_API_KEY" \
            --watch #--compiler-version "$SOLIDITY_VERSION"
        )
    elif [ "$name" = "ASCLottery" ] ; then
        ( set -x
        forge verify-contract \
            "$address" \
            src/ASCLottery.sol:ASCLottery \
            --rpc-url "$RPC_URL" \
            --guess-constructor-args \
            --optimizer-runs 1000 \
            --verifier=etherscan \
            --verifier-url="$VERIFIER_URL" \
            --verifier-api-key "$ETHERSCAN_API_KEY" \
            --watch #--compiler-version "$SOLIDITY_VERSION"
        )
    elif [ "$name" = "ERC1967Proxy" ] ; then
        ( set -x
        forge verify-contract \
            "$address" \
            lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
            --rpc-url "$RPC_URL" \
            --guess-constructor-args \
            --optimizer-runs 1000 \
            --verifier=etherscan \
            --verifier-url="$VERIFIER_URL" \
            --verifier-api-key "$ETHERSCAN_API_KEY" \
            --watch #--compiler-version "$SOLIDITY_VERSION"
        )
    else
        echo WHAT IS "$name"
    fi

done
