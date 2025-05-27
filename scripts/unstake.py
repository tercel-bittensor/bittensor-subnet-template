import bittensor as bt
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--amount', type=float, default=1.0, help='Unstake amount (default: 1.0)')
parser.add_argument('--netuid', type=int, default=2, help='NetUID (default: 2)')
parser.add_argument('--network', type=str, default='local', help='Network (default: local)')
parser.add_argument('--chain-endpoint', type=str, default='ws://127.0.0.1:9944', help='Chain endpoint (default: ws://127.0.0.1:9944)')
parser.add_argument('--wallet-name', type=str, default='owner', help='Wallet name (default: owner)')
parser.add_argument('--wallet-hotkey', type=str, default='miner_hotkey', help='Wallet hotkey (default: miner_hotkey)')
bt.subtensor.add_args(parser)
config = bt.config(parser)
config.subtensor.network = config.network
config.subtensor.chain_endpoint = config.chain_endpoint

subtensor = bt.subtensor(config=config)

netuid = config.netuid
amount = config.amount

wallet = bt.wallet(name=config.wallet_name, hotkey=config.wallet_hotkey)

subtensor.unstake(
    netuid=netuid,
    wallet=wallet,
    amount=amount,
)
print("Unstake submitted.")