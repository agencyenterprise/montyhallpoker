#!/bin/sh

set -e

echo "##### Running module function #####"

aptos move run \
  --function-id '0x7436bbe16422c873f3d81bf1668b96ef50f2c6624a851c1a991c92de1b253b29::poker_manager::perform_action' \
  --profile testlolo52 \
  --assume-yes \
  --args u64:1 u64:1 u64:5000012

aptos move run \
  --function-id '0x7436bbe16422c873f3d81bf1668b96ef50f2c6624a851c1a991c92de1b253b29::poker_manager::perform_action' \
  --profile testlolo51 \
  --assume-yes \
  --args u64:1 u64:1 u64:5000012

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
