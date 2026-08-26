terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.8"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

module "ubuntu_vm" {
  source = "../modules/modern"

  vm_name = "ubuntu-24-04-vm"

  host_only_network_name    = "host-only-bridge-2"
  host_only_network_gateway = "192.168.150.1"

  storage_pool_name      = "default"
  overlay_volume_name    = "ubuntu-24-04-vm-overlay.qcow2"
  overlay_capacity_bytes = 10737418240 # 10 GiB
  base_image_name        = "ubuntu-24.04-server-cloudimg-amd64.img"
}

output "vm_connection" {
  description = "作成したUbuntu VMの接続情報"
  value       = module.ubuntu_vm.vm_connection
}
