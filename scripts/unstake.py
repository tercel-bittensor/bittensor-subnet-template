import bittensor as bt
import argparse

wallet = bt.wallet(name="owner", hotkey="miner_hotkey")

# use argparse and bt.config to create config
parser = argparse.ArgumentParser()
bt.subtensor.add_args(parser)
config = bt.config(parser)
config.subtensor.network = "local"
config.subtensor.chain_endpoint = "ws://127.0.0.1:9944"

subtensor = bt.subtensor(config=config)

netuid = 2
amount = 1.0  # unstake amount

subtensor.unstake(
    netuid=netuid,
    wallet=wallet,
    amount=amount,
)
print("Unstake submitted.")