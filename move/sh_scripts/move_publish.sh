#!/bin/sh

set -e

echo "##### Publishing module #####"

# Profile is the account you used to execute transaction
# Run "aptos init" to create the profile, then get the profile name from .aptos/config.yaml

echo | aptos init --profile local --network local --assume-yes

echo | aptos init --profile local2 --network local --assume-yes

# PROFILE=0x2c48a1afc19e2fc88c85d28f7449c9fa6ff22ab7165553fcf50ca32d007366fe

aptos move publish \
	--assume-yes \
  --profile local \
  --named-addresses poker_manager=local



aptos move view \
    --profile local \
    --function-id 0x2c48a1afc19e2fc88c85d28f7449c9fa6ff22ab7165553fcf50ca32d007366fe::poker_manager::get_game_by_id \
    --args u64:1

