## K8s cluster with Vagrant on Ubuntu 20 + KVM/libvirt
---


A `Vagrantfile` and required scripts to setup within minutes a Kubernetes cluster on Ubuntu.  
Tested on Ubuntu 20 with KVM and `libvirt`.  
The cluster and node size can be customized from `settings.yaml` - current setting is for 1 master and 3 worker nodes.  
The folder in which the `Vagrantfile` is, will be shared with NFS in the spawned up nodes in `/vagrant`.  
Setup the required mounts and K8s persistent volumes after installation is completed.

  
This repo is based on multiple other similar repos, but it's expanded and the `Vagrantfile` had to be completely rewritten in order to make it work with the `libvirt` provider for Vagrant. In addition, the existing scripts had to be modified and safeguards had to be added.

### Dashboard 

The Kubernetes dashboard UI can be accessed on the worker node , port 30000, using the token from the `./configs/dashboard.token` file.  
After the Vagrant setup is completed, it takes several minutes for the UI to be accessible.

### Fresh VMs

If you want to restart the setup make sure to run `vagrant destroy -f` and check that the NFS exports were removed from `/etc/exports` plus remove the `.vagrant` and the `config` folders:  

`vagrant destroy -f && rm -rf configs .vagrant && vagrant up | tee vagrant.log`

### Setup Vagrant sudoers

https://developer.hashicorp.com/vagrant/docs/synced-folders/nfs#root-privilege-requirement

This is required to create NFS exports for the shared folder `/vagrant`.  Without this, vagrant will ask for the sudo password while setting up the VMs, in order to create the NFS exports.  
On the Ubuntu host, add this to `/etc/sudoers` on the host on which vagrant and the K8s vm nodes will be running, and make sure the sudo works :
```
Cmnd_Alias VAGRANT_EXPORTS_CHOWN = /bin/chown 0\:0 /tmp/vagrant-exports
Cmnd_Alias VAGRANT_EXPORTS_MV = /bin/mv -f /tmp/vagrant-exports /etc/exports
Cmnd_Alias VAGRANT_NFSD_CHECK = /etc/init.d/nfs-kernel-server status
Cmnd_Alias VAGRANT_NFSD_START = /etc/init.d/nfs-kernel-server start
Cmnd_Alias VAGRANT_NFSD_APPLY = /usr/sbin/exportfs -ar
%sudo ALL=(root) NOPASSWD: VAGRANT_EXPORTS_CHOWN, VAGRANT_EXPORTS_MV, VAGRANT_NFSD_CHECK, VAGRANT_NFSD_START, VAGRANT_NFSD_APPLY

```

### Forward the kubernetese-dashboard port to local machine

Initilly I've forwarded the port through SSH to use the UI. Just another way to access the dashboard without exposing it.
Current setup exposes the service, the dashboard UI can be accessed on the worker node IPs and the defined `NodePort`.

- get the Vagrant SSH config: `vagrant ssh-config`
- create a remote port forwarding with ssh: `ssh -R -i <path-to-your-vagrant-ssh-key> 8001:localhost:8001 vagrant@<ip-of-k8s-worker1>`