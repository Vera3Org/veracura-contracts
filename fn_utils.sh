# You should source this file with "source fn_utils.sh"
# so that you'll have various utility functions and variables in your shell

# source .env.testnet.eth-sepolia
source .env.mainnet.base

ASC_MANAGER="0xc8c0F52307862D6a0f840eC34dA59c1908Bf000E"
elephant=0x6181d43D9983795247Ccb8797FcC441408246E04
tiger=0x155a3DABFDDFd22d75da2f6D67139405d1679932
shark=0xe2EaDddC6f628d293A72Bb4aD22C71a2051C2985
eagle=0xa658c2e3607a592660631bCD4de33D5eb850C528
stakeholder=0xAD829b08c1b18c1eE3479447c25a28560E03c5f1
lottery=0x8cb2f272b267779413608095c005a9b2b1b68390



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
