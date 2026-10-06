# ===============================================================================
# 1. ビルド用ステージ
# ===============================================================================
FROM almalinux:9.7 AS terraform-build

# dnf-plugins-core は dnf config-manager を使うために必要
RUN dnf --releasever=9.7 -y install --nodocs dnf-plugins-core-4.3.0 && \
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    # HashiCorp repoはRHEL/9を提供し、RHEL/9.7というreleaseverは提供しない。
    dnf --releasever=9 -y install --nodocs terraform-1.16.5 && \
    dnf clean all && \
    rm -rf /var/cache/dnf

WORKDIR /tmp/provider
COPY providers.tf ./
COPY .terraformrc /root/.terraformrc

# Providerを通常のterraform initで取得し、rootの標準キャッシュへ保存する。
RUN mkdir -p /root/.terraform.d/plugin-cache && \
    terraform init -backend=false

# ===============================================================================
# 2. 実行用イメージ
# ===============================================================================
FROM almalinux:9.7

# 9.7用のリポジトリを参照するために releasever=9.7 を指定（デフォルトは latest 用）
# libvirt-libs は terraform-libvirt プラグインの利用に必要
# openssh-clients は libvirt サーバへの qemu+ssh 接続に必要
RUN dnf --releasever=9.7 -y install --nodocs \
        libvirt-libs-10.10.0 \
        openssh-clients-8.7p1 && \
    dnf clean all && \
    rm -rf /var/cache/dnf

COPY --from=terraform-build /usr/bin/terraform /usr/local/bin/terraform
COPY .terraformrc /root/.terraformrc
COPY --from=terraform-build /root/.terraform.d/plugin-cache /root/.terraform.d/plugin-cache
RUN chmod 444 /root/.terraformrc

WORKDIR /workspace
CMD ["/bin/bash"]
