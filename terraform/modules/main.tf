# 本ファイルは単一のLibvirtVMを直値指定で作成するもの

# 要求プロバイダの指定はモジュールでも必要
terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      # 2026/07/05時点の最新バージョン
      version = "0.9.8"
    }
  }
}

# プロバイダ設定はルートモジュールで実施すること
# モジュールでuriを設定するとデプロイ先が固定されてしまう

# libvirt の default ネットワークの DHCP リースから、eth0 の IPv4 を取得する。
data "libvirt_domain_interface_addresses" "nested_guest" {
  domain     = libvirt_domain.nested_guest.name
  depends_on = [libvirt_domain.nested_guest] 
  source = "lease"
}

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
    # ベースイメージはVM間で共有したいので文字列で指定する
    # 共有リソースをresourceで定義すると不整合につながるので注意
    path = var.base_image_name
    format = {
      type = "qcow2"
    }
  }

  # libvirt のストレージボリュームは更新できない。
  # 作成後の差分は管理対象外とする。
  # (更新時は削除→作成を実施すること)
  lifecycle {
    ignore_changes = all
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
    # hvmは完全仮想化で負荷が高い、本当はkvmが使いたいがmacでは使えないため断念
    type      = "hvm"
    type_arch = "x86_64"
    # type_machine には、BIOS使用時はpc、UEFI使用時はq35を指定
    # prefix　を指定すると、使用可能な最新バージョンが自動選択される
    type_machine = "pc"
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
          # 下の設定で50秒くらい起動時間を短縮できる
          cache = "writeback"
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
