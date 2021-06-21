#!/usr/bin/env bash

# exit script if any command has nonzero exit code
set -e

kubernetes_version=v1.18.10-vmware.1
etcd_image_version=v3.4.3-vmware.11
coredns_image_version=v1.6.7-vmware.6
pause_image_version=3.2

vmware_kubernetes_dir_name=vmware-kubernetes-v1.18.10+vmware.1
kubernetes_sub_dir=kubernetes-v1.18.10+vmware.1/images
etcd_sub_dir=etcd-v3.4.3+vmware.11/images
coredns_sub_dir=coredns-v1.6.7+vmware.6/images

# disable ipv6 to avoid possible connection errors
echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
sudo sysctl -p

echo 'nameserver 8.8.8.8' >> /etc/resolvconf/resolv.conf.d/tail
resolvconf -u

systemctl restart networking.service
while [ `systemctl is-active networking` != 'active' ]; do echo 'waiting for network'; sleep 5; done

# '|| :' ensures that exit code is 0
growpart /dev/sda 1 || :
resize2fs /dev/sda1 || :

# redundancy: https://github.com/vmware/container-service-extension/issues/432
systemctl restart networking.service
while [ `systemctl is-active networking` != 'active' ]; do echo 'waiting for network'; sleep 5; done

echo 'installing docker'
export DEBIAN_FRONTEND=noninteractive
apt-get -q update -o Acquire::Retries=3 -o Acquire::http::No-Cache=True -o Acquire::http::Timeout=20 -o Acquire::https::No-Cache=True -o Acquire::https::Timeout=20 -o Acquire::ftp::Timeout=20
apt-get -q install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get -q update -o Acquire::Retries=3 -o Acquire::http::No-Cache=True -o Acquire::http::Timeout=20 -o Acquire::https::No-Cache=True -o Acquire::https::Timeout=20 -o Acquire::ftp::Timeout=20
apt-get -q install -y docker-ce=5:19.03.12~3-0~ubuntu-xenial
apt-get -q install -y docker-ce-cli=5:19.03.12~3-0~ubuntu-xenial --allow-downgrades

systemctl restart docker
while [ `systemctl is-active docker` != 'active' ]; do echo 'waiting for docker'; sleep 5; done

# download Essential-PKS Kubernetes components and install them
wget https://downloads.heptio.com/vmware-tanzu-kubernetes-grid/523a448aa3e9a0ef93ff892dceefee0a/vmware-kubernetes-v1.18.10%2Bvmware.1.tar.gz
tar xvzf $vmware_kubernetes_dir_name.tar.gz
dpkg -i $vmware_kubernetes_dir_name/debs/*.deb || :
sudo apt-get -f install -y

# kube proxy
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/kube-proxy-v1.18.10_vmware.1.tar.gz

# kube controller manager
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/kube-controller-manager-v1.18.10_vmware.1.tar.gz

# kube api server
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/kube-apiserver-v1.18.10_vmware.1.tar.gz

# kube scheduler
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/kube-scheduler-v1.18.10_vmware.1.tar.gz

# pause
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/pause-3.2.tar.gz

# e2e test
docker load -i ./$vmware_kubernetes_dir_name/$kubernetes_sub_dir/e2e-test-v1.18.10_vmware.1.tar.gz

# etcd
docker load -i ./$vmware_kubernetes_dir_name/$etcd_sub_dir/etcd-v3.4.3_vmware.11.tar.gz

# coredns
docker load -i ./$vmware_kubernetes_dir_name/$coredns_sub_dir/coredns-v1.6.7_vmware.6.tar.gz

docker tag registry.tkg.vmware.run/kube-proxy:v1.18.10_vmware.1 k8s.gcr.io/kube-proxy:$kubernetes_version
docker tag registry.tkg.vmware.run/kube-controller-manager:v1.18.10_vmware.1 k8s.gcr.io/kube-controller-manager:$kubernetes_version
docker tag registry.tkg.vmware.run/kube-apiserver:v1.18.10_vmware.1 k8s.gcr.io/kube-apiserver:$kubernetes_version
docker tag registry.tkg.vmware.run/kube-scheduler:v1.18.10_vmware.1 k8s.gcr.io/kube-scheduler:$kubernetes_version
docker tag registry.tkg.vmware.run/pause:$pause_image_version k8s.gcr.io/pause:$pause_image_version
docker tag registry.tkg.vmware.run/e2e-test:v1.18.10_vmware.1 k8s.gcr.io/e2e-test:$kubernetes_version
docker tag registry.tkg.vmware.run/etcd:v3.4.3_vmware.11 k8s.gcr.io/etcd:$etcd_image_version
docker tag registry.tkg.vmware.run/coredns:v1.6.7_vmware.6  k8s.gcr.io/coredns:$coredns_image_version

# download weave.yml
export kubever=$(kubectl version --client | base64 | tr -d '\n')
wget --no-verbose -O weave_v2-6-5.yml "https://cloud.weave.works/k8s/net?k8s-version=$kubever&v=2.6.5"

# pull weave docker images in case cluster has no outbound internet access
docker pull weaveworks/weave-npc:2.6.5
docker pull weaveworks/weave-kube:2.6.5

echo 'installing required software for NFS'
apt-get -q install -y nfs-common nfs-kernel-server
systemctl stop nfs-kernel-server.service
systemctl disable nfs-kernel-server.service

# prevent updates to software that CSE depends on
apt-mark hold open-vm-tools
apt-mark hold docker-ce
apt-mark hold docker-ce-cli
apt-mark hold kubelet
apt-mark hold kubeadm
apt-mark hold kubectl
apt-mark hold kubernetes-cni
apt-mark hold nfs-common
apt-mark hold nfs-kernel-server
apt-mark hold shim-signed

echo 'upgrading the system'
apt-get -q update -o Acquire::Retries=3 -o Acquire::http::No-Cache=True -o Acquire::http::Timeout=20 -o Acquire::https::No-Cache=True -o Acquire::https::Timeout=20 -o Acquire::ftp::Timeout=20
apt-get -y -q -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

echo 'deleting downloaded files'
rm -rf $vmware_kubernetes_dir_name || :
rm $vmware_kubernetes_dir_name.tar.gz || :

# enable kubelet service (essential PKS does not enable it by default)
systemctl enable kubelet

# /etc/machine-id must be empty so that new machine-id gets assigned on boot (in our case boot is vApp deployment)
# https://jaylacroix.com/fixing-ubuntu-18-04-virtual-machines-that-fight-over-the-same-ip-address/
truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id || :
ln -fs /etc/machine-id /var/lib/dbus/machine-id || : # dbus/machine-id is symlink pointing to /etc/machine-id

# create /root/kubeadm-defaults.conf
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
---" > /root/kubeadm-defaults.conf

sync
sync
echo 'customization completed'
