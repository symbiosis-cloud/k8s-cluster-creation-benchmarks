#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../functions.sh"
name="benchmark-$(random_name)"
provider="AWS"
node_pool_id=""

cleanup() {
  print_with_date "Running cleanup"
  rm /tmp/aws
  eksctl delete cluster --name=${name} &>/dev/null

  if [ $? -gt 0 ]; then
    print_with_date "Failed to clean up resources"
    print_with_date $m
    exit
  fi
}

create_cluster() {
  print_with_date "Creating cluster ${name}..."

  eksctl create cluster --managed=false --name=${name} --region eu-central-1 --nodes=1 --nodes-max=2 --kubeconfig=/tmp/aws &>/dev/null

  if [ $? -gt 0 ]; then
    print_with_date "Cluster creation failed"
    cleanup
    exit
  fi

  node_pool_id="$(eksctl get nodegroup --cluster ${name} -o json | jq -r '.[0].Name')"
}

add_node() {
  eksctl scale nodegroup --cluster ${name} ${node_pool_id} --nodes=2

  if [ $? -gt 0 ]; then
    print_with_date "Failed to create additional node pool"
    cleanup
    exit
  fi
}

$(eksctl get cluster &>/dev/null)

if [ $? -gt 0 ]; then
  print_with_date "Failed to retrieve clusters, please check your aws credentials and make sure you have the proper access rights."
  exit
fi

create_cluster

# eksctl waits for the cluster to be ready so we don't get an accurate reading when the cluster was created
# nor do we need to wait until the first node comes online
end_cluster_create_timer
end_cluster_ready_timer

# Add a new node and wait for it to be ready
start_add_node_timer

add_node

wait_for_ready_nodes "/tmp/aws" 2

end_add_node_timer

write_result

cleanup
