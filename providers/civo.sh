#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../functions.sh"
name="benchmark-$(random_name)"
provider="CIVO"

cleanup() {
  print_with_date "Running cleanup"

  rm /tmp/civo

  civo -y --region FRA1 kubernetes delete ${name}

  if [ $? -gt 0 ]; then
    print_with_date "Failed to clean up resources"
    echo $m
    exit
  fi
}

wait_for_cluster() {
  local iterations=0
  while true; do
    if [ $iterations -gt 1800 ]; then
      print_with_date "No nodes in ready state"
      echo 0
    fi

    $(civo kubernetes config --region FRA1 ${name} >/tmp/civo)
    if [ $? = 0 ]; then
      break
    fi

    let iterations++
    sleep 1
  done
}

add_node() {
  civo kubernetes node-pool create ${name} --size=g4s.kube.medium --nodes 1 --region FRA1

  if [ $? -gt 0 ]; then
    print_with_date "Adding node pool failed"
    cleanup
    exit
  fi
}

create_cluster() {
  print_with_date "Creating cluster..."

  civo -y kubernetes create ${name} --size=g4s.kube.medium --nodes 1 --region FRA1 --wait

  if [ $? -gt 0 ]; then
    print_with_date "Cluster creation failed"
    cleanup
    exit
  fi
}

create_cluster

end_cluster_create_timer

wait_for_cluster

wait_for_ready_nodes "/tmp/civo" 1

end_cluster_ready_timer

# Add a new node and wait for it to be ready
start_add_node_timer

add_node

wait_for_ready_nodes "/tmp/civo" 2

end_add_node_timer

write_result
cleanup
