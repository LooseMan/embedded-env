#!/bin/bash
set -e

echo "[5/7] Creating Pod..."

POD_NAME="pxe-server-pod"

# 既存のPodが存在する場合は停止・削除
if sudo podman pod exists "${POD_NAME}"; then
    echo "Existing pod '${POD_NAME}' found."
    echo "Stopping and removing existing pod..."
    sudo podman pod stop "${POD_NAME}" >/dev/null 2>&1 || true
    sudo podman pod rm "${POD_NAME}" >/dev/null 2>&1 || true
fi

# ホストネットワーク（--net=host）を利用してPodを作成
# これによりTFTPの動的データ転送ポート遮断やポートバインドの問題を完全に回避
sudo podman pod create --name "${POD_NAME}" --net=host

# ------------------------------------------------------------
# 6. Nginx起動 (HTTPインストール用)
# ------------------------------------------------------------
# echo "Starting Nginx..."
# sudo podman rm -f pxe-http >/dev/null 2>&1 || true
# sudo podman run -d \
#   --pod "${POD_NAME}" \
#   --name pxe-http \
#   -v /opt/pxe/iso_root:/usr/share/nginx/html/alma9:ro \
#   docker.io/library/nginx:alpine

# ------------------------------------------------------------
# 7. DNS/DHCP/TFTP サーバー (dnsmasq) 起動
# ------------------------------------------------------------
echo "Starting DNS/DHCP/TFTP (dnsmasq)..."
sudo podman rm -f pxe-dhcp >/dev/null 2>&1 || true
sudo podman run -d \
  --pod "${POD_NAME}" \
  --name pxe-dhcp \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -v /opt/pxe/dnsmasq.conf:/etc/dnsmasq.conf:ro \
  -v /opt/pxe/iso_root:/var/lib/tftpboot:ro \
  quay.io/poseidon/dnsmasq:v0.5.0-51-gc8a9de4

echo
echo "=========================================="
echo "Setup completed."
echo "=========================================="

echo
echo "Services Status:"
echo "  ProxyDHCP : UDP 4011 (Host network)"
echo "  TFTP      : UDP 69   (Host network)"
echo "  Nginx     : TCP 80   (Host network)"
