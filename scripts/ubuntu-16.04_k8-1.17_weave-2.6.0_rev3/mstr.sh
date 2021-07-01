#!/usr/bin/env bash
set -e
while [ `systemctl is-active docker` != 'active' ]; do echo 'waiting for docker'; sleep 5; done
kubeadm init --kubernetes-version=v1.17.9 > /root/kubeadm-init.out
mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config

kubectl apply -f /root/weave_v2-6-0.yml
systemctl restart kubelet
while [ `systemctl is-active kubelet` != 'active' ]; do echo 'waiting for kubelet'; sleep 5; done
