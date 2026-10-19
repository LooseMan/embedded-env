# 2台のVMで共有するTerraform設定。
# VM固有の定義は pc1.tf / pc2.tf に分離する。

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.8"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

variable "libvirt_uri" {
  description = "リモート libvirt への接続 URI"
  type        = string
  sensitive   = true
}

output "vm_connections" {
  description = "2台のVMの接続情報"
  value = [
    module.libvirt_vm_pc1.vm_connection,
    module.libvirt_vm_pc2.vm_connection,
  ]
}
