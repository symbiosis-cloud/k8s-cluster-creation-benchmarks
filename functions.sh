#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

provider=""
start=$(date +%s)
start_add_nodes=""

providers=("symbiosis scaleway linode gke do civo azure aws")

total_time_created=""
total_time_ready=""
total_time_node_added=""

write_result() {
  echo "${provider},${total_time_created},${total_time_ready},${total_time_node_added}" >>${SCRIPT_DIR}/results.csv

  cat <<EOF
------------------------------------------------------------------------------
                     Final results for ${provider}
------------------------------------------------------------------------------

Event                                     Seconds
------------------------------------------------------------------------------
Cluster created                           ${total_time_created}
Cluster ready for use                     ${total_time_ready}
Scale up finished                         ${total_time_node_added}
------------------------------------------------------------------------------

EOF
}

end_cluster_create_timer() {
  local current=$(date +%s)
  total_time_created=$((current - start))
  print_with_date "Cluster created in ${total_time_created} seconds"
}

end_cluster_ready_timer() {
  local current=$(date +%s)
  total_time_ready=$((current - start))
  print_with_date "Cluster fully ready in ${total_time_ready} seconds"
}

start_add_node_timer() {
  start_add_nodes=$(date +%s)
}

end_add_node_timer() {
  local current=$(date +%s)
  total_time_node_added=$((current - start_add_nodes))
  print_with_date "Added node fully ready in ${total_time_node_added} seconds"
}

wait_for_ready_nodes() {
  print_with_date "Polling for ready nodes"
  local iterations=1
  local config=$1
  local expected_nodes=$2

  while true; do

    if [ $iterations -gt 1800 ]; then
      print_with_date "Timeout: No nodes in ready state"
      break
    fi

    if [ ! -r ${config} ]; then
      print_with_date "Failed to read KUBECONFIG! Check get credentials call"
      break
    fi

    nodes=$(KUBECONFIG=${config} kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.conditions[] | select(.type=="Ready" and .status=="True")] | length')

    if [[ "$nodes" == "${expected_nodes}" ]]; then
      break
    fi

    repeat_print_with_date "Found ${nodes} ready nodes, expected ${expected_nodes} node(s). Took ${iterations} seconds so far..."

    let iterations++
    sleep 1
  done

  echo -n
}

print_with_date() {
  echo "[$(date)] [${provider}] $1"
}

repeat_print_with_date() {
  echo -ne "[$(date)] [${provider}] $1 \r"
}

random_name() {
  openssl rand -hex 3
}
