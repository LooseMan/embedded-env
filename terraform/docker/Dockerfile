# 更新時は、ここを書き換える。
ARG TERRAFORM_VERSION=1.16.5

# ===============================================================================
# 1. ビルドステージ: Terraform CLIとProvider cacheを準備
# ===============================================================================
FROM almalinux:9 AS terraform-build

ARG TERRAFORM_VERSION

WORKDIR /tmp/provider

# dnf-plugins-coreはdnf config-managerを提供する。
# AlmaLinux と HashiCorp repo は EL 9 系列として参照する。
# Terraform CLIの導入後、不要なDNFキャッシュを削除する。
RUN dnf -y install --nodocs dnf-plugins-core && \
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    dnf -y install --nodocs terraform-${TERRAFORM_VERSION} && \
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
FROM almalinux:9

# ベースイメージの AlmaLinux 9 リポジトリ設定を使用する。
# libvirt-libsはlibvirt Providerの実行時共有ライブラリとして必要。
# openssh-clientsはqemu+sshでリモートlibvirtへ接続するために必要。
RUN dnf -y install --nodocs \
        libvirt-libs \
        openssh-clients && \
    dnf clean all && \
    rm -rf /var/cache/dnf

COPY --from=terraform-build /usr/bin/terraform /usr/bin/terraform
COPY --from=terraform-build /root/.terraform.d/plugin-cache /root/.terraform.d/plugin-cache
COPY .terraformrc /root/.terraformrc
RUN chmod 0444 /root/.terraformrc

WORKDIR /workspace
CMD ["/bin/bash"]
