### TerraformとAnsibleの責務整理

**Terraform**

* libvirtでVMを作成・起動する。
* DHCPリース完了（IPアドレス取得）までを責務とする。
* VMが管理対象として存在することを保証する。
* SSH接続やOS初期化までは責務に含めない。

**Ansible**

* VMへの接続開始からを担当する。
* モダンOSでは`wait_for_connection`でSSH接続可能になるまで待機し、その後`gather_facts`・構成管理を実施する。
* レガシーOSでは`raw`モジュールやSSHリトライなど、そのOSに適した方法で接続・初期化を行う。

### cloud-initとの関係

* cloud-initはDHCPリース取得後も処理を継続するため、**IP取得＝初期化完了ではない**。
* そのため、TerraformがSSH接続可能になるまで待つよりも、Ansible側で接続待ちを行う方が責務として自然。

### ポートフォリオでの構成

```text
Terraform
  ├─ VM作成
  ├─ VM起動
  └─ DHCPリース取得（IP出力）

        ↓

Ansible
  ├─ 接続待ち
  ├─ 構成管理
  ├─ ミドルウェア導入
  └─ アプリ配備
```

### この設計のメリット

* Terraformは**インフラ管理**、Ansibleは**構成管理**と責務が明確。
* モダンOS（cloud-initあり）・レガシーOS（RHEL 5など）のどちらにも対応しやすい。
* ツール間の結合度が低く、実務でも説明しやすく保守しやすい設計。
