# You should source this file with "source fn_utils.sh"
# so that you'll have various utility functions and variables in your shell

source .env.testnet

ASC_MANAGER="0x91D9fBa2557aD50766e09B5D4e1ac1431f5d3d09"
ELEPHANT="0x7115431C0E9615C9A0688F32D0Fa432D61E25434"
TIGER="0x2F856f40472270360AAA6eE01dF5aAC1E61b0a36"
SHARK="0x3c5ffa7E5DcF8BE4c7BC676e29d702Ae95D92CC7"
EAGLE="0xc64943eb6c2b4738A1351C6e896cAC7110021052"
STAKEHOLDER="0x87257bFfd8f53E6d2fEB42367726B616578d5299"
LOTTERY="0x33f30863E640E1a3870C0E451c0719aeD3124741"



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

function print_names_blockscout() {
    echo " - manager: https://base-sepolia.blockscout.com/address/$ASC_MANAGER"
    for x in elephant tiger shark eagle stakeholder lottery ; do 
        echo " - $x  https://base-sepolia.blockscout.com/address/$(cast_manager call $x'()(address)')"
    done
}
