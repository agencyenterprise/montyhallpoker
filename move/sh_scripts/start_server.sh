#!/bin/sh

set -e

echo "##### Restarting server #####"

yes | aptos node run-local-testnet --force-restart