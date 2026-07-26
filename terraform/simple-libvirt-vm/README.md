# RHEL 5 系ゲストをリモート libvirt に配備する Terraform 構成

AlmaLinux 10 上で稼働するリモート libvirt サーバーに、RHEL/CentOS 5 系のゲストを 1 台作成します。Terraform は macOS などの操作端末から SSH 経由で libvirt に接続します。

ゲストの eth0 は、リモート libvirt ホストにあらかじめ存在する `default` NAT ネットワークに接続されます。IP アドレスはその DHCP により動的に割り当てられます。OS 固有の初期設定は Terraform では行わず、ゲストイメージの準備または Ansible で行います。

## 構成

```text
操作端末
  └─ SSH / libvirt URI ──> AlmaLinux 10 (192.168.56.5)
                               └─ default (libvirt 既定 NAT)
                                    └─ nested-guest-vm-2 (DHCP)
```

| 項目 | 現在の設定 |
| --- | --- |
| libvirt 接続先 | `qemu+ssh://ifour@192.168.56.5/system` |
| VM 名 | `nested-guest-vm-2` |
| CPU / メモリ | 2 vCPU / 2048 MiB |
| エミュレーター | QEMU、`host-model` CPU |
| マシンタイプ | `pc-i440fx-rhel10.0.0`（BIOS 起動） |
| ディスク | IDE の `hda`、qcow2 overlay、最大 64 GiB |
| ネットワーク | eth0: libvirt の `default`（DHCP）／eth1: `host-only-bridge-2`（`192.168.150.0/24`、静的設定） |
| ゲスト IP / MAC | eth0 は libvirt が DHCP／MAC を自動割り当て |
| 画面コンソール | VNC（ホストの空きポートを自動使用） |

ホストオンリー用ネットワークの定義は残っていますが、ゲストへの NIC 接続はコメントアウトされています。現状、ゲストに接続される NIC は NAT 用の `eth0` のみです。

## 事前条件

- 操作端末に Terraform と、`dmacvicar/libvirt` プロバイダーが動作する環境があること。
- 操作端末から `ifour@192.168.56.5` へ SSH 接続できること。接続 URI と秘密鍵のパスは `terraform.tfvars` に設定します。
- リモートホストに libvirt の `default` ネットワークが存在し、起動していること。
- リモートホストに libvirt の `default` ストレージプールがあり、ベースイメージ `centos-5.11.qcow2` をそのプールから参照できること。
- ベースイメージは RHEL/CentOS 5 系で、NAT 側を DHCP で起動できるようあらかじめ設定済みであること。

`backing_store.path` は現在 `centos-5.11.qcow2` です。Terraform を実行する前に、リモート libvirt ホストの `default` プールでこの名前が解決できることを確認してください。

```bash
ssh ifour@192.168.56.5 'virsh vol-info --pool default centos-5.11.qcow2'
```

## デプロイ

```bash
cd terraform/simple-libvirt-vm
terraform init
terraform plan
terraform apply
```

適用後、DHCP リースからゲストの IP を確認し、その IP への疎通を確認します。

```bash
ssh ifour@192.168.56.5 'virsh net-dhcp-leases default'
ping <DHCPで割り当てられたIPアドレス>
```

## レガシー SSH への接続

RHEL/CentOS 5 系の SSH サーバーは、現行クライアントで無効な `ssh-rsa` などの旧式アルゴリズムしか提供しない場合があります。このリポジトリでは `ansible/playbook/playbook.yml` に、対象ゲストだけへ適用する `HostKeyAlgorithms=+ssh-rsa` と `PubkeyAcceptedAlgorithms=+ssh-rsa` を設定しています。必要な場合だけ対象ホストに限定してください。

AlmaLinux 10 の暗号ポリシーによっては、ホスト側でも SHA-1 を許可する追加設定が必要になることがあります。これはシステム全体のセキュリティを弱めるため、影響範囲を確認し、可能なら専用の踏み台や接続元に限定してください。`ssh-dss` は AlmaLinux 10 では利用できないため指定しません。

## 運用上の注意

- overlay の `capacity`（64 GiB）は仮想上限です。ベースイメージより小さく設定するとゲストが起動不能になることがあります。
- VNC は `0.0.0.0` で待ち受けます。外部ネットワークから到達可能な環境では、ファイアウォールなどで接続元を制限してください。
- `terraform destroy` は、この構成で Terraform が管理する VM、NAT／ホストオンリーのネットワーク、overlay ボリュームを削除します。ベースイメージ自体は削除対象ではありません。
- 接続先、鍵の場所、VM／ネットワーク名は `terraform.tfvars` で環境ごとに設定します。`terraform.tfvars` は Git 管理対象外です。
