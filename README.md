# Kubernetes Cluster Creation Benchmarks

---

## What are we benchmarking?

We are benchmarking:

- Cluster creation
- Cluster ready to use
- Scaling a node pool (+1 node)

## Requirements

- curl
- bash
- jq

## How to run

```sh
# this will take quite a long time
$ bash benchmark_all.sh 10 # run the benchmark 10 times
```

## Installation

### Symbiosis

- only curl and jq are required

### AWS

- Configured AWS CLI
- eksctl

### CIVO

- Configured CIVO CLI

### Azure

- Configured Azure CLI

** Note ** A resource group called benchmark-azure will be created but not removed automatically.

### Scaleway

- Configured Sclaway CL

### Linode

- Configured Linode CLI

### Google Cloud

- Configured Google Cloud CLI

### Digitalocean

- Configured Digitalocean CLI
