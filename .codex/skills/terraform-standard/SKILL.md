---
name: terraform-personal-standard
description: ユーザー好みのTerraform構成（Libvirt 0.9.8準拠、ルートは単一ファイル変数はベタ書き、子モジュールはファイル分割、差分ディスク構成、デフォルトネットワーク）を強制適用し、手直しなしで実戦投入できるコードを生成するスキル。
---

# 目的
Terraformコード生成時、ユーザーの設計思想（ルートはシンプルに1ファイル、モジュール側は綺麗に分割）に100%合致したコードとディレクトリ構成を一発で出力する。

# 1. 必須環境・バージョン定義
- **Libvirt Provider Version**: `0.9.8`
- **構文規則**: `required_providers` ブロックを必須とし、0.8系の古いパラメータは一切排除する。

# 2. ディレクトリ構成・ファイル分割ルール
コードを出力する際は、ルートと子モジュールで以下のように役割とファイル構成を明確に分けること。

## 既存モジュールの優先利用
- 作業対象リポジトリに既存の`modules/`または利用可能な子モジュールがある場合は、まずそれを確認し、要件を満たすものを再利用すること。
- 既存モジュールで要件を満たせる場合、新しい子モジュールディレクトリを作成してはならない。
- 既存モジュールを使う場合、ルートの`main.tf`から相対パスで呼び出し、必要な引数は既存モジュールの変数定義に合わせて具体的な値を渡すこと。
- 既存モジュールで要件を満たせない場合に限り、下記の分割構成で新しい子モジュールを作成すること。

```text
.（ルートモジュール）
└── main.tf               <-- 【必須】ルートはこれ単一。variablesやoutputsに分けない
└── modules/
    └── kvm_vm/           <-- （子モジュール側）
        ├── main.tf       <-- リソースの実態定義
        ├── variables.tf  <-- 変数定義のみ
        └── outputs.tf    <-- 出力定義のみ
```

# 3. ルートモジュールの設計（単一ファイル ＋ 変数ベタ書き）
- **単一ファイルの徹底**: ルート側には `variables.tf` や `outputs.tf` を作成しない。
- **実態のベタ書き**: ルートの `main.tf` で子モジュールを呼び出す際、引数には変数の参照（`var.xxx`）を使わず、その場に**具体的な値（リソース名、スペック、ベースイメージパスなど）を直接ベタ書き（ハードコード）**して定義すること。

# 4. ディスクおよびネットワーク構成
- **差分ディスク（Copy-On-Write）の強制**: ベースとなるOSイメージを `base_volume_id`（または `backing_store`）として指定し、その差分としてインスタンス用のボリュームを作成する構造にすること。
- **ネットワーク**: Libvirtの標準的な `default` ネットワークを使用する。

---

# コード出力テンプレート（基準構造）

AIは以下のファイル構造と記述スタイルを厳格に模倣してコードを生成すること。

### 📁 ［ルート］ ./main.tf
```hcl
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.8"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# ルートはこれ1つ。引数はすべてベタ書きで実態を定義する
module "kvm_vm" {
  source             = "./modules/kvm_vm"
  vm_name            = "prod-web-server"
  vcpu               = 4
  memory             = 8192
  base_image_path    = "/var/lib/libvirt/images/ubuntu-22.04-server-cloudimg-amd64.img"
  disk_size          = 21474836480 # 20GB
  network_name       = "default"
}
```

### 📁 ［子モジュール］ ./modules/kvm_vm/variables.tf
```hcl
variable "vm_name" { type = string }
variable "vcpu" { type = number }
variable "memory" { type = number }
variable "base_image_path" { type = string }
variable "disk_size" { type = number }
variable "network_name" { type = string }
```
