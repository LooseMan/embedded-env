# Ubuntu libvirt VM

既存の`terraform/modules/modern`を利用して、Ubuntu 24.04 Server cloud imageからqcow2の差分ディスクを作成し、libvirtの`default`ネットワークへ接続します。

## 事前準備

`default`ストレージプールにベースイメージを配置してください。

```bash
sudo virsh vol-info --pool default ubuntu-24.04-server-cloudimg-amd64.img
```

この構成は、Ubuntuイメージ側でDHCPとSSHが利用可能になっている前提です。cloud-initによるユーザー・SSH鍵設定は含めていません。

## 実行

```bash
cd terraform/ubuntu-libvirt-vm
terraform init
terraform plan
terraform apply
```

適用後は、`terraform output vm_connection` でDHCP取得アドレスを確認できます。
