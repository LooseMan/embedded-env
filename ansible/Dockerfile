FROM almalinux:9

# 以下の理由からOS更新は実施しない
# 1. イメージのサイズが肥大化する
# 2. ビルドが遅くなり、壊れる原因になる
# 3. 公式イメージはすでに定期更新されている
# RUN dnf -y update

# パッケージインストール（ドキュメント・キャッシュを除外）
RUN dnf -y install epel-release && \
    dnf -y install --nodocs \
        ansible \
        python3-winrm \
        openssh-clients \
        rsync \
        crypto-policies-scripts && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# システム設定（旧暗号化ポリシーを有効化）
RUN update-crypto-policies --set DEFAULT:SHA1

# Ansible 設定
COPY ansible.cfg /etc/ansible/ansible.cfg

# 作業ディレクトリ
WORKDIR /workspace

# デフォルト起動
CMD ["/bin/bash"]
