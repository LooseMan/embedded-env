## Bento/centos-5.11 から libvirt 用 qcow2 を作る方法

この構成では、元々 VirtualBox 用の Box イメージ `bento/centos-5.11` を基にして、libvirt で扱える qcow2 を作る流れを想定しています。

### 1. Bento の Box イメージを入手する

まずは Bento の CentOS 5.11 Box を取得します。

```bash
mkdir -p ~/work/box
cd ~/work/box
curl -L -o centos-5.11.box https://app.vagrantup.com/bento/boxes/centos-5.11/versions/latest/providers/virtualbox.box
```

### 2. Box アーカイブを展開して VMDK を取り出す

```bash
mkdir -p unpacked
cd unpacked
unzip ../centos-5.11.box
```

展開後に `*.vmdk` が含まれているはずです。VirtualBox で使うディスクファイルを見つけます。

### 3. VMDK を qcow2 に変換する

macOS では `qemu-img` を使うと変換できます。

```bash
qemu-img convert -f vmdk -O qcow2 input.vmdk output.qcow2
```

### 4. 変換後の qcow2 をデプロイ先へ配置する

libvirt 側で参照できるように、対象ホストへ転送します。

```bash
scp output.qcow2 ifour@192.168.56.5:~
```

### 5. ホスト側でベースイメージとして配置する

デプロイ先のホスト上で、libvirt で参照可能な場所に置きます。

```bash
ssh ifour@192.168.56.5
sudo install -m 0644 ~/output.qcow2 /var/lib/libvirt/images/centos-5.11.qcow2
```
