# VM 2 固有の定義
module "libvirt_vm_pc2" {
  source = "../modules/pc"

  vm_group = "old_servers"
  vm_name  = "libvirt_vm_b"

  host_only_network_name    = "host-only-bridge-2"
  host_only_network_gateway = "192.168.150.1"

  storage_pool_name      = "default"
  overlay_volume_name    = "libvirt_vm_b.qcow2"
  overlay_capacity_bytes = 68719476736 # 64 GiB
  base_image_name        = "centos-5.11.qcow2"
}
