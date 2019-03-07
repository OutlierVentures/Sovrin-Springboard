#!/bin/bash

onred='\033[41m'
ongreen='\033[42m'
onyellow='\033[43m'
endcolor="\033[0m"

# Handle errors
set -e
error_report() {
    echo -e "${onred}Error: failed on line $1.$endcolor"
}
trap 'error_report $LINENO' ERR

get_latest() {
    if [ ! -d $2 ]; then
        git clone https://github.com/$1/$2.git --recursive
        cd $2
    else
        cd $2
        git pull
    fi
    cd ..
}

echo -e "${onyellow}Installing Hyperledger Indy...$endcolor"

if [[ "$OSTYPE" == "linux-gnu" ]]; then
    yes | sudo apt-get install build-essential \
                               git \
                               cmake \
                               python3 \
                               python3-pip \
                               python3-pytest
elif [[ "$OSTYPE" == "darwin"* ]]; then
    xcode-select --version || xcode-select --install
    brew --version || yes | /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    python3 --version || brew install python
    cmake --version || brew install cmake
fi
pip3 install --upgrade setuptools
pip3 install wheel
get_latest hyperledger indy-sdk
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 68DB5E88
    sudo add-apt-repository "deb https://repo.sovrin.org/sdk/deb xenial master"
    sudo apt-get update
    sudo apt-get install -y libindy
    pip3 install base58
elif [[ "$OSTYPE" == "darwin"* ]]; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    export PATH="$HOME/.cargo/bin:$PATH" # so can use cargo without relog
    brew install pkg-config \
                 https://raw.githubusercontent.com/Homebrew/homebrew-core/65effd2b617bade68a8a2c5b39e1c3089cc0e945/Formula/libsodium.rb \
                 automake \
                 autoconf \
                 openssl \
                 zeromq \
                 zmq
    export PKG_CONFIG_ALLOW_CROSS=1
    export CARGO_INCREMENTAL=1
    export RUST_LOG=indy=trace
    export RUST_TEST_THREADS=1
    for version in `ls -t /usr/local/Cellar/openssl/`; do
        export OPENSSL_DIR=/usr/local/Cellar/openssl/$version
        break
    done
    cd indy-sdk/libindy
    cargo build
    export LIBRARY_PATH=$(pwd)/target/debug
    cd ../cli
    cargo build
    echo 'export DYLD_LIBRARY_PATH='$LIBRARY_PATH'
export LD_LIBRARY_PATH='$LIBRARY_PATH >> ~/.bash_profile 
    cd ../..
fi
pip3 install python3-indy 
echo -e "${onyellow}Testing install...$endcolor"
cd indy-sdk/wrappers/python
pytest || true

echo -e "${ongreen}Hyperledger Indy installed. See test results above.$endcolor"
