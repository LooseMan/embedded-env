# Ansible インストールガイド

## 概要

本書では、Ansible実行環境を構築する手順を説明します。

本プロジェクトでは、Ansible Control NodeをAlmaLinux 9ベースの環境として構築し、Playbookの実行環境を統一します。

管理対象は以下を想定しています。

- AlmaLinux 9（SSH）
- Windows 11（WinRM）
- CentOS 5（SSH）

CentOS 5のようなレガシーOSとの互換性を確保するため、Control NodeではSHA-1を有効化した暗号ポリシーを採用します。

---

# システム構成

```text
                 Ansible Control Node
                  (AlmaLinux 9)
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   AlmaLinux 9      Windows 11       CentOS 5
      (SSH)           (WinRM)          (SSH)
```

ホストOS（macOS・Linux・Windowsなど）はPlaybookやInventoryの作成・Git管理を担当し、AnsibleはControl Node上で実行します。

---

# 前提条件

ホストOSには以下を導入してください。

- Docker Engine または Docker Desktop（Dockerを利用する場合）
- Git

確認

```bash
docker --version
git --version
```

---

# 必要パッケージ

Control Nodeには以下のソフトウェアが必要です。

| パッケージ | 用途 |
|------------|------|
| ansible | Playbook実行 |
| python3-pywinrm | Windows (WinRM) 管理 |
| openssh-clients | Linux (SSH) 管理 |
| crypto-policies-scripts | CentOS 5とのSSH互換性確保 |

ansible パッケージ（および主要なコレクション）取得のため、EPEL リポジトリを追加します。

```bash
RUN dnf -y install epel-release
```

CentOS 5との互換性のため、システム暗号ポリシーを以下へ変更します。

```bash
update-crypto-policies --set DEFAULT:SHA1
```

---

# 動作確認

Ansibleが導入されていることを確認します。

```bash
ansible --version
```

Windows管理ライブラリを確認します。

```bash
python3 -c "import winrm"
```

---

# Inventory作成

例

```yaml
all:
  children:
    alma9:
      hosts:
        alma9:
          ansible_host: 192.168.10.10

    windows:
      hosts:
        win11:
          ansible_host: 192.168.10.20
          ansible_connection: winrm
          ansible_port: 5986
          ansible_winrm_transport: ntlm
          ansible_winrm_server_cert_validation: ignore

    centos5:
      vars:
        ansible_python_interpreter: /usr/bin/python
        ansible_ssh_common_args: >
          -oHostKeyAlgorithms=+ssh-rsa
          -oPubkeyAcceptedAlgorithms=+ssh-rsa
      hosts:
        legacy:
          ansible_host: 192.168.10.30
```

---

# 接続確認

## AlmaLinux 9

```bash
ansible alma9 -m ping
```

## Windows 11

```bash
ansible windows -m ansible.windows.win_ping
```

## CentOS 5

まずはFact収集を行わず、SSH疎通のみ確認します。

```bash
ansible centos5 -m raw -a "uname -a"
```

---

# Docker環境（任意）

本プロジェクトでは、Ansible実行環境をDockerコンテナとして提供することもできます。

Dockerを利用することで、

- 開発者間で実行環境を統一できる
- Pythonライブラリを共通化できる
- ホストOSを汚さず利用できる
- CI/CD環境へそのまま流用できる

といったメリットがあります。

Dockerを利用する場合は、リポジトリに同梱されている `Dockerfile` を利用してください。

## Dockerイメージ作成

```bash
docker build -t ansible-control-node .
```

## コンテナ起動

```bash
docker run --rm -it \
  -v "$(pwd):/workspace" \
  -v "$HOME/.ssh:/root/.ssh:ro" \
  ansible-control-node
```

Playbookは `/workspace` 配下で実行します。

---

# CentOS 5管理時の注意事項

CentOS 5はサポート終了済みのレガシーOSです。

現行LinuxとはSSH暗号方式やPython環境が異なるため、以下の対応を行っています。

- SHA-1暗号ポリシーを有効化
- `ansible_python_interpreter`を指定
- 必要に応じて`raw`モジュールを利用

Pythonが導入されていない環境では、`raw`モジュールによる初期セットアップを実施してください。

---

# 参考資料

- Ansible公式  
  https://docs.ansible.com/

- AlmaLinux公式  
  https://almalinux.org/

- Red Hat Crypto Policies  
  https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/using-the-system-wide-cryptographic-policies_security-hardening
