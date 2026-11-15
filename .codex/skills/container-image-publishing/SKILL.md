---
name: container-image-publishing
description: このリポジトリのDockerfile-v2から実行環境コンテナを設計・変更し、GitHub ActionsとGHCR公開設定まで一貫して扱うスキル。既存のTerraform／Ansibleおよび今後追加するコンテナの設計、Dockerfile変更、ビルドトリガー変更、イメージ公開設定に適用する。
---

# 目的

このリポジトリの実行環境コンテナを、Dockerfile・ビルドコンテキスト・GitHub Actions・GHCRの関係を壊さずに変更する。

# 必須方針

- 各コンテナは別々のビルドコンテキスト、別々のGitHub Actionsワークフローとして扱う。あるコンテナの変更で、変更のない他のコンテナをビルドしない。現在のTerraformとAnsibleにもこの原則を適用する。
- 実際の公開用Dockerfileは、コンテナごとのディレクトリにある`Dockerfile-v2`を使用する。
  - Terraform: `terraform/docker/Dockerfile-v2`
  - Ansible: `ansible/docker/Dockerfile-v2`
- ビルド対象は`linux/amd64`とする。libvirt Providerおよび利用先のAlmaLinux環境との互換性を優先する。
- Dockerfileが`COPY`またはビルドに使用する外部ファイルを変更した場合、対応するワークフローの`push.paths`と`pull_request.paths`にも追加する。
- Pull Requestではビルド検証だけを行い、GHCRへ公開しない。
- `main`へのpushだけをGHCR公開対象とする。一時ブランチへのpushでは公開ビルドを実行しない。
- `workflow_dispatch`は手動リリース用途として、ビルドとGHCR公開を許可する。
- 秘密鍵、クラウド認証情報、Terraform state、環境固有の変数をイメージへコピーしない。

# 現在のファイル対応表（既存コンテナ）

| イメージ | ビルドコンテキスト | Dockerfile | Dockerfileの参照ファイル | ワークフロー |
| --- | --- | --- | --- | --- |
| Terraform | `terraform/docker` | `terraform/docker/Dockerfile-v2` | `providers.tf`, `terraform-v2.rc` | `.github/workflows/publish-terraform-image.yml` |
| Ansible | `ansible/docker` | `ansible/docker/Dockerfile-v2` | `ansible.cfg` | `.github/workflows/publish-ansible-image.yml` |

各コンテキストの`.dockerignore`もビルド結果を変えるため、対応するトリガー対象に含める。

# 新しいコンテナを追加するとき

新しい実行環境コンテナを追加する場合は、既存のTerraform／Ansibleの例をコピーするのではなく、次の独立した単位として設計する。

- `<container>/docker/Dockerfile-v2`
- `<container>/docker/.dockerignore`
- Dockerfileが参照する設定ファイル、依存定義、Provider／パッケージ定義
- `.github/workflows/publish-<container>-image.yml`
- 人が設計を確認できる対応表とトリガー対象の記録

新しいワークフローには、そのコンテナのDockerfile、`.dockerignore`、Dockerfileが直接または間接に使用するファイル、ワークフロー自身だけを`push.paths`と`pull_request.paths`へ指定する。共通ファイルを参照する場合は、その変更が影響する全コンテナのワークフローへ追加する。

# ワークフローを変更するとき

複数コンテナを一つのmatrixジョブで無条件にビルドする構成にしない。path filterはコンテナごとのワークフローに定義し、次の条件を維持する。

```yaml
on:
  push:
    branches:
      - main
    paths:
      # 対応するDockerfile、参照ファイル、.dockerignore、ワークフロー自身
  pull_request:
    paths:
      # pushと同じ対象ファイル
  workflow_dispatch:
```

GHCR公開は`docker/login-action`と`docker/build-push-action`で`GITHUB_TOKEN`を使用する。Pull Requestでは次の条件でログインとpushを無効化する。

```yaml
if: github.event_name != 'pull_request'
```

イメージ名は次の形式を維持する。`<image-name>`はコンテナごとに一意で、できるだけディレクトリ名と対応させる。

```text
ghcr.io/<owner>/<repository>/<image-name>
```

デフォルトブランチへの公開では`latest`とコミットSHAタグを付け、それ以外の手動実行では少なくともコミットSHAタグを付ける。

# 変更手順

1. 対象コンテナのDockerfile、ビルドコンテキスト、`.dockerignore`、既存ワークフローを確認する。
2. 変更が対象コンテナだけに影響するか、複数コンテナに共有されるかを判断する。
3. Dockerfileと参照ファイルを変更する場合、対応するワークフローのpath filterを更新する。
4. `git diff --check`を実行し、利用可能ならDockerfile lintおよびGitHub Actions lintを実行する。
5. ローカルで検証できる場合は、対象コンテナだけを`docker build --platform linux/amd64`でビルドする。
6. PRでは公開されず、`main`へのマージ後にGHCRへ公開されることを変更結果に明記する。

既存のユーザー変更や未追跡ファイルを削除・リセットしてはならない。対象外のDockerfileや利用者の実行スクリプトを、公開方針を理由に勝手に統合・削除しない。
