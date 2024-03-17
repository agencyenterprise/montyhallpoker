#!/bin/sh

set -e

echo "##### Running module function #####"

aptos move run \
  --function-id '0xe4ab044df91caf41e1b13ea1a2d57a72f5d9a3b8edb52755046e3f5d3d3082d7::poker_manager::join_game' \
  --profile testlolo52 \
  --assume-yes \
  --args u64:1 u64:5000000

aptos move run \
  --function-id '0x2c48a1afc19e2fc88c85d28f7449c9fa6ff22ab7165553fcf50ca32d007366fe::poker_manager::join_game' \
  --profile testlolo52 \
  --assume-yes \
  --args u64:1 u64:5000000
  

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
