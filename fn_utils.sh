# You should source this file with "source fn_utils.sh"
# so that you'll have various utility functions and variables in your shell

source .env.testnet.eth-sepolia

ASC_MANAGER="0x6a14b7745dfac89a1fe673d034c2e574d8bf06e4"
ELEPHANT=0xA6fEbb3d0D63968f54A5EA5B72718fF5fe21022d
TIGER=0x7294F592448663D169F18704ddc6CC532c27A22f
SHARK=0x4bB30957d7a9a51545c606e13E2Ef4e98d1bcc40
EAGLE=0xAfD8255C1abAAbd25F70178be9531da0087424Bc
STAKEHOLDER=0x83712599317Ea81453C48530db1eAe624885dFa8
LOTTERY=0xA52672A2aC57263d599284a75585Cc7771363A05



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
