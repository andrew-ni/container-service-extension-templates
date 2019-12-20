#!/usr/bin/env bash

set -e

echo 'upgrading packages to: kubelet=1.15.5-00 kubeadm=1.15.5-00 kubectl=1.15.5-00 kubernetes-cni=0.7.5-00'
apt-mark unhold kubeadm kubelet kubectl kubernetes-cni
apt-get -q update -o Acquire::Retries=3 -o Acquire::http::No-Cache=True -o Acquire::http::Timeout=20 -o Acquire::https::No-Cache=True -o Acquire::https::Timeout=20 -o Acquire::ftp::Timeout=20
apt-get -q install -y kubelet=1.15.5-00 kubeadm=1.15.5-00 kubectl=1.15.5-00 kubernetes-cni=0.7.5-00 --allow-unauthenticated
apt-mark hold kubeadm kubelet kubectl kubernetes-cni

echo 'upgrading kubeadm to v1.15.5'
while [ `systemctl is-active kubelet` != 'active' ]; do echo 'waiting for kubelet'; sleep 5; done
sleep 120
# sometimes master will be in 'NotReady' state for a few seconds
kubeadm upgrade apply v1.15.5 -y

systemctl restart kubelet
while [ `systemctl is-active kubelet` != 'active' ]; do echo 'waiting for kubelet'; sleep 5; done
