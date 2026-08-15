
**構成概要**

* **PXE 方式:** DHCP Proxy（既存ルーター `192.168.2.1` を生かし、PXE 情報のみ配信）
* **コンテナ構成:** Podman ポッド（`dnsmasq` で DHCP Proxy / TFTP、`nginx` で ISO メディア配信）
* **対象 OS:** AlmaLinux 9（UEFI 64-bit / `Arch:00007`）

---

**1. 構成ファイル・パス構造**

```text
/var/lib/tftpboot/                      # TFTP ルート
├── BOOTX64.EFI                         # ISO/EFI/BOOT/BOOTX64.EFI よりコピー
├── grubx64.efi                         # ISO/EFI/BOOT/grubx64.efi よりコピー
├── grub.cfg                            # GRUB 設定ファイル
└── images/
    ├── vmlinuz                         # ISO/images/pxeboot/vmlinuz よりコピー
    └── initrd.img                      # ISO/images/pxeboot/initrd.img よりコピー

/opt/pxe/iso_root/                      # ISO マウント先（Nginx 配信ルート）

```

---

**2. ホスト側のセットアップコマンド**

**ISO のマウント（SELinux コンテキスト付与）**
Read-Only ファイルシステムである ISO をコンテナに安全に読み込ませるため、マウント時に SELinux ラベルを付与します。

```bash
sudo mkdir -p /opt/pxe/iso_root
sudo mount -o loop,ro,context="system_u:object_r:container_file_t:s0" ~/AlmaLinux-9.8-x86_64-minimal.iso /opt/pxe/iso_root

```

**Nginx コンテナのマウント指定（`:ro` のみ使用）**
Podman が属性変更（`lsetxattr`）で失敗するのを防ぐため、`:Z` や `:z` は付けずに `:ro` のみでマウントします。

```bash
-v /opt/pxe/iso_root:/usr/share/nginx/html/alma9:ro

```

---

**3. ハマりやすいポイントと解決策**

* **クライアントが BIOS（`Arch:00000`）で起動して反応しない:**
* VMware 等の VM 設定で **EFI（UEFI）モード** を有効化する。


* **`images/vmlinuz not found` になる:**
* TFTP ルート配下に `images` ディレクトリを作り、ISO から `vmlinuz` と `initrd.img` を配置する。


* **`.treeinfo` や `.discinfo` が 404 エラーになる:**
* 手動コピー時にドット隠しファイルが漏れるのが原因。ISO を直接マウント（`mount -o loop`）して全ファイルを参照可能にする。


* **Podman 起動時に `Read-only file system` エラー（`lsetxattr`）が出る:**
* ISO の Read-Only マウントに対して `:Z` や `:z` を指定すると発生。マウント指定を `:ro` に変更し、ホストのマウント時に `context="..."` を付与する。

**4. 便利コマンド**

**UDP関連（DHCP / TFTP / DNS 等）**

* `ss -ulnp | grep -E '53|67|69'`
* UDPで待機（Listen）しているプロセスやポート状態を確認する。


* `nc -u -z -v <IPアドレス> <ポート番号>`（例: `nc -u -z -v 127.0.0.1 69`）
* 指定したUDPポートへのソケット疎通を確認する。


* `sudo firewall-cmd --add-port=<ポート番号>/udp --permanent`
* UDPポートの受信をファイアウォールで常時許可する。



**TCP関連（HTTP / HTTPS / SSH 等）**

* `ss -tlnp | grep -E '80|8080|8081'`
* TCPで待機しているプロセスやポート状態を確認する。


* `sudo firewall-cmd --add-port=<ポート番号>/tcp --permanent`
* TCPポートの受信をファイアウォールで常時許可する。



**IP / ネットワーク層（L3）**

* `ip addr`
* インターフェースのIPアドレス割り当て状態やリンク状態を確認する。


* `sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53`
* 特権なし（Rootless）プロセスが1024未満のウェルノウンポート（53番〜）をバインドできるようにカーネルパラメータを変更する。



**ファイアウォール全般**

* `sudo firewall-cmd --list-ports`
* 開放されているポート（TCP/UDP）の一覧を確認する。


* `sudo firewall-cmd --reload`
* 変更したファイアウォール設定を即座に再読み込みして反映する。



**コンテナ・システムログ追尾（動作検証時）**

* `podman logs -f <コンテナ名またはID>`
* コンテナ側のログをリアルタイムで追尾する。


* `sudo tail -f /var/log/messages`
* ホストOS側のシステムログ（カーネルやネットワークイベント等）をリアルタイムで追尾する。


以下のファイルにpxeサーバのIPアドレス、ネットワークアドレスをベタ書きしている
pxe/grub.cfg
pxe/dnsmasq.conf

TODO：
現在はファイアウォールでtftp通信がブロックされるため、ファイアウォールを止めている。
sudo systemctl stop firewalld
以下のコマンドで必要なポートのみ開いて対応したい。

sudo firewall-cmd --add-service=tftp --permanent
sudo firewall-cmd --add-service=dhcp --permanent
sudo firewall-cmd --add-helper=tftp --permanent
sudo firewall-cmd --reload
