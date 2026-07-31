# Terraform コンテナ環境

このディレクトリの Dockerfile は Terraform 実行専用です。Terraform、リモート libvirt への接続に必要なライブラリ、SSH クライアント、および中央カタログで固定した Provider を含みます。Terraform プロジェクト自体はイメージに含めません。

このイメージは `linux/amd64`（x86_64）専用です。`dmacvicar/libvirt` Provider 0.9.8 は、Terraform 公式の `terraform providers mirror` コマンドでビルド時に取得し、展開済みの filesystem mirror として同梱します。

## ビルド

リポジトリのルートで実行します。

```bash
docker build --platform linux/amd64 -t embedded-env-terraform ./terraform
```

x86_64 Linux ホストでは `--platform linux/amd64` を省略できます。Apple Silicon など別アーキテクチャのホストでは、この指定により x86_64 イメージとしてビルド・実行されます。

バージョンを確認します。

```bash
docker run --rm embedded-env-terraform terraform version
```

## Terraform の実行

構成ディレクトリを `/workspace` としてマウントして実行します。状態ファイルと `.terraform` ディレクトリはホスト側に保存されます。

```bash
cd terraform/simple-libvirt-vm
docker run --rm -it \
  -v "$PWD:/workspace" -w /workspace \
  embedded-env-terraform terraform init
docker run --rm -it \
  -v "$PWD:/workspace" -w /workspace \
  embedded-env-terraform terraform plan
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
  embedded-env-terraform terraform apply
```

初回接続時は、ホストの SSH で接続先のホスト鍵を確認しておくと安全です。

秘密鍵をコンテナイメージへコピーしたり、Terraform の設定ファイルに記録したりしないでください。

## 閉域環境向け Provider ミラー

`terraformrc` は、同梱する `/opt/terraform/providers` の展開済み filesystem mirror だけを Provider の取得元として設定しています。`direct` を定義していないため、`terraform init` は Terraform Registry から Provider を取得しません。Terraform は各プロジェクトの `.terraform/providers` からミラー内の Provider 実体へのシンボリックリンクを作成できるため、Provider バイナリをプロジェクトごとに複製しません。

`providers.tf` は、イメージに同梱する Provider の中央カタログです。Provider を追加・更新する場合は、このファイルの `required_providers` を更新してイメージを再ビルドしてください。ビルド時に `terraform providers mirror` が `/opt/terraform/providers` を生成し、Dockerfile が展開済みレイアウトへ変換します。各 Terraform プロジェクトの `required_providers` は、中央カタログに含まれる同じ Provider とバージョン制約を指定します。

この設定は Provider の取得だけを閉域化します。モジュールのダウンロード、remote backend への接続、Terraform の更新チェックには、それぞれの設定に応じて外部ネットワーク接続が必要になる場合があります。

## 注意事項

- Docker Desktop から接続先の libvirt ホストへ到達できることを事前に確認してください。
- `terraform apply` と `terraform destroy` はリモートの libvirt リソースを変更・削除します。実行前に `terraform plan` を確認してください。
- RHEL/CentOS 5 系など旧式 SSH の接続互換性は、必要な接続先だけに限定して SSH 設定で有効化してください。

## 参考資料

https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html
