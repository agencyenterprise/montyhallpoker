#!/bin/sh

set -e

echo "##### Publishing module #####"

# Profile is the account you used to execute transaction
# Run "aptos init" to create the profile, then get the profile name from .aptos/config.yaml

#echo | aptos init --profile local --network local --assume-yes

#echo | aptos init --profile local2 --network local --assume-yes

#echo | aptos init --profile local3 --network local --assume-yes

#echo | aptos init --profile local4 --network local --assume-yes

# PROFILE=0x2c48a1afc19e2fc88c85d28f7449c9fa6ff22ab7165553fcf50ca32d007366fe

aptos move publish \
	--assume-yes \
  --profile blush \
  --named-addresses poker=0x423ef3020fb7a779dedc4d26b202cfd76b516fc6f441d9f015205f212c687d14

