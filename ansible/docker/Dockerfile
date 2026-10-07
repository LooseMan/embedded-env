# 更新時は、ここを書き換えるか podman build --build-arg で外部から注入する。
ARG ALMALINUX_VERSION=9.7

# ============================================================
# Ansible実行用イメージ
# ============================================================
FROM almalinux:${ALMALINUX_VERSION}

# パッケージは9.7/ EPEL 9時点の既定RPM版を固定する。
# 更新時は、ここを書き換えるか podman build --build-arg で外部から注入する。
ARG EPEL_RELEASEVER=9
ARG CRYPTO_POLICIES_PACKAGE=crypto-policies-scripts-20250905
ARG EPEL_RELEASE_PACKAGE=epel-release-9
ARG ANSIBLE_PACKAGE=ansible-7.7.0
ARG PYTHON3_WINRM_PACKAGE=python3-winrm-0.4.3
ARG OPENSSH_CLIENTS_PACKAGE=openssh-clients-8.7p1
ARG RSYNC_PACKAGE=rsync-3.2.5

# 以下の理由からOS更新は実施しない
# 1. イメージのサイズが肥大化する
# 2. ビルドが遅くなり、壊れる原因になる
# 3. 公式イメージはすでに定期更新されている
# RUN dnf -y update

# パッケージインストール（ドキュメント・キャッシュを除外）
# システム設定（旧暗号化ポリシーを有効化、Alma10以降は削除されている）
# AlmaLinux由来のOSパッケージは9.7のリポジトリを明示する。
# パッケージ名とバージョンはCRYPTO_POLICIES_PACKAGEに完全指定する。
# hadolint ignore=DL3041
RUN dnf --releasever="${ALMALINUX_VERSION}" -y install --nodocs \
        "${CRYPTO_POLICIES_PACKAGE}" && \
    update-crypto-policies --set DEFAULT:SHA1 && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Ansible関連パッケージ（ドキュメント・キャッシュを除外）
# EPELはAlmaLinuxのマイナー版ではなく、EPEL 9のリポジトリを参照する。
# パッケージ名とバージョンは各ARGに完全指定する。
# hadolint ignore=DL3041
RUN dnf --releasever="${EPEL_RELEASEVER}" -y install --nodocs "${EPEL_RELEASE_PACKAGE}" && \
    dnf --releasever="${EPEL_RELEASEVER}" -y install --nodocs \
        "${ANSIBLE_PACKAGE}" \
        "${PYTHON3_WINRM_PACKAGE}" \
        "${OPENSSH_CLIENTS_PACKAGE}" \
        "${RSYNC_PACKAGE}" && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# 作業ディレクトリ
WORKDIR /workspace

# Ansible設定
COPY ansible.cfg /etc/ansible/ansible.cfg

# デフォルト起動
CMD ["/bin/bash"]
