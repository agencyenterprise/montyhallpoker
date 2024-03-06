#!/bin/sh

set -e

echo "##### Running module function #####"

aptos move run \
  --function-id '0x2c48a1afc19e2fc88c85d28f7449c9fa6ff22ab7165553fcf50ca32d007366fe::poker_manager::join_game' \
  --profile local2 \
  --assume-yes \
  --args u64:1 u64:5000033
  

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
