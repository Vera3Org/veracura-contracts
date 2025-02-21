# You should source this file with "source fn_utils.sh"
# so that you'll have various utility functions and variables in your shell

# source .env.testnet.eth-sepolia
source .env.mainnet.base

ASC_MANAGER="0x350a3b9d65b0c5e1ac1861ede5ee7f230d7c8063"
elephant=0x4953a2B6E30F0e0c44d30eBCA833CeFc59249d44
tiger=0x2f65eeBF86875988484C3ec697D4c7b26b20Aae0
shark=0x61ef41eaaC9540dC015C3BD8A631Af5209FA2F4a
eagle=0x9510a56002b7f8c489c86b3ff77B63e13a6599DD
stakeholder=0xef48D2C7E6BeFB54A270FC44cab56a7Fa444D37e
lottery=0x9800b9C6267619e9ceF08F47Fd5dec94A2D303C8



function cast_base() {
    local verb="$1"
    shift
    cast $verb -r "$RPC_URL" $@
}

function cast_manager() {
    local verb="$1"
    shift
    cast_base $verb "$ASC_MANAGER" $@
}

function cast_elephant() {
    local verb="$1"
    shift
    cast_base $verb "$elephant" $@
}

function cast_shark() {
    local verb="$1"
    shift
    cast_base $verb "$shark" $@
}

function cast_eagle() {
    local verb="$1"
    shift
    cast_base $verb "$eagle" $@
}


function cast_tiger() {
    local verb="$1"
    shift
    cast_base $verb "$tiger" $@
}

function cast_stakeholder() {
    local verb="$1"
    shift
    cast_base $verb "$stakeholder" $@
}

function cast_lottery() {
    local verb="$1"
    shift
    cast_base $verb "$lottery" $@
}


function print_names() {
    echo " - manager: $ASC_MANAGER"
    for x in elephant tiger shark eagle stakeholder lottery ; do
        echo " - $x  $(cast_manager call $x'()(address)')"
    done
}

function print_names_shell() {
    echo "ASC_MANAGER=$ASC_MANAGER"
    for x in elephant tiger shark eagle stakeholder lottery ; do
        echo "$x=$(cast_manager call $x'()(address)')"
    done
}

function print_names_etherscan() {
    echo " - manager: https://sepolia.etherscan.io/address/$ASC_MANAGER"
    for x in elephant tiger shark eagle stakeholder lottery ; do
        echo " - $x  https://sepolia.etherscan.io/address/$(cast_manager call $x'()(address)')"
    done
}
