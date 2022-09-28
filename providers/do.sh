#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../functions.sh"
name="benchmark-$(random_name)"
provider="DigitalOcean"
pool="pool$(random_name)"

cleanup() {
  print_with_date "Running cleanup"
  rm /tmp/digitalocean &>/dev/null

  doctl kubernetes cluster delete -f ${name}
  if [ $? -gt 0 ]; then
    print_with_date "Failed to clean up resources"
    echo $m
    exit
  fi
}

create_cluster() {
  print_with_date "Creating cluster ${name}..."
  doctl kubernetes cluster create ${name} \
    --node-pool "name=${pool};size=s-2vcpu-4gb;count=1" \
    --update-kubeconfig=false --region fra1 --wait >/dev/null

  if [ $? -gt 0 ]; then
    print_with_date "Cluster creation failed"
    cleanup
    exit
  fi

  doctl kubernetes cluster kubeconfig show ${name} >/tmp/digitalocean
}

add_node() {

  print_with_date "Adding node to pool ${pool}"
  doctl kubernetes cluster node-pool update ${name} ${pool} --count 2 >/dev/null

  if [ $? -gt 0 ]; then
    print_with_date "Failed to add additional node to pool"
    cleanup
    exit
  fi
}

create_cluster

end_cluster_create_timer

wait_for_ready_nodes "/tmp/digitalocean" 1

end_cluster_ready_timer

# Add a new node and wait for it to be ready
start_add_node_timer

add_node

wait_for_ready_nodes "/tmp/digitalocean" 2

end_add_node_timer

write_result
cleanup
