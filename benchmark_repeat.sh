#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/functions.sh"

# controls how many benchmarks are run per provider
provider=$1
times=$2

if [ ! -r providers/${provider}.sh ]; then
  echo "Provider ${provider} does not exist!"
  exit
fi

pids=""
for i in $(seq 1 ${times}); do

  echo "Executing providers/${provider}.sh ..."
  bash providers/${provider}.sh &
  pids="$pids,$!"

  for pid in ${pids//,/ }; do
    wait $pid
    sleep 10
  done

done
