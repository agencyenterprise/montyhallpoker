#!/bin/sh

set -e

echo "##### Running module function #####"

aptos move run \
  --function-id '0x9f535b0ec315f49bc4e3aea04e79b28fb5077726aeb9eb09276d3ef0ad1e0953::poker_manager::skip_inactive_player' \
  --profile testlolo52 \
  --assume-yes \
  --args u64:13

aptos move run \
  --function-id '0x598d48199c7214e2e080cce37ceac7d6a34c8bad56631a921717ee7a2e17f5f6::poker_manager::perform_action' \
  --profile flushy \
  --assume-yes \
  --args u64:3 u64:0 u64:0

aptos move run \
  --function-id '0x7436bbe16422c873f3d81bf1668b96ef50f2c6624a851c1a991c92de1b253b29::poker_manager::perform_action' \
  --profile default \
  --assume-yes \
  --args u64:1 u64:1 u64:5000012

aptos move run \
  --function-id '0x7436bbe16422c873f3d81bf1668b96ef50f2c6624a851c1a991c92de1b253b29::poker_manager::perform_action' \
  --profile testlolo \
  --assume-yes \
  --args u64:1 u64:1 u64:5000012
  

#curl --request POST \
#  --url http://127.0.0.1:8080/v1/view \
#  --header 'Accept: application/json, application/x-bcs' \
#  --header 'Content-Type: application/json' \
#  --data '{
#  "function": "0x2c48a1afc19e2fc88c85d28f7449c9fa6ff22ab7165553fcf50ca32d007366fe::poker_manager::get_gamestate",
#  "type_arguments": [
#  ],
#  "arguments": [
#  ]
#}'
