# 本ファイルは単一のLibvirtVMを直値指定で作成するもの

# プロバイダにlibvirtを指定
terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      # 2026/07/05時点の最新バージョン
      version = "0.9.8"
    }
    # no null provider needed anymore
  }
}

# 仮想マシンのデプロイ先を指定
#   terraformはデフォルトでssh-agentを自動起動しないため、
#   別途ssh-agentを起動、もしくは、uriにkeyファイルを指定する必要がある
provider "libvirt" {
  uri = var.libvirt_uri
}

variable "libvirt_uri" {
  description = "リモート libvirt への接続 URI（SSH ユーザー、ホスト、秘密鍵パスを含む）"
  type        = string
  sensitive   = true
}

# モジュール実行
module "my_nested_vm" {
  source = "../modules"

  vm_name		= "nested-guest-vm-2"

  host_only_network_name    = "host-only-bridge-2"
  host_only_network_gateway = "192.168.150.1"

  storage_pool_name      = "default"
  overlay_volume_name    = "overlay.qcow2"
  overlay_capacity_bytes = 68719476736 # 64 GiB
  base_image_name        = "centos-5.11.qcow2"
}

# モジュールの出力を直接terraform outputで取得できないので穴あけ
output "test" {
  value = module.my_nested_vm.vm_connection
}
