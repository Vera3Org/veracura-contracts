#!/usr/bin/env bash

source .env

forge script \
    --rpc-url $LOCAL_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    script/AnimalSocialClubERC1155.s.sol:DeployAnimalSocialClub \
    -vvvv
