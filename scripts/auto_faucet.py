import os
import pexpect

def load_env():
    if not os.path.exists('.env'):
        print("Error: .env file not found")
        exit(1)
    with open('.env') as f:
        for line in f:
            if line.strip() and not line.startswith('#'):
                key, value = line.strip().split('=', 1)
                os.environ[key] = value

load_env()

wallet_name = os.environ.get('TEST_WALLET_NAME', 'owner')
endpoint = os.environ.get('TEST_ENDPOINT', 'ws://127.0.0.1:9944')
password = os.environ.get('TEST_WALLET_PASSWORD', '')

cmd = f'btcli wallet faucet --wallet.name {wallet_name} --subtensor.chain_endpoint {endpoint}'
child = pexpect.spawn(cmd)

child.expect('Run Faucet?')
child.sendline('y')
child.expect('Enter your password:')
child.sendline(password)
child.expect(pexpect.EOF)