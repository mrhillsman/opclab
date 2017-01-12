# WIP (DRAFT STATUS)
[![Stories in Ready](https://badge.waffle.io/mrhillsman/rpcops-onmetal-labconfigurator.png?label=ready&title=Ready)](https://waffle.io/mrhillsman/rpcops-onmetal-labconfigurator)
## rpcops-onmetal-labconfigurator
Configuration script that builds out a X node lab environment for onboarding and testing purposes for Rackspace Private Cloud.  

![High Level Overview](overview.png)  

# Requirements
# Full Automation Requirements
**i.e. localhost (can be your local machine or cloud server) NOT OnMetal host**
##### Rackspace Public Cloud Credentials  
_.raxpub_ file **in the repo directory** formatted like this:  
```shell
[rackspace_cloud]
username = your-cloud.username
api_key = e1b835d65f0311e6a36cbc764e00c842
```

##### Packages
+ apt-get
  + python-dev
  + build-essential
  + libssl-dev
  + curl
  + git
  + pkg-config
  + libvirt-dev
  + jenkins
+ pip [ python <(curl -sk https://bootstrap.pypa.io/get-pip.py) ]
  + ansible >= 2.0
  + lxml
  + pyrax
  + libvirt-python
+ rack binary
  + [installation and configuration](https://developer.rackspace.com/docs/rack-cli/configuration/#installation-and-configuration)

##### SSH Key Pair  
```shell
mkdir /root/.ssh
ssh-keygen -q -t rsa -N "" -f /root/.ssh/id_rsa
```

# Manual Setup Requirements  
##### OnMetal Cloud Server (has only been tested with I/O v1 and I/O v2)  
##### NOW WORKS IN DFW AND IAD!

## Pre Installation Considerations
##### Make sure your OnMetal host is using all available CPU power  
will not be necessary in the future (probably 16.04 - images team is aware)
##### rpcops-host-setup will perform this if you forget

```shell
# Manually check for acpi bug and fix if you did not already heed the IMPORTANT section above
if ! [ `awk '/processor/ { count++ } END { print count }' /proc/cpuinfo` -eq 40 ]; then
  if [ -f /root/.cpufixed ]; then
    echo -e "You have another problem other than acpi.\n"
    echo -e "Investigate or you can continue at your own risk.\n"
    read -p "Continue [y/n]: " __UNDER40__
    if [ $__UNDER40__ == "n" ]; then
      exit 200
    fi
  fi
  if ! [ -f /root/.cpufixed ]; then
    echo -e "No bueno! acpi=off or another issue.\n"
    echo -e "Fixing acpi=off. If this does not work, investigate further.\n"
    sed -i.bak 's/acpi=off/acpi=noirq/' /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
    update-grub
    touch /root/.cpufixed
    shutdown -r now "REBOOTING YOUR SYSTEM. RE-RUN SCRIPT WHEN LOGGED BACK IN."
  fi
else
  echo -e "Good to go! acpi=noirq or bug irrelevant.\n"
  sleep 3
fi
```
__Server will reboot and take about 4 minutes to become accessible again__

# Installation
## Full Automation Installation Steps##
_be sure you have met the requirements listed above_  

__Build and Prepare OnMetal Server__  
_there's a script for this - launch_phase.sh_
```shell
# Tag needs to be passed (dfw or iad)
ansible-playbook build_onmetal.yaml --tags 'iad'
ansible-playbook -i hosts get_onmetal_facts.yaml --tags 'iad'
ansible-playbook -i hosts prepare_onmetal.yaml
ansible-playbook -i hosts set_onmetal_cpu.yaml
ansible-playbook -i hosts configure_onmetal.yaml
ansible-playbook -i hosts create_lab.yaml
```  

__Deploy OpenStack-Ansible__  
_there's a script for this - deploy_phase.sh_
```shell
ansible-playbook -i hosts prepare_for_osa.yaml
ansible-playbook -i hosts deploy_osa.yaml
```  

__Clean and Delete OnMetal Host__  
_there's a script for this - destroy_phase.sh_
```shell
ansible-playbook -i hosts destroy_virtual_machines.yaml
ansible-playbook -i hosts destroy_virtual_networks.yaml
ansible-playbook -i hosts destroy_lab_state_file.yaml
# Tag needs to be the same as used when building
ansible-playbook -i hosts destroy_onmetal.yaml --tags 'iad'
```  

## Manual Installation Steps - non rpc-openstack##
```shell
# Install required packages
apt-get update
apt-get install -y tmux vim git
# From the OnMetal host change to root directory
cd /root
# Clone the lab repo
git clone https://github.com/mrhillsman/rpcops-onmetal-labconfigurator -b usehaproxy
# Change into the lab repo directory
cd rpcops-onmetal-labconfigurator
# Create tmux session for install (recommended but not required)
tmux new-session -s rpcops
# Run the host setup script; will take some time (10-15m)
bash rpcops-host-setup
# You can pass lab configuration/type, if nothing, default
# Lab Configs: default (3 infra, 2 network, 1 logging, 3 compute, 3 cinder, 3 swift)
# default, defaultceph, defaultswift, defaultcinder, cephonly, swiftonly
# ex. bash rpcops-lab-setup defaultcinder
bash rpcops-lab-setup

# Prepare swift Nodes
ansible-playbook -i inventory playbooks/swift-disks-prepare.yml

# Prepare cinder Nodes
ansible-playbook -i inventory playbooks/cinder-disks-prepare.yml

# Vanilla OpenStack-Ansible (master if branch not specified)
ansible-playbook -i inventory playbooks/prepare-for-osa.yml

# Install OpenStack
cd /opt/openstack-ansible/playbooks
openstack-ansible setup-everything.yml -f15
```

## Manual Installation Steps - rpc-openstack##

```shell
git clone --recursive -b <your_branch> http://github.com/rcbops/rpc-openstack
cd rpc-openstack

cp -R openstack-ansible/etc/openstack_deploy /etc/openstack_deploy
python openstack-ansible/scripts/pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml
scripts/update-yaml.py /etc/openstack_deploy/user_variables.yml rpcd/etc/openstack_deploy/user_variables.yml
cp rpcd/etc/openstack_deploy/user_extras_*.yml /etc/openstack_deploy
cp rpcd/etc/openstack_deploy/env.d/* /etc/openstack_deploy/env.d
cp /root/openstack_user_config.yml /etc/openstack_deploy/openstack_user_config.yml
cp /root/swift.yml /etc/openstack_deploy/conf.d/swift.yml
python /opt/rpc-openstack/openstack-ansible/playbooks/inventory/dynamic_inventory.py > /dev/null

cd /opt/rpc-openstack && ./scripts/deploy.sh
```

## Post Installation Considerations - INFORMATIONAL ONLY ##

## Login Considerations ##
__OnMetal Host__  
SSH Public Key Authentication required during build  
*you can modify /etc/ssh/sshd_config to allow password authentication*  

__VyOS Firewall__  
ssh vyos@192.168.0.2  
password: vyos

__OpenStack Nodes__  
User: root  
Pass: stack  

## Network Considerations ##

Firewalls: 192.168.0.2-7/24  
LoadBalancers: 192.168.0.249-254/24  
Node Public Addresses: 192.168.239.101-124/24  
OpenStack Public/Floating IPs: 192.168.240.1-99/22  

Tenant VLANS: 206-210  

Network | IP Block(s) | VLAN
--------|-------------|-----
Host/Node | 10.239.0.0/24 | 201
Gateway | 10.240.0.0/24 | 205
Container | 172.29.236.0/22 | 202
Tunnel/Overlay | 172.29.240.0/22 |
Storage | 172.29.244..0/22 |
Swift | 172.29.248.0/22 |
DRAC | 10.5.0.0/24 |
ServiceNet | 10.6.0.0/24 |
Public | 192.168.0.0/24 |
       | 192.168.239.0/24 |
       | 192.168.240.0/24 |

__NAT Translations on Firewall__  

Type | Address Block | Translation
-----|---------------|------------
DNAT | 192.168.239.101-105/24 | 10.239.0.101-105/24
     | 192.168.240.2-16/24 | 10.240.0.21-36/24
     | 172.29.236.100/22 | 192.168.0.249/24
SNAT | 10.239.0.101-105/24 | 192.168.239.101-105/24
     | 10.240.0.21-36/24 | 192.168.240.2-16/24
     | 172.24.96.249/24 | 192.168.0.249/24

## Libvirt Virtualization Considerations ##
#### Networks  
drac00: 10.5.0.0/24  
snet00: 10.6.0.0/24  
public00: 192.168.0.0/24 192.168.239.0/24 192.168.240.0/24

## Open vSwitch Considerations ##
#### Virtual Switches  
lbsrvsw

#### Contributors
Melvin Hillsman _mrhillsman_
