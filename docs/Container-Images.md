# コンテナイメージの設計と公開

このリポジトリでは、各実行環境を独立したコンテナイメージとして管理し、GitHub ActionsでGHCR（GitHub Container Registry）へ公開します。現在はTerraformとAnsibleを対象にしていますが、この設計は今後追加するすべての実行環境コンテナに適用します。

## 全体構成

```text
terraform/docker/
├── Dockerfile-v2
├── .dockerignore
├── providers.tf
└── terraform-v2.rc

ansible/docker/
├── Dockerfile-v2
├── .dockerignore
└── ansible.cfg
```

各コンテナはビルドコンテキストとワークフローを分離します。一つのコンテナを変更しても、変更のない他のイメージはビルドされません。

| イメージ | Dockerfile | ビルドコンテキスト | GHCRイメージ |
| --- | --- | --- | --- |
| Terraform | `terraform/docker/Dockerfile-v2` | `terraform/docker` | `ghcr.io/<owner>/<repository>/terraform` |
| Ansible | `ansible/docker/Dockerfile-v2` | `ansible/docker` | `ghcr.io/<owner>/<repository>/ansible` |

現在のイメージは`linux/amd64`向けにビルドします。Terraformのlibvirt Providerと、利用先のAlmaLinux環境との互換性を優先した設定です。新しいコンテナも、特別な要件がない限りこのプラットフォームを使用します。

## 設計単位

新しいコンテナは、次の一式を一つの設計単位として追加します。

```text
<container>/docker/
├── Dockerfile-v2
├── .dockerignore
└── Dockerfileが参照する設定・依存定義

.github/workflows/publish-<container>-image.yml
```

ワークフローはコンテナごとに作成し、そのコンテナの変更だけをpath filterで検知します。Dockerfileが共通ファイルを参照する場合は、その共通ファイルを変更したときに影響を受ける全ワークフローを起動します。

## 変更から公開まで

```text
対象ファイル変更
      │
      ├─ Pull Request ──> 対応するイメージだけビルド検証（公開なし）
      │
      └─ mainへpush ────> 対応するイメージだけビルド ──> GHCRへ公開
```

一時ブランチへの通常のpushではワークフローは実行されません。Pull Requestで新しいコミットをpushすると、そのPull Requestの検証として対象イメージだけがビルドされます。Pull Requestが`main`へマージされると、`main`へのpushを契機にビルドと公開が行われます。

手動で確認・公開したい場合は、GitHub Actions画面から対象ワークフローの`workflow_dispatch`を実行します。

## トリガー対象ファイル

各ワークフローは、対応するコンテナの次のファイルを`push.paths`と`pull_request.paths`に列挙します。

- `Dockerfile-v2`
- `.dockerignore`
- Dockerfileの`COPY`対象、依存定義、設定ファイル
- 対応するワークフロー自身

新しい`COPY`対象やビルド時入力を追加した場合は、ワークフローのpath filterも同時に更新します。

### 現在のTerraform

`.github/workflows/publish-terraform-image.yml`は次の変更で起動します。

- `terraform/docker/Dockerfile-v2`
- `terraform/docker/.dockerignore`
- `terraform/docker/providers.tf`
- `terraform/docker/terraform-v2.rc`
- Terraform用ワークフロー自身

`Dockerfile-v2`は`providers.tf`をProvider mirrorの生成に、`terraform-v2.rc`をTerraform CLI設定に使用します。.dockerignoreの変更もビルドコンテキストを変えるため、トリガー対象です。

### 現在のAnsible

`.github/workflows/publish-ansible-image.yml`は次の変更で起動します。

- `ansible/docker/Dockerfile-v2`
- `ansible/docker/.dockerignore`
- `ansible/docker/ansible.cfg`
- Ansible用ワークフロー自身

`Dockerfile-v2`は`ansible.cfg`をイメージ内の固定パスへコピーします。.dockerignoreの変更も同様にトリガー対象です。

## タグと権限

`main`へのpushでは、次のタグを付けて公開します。

- `latest`
- `sha-<コミットSHA>`

Pull RequestではイメージをGHCRへ公開しません。公開にはワークフローの`GITHUB_TOKEN`を使用し、必要な権限は次のとおりです。

```yaml
permissions:
  contents: read
  packages: write
```

リポジトリ設定でActionsによるパッケージ書き込みが許可されている必要があります。

## ローカルビルド

公開前に対象イメージだけを確認できます。

```bash
cd terraform/docker
docker build --pull --platform linux/amd64 \
  -f Dockerfile-v2 \
  -t terraform:local .
```

```bash
cd ansible/docker
docker build --pull --platform linux/amd64 \
  -f Dockerfile-v2 \
  -t ansible:local .
```

Terraformはビルド時にTerraform RegistryからProvider mirrorを取得します。AnsibleはOSパッケージ、PyPI、Ansible Galaxyへ接続して必要な依存物を取得します。そのため、初回ビルドには外部ネットワーク接続が必要です。

新しいコンテナを追加する場合は、ビルド時に接続するレジストリやパッケージサーバー、固定するバージョン、実行時に必要な接続先をこのREADMEの対応表またはコンテナ固有のREADMEへ記録します。

## 設計上の注意

- 秘密鍵、認証情報、Terraform state、環境固有の設定をDockerfileへコピーしない。
- Dockerfileが新しい`COPY`対象を参照する場合、対応するワークフローの`push.paths`と`pull_request.paths`へ追加する。
- 複数コンテナを無条件に同じmatrixジョブでビルドしない。変更のないイメージまでリビルド・公開されるためです。
- `main`以外のブランチへpushしても、GHCR公開は発生しない。公開結果を確認する場合はPull Requestを`main`へマージするか、手動実行を使う。
- 新しいコンテナを追加したら、対応表、ワークフロー、トリガー対象、ローカルビルド方法を更新する。

## 関連ファイル

- [Terraform用ワークフロー](../.github/workflows/publish-terraform-image.yml)
- [Ansible用ワークフロー](../.github/workflows/publish-ansible-image.yml)
- [Terraform Dockerfile](../terraform/docker/Dockerfile-v2)
- [Ansible Dockerfile](../ansible/docker/Dockerfile-v2)
