#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../functions.sh"

name="benchmark-$(random_name)"
provider="Symbiosis"
endpoint=""

cleanup() {
  print_with_date "Running cleanup"

  rm /tmp/symbiosis

  sleep 2
  m=$(curl -s --fail -X DELETE \
    --url https://api.symbiosis.host/rest/v1/cluster/${name} \
    -H 'Content-Type: application/json' \
    -H "x-auth-apikey: ${SYMBIOSIS_API_KEY}" 2>&1)

  if [ $? -gt 0 ]; then
    print_with_date "Failed to clean up resources"
    echo $m
    exit
  fi

}

create_service_account() {
  print_with_date "Creating service account"
  result=""
  local iterations=0

  until [[ "${result}" != "" ]] || [ $iterations -gt 30 ]; do
    result=$(curl -s -X GET \
      --url https://api.symbiosis.host/rest/v1/cluster/${name}/identity \
      -H 'Content-Type: application/json' \
      -H "x-auth-apikey: ${SYMBIOSIS_API_KEY}")
    let iterations++
    sleep 1
  done

  if [ $iterations -gt 30 ]; then
    print_with_date "Failed to create service account"
    exit
  fi

  certificate=$(echo $result | jq -r '.certificatePem' | base64)
  private_key=$(echo $result | jq -r '.privateKeyPem' | base64)
  ca=$(echo $result | jq -r '.clusterCertificateAuthorityPem' | base64)

  cat <<EOF >/tmp/symbiosis
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${ca}
    server: "https://${endpoint}"
  name: ${name}
contexts:
- context:
    cluster: ${name}
    user: kubernetes-admin
  name: ${name}
current-context: ${name}
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: ${certificate}
    client-key-data: ${private_key}
EOF
}

create_cluster() {
  print_with_date "[Symbiosis] Creating cluster ${name}..."
  endpoint=$(curl -s --fail -X POST \
    --url https://api.symbiosis.host/rest/v1/cluster \
    -H 'Content-Type: application/json' \
    -H "x-auth-apikey: ${SYMBIOSIS_API_KEY}" \
    -d "{
    \"name\": \"${name}\",
    \"kubeVersion\": \"latest\",
    \"nodes\": [
        {
        \"nodeTypeName\": \"memory-2\",
        \"quantity\": 1
        }
    ],
    \"regionName\": \"germany-1\",
    \"isHighlyAvailable\": false
    }" | jq -r '.apiServerEndpoint')

  if [ $? -gt 0 ]; then
    print_with_date "Cluster creation failed"
    cleanup
    exit
  fi

  iterations=0
  while true; do

    # time out after approximately 30 minutes
    if [ $iterations -gt 1800 ]; then
      print_with_date "Cluster creation timed out"
      cleanup
      exit
    fi

    status=$(curl -s -X GET \
      --url "https://api.symbiosis.host/rest/v1/cluster/${name}" \
      -H 'Content-Type: application/json' \
      -H "x-auth-apikey: ${SYMBIOSIS_API_KEY}" | jq -r '.state')

    if [[ "${status}" == "ACTIVE" ]]; then
      break
    fi

    let iterations++
    sleep 1
  done

}

add_node() {
  node_pool_id=$(curl -s --fail -X POST \
    --url https://api.symbiosis.host/rest/v1/node-pool \
    -H 'Content-Type: application/json' \
    -H "x-auth-apikey: ${SYMBIOSIS_API_KEY}" \
    --data "{
    \"name\": \"${name}-pool1\",
    \"clusterName\": \"${name}\",
    \"nodeTypeName\": \"general-1\",
    \"quantity\": 1
  }" | jq -r '.id')

  if [ $? -gt 0 ]; then
    print_with_date "Failed to add a new node"
    exit
  fi

}

if [ -z "${SYMBIOSIS_API_KEY}" ]; then
  print_with_date "Symbiosis API key not set"
  exit
fi

create_cluster

end_cluster_create_timer

create_service_account

wait_for_ready_nodes "/tmp/symbiosis" 1

end_cluster_ready_timer

# Add a new node and wait for it to be ready
start_add_node_timer

add_node

wait_for_ready_nodes "/tmp/symbiosis" 2

end_add_node_timer

write_result
cleanup
