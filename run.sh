#!/bin/sh

requiredTools=("terraform", "ansible", "packer")


for tool in $requiredTools
do
    if ! command -v $(tool) &> /dev/null
    then
        echo "$tool is not installed. Aborting.."
        exit
    fi
done

read -p "vsphere_server: " vsphere_server
read -p "vsphere_cluster: " vsphere_cluster
read -p "vsphere_datacenter: " vsphere_datacenter
read -p "vsphere_datastore: " vsphere_datastore
read -p "vsphere_network: " vsphere_network
read -p "vsphere_user: " vsphere_user
read -p "vsphere_password: " vsphere_password

cat << EOF > tf/variables.tfvars
vsphere_server          = "${vsphere_server}"
vsphere_cluster         = "${vsphere_cluster}"
vsphere_datacenter      = "${vsphere_datacenter}"
vsphere_datastore       = "${vsphere_datastore}"
vsphere_network         = "${vsphere_network}"
vsphere_resource_pool   = "${vsphere_resource_pool}"
vsphere_folder          = "${vsphere_folder}"
vsphere_template        = "${vsphere_template}"
vsphere_user            = "${vsphere_user}"
vsphere_password        = "${vsphere_password}"
EOF


cat << EOF > packer/var_cento8.auto.pkrvars.hcl
vsphere_user            = "${vsphere_user}"
vsphere_password        = "${vsphere_password}"

ssh_username            = "root"
ssh_password            = "${vsphere_password}"

vsphere_template_name   = "${vsphere_template}"
vsphere_folder          = "${vsphere_folder}"

cpu_num                 = 2
mem_size                = 4096
disk_size               = 20000

vsphere_server          = "${vsphere_server}"
vsphere_dc_name         = "${vsphere_datacenter}"
vsphere_compute_cluster = "Hosts/${vsphere_cluster}"
vsphere_resource_pool   = "${vsphere_resource_pool}"
vsphere_datastore       = "${vsphere_datastore}"
vsphere_portgroup_name  = "${vsphere_network}"

os_iso_path             = "[ISO]  CentOS-Stream-8-x86_64-latest-dvd1.iso"
EOF

cat << EOF > packer/scripts/ks.cfg
cdrom 
text 
eula --agreed
lang en_GB.UTF-8
keyboard --vckeymap=gb --xlayouts='gb'
network --device ens192 --onboot yes --bootproto dhcp --activate --noipv6 --hostname=${vsphere_template}
rootpw ${vsphere_password}
firewall --disabled
selinux --disabled
skipx
timezone Europe/London --isUtc
autopart
clearpart --all --initlabel
reboot --eject

%packages --ignoremissing 
@Core
bind-utils
unzip
curl
nano
net-tools
traceroute
wget


-aic94xx-firmware
-atmel-firmware
-b43-openfwwf
-bfa-firmware
-ipw2100-firmware
-ipw2200-firmware
-ivtv-firmware
-iwl100-firmware
-iwl1000-firmware
-iwl3945-firmware
-iwl4965-firmware
-iwl5000-firmware
-iwl5150-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-iwl6050-firmware
-libertas-usb8388-firmware
-ql2100-firmware
-ql2200-firmware
-ql23xx-firmware
-ql2400-firmware
-ql2500-firmware
-rt61pci-firmware
-rt73usb-firmware
-xorg-x11-drv-ati-firmware
-zd1211-firmware
%end 

%post
sudo yum update -y
%end
EOF

packer build ./packer

terraform -chdir=./tf init -input=false 
terraform -chdir=./tf plan -var-file="./variables.tfvars" -out=tfplan -input=false 
terraform -chdir=./tf apply -input=false tfplan

ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
