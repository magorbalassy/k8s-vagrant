# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"
settings = YAML.load_file "settings.yaml"

VAGRANTFILE_API_VERSION = "2"

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0]
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1])
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.provider :libvirt do |libvirt|
        libvirt.driver = "kvm"
    end
    config.vm.box = settings["software"]["box"]
    config.vm.box_version = "4.2.12"
    config.vm.synced_folder ".", "/vagrant", type: "nfs"
    
    config.vm.provision :shell, env: { "IP_NW" => IP_NW, "IP_START" => IP_START, "NUM_WORKER_NODES" => NUM_WORKER_NODES }, inline: <<-SHELL
        echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
        sudo ip route delete default
        sudo ip route add default via 192.168.10.1
        sudo sed -iE 's/127\.0\.1\.1.*$/ /g' /etc/hosts
        apt-get update -y
        echo "root:rootroot" | sudo chpasswd
        echo "magor:rootroot:1010:1010:magor:/home/magor:/bin/bash" | newusers
        sudo timedatectl set-timezone Europe/Zurich
        echo "${IP_NW}${IP_START} k8s-control" >> /etc/hosts
        for i in `seq 1 ${NUM_WORKER_NODES}`; do
          echo "$IP_NW$((IP_START+i)) k8s-worker${i}" >> /etc/hosts
        done        
    SHELL

    config.vm.define "k8s-control" do |control|
      control.vm.hostname = "k8s-control"
      control.vm.network :public_network,
          :network_name => "bridged-network",
          :type => "bridge",
          :dev => "bridge0",
          :ip => settings["network"]["control_ip"]
  
      control.vm.provider "libvirt" do |vb|
          vb.cpus = settings["nodes"]["control"]["cpu"]
          vb.memory = settings["nodes"]["control"]["memory"]
      end
      control.vm.provision :shell, inline: <<-SHELL
          sudo sed -i 's/ubuntu2004.localdomain/k8s-control/g' /etc/hosts
      SHELL
      control.vm.provision "shell",
          env: {
            "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
            "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
            "OS" => settings["software"]["os"]
          },
          path: "scripts/common.sh"
      control.vm.provision "shell",
          env: {
            "CONTROL_IP" => settings["network"]["control_ip"],
            "POD_CIDR" => settings["network"]["pod_cidr"],
            "SERVICE_CIDR" => settings["network"]["service_cidr"]
          },
          path: "scripts/master.sh"
      control.vm.synced_folder "/nvme/k8s-nfs/k8s-control", "/data", type: "nfs", create: true
    end

    (1..NUM_WORKER_NODES).each do |i|
      config.vm.define "k8s-worker#{i}" do |worker|
          worker.vm.hostname = "k8s-worker#{i}"
          worker.vm.network :public_network,
              :network_name => "bridged-network",
              :type => "bridge",
              :dev => "bridge0",
              :ip => IP_NW + "#{IP_START + i}"
          worker.vm.provider "libvirt" do |vb|
              vb.cpus = settings["nodes"]["workers"]["cpu"]
              vb.memory = settings["nodes"]["workers"]["memory"]
          end
          worker.vm.provision :shell, inline: <<-SHELL
              sudo sed -i 's/ubuntu2004.localdomain/'"k8s-worker#{i}"'/g' /etc/hosts
          SHELL
          worker.vm.provision "shell",
              env: {
                "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
                "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
                "OS" => settings["software"]["os"]
              },
              path: "scripts/common.sh"
          worker.vm.provision "shell", path: "scripts/node.sh"
          worker.vm.synced_folder "/nvme/k8s-nfs/k8s-worker#{i}", "/data", type: "nfs", create: true
      end
    end
    
end
