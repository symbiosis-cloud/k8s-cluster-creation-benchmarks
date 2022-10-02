#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../functions.sh"

name="benchmark-$(random_name)"
provider="Scaleway"
cluster_id=""
node_pool_id=""

cleanup() {
  print_with_date "Running cleanup"
  rm /tmp/scaleway

  scw k8s cluster delete $1 region=nl-ams with-additional-resources=true --wait &>/dev/null
  if [ $? -gt 0 ]; then
    print_with_date "Failed to clean up resources"
    echo $m
    exit
  fi
}

create_cluster() {
  print_with_date "Creating cluster..."
  cluster_id=$(scw k8s cluster create name=${name} region=nl-ams pools.0.zone=nl-ams-2 pools.0.size=1 pools.0.node-type=DEV1_M pools.0.name=default -w -o json | jq -r '.id')
  node_pool_id=$(scw k8s cluster get ${cluster_id} region=nl-ams -o json | jq -r '.pools[0].id')

  if [ $? -gt 0 ] || [[ "${cluster_id}" == "" ]]; then
    print_with_date "Cluster creation failed"
    cleanup
    exit
  fi
}

add_node() {
  print_with_date "Adding a node to pool ${node_pool_id}"

  scw k8s pool update ${node_pool_id} region=nl-ams size=2 >/dev/null
  if [ $? -gt 0 ]; then
    print_with_date "Failed to update existing node pool"
    exit
  fi
}

create_cluster

end_cluster_create_timer

scw k8s kubeconfig get ${cluster_id} region=nl-ams >/tmp/scaleway

wait_for_ready_nodes "/tmp/scaleway" 1

end_cluster_ready_timer

# Add a new node and wait for it to be ready
start_add_node_timer

add_node

wait_for_ready_nodes "/tmp/scaleway" 2

end_add_node_timer

write_result

cleanup "${cluster_id}"
