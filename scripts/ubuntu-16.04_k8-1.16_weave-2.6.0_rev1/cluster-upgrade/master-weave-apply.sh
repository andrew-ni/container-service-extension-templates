#!/usr/bin/env bash

set -e

export kubever=$(kubectl version --client | base64 | tr -d '\n')
wget --no-verbose -O weave.yml "https://cloud.weave.works/k8s/net?k8s-version=$kubever&v=2.6.0"
kubectl apply -f /root/weave.yml
