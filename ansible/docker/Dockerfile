# 更新時は、ここを書き換える。
ARG ANSIBLE_VERSION=7.7.0

# ============================================================
# Ansible実行用イメージ
# ============================================================
FROM almalinux:9
ARG ANSIBLE_VERSION

# パッケージインストール（ドキュメント・キャッシュを除外）
# システム設定（旧暗号化ポリシーを有効化、Alma10以降は削除されている）
# AlmaLinux由来のOSパッケージはベースイメージのリポジトリから解決する。
RUN dnf -y install --nodocs \
        crypto-policies-scripts && \
    update-crypto-policies --set DEFAULT:SHA1 && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Ansible関連パッケージ（ドキュメント・キャッシュを除外）
# epel-releaseがEPELリポジトリ設定を提供する。
# Ansible のバージョンだけは実行環境として固定し、周辺の OS パッケージは更新を取り込む。
RUN dnf -y install --nodocs epel-release && \
    dnf -y install --nodocs \
        ansible-${ANSIBLE_VERSION} \
        python3-winrm \
        openssh-clients \
        rsync && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# 作業ディレクトリ
WORKDIR /workspace

# Ansible設定
COPY ansible.cfg /etc/ansible/ansible.cfg

# デフォルト起動
CMD ["/bin/bash"]
