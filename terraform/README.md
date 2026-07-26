# Terraform インストールガイド（macOS 15）

## 概要

本書では、macOS 15 (Sequoia) に Terraform を導入する手順を説明します。

Terraform本体のインストールは HashiCorp が推奨する Homebrew を利用します。

対象読者

- macOS 15
- Homebrew導入済み
- Terraform開発環境を構築したい

---

# 前提条件

以下が導入済みであること

- Homebrew
- Apple Command Line Tools

確認

```bash
brew --version
xcode-select -p
```

---

# 1. HashiCorp Tapを追加

```bash
brew tap hashicorp/tap
```

---

# 2. Terraformをインストール

```bash
brew install hashicorp/tap/terraform
```

最新版へ更新

```bash
brew upgrade terraform
```

---

# 3. 動作確認

```bash
terraform version
```

例

```
Terraform v1.x.x
on darwin_arm64
```

---

# 4. PATH確認

```bash
which terraform
```

Homebrew管理下であることを確認する。

Apple Silicon

```
/opt/homebrew/bin/terraform
```

Intel Mac

```
/usr/local/bin/terraform
```

---

# 5. 動作確認

作業ディレクトリ作成

```bash
mkdir terraform-test
cd terraform-test
```

初期化

```bash
terraform init
```

ヘルプ表示

```bash
terraform -help
```

ここまで実行できれば導入完了。

---

# トラブルシューティング

## Command Line Toolsが古い

Terraformインストール時に

```
Your Command Line Tools are too outdated.
```

が表示される場合はCommand Line Toolsを更新する。

```bash
sudo rm -rf /Library/Developer/CommandLineTools

xcode-select --install
```

インストール完了後に再度

```bash
brew install hashicorp/tap/terraform
```

を実行する。

---

# Dockerコンテナでの利用について

Terraformは単一バイナリで提供されており、依存ライブラリも少ないため、開発環境をコンテナ化するメリットは限定的です。HashiCorpも通常は各OSへ直接インストールする方法を案内しています。

特に、SSH経由でリモート環境を操作するProvider（libvirt Providerなど）を利用する場合、Docker Desktop上では以下のような制約が発生することがあります。

- ホストのSSH鍵をコンテナへマウントする必要がある
- Docker Desktopのネットワーク構成により、VirtualBoxのHost-Only Networkなどホスト専用ネットワークへ接続できない場合がある
- Terraform本来とは関係のないDockerのネットワークやボリューム設定の影響を受ける

そのため、TerraformはmacOSへ直接インストールして利用することを推奨します。

一方で、以下のような用途ではDockerコンテナの利用が有効です。

- `terraform fmt`
- `terraform validate`
- `tflint`
- `tfsec`
- `checkov`

これらは静的解析やCI/CD用途であり、ターゲット環境へのSSH接続を必要としないため、コンテナ環境との相性が良好です。

---

# 参考資料

HashiCorp公式

https://developer.hashicorp.com/terraform/install

Homebrew

https://brew.sh/
