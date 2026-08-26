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
# また環境間で共有するリソースはresourceで定義せず、文字列で指定すること

# ベースイメージは共有、差分イメージはVM毎に用意
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
  memory      = 4048
  memory_unit = "MiB"
  vcpu        = 2
  type = "qemu"
  cpu = {
    mode = "host-model"
  }

  os = {
    type      = "hvm"
    type_arch = "x86_64"
    type_machine = "q35"
  }

  devices = {
    # ネットワーク設定
    interfaces = [
      # eth0: libvirt の既定 NAT ネットワーク。
      # libvirt が DNS(ポート53) 兼 DHCP(ポート67) サーバとして動作する。
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
        # libvirt の DHCP リース完了を待機（後続の処理で本IPアドレス）
        wait_for_ip = {
          source  = "lease"
          timeout = 300
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
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          name = "qemu"
          type = "qcow2"
          cache = "writeback"
        }
      }
    ]

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

# libvirt の default ネットワークの DHCP リースから、eth0 の IPv4 を取得する。
data "libvirt_domain_interface_addresses" "nested_guest" {
  domain     = libvirt_domain.nested_guest.name
  depends_on = [libvirt_domain.nested_guest] 
  source = "lease"
}
