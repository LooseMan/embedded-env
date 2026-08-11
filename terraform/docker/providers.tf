terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      # 2026/07/05時点の最新バージョン
      version = "0.9.8"
    }
  }
}
