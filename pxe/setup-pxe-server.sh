#!/bin/bash
set -e

# --- 設定項目 ---
POD_NAME="pxe-server-pod"
ISO_PATH="${HOME}/AlmaLinux-9.8-x86_64-minimal.iso"
MOUNT_DIR="/opt/pxe/iso_root"
CONFIG_DIR="/home/user/embedded-env/pxe"

echo "[1/4] Checking and Mounting ISO Image..."

# マウントポイントの存在確認と作成
sudo mkdir -p "${MOUNT_DIR}"

# ISOがマウントされていない場合のみマウント（SELinuxラベル付与）
if ! mountpoint -q "${MOUNT_DIR}"; then
    echo "Mounting ISO to ${MOUNT_DIR}..."
    sudo mount -o loop,ro,context="system_u:object_r:container_file_t:s0" "${ISO_PATH}" "${MOUNT_DIR}"
else
    echo "ISO is already mounted at ${MOUNT_DIR}."
fi

echo "[2/4] Cleaning up existing Pod/Containers..."

# 既存Podの削除（Podを強制的かつ一括で削除）
if sudo podman pod exists "${POD_NAME}"; then
    echo "Stopping and removing existing pod '${POD_NAME}'..."
    sudo podman pod rm -f "${POD_NAME}" >/dev/null 2>&1 || true
fi

echo "[3/4] Creating Pod (--net=host)..."

# ホストネットワーク（--net=host）でPodを作成
sudo podman pod create --name "${POD_NAME}" --net=host

echo "[4/4] Starting Containers..."

# 1. Nginx (HTTP配信サーバー)
# Read-Only領域のため :ro のみ指定（:Z は使用しない）
echo "  -> Starting Nginx (pxe-http)..."
sudo podman run -d \
  --pod "${POD_NAME}" \
  --name pxe-http \
  -v "${MOUNT_DIR}":/usr/share/nginx/html/alma9:ro \
  docker.io/library/nginx:alpine

# 2. dnsmasq (DHCP Proxy / TFTP サーバー)
# 設定ファイルとtftpboot領域は書き込み可能なため :z（共有ラベル）を指定
echo "  -> Starting dnsmasq (pxe-dhcp)..."
sudo podman run -d \
  --pod "${POD_NAME}" \
  --name pxe-dhcp \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -v "${CONFIG_DIR}/dnsmasq.conf":/etc/dnsmasq.conf:z \
  -v "${CONFIG_DIR}":/var/lib/tftpboot:z \
  quay.io/poseidon/dnsmasq:v0.5.0-51-gc8a9de4 \
  --no-daemon

echo
echo "=========================================="
echo " PXE Server started successfully."
echo "=========================================="