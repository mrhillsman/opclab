# WIP (DRAFT STATUS)

[![Stories in Ready](https://badge.waffle.io/mrhillsman/opclab.svg?label=ready&title=Ready)](http://waffle.io/mrhillsman/opclab)  

## opclab
Configuration scripts to build an OpenStack multi-node VM lab environment for onboarding and testing purposes.  

##### OnMetal Cloud Server is required (has only been tested with I/O v1 and I/O v2)
*I/O v2 recommended*  


## Pre-install Consideration (v1 only)
##### Make sure your OnMetal host is using all available CPU power  
will not be necessary in the future (probably 16.04 - images team is aware)
##### opc-host-setup will NOT perform this if you forget

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

## OpenStack Upstream (using openstack-ansible)##
```shell
# Install required packages
apt-get update
apt-get install -y tmux vim git
# From the OnMetal host change to root directory
cd /root
# Clone the lab repo
git clone https://github.com/mrhillsman/opclab
# Change into the lab repo directory
cd opclab
# Create tmux session for install (recommended but not required)
tmux new-session -s opclab
# Run the host setup script; will take some time (10-15m)
bash opc-host-setup
# You can pass lab configuration/type, if nothing, default
# Lab Configs: default (3 infra, 2 network, 1 logging, 3 compute, 3 cinder, 3 swift)
# configurations exist in '/path/to/opclab/resources/labconfigs' folder
# ex. bash rpcops-lab-setup defaultcinder
bash opc-lab-setup

# Prepare swift Nodes
ansible-playbook -i inventory playbooks/prepare-swift-disks.yml

# Prepare cinder Nodes
ansible-playbook -i inventory playbooks/prepare-cinder-disks.yml

# Vanilla OpenStack-Ansible (master if branch not specified)
ansible-playbook -i inventory playbooks/prepare-for-osa.yml

# Install OpenStack
cd /opt/openstack-ansible/playbooks
openstack-ansible setup-everything.yml -f15
```

## WIP - Rackspace Open Private Cloud (using openstack-ansible)##

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

## WIP - OpenStack Upstream (using kolla)##

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

### Login Considerations ###  
__OnMetal Host__  
SSH Public Key Authentication required during build  
*you can modify /etc/ssh/sshd_config to allow password authentication*  

__VyOS Firewall__  
ssh vyos@192.168.0.2  
password: vyos

__OpenStack Nodes__  
User: root  
Pass: stack  

__Provided Lab Configuration__  

Node Count | Role | Addresses
-----------|------|----------
3 | Infra | 172.29.236.101-103  
2 | Network | 172.29.236.240-242  
1 | Logging | 172.29.236.110  
3 | Compute | 172.29.236.120-122  
3 | Cinder | 172.29.236.130-132  
3 | Swift | 172.29.236.140-142  


### Network Considerations ###  

Firewalls: 192.168.0.2-7/24  
LoadBalancers: 192.168.0.249-254/24  
Node Public Addresses: 192.168.239.101-254/24  
OpenStack Public/Floating IPs: 192.168.240.12-254/24  

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
     | 192.168.240.2-254/24 | 10.240.0.2-251/24
     | 172.29.236.100/22 | 192.168.0.249/24
SNAT | 10.239.0.101-254/24 | 192.168.239.101-254/24
     | 10.240.0.2-254/24 | 192.168.240.2-254/24
     | 172.24.96.249/24 | 192.168.0.249/24

## Libvirt Virtualization Considerations ##
#### Networks  
drac00: 10.5.0.0/24  
snet00: 10.6.0.0/24  
public00: 192.168.0.0/24 192.168.239.0/24 192.168.240.0/24  

#### Network Considerations
__Path for packet from one instance to 8.8.8.8 based on the following post install neutron commands:__  
neutron net-create --provider:physical_network=vlan --provider:network_type=vlan --provider:segmentation_id=205 --router:external ext-net  
neutron subnet-create ext-net 10.240.0.0/24 --name ext-subnet --gateway=10.240.0.1 --allocation-pool start=10.240.0.11,end=10.240.0.254 --enable_dhcp=false  
neutron net-create --provider:physical_network=vlan --provider:network_type=vlan --provider:segmentation_id=206 --shared int-net  
neutron subnet-create int-net 10.241.0.0/24 --name int-subnet --dns-nameservers list=true 8.8.8.8 8.8.4.4  
neutron router-create ext-rtr  
neutron router-gateway-set --enable-snat ext-rtr ext-net  
neutron router-interface-add ext-rtr int-subnet  
{{ image here showing packet path }}  


#### Open vSwitch CONFIGURATION  
Only 4 networks now (public00, drac00, snet00, lbsrvsw)  
```shell
root@server-41:~# virsh net-list --all
 Name                 State      Autostart     Persistent
----------------------------------------------------------
 drac00               active     yes           yes
 lbsrvsw              active     yes           yes
 public00             active     yes           yes
 snet00               active     yes           yes

root@server:~# virsh net-dumpxml lbsrvsw
<network>
  <name>lbsrvsw</name>
  <uuid>75a1115f-6d33-4b30-bbfd-1c9dae3d7614</uuid>
  <forward mode='bridge'/>
  <bridge name='lbsrvsw'/>
  <virtualport type='openvswitch'/>
  <portgroup name='vlan-all' default='yes'>
    <vlan trunk='yes'>
      <tag id='201' nativeMode='untagged'/>
      <tag id='202'/>
      <tag id='203'/>
      <tag id='204'/>
      <tag id='205'/>
      <tag id='206'/>
      <tag id='207'/>
      <tag id='208'/>
      <tag id='209'/>
      <tag id='210'/>
      <tag id='211'/>
      <tag id='212'/>
      <tag id='213'/>
      <tag id='214'/>
      <tag id='215'/>
    </vlan>
  </portgroup>
  <portgroup name='bond0'>
    <vlan trunk='yes'>
      <tag id='201' nativeMode='untagged'/>
      <tag id='202'/>
      <tag id='203'/>
    </vlan>
  </portgroup>
  <portgroup name='bond1'>
    <vlan trunk='yes'>
      <tag id='204'/>
      <tag id='205'/>
      <tag id='206'/>
      <tag id='207'/>
      <tag id='208'/>
      <tag id='209'/>
      <tag id='210'/>
      <tag id='211'/>
      <tag id='212'/>
      <tag id='213'/>
      <tag id='214'/>
      <tag id='215'/>
    </vlan>
  </portgroup>
</network>

root@server:~# virsh net-dumpxml snet00
<network>
  <name>snet00</name>
  <uuid>2f113df4-a5f5-4899-ad47-8d19e06bcbc8</uuid>
  <forward dev='bond0.232' mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
    <interface dev='bond0.232'/>
  </forward>
  <bridge name='virbr1' stp='off' delay='0'/>
  <mac address='52:54:00:e5:9e:93'/>
  <domain name='snet00'/>
  <ip address='10.6.0.1' netmask='255.255.255.0'>
  </ip>
</network>

root@server:~# virsh net-dumpxml drac00
<network>
  <name>drac00</name>
  <uuid>2a40304f-300a-4e47-9e6c-05bf7ead4aa3</uuid>
  <forward dev='bond0.132' mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
    <interface dev='bond0.132'/>
  </forward>
  <bridge name='virbr2' stp='off' delay='0'/>
  <mac address='52:54:00:dd:09:46'/>
  <domain name='drac00'/>
  <ip address='10.5.0.1' netmask='255.255.255.0'>
  </ip>
</network>

root@server:~# virsh net-dumpxml public00
<network>
  <name>public00</name>
  <uuid>a38dbe0e-cd74-45e9-92a1-19698839efbe</uuid>
  <forward dev='bond0.132' mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
    <interface dev='bond0.132'/>
  </forward>
  <bridge name='virbr0' stp='off' delay='0'/>
  <mac address='52:54:00:d8:1b:c5'/>
  <domain name='public00'/>
  <ip address='192.168.0.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.239.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.240.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.241.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.242.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.243.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.244.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.245.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.246.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.247.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.248.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.249.1' netmask='255.255.255.0'>
  </ip>
  <ip address='192.168.250.1' netmask='255.255.255.0'>
  </ip>
</network>
```

#### vyOS CONFIGURATION  

```shell
interfaces {
    ethernet eth0 {
        address 192.168.0.2/24
        address 192.168.0.3/24
        address 192.168.0.4/24
        address 192.168.0.5/24
        address 192.168.0.6/24
        address 192.168.0.7/24
        address 192.168.0.8/24
        address 192.168.0.9/24
        address 192.168.0.247/24
        address 192.168.0.248/24
        address 192.168.0.249/24
        address 192.168.0.250/24
        address 192.168.0.251/24
        address 192.168.0.252/24
        ...
        address 192.168.250.253/24
        address 192.168.250.254/24
        duplex auto
        hw-id 52:54:00:83:8c:52
        smp_affinity auto
        speed auto
    }
     }
     ethernet eth1 {
         address 172.24.96.1/22
         address 10.239.0.1/24
         duplex auto
         hw-id 52:54:00:3a:88:40
         smp_affinity auto
         speed auto
         vif 202 {
             address 172.29.236.1/22
         }
         vif 205 {
             address 10.240.0.1/24
         }
         vif 206 {
             address 10.241.0.1/24
         }
         vif 207 {
             address 10.242.0.1/24
         }
         vif 208 {
             address 10.243.0.1/24
         }
         vif 209 {
             address 10.244.0.1/24
         }
         vif 210 {
             address 10.245.0.1/24
         }
         vif 211 {
             address 10.246.0.1/24
         }
         vif 212 {
             address 10.247.0.1/24
         }
         vif 213 {
             address 10.248.0.1/24
         }
         vif 214 {
             address 10.249.0.1/24
         }
         vif 215 {
             address 10.250.0.1/24
         }
     }
     ethernet eth2 {
         duplex auto
         hw-id 52:54:00:cb:b4:88
         smp_affinity auto
         speed auto
     }
     loopback lo {
     }
 }
 nat {
     destination {
         rule 2 {
             destination {
                 address 192.168.239.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.239.0.0/24
             }
         }
         rule 3 {
             destination {
                 address 192.168.240.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.240.0.0/24
             }
         }
         rule 4 {
             destination {
                 address 192.168.241.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.241.0.0/24
             }
         }
         rule 5 {
             destination {
                 address 192.168.242.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.242.0.0/24
             }
         }
         rule 6 {
             destination {
                 address 192.168.243.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.243.0.0/24
             }
         }
         rule 7 {
             destination {
                 address 192.168.244.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.244.0.0/24
             }
         }
         rule 8 {
             destination {
                 address 192.168.245.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.245.0.0/24
             }
         }
         rule 9 {
             destination {
                 address 192.168.246.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.246.0.0/24
             }
         }
         rule 10 {
             destination {
                 address 192.168.247.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.247.0.0/24
             }
         }
         rule 11 {
             destination {
                 address 192.168.248.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.248.0.0/24
             }
         }
         rule 12 {
             destination {
                 address 192.168.249.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.249.0.0/24
             }
         }
         rule 13 {
             destination {
                 address 192.168.250.0/24
             }
             inbound-interface eth0
             translation {
                 address 10.250.0.0/24
             }
         }
         rule 3038 {
             destination {
                 address 192.168.0.249
             }
             inbound-interface eth0
             translation {
                 address 172.24.96.249
             }
         }
     }
     source {
         rule 2 {
             outbound-interface eth0
             source {
                 address 10.239.0.0/24
             }
             translation {
                 address 192.168.239.0/24
             }
         }
         rule 3 {
             outbound-interface eth0
             source {
                 address 10.240.0.0/24
             }
             translation {
                 address 192.168.240.0/24
             }
         }
         rule 4 {
             outbound-interface eth0
             source {
                 address 10.241.0.0/24
             }
             translation {
                 address 192.168.241.0/24
             }
         }
         rule 5 {
             outbound-interface eth0
             source {
                 address 10.242.0.0/24
             }
             translation {
                 address 192.168.242.0/24
             }
         }
         rule 6 {
             outbound-interface eth0
             source {
                 address 10.243.0.0/24
             }
             translation {
                 address 192.168.243.0/24
             }
         }
         rule 7 {
             outbound-interface eth0
             source {
                 address 10.244.0.0/24
             }
             translation {
                 address 192.168.244.0/24
             }
         }
         rule 8 {
             outbound-interface eth0
             source {
                 address 10.245.0.0/24
             }
             translation {
                 address 192.168.245.0/24
             }
         }
         rule 9 {
             outbound-interface eth0
             source {
                 address 10.246.0.0/24
             }
             translation {
                 address 192.168.246.0/24
             }
         }
         rule 10 {
             outbound-interface eth0
             source {
                 address 10.247.0.0/24
             }
             translation {
                 address 192.168.247.0/24
             }
         }
         rule 11 {
             outbound-interface eth0
             source {
                 address 10.248.0.0/24
             }
             translation {
                 address 192.168.248.0/24
             }
         }
         rule 12 {
             outbound-interface eth0
             source {
                 address 10.249.0.0/24
             }
             translation {
                 address 192.168.249.0/24
             }
         }
         rule 13 {
             outbound-interface eth0
             source {
                 address 10.250.0.0/24
             }
             translation {
                 address 192.168.250.0/24
             }
         }
         rule 3038 {
             outbound-interface eth0
             source {
                 address 172.24.96.249
             }
             translation {
                 address 192.168.0.249
             }
         }
     }
 }
 protocols {
     static {
         route 0.0.0.0/0 {
             next-hop 192.168.0.1 {
             }
         }
         route 10.239.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.240.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.241.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.242.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.243.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.244.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.245.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.246.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.247.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.248.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.249.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 10.250.0.0/24 {
             next-hop 172.24.96.249 {
             }
         }
         route 172.29.236.0/22 {
             next-hop 172.29.236.100 {
             }
         }
         route 172.29.240.0/22 {
             next-hop 172.29.236.100 {
             }
         }
         route 172.29.244.0/22 {
             next-hop 172.29.236.100 {
             }
         }
         route 172.29.248.0/22 {
             next-hop 172.29.236.100 {
             }
         }
     }
 }
 service {
     dns {
         forwarding {
             cache-size 1000
             listen-on eth1
             name-server 8.8.8.8
             name-server 8.8.4.4
         }
     }
     ssh {
         allow-root
         disable-host-validation
         listen-address 192.168.0.2
         port 22
     }
 }
 system {
     config-management {
         commit-revisions 20
     }
     console {
         device ttyS0 {
             speed 9600
         }
     }
     domain-name firewall.local
     host-name firewall
     login {
         user vyos {
             authentication {
                 encrypted-password $1$Fh1pFYPt$VDEXEAx66.uYJ/f/XBIje0
                 plaintext-password ""
             }
             level admin
         }
     }
     ntp {
         server 0.pool.ntp.org {
         }
         server 1.pool.ntp.org {
         }
         server 2.pool.ntp.org {
         }
     }
     package {
         auto-sync 1
         repository community {
             components main
             distribution helium
             password ""
             url http://packages.vyos.net/vyos
             username ""
         }
     }
     syslog {
         global {
             facility all {
                 level notice
             }
             facility protocols {
                 level debug
             }
         }
     }
     time-zone UTC
 }
```

#### iptables CONFIGURATION  
__there is a playbook to handle this__ *(openstack-rules.yml)*  
__YOU WILL NEED TO UPDATE THE bond0.132 to your public bond/interface and the 65.61.190.218 address to your public IP__  
```shell
root@server-41:~# iptables -S
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT
-A INPUT -i virbr1 -p udp -m udp --dport 53 -j ACCEPT
-A INPUT -i virbr1 -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -i virbr1 -p udp -m udp --dport 67 -j ACCEPT
-A INPUT -i virbr1 -p tcp -m tcp --dport 67 -j ACCEPT
-A INPUT -i virbr0 -p udp -m udp --dport 53 -j ACCEPT
-A INPUT -i virbr0 -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -i virbr0 -p udp -m udp --dport 67 -j ACCEPT
-A INPUT -i virbr0 -p tcp -m tcp --dport 67 -j ACCEPT
-A INPUT -i virbr2 -p udp -m udp --dport 53 -j ACCEPT
-A INPUT -i virbr2 -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -i virbr2 -p udp -m udp --dport 67 -j ACCEPT
-A INPUT -i virbr2 -p tcp -m tcp --dport 67 -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 35357 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 15672 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 9511 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 6385 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8042 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 9418 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8181 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8888 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 9200 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 3142 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 5672 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 3306 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 3260 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8080 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8777 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8003 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8000 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8004 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 6002 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 6001 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 6000 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 9696 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 9191 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 9292 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 5000 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8386 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 6082 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 6081 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 6080 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8775 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8773 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8774 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8776 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 8082 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 873 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 443 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.249/32 -i bond0.132 -o virbr0 -p tcp -m tcp --dport 80 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 192.168.0.2/32 -i bond0.132 -o virbr2 -p tcp -m tcp --dport 22 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -d 10.6.0.0/24 -i bond0.232 -o virbr1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 10.6.0.0/24 -i virbr1 -o bond0.232 -j ACCEPT
-A FORWARD -i virbr1 -o virbr1 -j ACCEPT
-A FORWARD -o virbr1 -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -i virbr1 -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -d 192.168.250.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.250.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.249.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.249.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.248.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.248.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.247.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.247.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.246.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.246.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.245.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.245.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.244.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.244.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.243.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.243.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.242.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.242.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.241.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.241.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.240.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.240.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.239.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.239.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -d 192.168.0.0/24 -i bond0.132 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.0.0/24 -i virbr0 -o bond0.132 -j ACCEPT
-A FORWARD -i virbr0 -o virbr0 -j ACCEPT
-A FORWARD -o virbr0 -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -i virbr0 -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -d 10.5.0.0/24 -i bond0.132 -o virbr2 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 10.5.0.0/24 -i virbr2 -o bond0.132 -j ACCEPT
-A FORWARD -i virbr2 -o virbr2 -j ACCEPT
-A FORWARD -o virbr2 -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -i virbr2 -j REJECT --reject-with icmp-port-unreachable
-A OUTPUT -o virbr1 -p udp -m udp --dport 68 -j ACCEPT
-A OUTPUT -o virbr0 -p udp -m udp --dport 68 -j ACCEPT
-A OUTPUT -o virbr2 -p udp -m udp --dport 68 -j ACCEPT
root@server-41:~# iptables -S -t nat
-P PREROUTING ACCEPT
-P INPUT ACCEPT
-P OUTPUT ACCEPT
-P POSTROUTING ACCEPT
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 35357 -j DNAT --to-destination 192.168.0.249:35357
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 15672 -j DNAT --to-destination 192.168.0.249:15672
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 9511 -j DNAT --to-destination 192.168.0.249:9511
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 6385 -j DNAT --to-destination 192.168.0.249:6385
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8042 -j DNAT --to-destination 192.168.0.249:8042
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 9418 -j DNAT --to-destination 192.168.0.249:9418
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8181 -j DNAT --to-destination 192.168.0.249:8181
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8888 -j DNAT --to-destination 192.168.0.249:8888
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 9200 -j DNAT --to-destination 192.168.0.249:9200
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 3142 -j DNAT --to-destination 192.168.0.249:3142
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 5672 -j DNAT --to-destination 192.168.0.249:5672
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 3306 -j DNAT --to-destination 192.168.0.249:3306
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 3260 -j DNAT --to-destination 192.168.0.249:3260
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8080 -j DNAT --to-destination 192.168.0.249:8080
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8777 -j DNAT --to-destination 192.168.0.249:8777
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8003 -j DNAT --to-destination 192.168.0.249:8003
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8000 -j DNAT --to-destination 192.168.0.249:8000
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8004 -j DNAT --to-destination 192.168.0.249:8004
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 6002 -j DNAT --to-destination 192.168.0.249:6002
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 6001 -j DNAT --to-destination 192.168.0.249:6001
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 6000 -j DNAT --to-destination 192.168.0.249:6000
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 9696 -j DNAT --to-destination 192.168.0.249:9696
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 9191 -j DNAT --to-destination 192.168.0.249:9191
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 9292 -j DNAT --to-destination 192.168.0.249:9292
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 5000 -j DNAT --to-destination 192.168.0.249:5000
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8386 -j DNAT --to-destination 192.168.0.249:8386
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 6082 -j DNAT --to-destination 192.168.0.249:6082
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 6081 -j DNAT --to-destination 192.168.0.249:6081
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 6080 -j DNAT --to-destination 192.168.0.249:6080
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8775 -j DNAT --to-destination 192.168.0.249:8775
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8773 -j DNAT --to-destination 192.168.0.249:8773
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8774 -j DNAT --to-destination 192.168.0.249:8774
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8776 -j DNAT --to-destination 192.168.0.249:8776
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 8082 -j DNAT --to-destination 192.168.0.249:8082
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 873 -j DNAT --to-destination 192.168.0.249:873
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 443 -j DNAT --to-destination 192.168.0.249:443
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 80 -j DNAT --to-destination 192.168.0.249:80
-A PREROUTING -d 65.61.190.218/32 -i bond0.132 -p tcp -m tcp --dport 1402 -j DNAT --to-destination 192.168.0.2:22
-A POSTROUTING -s 10.6.0.0/24 -d 224.0.0.0/24 -o bond0.232 -j RETURN
-A POSTROUTING -s 10.6.0.0/24 -d 255.255.255.255/32 -o bond0.232 -j RETURN
-A POSTROUTING -s 10.6.0.0/24 ! -d 10.6.0.0/24 -o bond0.232 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 10.6.0.0/24 ! -d 10.6.0.0/24 -o bond0.232 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 10.6.0.0/24 ! -d 10.6.0.0/24 -o bond0.232 -j MASQUERADE
-A POSTROUTING -s 192.168.250.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.250.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.250.0/24 ! -d 192.168.250.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.250.0/24 ! -d 192.168.250.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.250.0/24 ! -d 192.168.250.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.249.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.249.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.249.0/24 ! -d 192.168.249.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.249.0/24 ! -d 192.168.249.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.249.0/24 ! -d 192.168.249.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.248.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.248.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.248.0/24 ! -d 192.168.248.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.248.0/24 ! -d 192.168.248.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.248.0/24 ! -d 192.168.248.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.247.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.247.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.247.0/24 ! -d 192.168.247.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.247.0/24 ! -d 192.168.247.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.247.0/24 ! -d 192.168.247.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.246.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.246.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.246.0/24 ! -d 192.168.246.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.246.0/24 ! -d 192.168.246.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.246.0/24 ! -d 192.168.246.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.245.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.245.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.245.0/24 ! -d 192.168.245.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.245.0/24 ! -d 192.168.245.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.245.0/24 ! -d 192.168.245.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.244.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.244.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.244.0/24 ! -d 192.168.244.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.244.0/24 ! -d 192.168.244.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.244.0/24 ! -d 192.168.244.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.243.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.243.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.243.0/24 ! -d 192.168.243.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.243.0/24 ! -d 192.168.243.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.243.0/24 ! -d 192.168.243.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.242.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.242.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.242.0/24 ! -d 192.168.242.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.242.0/24 ! -d 192.168.242.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.242.0/24 ! -d 192.168.242.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.241.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.241.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.241.0/24 ! -d 192.168.241.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.241.0/24 ! -d 192.168.241.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.241.0/24 ! -d 192.168.241.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.240.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.240.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.240.0/24 ! -d 192.168.240.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.240.0/24 ! -d 192.168.240.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.240.0/24 ! -d 192.168.240.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.239.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.239.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.239.0/24 ! -d 192.168.239.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.239.0/24 ! -d 192.168.239.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.239.0/24 ! -d 192.168.239.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 192.168.0.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.0.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 192.168.0.0/24 ! -d 192.168.0.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.0.0/24 ! -d 192.168.0.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.0.0/24 ! -d 192.168.0.0/24 -o bond0.132 -j MASQUERADE
-A POSTROUTING -s 10.5.0.0/24 -d 224.0.0.0/24 -o bond0.132 -j RETURN
-A POSTROUTING -s 10.5.0.0/24 -d 255.255.255.255/32 -o bond0.132 -j RETURN
-A POSTROUTING -s 10.5.0.0/24 ! -d 10.5.0.0/24 -o bond0.132 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 10.5.0.0/24 ! -d 10.5.0.0/24 -o bond0.132 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 10.5.0.0/24 ! -d 10.5.0.0/24 -o bond0.132 -j MASQUERADE

```


#### Contributors
Melvin Hillsman _mrhillsman_
