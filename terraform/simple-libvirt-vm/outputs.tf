locals {
  vm_ipv4_address = one(flatten([
    for interface in data.libvirt_domain_interface_addresses.nested_guest.interfaces : [
      for address in interface.addrs : address.addr
      if address.type == "ipv4"
    ]
  ]))
}

output "vm_connection" {
  description = "作成した VM の接続情報。後続工程が利用するための汎用出力。"
  value = {
    name         = var.vm_name
    ipv4_address = local.vm_ipv4_address
  }
}
