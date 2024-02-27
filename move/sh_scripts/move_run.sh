#!/bin/sh

set -e

echo "##### Running module function #####"

aptos move run \
	--assume-yes \
  --function-id 'local::manager::set_message' \
  --profile local \
#  --args 'string:Hi all'
