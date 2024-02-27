# Monty Hall Poker


## Running local testnet and Move module
Cd to `move` folder and run the following command to start the local testnet:
```bash
    sh_scripts/start_server.sh
```

to test the module, run the following command:
```bash
    sh_scripts/move_tests.sh
```

then compile and publish the module in local testnet:
```bash
    sh_scripts/move_publish.sh
```

then running a command is as simple as:
```bash
    sh_scripts/move_run.sh
```

For running the frontend, cd to `frontend` folder and run the following command:
```bash
    pnpm i
    pnpm dev
```

For adding the random network to the wallet, the following steps are to be followed:

Name: `randomnet`
Node url enters `https://fullnode.random.aptoslabs.com/v1`.
Faucet url enters `https://faucet.random.aptoslabs.com`.
