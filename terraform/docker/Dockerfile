# 更新時は、ここを書き換えるか docker build --build-arg で外部から注入する。
ARG ALMALINUX_VERSION=9.7
ARG TERRAFORM_VERSION=1.16.5
ARG DNF_PLUGINS_VERSION=4.3.0
ARG LIBVIRT_VERSION=10.10.0
ARG OPENSSH_VERSION=8.7p1

# ===============================================================================
# 1. ビルドステージ: Terraform CLIとProvider cacheを準備
# ===============================================================================
FROM almalinux:${ALMALINUX_VERSION} AS terraform-build

ARG ALMALINUX_VERSION
ARG TERRAFORM_VERSION
ARG DNF_PLUGINS_VERSION

WORKDIR /tmp/provider

# dnf-plugins-coreはdnf config-managerを提供する。
# AlmaLinuxのパッケージは9.7、HashiCorp repoはRHEL/9として参照する。
# Terraform CLIの導入後、不要なDNFキャッシュを削除する。
RUN dnf --releasever=${ALMALINUX_VERSION} -y install --nodocs dnf-plugins-core-${DNF_PLUGINS_VERSION} && \
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    dnf --releasever=9 -y install --nodocs terraform-${TERRAFORM_VERSION} && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Providerの取得に使うTerraform設定と要求バージョンを配置する。
COPY providers.tf ./
COPY .terraformrc /root/.terraformrc

# Providerを取得し、実行ステージへ引き継ぐ標準cacheへ保存する。
RUN mkdir -p /root/.terraform.d/plugin-cache && \
    terraform init -backend=false

# ===============================================================================
# 2. 実行ステージ: Terraform実行に必要な最小構成
# ===============================================================================
FROM almalinux:${ALMALINUX_VERSION}

ARG ALMALINUX_VERSION
ARG LIBVIRT_VERSION
ARG OPENSSH_VERSION

# AlmaLinux 9.7のリポジトリを参照するためreleaseverを固定する。
# libvirt-libsはlibvirt Providerの実行時共有ライブラリとして必要。
# openssh-clientsはqemu+sshでリモートlibvirtへ接続するために必要。
RUN dnf --releasever=${ALMALINUX_VERSION} -y install --nodocs \
        libvirt-libs-${LIBVIRT_VERSION} \
        openssh-clients-${OPENSSH_VERSION} && \
    dnf clean all && \
    rm -rf /var/cache/dnf

COPY --from=terraform-build /usr/bin/terraform /usr/bin/terraform
COPY --from=terraform-build /root/.terraform.d/plugin-cache /root/.terraform.d/plugin-cache
COPY .terraformrc /root/.terraformrc
RUN chmod 0444 /root/.terraformrc

WORKDIR /workspace
CMD ["/bin/bash"]
