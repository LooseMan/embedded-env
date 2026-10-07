# Terraform コンテナ環境

このディレクトリの Dockerfile は Terraform 実行専用です。Terraform、リモート libvirt への接続に必要なライブラリ、SSH クライアント、およびProviderのキャッシュを含みます。Terraform プロジェクト自体はイメージに含めません。

このイメージは `linux/amd64`（x86_64）専用です。`dmacvicar/libvirt` Provider 0.9.8 は、イメージビルド時の `terraform init -backend=false` で取得し、`plugin_cache_dir` にキャッシュして同梱します。

## 固定バージョン

Terraform実行環境の再現性を保つため、Dockerfile冒頭の `ARG` に既定バージョンを集約し、ここにも明記します。Dockerfileを直接編集するか、`docker build --build-arg` で呼び出し元から上書きできます。

| コンポーネント | バージョン |
| --- | --- |
| ベースイメージ | AlmaLinux 9.7 |
| Terraform CLI | 1.16.5 |
| libvirt Provider | 0.9.8 |
| dnf-plugins-core | 4.3.0 |
| libvirt-libs | 10.10.0系 |
| openssh-clients | 8.7p1系 |

例:

```bash
docker build --platform linux/amd64 \
  --build-arg ALMALINUX_VERSION=9.7 \
  --build-arg TERRAFORM_VERSION=1.16.5 \
  --build-arg DNF_PLUGINS_VERSION=4.3.0 \
  --build-arg LIBVIRT_VERSION=10.10.0 \
  --build-arg OPENSSH_VERSION=8.7p1 \
  -t terraform .
```

libvirt Providerのバージョンは `providers.tf` で管理します。

`libvirt-libs` と `openssh-clients` は、AlmaLinux 9.7の有効なリポジトリから解決します。RPMのrelease番号（例: `el9_7.alma.1`）はミラーの更新状況によって変わるため、Dockerfileでは固定しません。

## ビルド

`terraform/docker` ディレクトリで実行します。

```bash
cd terraform/docker
docker build --platform linux/amd64 -t terraform .
```

x86_64 Linux ホストでは `--platform linux/amd64` を省略できます。Apple Silicon など別アーキテクチャのホストでは、この指定により x86_64 イメージとしてビルド・実行されます。

バージョンを確認します。

```bash
docker run --rm terraform terraform version
```

## Terraform の実行

構成ディレクトリを `/workspace` としてマウントして実行します。状態ファイルと `.terraform` ディレクトリはホスト側に保存されます。

```bash
cd terraform/simple-libvirt-vm
docker run --rm -it \
  -v "$PWD:/workspace" -w /workspace \
  terraform terraform init
docker run --rm -it \
  -v "$PWD:/workspace" -w /workspace \
  terraform terraform plan
```

## リモート libvirt への SSH 接続

この構成は `qemu+ssh` でリモート libvirt に接続します。ホストで SSH agent を起動し、コンテナへソケットを渡します。

```bash
eval "$(ssh-agent)"
ssh-add ~/.ssh/<private-key>

cd terraform/simple-libvirt-vm
docker run --rm -it \
  -v "$PWD:/workspace" -w /workspace \
  -v "$SSH_AUTH_SOCK:/ssh-agent" \
  -e SSH_AUTH_SOCK=/ssh-agent \
  terraform terraform apply
```

初回接続時は、ホストの SSH で接続先のホスト鍵を確認しておくと安全です。

秘密鍵をコンテナイメージへコピーしたり、Terraform の設定ファイルに記録したりしないでください。

## Provider キャッシュ

`.terraformrc` はTerraform標準の `/root/.terraform.d/plugin-cache` を `plugin_cache_dir` として指定しています。ビルド時に `terraform init -backend=false` がProviderを取得し、実行時の各プロジェクトの `terraform init` はこのキャッシュを再利用します。

`providers.tf` はビルド時に取得するProviderの定義です。Providerを追加・更新する場合は、このファイルを更新してイメージを再ビルドしてください。Providerのlock情報はビルド時の `terraform init` で生成されます。

初回のイメージビルドにはTerraform Registryへのネットワーク接続が必要です。モジュールのダウンロード、remote backendへの接続、Terraformの更新チェックにも、それぞれの設定に応じて外部ネットワーク接続が必要になる場合があります。

## 注意事項

- Docker Desktop から接続先の libvirt ホストへ到達できることを事前に確認してください。
- `terraform apply` と `terraform destroy` はリモートの libvirt リソースを変更・削除します。実行前に `terraform plan` を確認してください。
- RHEL/CentOS 5 系など旧式 SSH の接続互換性は、必要な接続先だけに限定して SSH 設定で有効化してください。

## 参考資料

https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html
