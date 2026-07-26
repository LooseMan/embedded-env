variable "libvirt_uri" {
  description = "リモート libvirt への接続 URI（SSH ユーザー、ホスト、秘密鍵パスを含む）"
  type        = string
  sensitive   = true
}

variable "vm_name" {
  description = "作成する仮想マシン名"
  type        = string
}

variable "host_only_network_name" {
  description = "ホストオンリー ネットワーク名"
  type        = string
}

variable "host_only_network_gateway" {
  description = "ホストオンリー ネットワークのゲートウェイ IPv4 アドレス"
  type        = string
}

variable "storage_pool_name" {
  description = "overlay ボリュームを配置する libvirt ストレージプール名"
  type        = string
}

variable "overlay_volume_name" {
  description = "作成する qcow2 overlay ボリューム名"
  type        = string
}

variable "overlay_capacity_bytes" {
  description = "overlay ボリュームの仮想最大容量（バイト）"
  type        = number
}

variable "base_image_name" {
  description = "ストレージプール内にあるベース qcow2 イメージ名"
  type        = string
}
