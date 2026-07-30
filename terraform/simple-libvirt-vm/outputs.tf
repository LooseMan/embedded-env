locals {
  vm_ipv4_address = one(flatten([
    for interface in data.libvirt_domain_interface_addresses.nested_guest.interfaces : [
      for address in interface.addrs : address.addr
      if address.type == "ipv4"
    ]
  ]))
}

output "vm_ipv4_address" {
  description = "libvirt default ネットワークの DHCP がゲストに割り当てた IPv4 アドレス"
  value       = local.vm_ipv4_address
}

output "ansible_applied_hosts" {
  description = "hosts.yml へ貼り付ける定義"
  value       = <<-YAML
---
all:
  children:
    old_servers:
      hosts:
        ${replace(var.vm_name, "-", "_")}:
          ansible_host: ${local.vm_ipv4_address}
      vars:
        ansible_ssh_common_args: >-
          -o KexAlgorithms=+diffie-hellman-group14-sha1
          -o HostKeyAlgorithms=+ssh-rsa
          -o PubkeyAcceptedAlgorithms=+ssh-rsa
          -o StrictHostKeyChecking=no
  YAML
}
