#!/usr/bin/env bash

set -eu -o pipefail

function cmd_pref() {
    if type -p "$2" > /dev/null; then
        eval "$1=$2"
    else
        eval "$1=$3"
    fi
}

# If a g-prefixed version of the command exists, use it preferentially.
function gprefix() {
    cmd_pref "$1" "g$2" "$2"
}

gprefix READLINK readlink
cd "$(dirname "$("$READLINK" -f "$0")")/.."

# Allow user overrides to $MAKE. Typical usage for users who need it:
#   MAKE=gmake ./zcutil/build.sh -j$(nproc)
if [[ -z "${MAKE-}" ]]; then
    MAKE=make
fi

# Allow overrides to $BUILD and $HOST for porters. Most users will not need it.
#   BUILD=i686-pc-linux-gnu ./zcutil/build.sh
if [[ -z "${BUILD-}" ]]; then
    BUILD="$(./depends/config.guess)"
fi
if [[ -z "${HOST-}" ]]; then
    HOST="$BUILD"
fi

# Allow users to set arbitrary compile flags. Most users will not need this.
if [[ -z "${CONFIGURE_FLAGS-}" ]]; then
    CONFIGURE_FLAGS=""
fi

if [ "x$*" = 'x--help' ]
then
    cat <<EOF
Usage:
$0 --help
  Show this help message and exit.
$0 [ --enable-lcov || --disable-tests ] [ --disable-mining ] [ --enable-proton ] [ --disable-libs ] [--enable-websockets] [ --enable-debug ] [ MAKEARGS... ]
  Build Komodo and most of its transitive dependencies from
  source. MAKEARGS are applied to both dependencies and Komodo itself.
  If --enable-lcov is passed, Komodo is configured to add coverage
  instrumentation, thus enabling "make cov" to work.
  If --disable-tests is passed instead, the Komodo tests are not built.
  If --disable-mining is passed, Komodo is configured to not build any mining
  code. It must be passed after the test arguments, if present.
  If --enable-proton is passed, Komodo is configured to build the Apache Qpid Proton
  library required for AMQP support. This library is not built by default.
  It must be passed after the test/mining arguments, if present.
  If --enable-websockets is passed, Komodo is configured to build with websockets support for nspv protocol (disabled for now)
  If --enable-debug is passed, Komodo is built with debugging information. It
  must be passed after the previous arguments, if present.
EOF
    exit 0
fi

set -x

# If --enable-lcov is the first argument, enable lcov coverage support:
LCOV_ARG=''
HARDENING_ARG='--enable-hardening'
TEST_ARG=''
if [ "x${1:-}" = 'x--enable-lcov' ]
then
    LCOV_ARG='--enable-lcov'
    HARDENING_ARG='--disable-hardening'
    shift
elif [ "x${1:-}" = 'x--disable-tests' ]
then
    TEST_ARG='--enable-tests=no'
    shift
fi

# If --disable-mining is the next argument, disable mining code:
MINING_ARG=''
if [ "x${1:-}" = 'x--disable-mining' ]
then
    MINING_ARG='--enable-mining=no'
    shift
fi

# If --enable-proton is the next argument, enable building Proton code:
PROTON_ARG='--enable-proton=no'
if [ "x${1:-}" = 'x--enable-proton' ]
then
    PROTON_ARG=''
    shift
fi

# If --enable-debug is the next argument, enable debugging
DEBUGGING_ARG=''
if [ "x${1:-}" = 'x--enable-debug' ]
then
    DEBUG=1
    export DEBUG
    DEBUGGING_ARG='--enable-debug'
    shift
fi

if [[ -z "${VERBOSE-}" ]]; then
   VERBOSITY="--enable-silent-rules"
else
   VERBOSITY="--disable-silent-rules"
fi

# If --enable-websockets is the next argument, enable websockets support for nspv clients:
WEBSOCKETS_ARG=''
# if [ "x${1:-}" = 'x--enable-websockets' ]
# then
# WEBSOCKETS_ARG='--enable-websockets=yes'
# shift
# fi

eval "$MAKE" --version
as --version
ld -v

HOST="$HOST" BUILD="$BUILD" NO_PROTON="$PROTON_ARG" "$MAKE" "$@" -C ./depends/ V=1
./autogen.sh

CONFIG_SITE="$PWD/depends/$HOST/share/config.site" ./configure "$HARDENING_ARG" "$LCOV_ARG" "$TEST_ARG" "$MINING_ARG" "$PROTON_ARG" "$DEBUGGING_ARG" "$CONFIGURE_FLAGS" "$WEBSOCKETS_ARG" CXXFLAGS='-g' \
  --with-custom-bin=yes CUSTOM_BIN_NAME=grms CUSTOM_BRAND_NAME=GRMS \
  CUSTOM_SERVER_ARGS="'-ac_name=GRMS -ac_supply=100000 -ac_reward=1200000000,900000000,10000000 -ac_end=180700,900000,3600000 -ac_algo=verushash -ac_adaptivepow=6 -ac_eras=3 -ac_blocktime=30 -ac_veruspos=50 -ac_cbmaturity=3 -ac_cc=333 -ac_sapling=1 -addnode=91.231.187.163 -addnode=91.231.187.130 -addnode=91.231.187.105 -addnode=91.231.187.20 -addnode=91.231.187.113 -addnode=91.231.187.115 -addnode=91.231.187.116 -addnode=91.231.187.120 -nspv_msg=1'" \
  CUSTOM_CLIENT_ARGS='-ac_name=GRMS'

"$MAKE" "$@" V=1
