#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../functions.sh"
name="benchmark-$(random_name)"
pool="pool$(random_name)"
provider="Azure"

cleanup() {
  print_with_date "Running cleanup"

  rm /tmp/azure &>/dev/null
  az aks delete -y -g ${name} --name ${name}
  az group delete -y -n ${name}

  if [ $? -gt 0 ]; then
    print_with_date "Failed to clean up resources"
    echo $m
    exit
  fi
}

create_cluster() {
  print_with_date "Creating cluster..."

  az group create --location germanywestcentral --resource-group ${name} >/dev/null
  if [ $? -gt 0 ]; then
    print_with_date "Resource group creation failed"
    exit
  fi

  az aks create -n ${name} --enable-managed-identity --node-count 1 --node-vm-size standard_e2bds_v5 --generate-ssh-keys -g ${name} --nodepool-name ${pool} >/dev/null
  if [ $? -gt 0 ]; then
    print_with_date "Cluster creation failed"
    exit
  fi
}

create_service_account() {
  az aks get-credentials --name ${name} -g ${name} -f "/tmp/azure" >/dev/null

  if [ $? -gt 0 ]; then
    print_with_date "Failed to write credentials file"
    cleanup
    exit
  fi
}

add_node() {
  print_with_date "Adding a node to pool ${pool}"

  az aks scale -g ${name} -n ${name} --node-count 2 --nodepool-name "${pool}" >/dev/null

  if [ $? -gt 0 ]; then
    print_with_date "Failed to add another node"
    cleanup
    exit
  fi
}

create_cluster

end_cluster_create_timer

create_service_account

wait_for_ready_nodes "/tmp/azure" 1

end_cluster_ready_timer

# Add a new node and wait for it to be ready
start_add_node_timer

add_node

wait_for_ready_nodes "/tmp/azure" 2

end_add_node_timer

write_result
cleanup
