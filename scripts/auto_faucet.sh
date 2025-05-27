#!/usr/bin/expect -f

if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

echo "TEST_WALLET_NAME: $TEST_WALLET_NAME"

set timeout 10
set wallet_name ${TEST_WALLET_NAME:-owner}
set endpoint ${TEST_ENDPOINT:-ws://127.0.0.1:9944}
set password $TEST_WALLET_PASSWORD

spawn btcli wallet faucet --wallet.name $wallet_name --subtensor.chain_endpoint $endpoint

expect "Run Faucet?"
send "y\r"

expect "Enter your password:"
send "$password\r"

expect eof