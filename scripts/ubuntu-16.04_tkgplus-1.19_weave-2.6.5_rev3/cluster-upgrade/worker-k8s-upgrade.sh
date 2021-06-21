#!/usr/bin/env bash

set -e

kubernetes_version=v1.19.3-vmware.1
etcd_image_version=v3.4.13-vmware.4
coredns_image_version=v1.7.0-vmware.5
pause_image_version=3.2

vmware_kubernetes_dir_name=vmware-kubernetes-v1.19.3+vmware.1
kubernetes_sub_dir=kubernetes-v1.19.3+vmware.1/images
etcd_sub_dir=etcd-v3.4.13+vmware.4/images
coredns_sub_dir=coredns-v1.7.0+vmware.5/images

kubeadm_config_path=/root/kubeadm-defaults.yaml

# download Essential-PKS Kubernetes components and install them
wget https://downloads.heptio.com/vmware-tanzu-kubernetes-grid/523a448aa3e9a0ef93ff892dceefee0a/vmware-kubernetes-v1.19.3%2Bvmware.1.tar.gz
tar xvzf $vmware_kubernetes_dir_name.tar.gz
dpkg -i $vmware_kubernetes_dir_name/debs/*.deb || :
sudo apt-get -f install -y

# kube proxy
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/kube-proxy-v1.19.3_vmware.1.tar.gz

# kube controller manager
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/kube-controller-manager-v1.19.3_vmware.1.tar.gz

# kube api server
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/kube-apiserver-v1.19.3_vmware.1.tar.gz

# kube scheduler
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/kube-scheduler-v1.19.3_vmware.1.tar.gz

# pause
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/pause-3.2.tar.gz

# e2e test
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/e2e-test-v1.19.3_vmware.1.tar.gz

# etcd
docker load -i ./$vmware_kubernetes_dir_name/$etcd_sub_dir/etcd-v3.4.13_vmware.4.tar.gz

# coredns
docker load -i ./$vmware_kubernetes_dir_name/$coredns_sub_dir/coredns-v1.7.0_vmware.5.tar.gz


docker tag registry.tkg.vmware.run/kube-proxy:v1.19.3_vmware.1 k8s.gcr.io/kube-proxy:$kubernetes_version
docker tag registry.tkg.vmware.run/kube-controller-manager:v1.19.3_vmware.1 k8s.gcr.io/kube-controller-manager:$kubernetes_version
docker tag registry.tkg.vmware.run/kube-apiserver:v1.19.3_vmware.1 k8s.gcr.io/kube-apiserver:$kubernetes_version
docker tag registry.tkg.vmware.run/kube-scheduler:v1.19.3_vmware.1 k8s.gcr.io/kube-scheduler:$kubernetes_version
docker tag registry.tkg.vmware.run/pause:$pause_image_version k8s.gcr.io/pause:$pause_image_version
docker tag registry.tkg.vmware.run/e2e-test:v1.19.3_vmware.1 k8s.gcr.io/e2e-test:$kubernetes_version
docker tag registry.tkg.vmware.run/etcd:v3.4.13_vmware.4 k8s.gcr.io/etcd:$etcd_image_version
docker tag registry.tkg.vmware.run/coredns:v1.7.0_vmware.5  k8s.gcr.io/coredns:$coredns_image_version

# pull weave docker images in case cluster has no outbound internet access
docker pull weaveworks/weave-npc:2.6.5
docker pull weaveworks/weave-kube:2.6.5

# create /root/v
echo "---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
dns:
  type: CoreDNS
  imageRepository: k8s.gcr.io
  imageTag: $coredns_image_version
etcd:
  local:
    imageRepository: k8s.gcr.io
    imageTag: $etcd_image_version
imageRepository: k8s.gcr.io
kubernetesVersion: $kubernetes_version
---" > $kubeadm_config_path

echo 'upgrading kubeadm to v1.19.3+vmware.1'
while [ `systemctl is-active kubelet` != 'active' ]; do echo 'waiting for kubelet'; sleep 5; done
sleep 120
kubeadm upgrade --config=$kubeadm_config_path

# delete downloaded Tanzu Kubernetes grid plus
rm -rf $vmware_kubernetes_dir_name || :
rm $vmware_kubernetes_dir_name.tar.gz || :

systemctl restart kubelet
while [ `systemctl is-active kubelet` != 'active' ]; do echo 'waiting for kubelet'; sleep 5; done
