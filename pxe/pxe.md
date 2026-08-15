#!/bin/bash
set -e

echo "[5/7] Creating Pod..."

# POD_NAME="pxe-server-pod"

# 既存のPodが存在する場合は停止・削除
# if sudo podman pod exists "${POD_NAME}"; then
#     echo "Existing pod '${POD_NAME}' found."
#     echo "Stopping and removing existing pod..."
#     sudo podman pod stop "${POD_NAME}" >/dev/null 2>&1 || true
#     sudo podman pod rm "${POD_NAME}" >/dev/null 2>&1 || true
# fi

# ホストネットワーク（--net=host）を利用してPodを作成
# これによりTFTPの動的データ転送ポート遮断やポートバインドの問題を完全に回避
# sudo podman pod create --name "${POD_NAME}" --net=host

# ------------------------------------------------------------
# 6. Nginx起動 (HTTPインストール用)
# ------------------------------------------------------------
echo "Starting Nginx..."
podman rm -f pxe-http >/dev/null 2>&1 || true
podman run -d \
  -p 8080:80 \
  --pod "${POD_NAME}" \
  --name pxe-http \
  docker.io/library/nginx:alpine
  # -v /opt/pxe/iso_root:/usr/share/nginx/html/alma9:Z \

# ------------------------------------------------------------
# 7. DNS/DHCP/TFTP サーバー (dnsmasq) 起動
# ------------------------------------------------------------

# 外部ホストからPXEブートを利用するために、53/udp, 67/udp, 69/udpを開放
# （ポートを閉じる場合は「--add-port」を「--remove-port」に変更して実行）
sudo firewall-cmd --add-port=53/udp --permanent
sudo firewall-cmd --add-port=67/udp --permanent
sudo firewall-cmd --add-port=69/udp --permanent
sudo firewall-cmd --reload
# $ sudo firewall-cmd --list-ports
# 53/udp 67/udp 69/udp
# $

# echo "Starting DNS/DHCP/TFTP (dnsmasq)..."

# コンテナ環境では、メインプロセスがバックグラウンドに移行すると、
# Podmanは「コンテナの仕事が終わった」と判断してコンテナ自体を終了（Exit）する。
# コンテナを終了させないため、dnsmasqに「--no-daemon」オプションを指定（フォアグラウンドで実行）する。
# ※メインプロセスの引数はイメージ名の後に記述する必要がある。

# $ podman logs pxe-dhcp
# dnsmasq: started, version 2.92rel2 DNS disabled
# dnsmasq: compile time options: IPv6 GNU-getopt no-DBus no-UBus no-i18n no-IDN DHCP DHCPv6 no-Lua TFTP no-conntrack ipset no-nftset auth no-DNSSEC loop-detect inotify dumpfile
# dnsmasq-dhcp: DHCP, proxy on subnet 192.168.122.0
# dnsmasq-tftp: TFTP root is /var/lib/tftpboot  
# $ 

# PXEブート（DHCPプロキシやTFTP）を別ホストから正常に利用できるようにするためには、ポートオフセット（8000番台）を諦め、本来のポート番号でバインドするのが唯一の確実な方法です。
# sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53

# コンテナ環境では、メインプロセスがバックグラウンドに移行すると、
# Podmanは「コンテナの仕事が終わった」と判断してコンテナ自体を終了（Exit）する。
# コンテナを終了させないため、dnsmasqに「--no-daemon」オプションを指定（フォアグラウンドで実行）する。
# ※メインプロセスの引数はイメージ名の後に記述する必要がある。
podman rm -f pxe-dhcp >/dev/null 2>&1 || true
podman run -d \
  --name pxe-dhcp \
  -p 53:53/udp \
  -p 67:67/udp \
  -p 69:69/udp \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -v /home/user/embedded-env/pxe/dnsmasq.conf:/etc/dnsmasq.conf:Z \
  -v /home/user/embedded-env/pxe:/var/lib/tftpboot:Z \
  quay.io/poseidon/dnsmasq:v0.5.0-51-gc8a9de4 \
  --no-daemon
#   --pod "${POD_NAME}" \

# [user@localhost pxe]$ podman ps -a | grep pxe-dhcp
# 312f583cfad7  quay.io/poseidon/dnsmasq:v0.5.0-51-gc8a9de4  --no-daemon           About a minute ago  Up About a minute  53/tcp, 67/tcp, 69/tcp  pxe-dhcp
# [user@localhost pxe]$ podman logs pxe-dhcp
# dnsmasq: started, version 2.92rel2 DNS disabled
# dnsmasq: compile time options: IPv6 GNU-getopt no-DBus no-UBus no-i18n no-IDN DHCP DHCPv6 no-Lua TFTP no-conntrack ipset no-nftset auth no-DNSSEC loop-detect inotify dumpfile
# dnsmasq-dhcp: DHCP, proxy on subnet 192.168.122.0
# dnsmasq-tftp: TFTP root is /var/lib/tftpboot  
# [user@localhost pxe]$ 

echo
echo "=========================================="
echo "Setup completed."
echo "=========================================="

echo
echo "Services Status:"
echo "  ProxyDHCP : UDP 4011 (Host network)"
echo "  TFTP      : UDP 69   (Host network)"
echo "  Nginx     : TCP 80   (Host network)"
