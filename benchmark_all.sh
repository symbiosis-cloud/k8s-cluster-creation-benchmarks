#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/functions.sh"
# controls how many benchmarks are run per provider
times=10

pids=""
for i in $(seq 1 ${times}); do
  for p in ${providers[@]}; do

    print_with_date "Benchmarking $p ..."
    bash providers/$p.sh &
    pids="$pids,$!"

  done

  for pid in ${pids//,/ }; do
    wait $pid
    print_with_date "Benchmarking run completed... Waiting 10 seconds before starting the next run."
    sleep 10
  done

done
