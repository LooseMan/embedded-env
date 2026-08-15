#!/bin/bash
set -e

# --- 設定項目 ---
POD_NAME="pxe-server-pod"
ISO_PATH="${HOME}/AlmaLinux-9.8-x86_64-minimal.iso"
MOUNT_DIR="/opt/pxe/iso_root"
CONFIG_DIR="/home/user/embedded-env/pxe"

echo "[1/4] Checking and Mounting ISO Image..."

sudo mkdir -p "${MOUNT_DIR}"

# ISOファイルが未マウントの場合のみマウントを実行
# -o loop,ro: 読取専用ルーフ゜マウント
# context="...": ISO(Read-Only)にSELinuxコンテキスト(container_file_t)を直接付与し、
#               コンテナ側の :Z による属性変更失敗(lsetxattr error)を回避する
if ! mountpoint -q "${MOUNT_DIR}"; then
    echo "Mounting ISO to ${MOUNT_DIR}..."
    sudo mount -o loop,ro,context="system_u:object_r:container_file_t:s0" "${ISO_PATH}" "${MOUNT_DIR}"
else
    echo "ISO is already mounted at ${MOUNT_DIR}."
fi

echo "[2/4] Cleaning up existing Pod/Containers..."

# 既存Podが存在する場合は一括強制削除 (-f オプションで所属コンテナもまとめて破棄)
if sudo podman pod exists "${POD_NAME}"; then
    echo "Stopping and removing existing pod '${POD_NAME}'..."
    sudo podman pod rm -f "${POD_NAME}" >/dev/null 2>&1 || true
fi

echo "[3/4] Creating Pod (--net=host)..."

# ホストネットワーク (--net=host) を利用してPodを作成
# これによりTFTP(UDP 69/動的ポート)やDHCP Proxy(UDP 67)のポートマッピング問題・遮断を完全に回避
sudo podman pod create --name "${POD_NAME}" --net=host

echo "[4/4] Starting Containers..."

# ------------------------------------------------------------
# 1. Nginx起動 (HTTPインストールソース配信)
# ------------------------------------------------------------
echo "  -> Starting Nginx (pxe-http)..."

# -v ...:ro
# ISOマウント領域は Read-Only のため、Podman による SELinux ラベル変更(:Z/:z)をスキップし、
# 純粋な読取専用マウント (:ro) として通過させる
sudo podman run -d \
  --pod "${POD_NAME}" \
  --name pxe-http \
  -v "${MOUNT_DIR}":/usr/share/nginx/html/alma9:ro \
  docker.io/library/nginx:alpine

# ------------------------------------------------------------
# 2. DNS/DHCP/TFTP サーバー (dnsmasq) 起動
# ------------------------------------------------------------
echo "  -> Starting DNS/DHCP/TFTP (dnsmasq)..."

# --cap-add=NET_ADMIN / NET_RAW: パケットの横取り・ブロードキャスト応答に必要な権限
# -v ...:Z : ホスト上の書込可能領域のため、Podmanの排他的SELinuxラベル(:Z)を正常適用可能
# --no-daemon (重要): 
#   コンテナ環境ではメインプロセスがバックグラウンドに移行すると、
#   Podmanは「仕事が終わった」と判断してコンテナをExitしてしまう。
#   コンテナを常駐させるため、dnsmasqをフォアグラウンド実行(--no-daemon)させる。
#   ※引数は必ずイメージ名の後ろに記述する。
sudo podman run -d \
  --pod "${POD_NAME}" \
  --name pxe-dhcp \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -v "${CONFIG_DIR}/dnsmasq.conf":/etc/dnsmasq.conf:Z \
  -v "${CONFIG_DIR}":/var/lib/tftpboot:Z \
  quay.io/poseidon/dnsmasq:v0.5.0-51-gc8a9de4 \
  --no-daemon

echo
echo "=========================================="
echo " PXE Server started successfully."
echo "=========================================="
