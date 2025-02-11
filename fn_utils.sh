# You should source this file with "source fn_utils.sh"
# so that you'll have various utility functions and variables in your shell

source .env.testnet.eth-sepolia

ASC_MANAGER="0xe5Efaa2470EDDBc32Dbc83027F08e06d408E8606"
ELEPHANT=0x6da40f96f59428b4cAAE79B8c2E29fcfE485fC17
TIGER=0x662D1c40D88b1E8290D5189026017738003dB3A4
SHARK=0xC722a160968EEeEE7cAEf1A5dd5aAd39f7bCa9F5
EAGLE=0x92A3E4c1B9f2315E2aB8DBb0B5e10277fa24041B
STAKEHOLDER=0xf12DF6b824d0FaC784e4935D7C6aFd8A825c5e81
LOTTERY=0x88B4537D0e0438659C796Cb83bC9CC7bAA4C31E6


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
    cast_base $verb "$ELEPHANT" $@
}

function cast_shark() {
    local verb="$1"
    shift
    cast_base $verb "$SHARK" $@
}

function cast_eagle() {
    local verb="$1"
    shift
    cast_base $verb "$EAGLE" $@
}


function cast_tiger() {
    local verb="$1"
    shift
    cast_base $verb "$TIGER" $@
}

function cast_stakeholder() {
    local verb="$1"
    shift
    cast_base $verb "$STAKEHOLDER" $@
}

function cast_lottery() {
    local verb="$1"
    shift
    cast_base $verb "$LOTTERY" $@
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
