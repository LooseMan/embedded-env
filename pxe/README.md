
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

**3. ハマりやすいポイントと解決策（まとめ）**

* **クライアントが BIOS（`Arch:00000`）で起動して反応しない:**
* VMware 等の VM 設定で **EFI（UEFI）モード** を有効化する。


* **`images/vmlinuz not found` になる:**
* TFTP ルート配下に `images` ディレクトリを作り、ISO から `vmlinuz` と `initrd.img` を配置する。


* **`.treeinfo` や `.discinfo` が 404 エラーになる:**
* 手動コピー時にドット隠しファイルが漏れるのが原因。ISO を直接マウント（`mount -o loop`）して全ファイルを参照可能にする。


* **Podman 起動時に `Read-only file system` エラー（`lsetxattr`）が出る:**
* ISO の Read-Only マウントに対して `:Z` や `:z` を指定すると発生。マウント指定を `:ro` に変更し、ホストのマウント時に `context="..."` を付与する。

