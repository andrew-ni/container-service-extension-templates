#!/usr/bin/env bash

set -e

# download Essential-PKS Kubernetes components and install them
wget https://downloads.heptio.com/vmware-tanzu-kubernetes-grid/523a448aa3e9a0ef93ff892dceefee0a/vmware-kubernetes-v1.19.3%2Bvmware.1.tar.gz
tar xvzf vmware-kubernetes-v1.19.3+vmware.1.tar.gz
dpkg -i vmware-kubernetes-v1.19.3+vmware.1/debs/*.deb || :
sudo apt-get -f install -y

# kube proxy
docker load < ./vmware-kubernetes-v1.19.3+vmware.1/kubernetes-v1.19.3+vmware.1/images/kube-proxy-v1.19.3_vmware.1.tar.gz

# kube controller manager
docker load < ./vmware-kubernetes-v1.19.3+vmware.1/kubernetes-v1.19.3+vmware.1/images/kube-controller-manager-v1.19.3_vmware.1.tar.gz

# kube api server
docker load < ./vmware-kubernetes-v1.19.3+vmware.1/kubernetes-v1.19.3+vmware.1/images/kube-apiserver-v1.19.3_vmware.1.tar.gz

# kube scheduler
docker load < ./vmware-kubernetes-v1.19.3+vmware.1/kubernetes-v1.19.3+vmware.1/images/kube-scheduler-v1.19.3_vmware.1.tar.gz

# pause
docker load < ./vmware-kubernetes-v1.19.3+vmware.1/kubernetes-v1.19.3+vmware.1/images/pause-3.2.tar.gz

# e2e test
docker load < ./vmware-kubernetes-v1.19.3+vmware.1/kubernetes-v1.19.3+vmware.1/images/e2e-test-v1.19.3_vmware.1.tar.gz

# etcd
docker load < ./vmware-kubernetes-v1.19.3+vmware.1/etcd-v3.4.13+vmware.4/images/etcd-v3.4.13_vmware.4.tar.gz

# coredns
docker load < ./vmware-kubernetes-v1.19.3+vmware.1/coredns-v1.7.0+vmware.5/images/coredns-v1.7.0_vmware.5.tar.gz


docker tag registry.tkg.vmware.run/kube-proxy:v1.19.3_vmware.1 localhost:5000/kube-proxy:v1.19.3
docker tag registry.tkg.vmware.run/kube-controller-manager:v1.19.3_vmware.1 localhost:5000/kube-controller-manager:v1.19.3
docker tag registry.tkg.vmware.run/kube-apiserver:v1.19.3_vmware.1 localhost:5000/kube-apiserver:v1.19.3
docker tag registry.tkg.vmware.run/kube-scheduler:v1.19.3_vmware.1 localhost:5000/kube-scheduler:v1.19.3
docker tag registry.tkg.vmware.run/pause:3.2 localhost:5000/pause:3.2
docker tag registry.tkg.vmware.run/e2e-test:v1.19.3_vmware.1 localhost:5000/e2e-test:v1.19.3
docker tag registry.tkg.vmware.run/etcd:v3.4.13_vmware.4 localhost:5000/etcd:3.4.13-0
docker tag registry.tkg.vmware.run/coredns:v1.7.0_vmware.5  localhost:5000/coredns:1.7.0

docker push localhost:5000/kube-proxy:v1.19.3
docker push localhost:5000/kube-controller-manager:v1.19.3
docker push localhost:5000/kube-apiserver:v1.19.3
docker push localhost:5000/kube-scheduler:v1.19.3
docker push localhost:5000/pause:3.2
docker push localhost:5000/e2e-test:v1.19.3
docker push localhost:5000/etcd:3.4.13-0
docker push localhost:5000/coredns:1.7.0


# pull weave docker images in case cluster has no outbound internet access
docker pull weaveworks/weave-npc:2.6.5
docker pull weaveworks/weave-kube:2.6.5


echo 'upgrading kubeadm to v1.19.3+vmware.1'
while [ `systemctl is-active kubelet` != 'active' ]; do echo 'waiting for kubelet'; sleep 5; done
sleep 120
kubeadm upgrade apply 1.19.3 -y

# delete downloaded Tanzu Kubernetes grid plus
rm -rf vmware-kubernetes-v1.19.3+vmware.1 || :
rm vmware-kubernetes-v1.19.3+vmware.1.tar.gz || :

systemctl restart kubelet
while [ `systemctl is-active kubelet` != 'active' ]; do echo 'waiting for kubelet'; sleep 5; done
