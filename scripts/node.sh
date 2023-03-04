#!/bin/bash
#
# Setup for worker nodes.

set -euxo pipefail

config_path="/vagrant/configs"

# Adding a wait loop, to wait for the required files create on the controller
# into the shared folder.
while ! [[ -f "${config_path}/dashboard.token" ]]; do 
    echo "Config path ${config_path} is not yet present, sleeping 10 seconds."
    sleep 10
    sync
done
/bin/bash $config_path/join.sh -v

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker
EOF
