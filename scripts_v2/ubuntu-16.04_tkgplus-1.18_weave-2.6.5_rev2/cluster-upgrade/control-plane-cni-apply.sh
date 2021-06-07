#!/usr/bin/env bash

set -e

export kubever=$(kubectl version --client | base64 | tr -d '\n')
wget --no-verbose -O /root/weave.yml "https://cloud.weave.works/k8s/net?k8s-version=$kubever&v=2.6.5"
kubectl apply -f /root/weave.yml

# pull weave docker images in case cluster has no outbound internet access
docker pull weaveworks/weave-npc:2.6.5
docker pull weaveworks/weave-kube:2.6.5

systemctl restart kubelet
while [ `systemctl is-active kubelet` != 'active' ]; do echo 'waiting for kubelet'; sleep 5; done
