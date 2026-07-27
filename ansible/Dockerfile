# ============================================================
# Base
# ============================================================
FROM almalinux:9 AS base

# 以下の理由からOS更新は実施しない
# 1. イメージのサイズが肥大化する
# 2. ビルドが遅くなり、壊れる原因になる
# 3. 公式イメージはすでに定期更新されている
# RUN dnf -y update

# パッケージインストール（ドキュメント・キャッシュを除外）
RUN dnf -y install --nodocs \
        python3 \
        python3-pip \
        crypto-policies-scripts && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# システム設定（旧暗号化ポリシーを有効化、Alma10以降は削除されている）
RUN update-crypto-policies --set DEFAULT:SHA1

# 作業ディレクトリ
WORKDIR /workspace

# ============================================================
# Ansible
#    - コマンド: docker build --target ansible -t ansible .
# ============================================================
FROM base AS ansible

# パッケージインストール（ドキュメント・キャッシュを除外）
RUN dnf -y install epel-release && \
    dnf -y install --nodocs \
        ansible \
        python3-winrm \
        openssh-clients \
        rsync && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Ansible 設定
COPY ansible.cfg /etc/ansible/ansible.cfg

# デフォルト起動
CMD ["/bin/bash"]

# ============================================================
# Verify
#    - コマンド: docker build --target verify -t verify .
# ============================================================
FROM ansible AS verify

RUN pip3 install --no-cache-dir \
        pytest \
        pytest-testinfra

CMD ["pytest"]
