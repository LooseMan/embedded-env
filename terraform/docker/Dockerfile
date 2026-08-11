# syntax=docker/dockerfile:1
# ==============================================================================
# 1. Terraform CLI インストールレイヤー
# ==============================================================================
FROM almalinux:9 AS terraform

RUN dnf -y install --nodocs dnf-plugins-core unzip && \
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    dnf -y install --nodocs terraform && \
    dnf clean all && \
    rm -rf /var/cache/dnf

    # ==============================================================================
# 2. プロバイダのダウンロード（ミラーリング）レイヤー
# ==============================================================================
FROM terraform AS provider-mirror

WORKDIR /source

# 【高速化】BuildKit のキャッシュマウントを利用し、プロバイダのDLを爆速化
RUN --mount=type=bind,source=providers.tf,target=providers.tf \
    --mount=type=cache,target=/root/.terraform.d/plugin-cache \
    terraform providers mirror -platform=linux_amd64 /opt/terraform/providers && \
    find /opt/terraform/providers -type f -name '*.zip' -print0 | \
    while IFS= read -r -d '' archive; do \
        provider_dir="$(dirname "$archive")"; \
        provider_type="$(basename "$provider_dir")"; \
        archive_name="$(basename "$archive" .zip)"; \
        version="${archive_name#terraform-provider-${provider_type}_}"; \
        version="${version%_linux_amd64}"; \
        target_dir="${provider_dir}/${version}/linux_amd64"; \
        mkdir -p "$target_dir"; \
        unzip -q "$archive" -d "$target_dir"; \
        rm "$archive"; \
    done

# ==============================================================================
# 3. 実行用イメージ（システム固定・閉域専用）
# ==============================================================================
FROM almalinux:9

RUN dnf -y install --nodocs \
        libvirt-libs \
        openssh-clients && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# CLIバイナリのコピー
COPY --from=terraform /usr/bin/terraform /usr/local/bin/terraform

# Provider の実体を展開済み filesystem mirror に配置
COPY --from=provider-mirror /opt/terraform/providers /opt/terraform/providers

# 設定ファイルをコピーし、権限を読み取り専用(444)にする
COPY --chmod=444 terraformrc /etc/terraformrc

# 設定ファイルのパスを固定
ENV TF_CLI_CONFIG_FILE=/etc/terraformrc

WORKDIR /workspace
CMD ["/bin/bash"]
