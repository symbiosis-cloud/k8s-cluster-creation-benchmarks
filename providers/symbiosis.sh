#!/bin/bash

cleanup()  {
    echo "Running cleanup"
    sleep 2
    m=$(curl -s --fail --request DELETE \
    --url https://api.symbiosis.host/rest/v1/cluster/benchmark-123 \
    --header 'Content-Type: application/json' \
    --header "x-auth-apikey: ${SYMBIOSIS_API_KEY}" 2>&1)


    if [ $? != 0 ]; then
        echo "Failed to clean up resources"
        echo $m
        exit
    fi
}


createCluster() {
    echo "[Symbiosis] Creating cluster..."
    curl -s --fail --request POST -o /dev/null \
  --url https://api.symbiosis.host/rest/v1/cluster \
  --header 'Content-Type: application/json' \
  --header "x-auth-apikey: ${SYMBIOSIS_API_KEY}" \
  --data '{
  "name": "benchmark-123",
  "kubeVersion": "latest",
  "nodes": [
    {
      "nodeTypeName": "general-1",
      "quantity": 1
    }
  ],
  "regionName": "germany-1",
  "isHighlyAvailable": false
}'

    if [ $? != 0 ]; then
        echo "Cluster creation failed"
        cleanup
        exit
    fi

    iterations=0
    while true; do

        # time out after approximately 1 hour
        if [ $iterations -gt 3600 ]; then
            echo "Cluster creation timed out"
            cleanup
            exit
        fi

        status=$(curl -s --request GET \
  --url 'https://api.symbiosis.host/rest/v1/cluster/benchmark-123' \
  --header 'Content-Type: application/json' \
  --header "x-auth-apikey: ${SYMBIOSIS_API_KEY}" | jq -r '.state')

        if [[ "${status}" == "ACTIVE" ]]; then
            break
        fi


        let iterations++
        sleep 1
    done

}

if [ -z "${SYMBIOSIS_API_KEY}" ]; then
    echo "Symbiosis API key not set"
    exit
fi

start=`date +%s`
createCluster
endCreateCluster=`date +%s`

createClusterTime=$((endCreateCluster-start))

echo "Symbiosis cluster ready in ${createClusterTime} seconds"

cleanup