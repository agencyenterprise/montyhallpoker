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
  --profile ruby \
  --named-addresses poker=0x984eabe343cb95aeb2e79cbcf19b1fe4bfe43b9048bc093d7fc6591aa5367f08

