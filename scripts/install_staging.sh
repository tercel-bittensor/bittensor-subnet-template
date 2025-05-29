#!/bin/bash

# Check if the current directory contains bittensor-subnet-template
if [ ! -d "bittensor-subnet-template" ]; then
    echo "Please run this script from the parent directory of bittensor-subnet-template."
    echo "The bittensor-subnet-template directory is not found in the current directory."
    exit 1
fi

# Section 1: Build/Install
# This section is for first-time setup and installations.

install_dependencies() {
    # Function to install packages on macOS
    install_mac() {
        which brew > /dev/null
        if [ $? -ne 0 ]; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        echo "Updating Homebrew packages..."
        brew update
        echo "Installing required packages..."
        brew install make llvm curl libssl protobuf tmux
    }

    # Function to install packages on Ubuntu/Debian
    install_ubuntu() {
        echo "Updating system packages..."
        sudo apt update
        echo "Installing required packages..."
        sudo apt install --assume-yes make build-essential git clang curl libssl-dev llvm libudev-dev protobuf-compiler tmux
    }

    # Detect OS and call the appropriate function
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install_mac
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        install_ubuntu
    else
        echo "Unsupported operating system."
        exit 1
    fi

    # Install rust and cargo
    if ! command -v rustc &> /dev/null || ! command -v cargo &> /dev/null; then
        echo "Installing rust and cargo..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source "$HOME/.cargo/env"
    fi

    # Check for nightly toolchain
    if ! rustup toolchain list | grep -q nightly; then
        echo "Installing nightly toolchain..."
        rustup install nightly
    fi
}

# Call install_dependencies only if it's the first time running the script
if [ ! -f ".dependencies_installed" ]; then
    install_dependencies
    touch .dependencies_installed
fi


# Section 2: Test/Run
# This section is for running and testing the setup.

# Create a coldkey for the owner role
wallet=${1:-owner}

NO_PROMPT="" # --no_prompt

# Logic for setting up and running the environment
setup_environment() {
    # Clone subtensor and enter the directory
    if [ ! -d "subtensor" ]; then
        git clone https://github.com/opentensor/subtensor.git
    fi
    cd subtensor
    git pull

    # Update to the nightly version of rust
    ./scripts/init.sh

    cd ../bittensor-subnet-template

    # Install the bittensor-subnet-template python package
    python -m pip install -e .

    # Create and set up wallets
    # This section can be skipped if wallets are already set up
    if [ ! -f ".wallets_setup" ]; then
        btcli wallet new_coldkey --wallet.name $wallet --no_password $NO_PROMPT
        btcli wallet new_coldkey --wallet.name miner --no_password $NO_PROMPT
        btcli wallet new_hotkey --wallet.name miner --wallet.hotkey default $NO_PROMPT
        btcli wallet new_coldkey --wallet.name validator --no_password $NO_PROMPT
        btcli wallet new_hotkey --wallet.name validator --wallet.hotkey default $NO_PROMPT
        touch .wallets_setup
    fi

}

# Call setup_environment every time
setup_environment 

## Setup localnet
# assumes we are in the bittensor-subnet-template/ directory
# Initialize your local subtensor chain in development mode. This command will set up and run a local subtensor network.
cd ../subtensor

# Start a new tmux session and create a new pane, but do not switch to it
echo "FEATURES='pow-faucet runtime-benchmarks' BT_DEFAULT_TOKEN_WALLET=$(cat ~/.bittensor/wallets/$wallet/coldkeypub.txt | sed -nE 's/.*"ss58Address": ?"([^"]+)".*/\1/p') bash scripts/localnet.sh" >> setup_and_run.sh
chmod +x setup_and_run.sh
tmux new-session -d -s localnet -n 'localnet'
tmux send-keys -t localnet 'bash ../subtensor/setup_and_run.sh' C-m

# Notify the user
echo ">> localnet.sh is running in a detached tmux session named 'localnet'"
echo ">> You can attach to this session with: tmux attach-session -t localnet"

# Register a subnet (this needs to be run each time we start a new local chain)
btcli subnet create --wallet.name $wallet --wallet.hotkey default --subtensor.chain_endpoint ws://127.0.0.1:9944 $NO_PROMPT

# Transfer tokens to miner and validator coldkeys
export BT_MINER_TOKEN_WALLET=$(sed -nE 's/.*"ss58Address": ?"([^"]+)".*/\1/p' ~/.bittensor/wallets/miner/coldkeypub.txt)
export BT_VALIDATOR_TOKEN_WALLET=$(sed -nE 's/.*"ss58Address": ?"([^"]+)".*/\1/p' ~/.bittensor/wallets/validator/coldkeypub.txt)

btcli wallet transfer --subtensor.network ws://127.0.0.1:9944 --wallet.name $wallet --dest $BT_MINER_TOKEN_WALLET --amount 1 $NO_PROMPT
btcli wallet transfer --subtensor.network ws://127.0.0.1:9944 --wallet.name $wallet --dest $BT_VALIDATOR_TOKEN_WALLET --amount 1100 $NO_PROMPT

# Register wallet hotkeys to subnet
btcli subnet register --wallet.name miner --netuid 1 --wallet.hotkey default --subtensor.chain_endpoint ws://127.0.0.1:9944 $NO_PROMPT
btcli subnet register --wallet.name validator --netuid 1 --wallet.hotkey default --subtensor.chain_endpoint ws://127.0.0.1:9944 $NO_PROMPT

# Add stake to the validator
btcli stake add --wallet.name validator --wallet.hotkey default --subtensor.chain_endpoint ws://127.0.0.1:9944 --amount 1000 $NO_PROMPT

# Ensure both the miner and validator keys are successfully registered.
btcli subnet list --subtensor.chain_endpoint ws://127.0.0.1:9944
btcli wallet overview --wallet.name validator --subtensor.chain_endpoint ws://127.0.0.1:9944 $NO_PROMPT
btcli wallet overview --wallet.name miner --subtensor.chain_endpoint ws://127.0.0.1:9944 $NO_PROMPT

cd ../bittensor-subnet-template


# Check if inside a tmux session
if [ -z "$TMUX" ]; then
    # Start a new tmux session and run the miner in the first pane
    tmux new-session -d -s bittensor -n 'miner' 'python neurons/miner.py --netuid 1 --subtensor.chain_endpoint ws://127.0.0.1:9944 --wallet.name miner --wallet.hotkey default --logging.debug'
    
    # Split the window and run the validator in the new pane
    tmux split-window -h -t bittensor:miner 'python neurons/validator.py --netuid 1 --subtensor.chain_endpoint ws://127.0.0.1:9944 --wallet.name validator --wallet.hotkey default --logging.debug'
    
    # Attach to the new tmux session
    tmux attach-session -t bittensor
else
    # If already in a tmux session, create two panes in the current window
    tmux split-window -h 'python neurons/miner.py --netuid 1 --subtensor.chain_endpoint ws://127.0.0.1:9944 --wallet.name miner --wallet.hotkey default --logging.debug'
    tmux split-window -v -t 0 'python neurons/validator.py --netuid 1 --subtensor.chain_endpoint ws://127.0.0.1:9944 --wallet.name3 validator --wallet.hotkey default --logging.debug'
fi
