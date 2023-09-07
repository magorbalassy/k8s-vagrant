#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)

sudo kubeadm config images pull &&\
echo "Preflight Check Passed: Downloaded All Required Images" ||\
exit 1

sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP \
  --apiserver-cert-extra-sans=$CONTROL_IP \
  --pod-network-cidr=$POD_CIDR \
  --service-cidr=$SERVICE_CIDR \
  --node-name "$NODENAME" \
  --ignore-preflight-errors Swap

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Save Configs to shared /vagrant location
# For Vagrant re-runs, check if there is existing configs in the location and
# delete it for saving new configuration.

config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -rf $config_path
else
  mkdir -p $config_path
fi
sync
cp -i /etc/kubernetes/admin.conf $config_path/config
touch $config_path/join.sh
chmod +x $config_path/join.sh
sync

kubeadm token create --print-join-command > $config_path/join.sh

# Install Calico Network Plugin
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O
kubectl apply -f calico.yaml

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

# Install Metrics Server
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

# Install Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Setup a NodePort for the kubernetes-dashboard
kubectl --namespace kubernetes-dashboard patch svc kubernetes-dashboard -p '{"spec": {"type": "NodePort"}}'


# Create objects required to enable the login through the dashboard UI
kubectl apply -f /vagrant/dashboard-svc-account.yaml
kubectl apply -f /vagrant/dashboard-clusterrolebinding.yaml
kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard --patch "$(cat /vagrant/dashboard-nodeport-patch.yaml)"

# Add local storage class to the cluster
kubectl apply -f /vagrant/local-storage-class.yaml

# Create token and place in the shared folder 
# Use token to login through the UI after creating an SSH remote port forwarding
kubectl -n kubernetes-dashboard create token admin-user | tee /vagrant/configs/dashboard.token && sync