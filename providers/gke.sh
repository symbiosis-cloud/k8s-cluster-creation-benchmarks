#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../functions.sh"
name="benchmark-$(random_name)"
provider="Google Cloud"

# GKE specific. See: https://cloud.google.com/blog/products/containers-kubernetes/kubectl-auth-changes-in-gke
export USE_GKE_GCLOUD_AUTH_PLUGIN=False

cleanup() {
  print_with_date "Running cleanup"

  rm /tmp/gke 2>/dev/null

  local output=$(gcloud -q container clusters delete ${name} --zone "europe-west3-a" 2>&1)

  if [ $? -gt 0 ]; then
    print_with_date "Failed to clean up resources"
    print_with_date $output
    echo $m
    exit
  fi
}

create_cluster() {
  print_with_date "Creating cluster ${name}..."
  local output=$(gcloud -q container clusters create "${name}" --zone "europe-west3-a" --no-enable-basic-auth --cluster-version "1.22.12-gke.300" --release-channel "regular" --machine-type "e2-standard-2" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --max-pods-per-node "110" --num-nodes "1" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias --network "projects/maxroll-282019/global/networks/default" --subnetwork "projects/maxroll-282019/regions/europe-west3/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --node-locations europe-west3-a --location-policy ANY 2>&1)

  if [ $? -gt 0 ]; then
    print_with_date "Cluster creation failed"
    print_with_date $output
    cleanup
    exit
  fi

  local output=$(KUBECONFIG=/tmp/gke gcloud container clusters get-credentials "${name}" --zone "europe-west3-a" 2>&1)

  if [ $? -gt 0 ]; then
    print_with_date "Failed to retrieve credentials"
    print_with_date $output
    cleanup
    exit
  fi
}

add_node() {
  local output=$(gcloud -q container clusters resize ${name} --num-nodes 2 --async --zone "europe-west3-a" 2>&1)

  if [ $? -gt 0 ]; then
    print_with_date "Failed to resize clusters"
    print_with_date $output
    cleanup
    exit
  fi
}

create_cluster

end_cluster_create_timer

wait_for_ready_nodes "/tmp/gke" 1

end_cluster_ready_timer

# Add a new node and wait for it to be ready
start_add_node_timer

add_node

wait_for_ready_nodes "/tmp/gke" 2

end_add_node_timer

write_result
cleanup
