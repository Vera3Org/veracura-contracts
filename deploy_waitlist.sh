#!/bin/bash

source .env.testnet

RPC_BASE_TESTNET="https://base-sepolia.blockpi.network/v1/rpc/public"

FEE_PROXY_ADDRESS="0xA52672A2aC57263d599284a75585Cc7771363A05"
TESTNET_TREASURY_ADDRESS="0x2c6eC800DD7656c9E2901B2b8D5aCF215b9300a8"

forge create \
    --rpc-url "$RPC_BASE_TESTNET" \
    --private-key "$PRIVATE_KEY" \
    src/Waitlist.sol:ASCWaitlist \
    --verify \
    --verifier blockscout \
    --verifier-url https://base-sepolia.blockscout.com/api/ \
    --constructor-args "$FEE_PROXY_ADDRESS" "$TESTNET_TREASURY_ADDRESS"

