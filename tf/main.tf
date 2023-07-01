provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vsphere_template
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_resource_pool
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

locals {
  vms = ["jenkins", "nexus", "trivy", "sonar"]
}

resource "vsphere_virtual_machine" "vm" {
  count            = length(local.vms)
  name             = local.vms[count.index]
  num_cpus         = 2
  memory           = 4096
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  folder           = "/${var.vsphere_datacenter}/vm/${var.vsphere_folder}"
  network_interface {
    network_id = data.vsphere_network.network.id
  }
  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    thin_provisioned = true
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }
}

# Generate inventory file for Ansible
resource "local_file" "inventory" {
  filename = "../ansible/inventory.ini"
  content  = <<EOF

[${vsphere_virtual_machine.vm[0].name}]
${vsphere_virtual_machine.vm[0].guest_ip_addresses[0]}

[${vsphere_virtual_machine.vm[1].name}]
${vsphere_virtual_machine.vm[1].guest_ip_addresses[0]}

[${vsphere_virtual_machine.vm[2].name}]
${vsphere_virtual_machine.vm[2].guest_ip_addresses[0]}
 
[${vsphere_virtual_machine.vm[3].name}]
${vsphere_virtual_machine.vm[3].guest_ip_addresses[0]}
 
[all:vars]
ansible_ssh_user=root
ansible_ssh_password=${var.vsphere_password}
EOF
}
