#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../functions.sh"

name="benchmark-$(random_name)"
provider="Linode"
cluster_id=""

cleanup() {
  rm /tmp/linode

  linode-cli lke cluster-delete ${cluster_id}
  if [ $? -gt 0 ]; then
    echo "Failed to clean up resources"
    echo $m
    exit
  fi
}

wait_for_cluster() {
  print_with_date "Trying to retrieve credentials..."

  local iterations=0
  while true; do
    if [ $iterations -gt 1800 ]; then
      echo "No nodes in ready state"
      echo 0
    fi

    $(linode-cli lke kubeconfig-view ${cluster_id} &>/dev/null)
    if [ $? = 0 ]; then
      $(linode-cli lke kubeconfig-view ${cluster_id} --json | jq -r '.[0].kubeconfig' | base64 -d >/tmp/linode)
      break
    fi

    let iterations++
    sleep 1
  done
}

create_cluster() {

  print_with_date "Creating cluster"
  # create the cluster
  cluster=$(linode-cli lke cluster-create --node_pools.count 1 --node_pools.type g6-standard-4 --label ${name} --k8s_version 1.23 --json)

  if [ $? -gt 0 ]; then
    echo "Cluster creation failed: ${cluster}"
    exit
  fi

  cluster_id=$(echo $cluster | jq -r '.[0].id')
}

add_node() {
  linode-cli lke pool-create ${cluster_id} --count 1 --type g6-standard-4

  if [ $? -gt 0 ]; then
    echo "adding nodepool failed for cluster ${cluster_id}"
    cleanup
    exit
  fi
}

create_cluster

end_cluster_create_timer

wait_for_cluster

wait_for_ready_nodes "/tmp/linode" 1

end_cluster_ready_timer

# Add a new node and wait for it to be ready
start_add_node_timer

add_node

wait_for_ready_nodes "/tmp/linode" 2

end_add_node_timer

write_result
cleanup
