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

# libvirt の default ネットワークの DHCP リースから、eth0 の IPv4 を取得する。
data "libvirt_domain_interface_addresses" "nested_guest" {
  domain     = libvirt_domain.nested_guest.name
  depends_on = [libvirt_domain.nested_guest] 
  source = "lease"
}

# 仮想マシンのデプロイ先を指定
#   terraformはデフォルトでssh-agentを自動起動しないため、
#   別途ssh-agentを起動、もしくは、uriにkeyファイルを指定する必要がある
provider "libvirt" {
  uri = var.libvirt_uri
}

# NOTE: image provisioning is expected to be done outside of Terraform now.
# The VM will reference /home/ifour/images/nested-guest-vm.qcow2 directly.

# 孫VM用のネットワーク（ホストオンリー）
resource "libvirt_network" "host_only" {
  name = var.host_only_network_name
  # ホストOS起動時に有効化する
  autostart = true

  dns = {
    enable = "no"
  }

  ips = [
    {
      address = var.host_only_network_gateway
      prefix  = 24
      # DHCP disabled — guest will be configured with a static ifcfg-eth1
    }
  ]
}

resource "libvirt_volume" "overlay" {
  name = var.overlay_volume_name
  pool = var.storage_pool_name
  # 以下で指定する容量は、overlay.qcow2 の最大容量であり、実際の使用容量は centos-5.11.qcow2 のサイズに依存する。
  # 指定を誤る（実際より小さい値に設定する）とカーネルパニックが発生するため注意
  capacity = var.overlay_capacity_bytes
  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = var.base_image_name
    format = {
      type = "qcow2"
    }
  }
}

# cloud-init は使わず、eth0 の libvirt 既定 NAT アダプタ経由で SSH 接続して eth1 を設定する。

# 孫VM本体の作成
resource "libvirt_domain" "nested_guest" {

  name = var.vm_name
  # プロビジョニング用に仮想マシン起動する（デフォルトは作成のみ）
  running     = true
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 2
  # MacOS 15以降だとkvmが使用できない？ためqemu
  type = "qemu"
  # ホストの物理CPUの命令セットをそのまま引き継ぐ（カーネルパニック対策、qemu64ではカーネルパニックになった）
  cpu = {
    mode = "host-model"
  }

  os = {
    type      = "hvm"
    type_arch = "x86_64"
    # BIOS起動を前提にpc-i440fx-rhel10.0.0を指定
    # （UEFIで起動する場合は q35-rhel10.0.0）
    type_machine = "pc-i440fx-rhel10.0.0"
  }

  devices = {
    # ネットワーク設定
    interfaces = [
      # eth0: libvirt の既定 NAT ネットワーク。DHCP で IP が割り当てられる。
      {
        model = {
          type = "e1000"
        }
        source = {
          network = {
            network = "default"
          }
        }
        # DHCP リースを取得するまで apply の完了を待つ。
        wait_for_ip = {
          source  = "lease"
          timeout = 300
        }
      },
      # eth1: ホストオンリー接続用のアダプタ
      {
        model = {
          type = "e1000"
        }
        source = {
          network = {
            # eth1: host-onlyネットワーク
            network = libvirt_network.host_only.name
          }
        }
      }
    ]

    # ディスク設定
    disks = [
      {
        source = {
          file = {
            file = libvirt_volume.overlay.path
          }
        }
        target = {
          dev = "hda"
          bus = "ide"
        }
        driver = {
          name = "qemu"
          type = "qcow2"
        }
      }
    ]

    # GUI設定
    graphics = [
      {
        # Alma9以降はデフォルトでspiceを使えないためvnc
        vnc = {
          # ホスト上の任意のポートに自動割り当てする場合は true、固定ポートにしたい場合は false
          auto_port = true
          listeners = [
            {
              address = {
                # ホスト外部からもVNC接続を許可する場合。ホスト内限定なら "127.0.0.1"
                address = "0.0.0.0"
              }
            }
          ]
        }
      }
    ]
  }
}
