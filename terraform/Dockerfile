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
COPY providers.tf .

# providers.tf は、イメージに同梱する Provider の中央カタログである。
# linux/amd64 用の全 Provider を取得し、展開済み filesystem mirror に変換する。
# 展開済みレイアウトでは、terraform init が各プロジェクトの .terraform/providers
# からこのディレクトリへのシンボリックリンクを作成できる。
# providers.tf に Provider またはバージョンを追加した場合、このループは出力された
# すべての zip を処理するため、Dockerfile の個別修正は不要である。
# このイメージは linux/amd64 固定である。別プラットフォームを追加する場合は、
# `-platform` 指定と下記の `linux_amd64` を使う展開先を合わせて更新すること。
#
# 現在の中央カタログの展開例:
# ・展開イメージ：
# /opt/terraform/providers
# └── registry.terraform.io
#     └── dmacvicar
#         └── libvirt
#             └── 0.9.8
#                 └── linux_amd64
#                     ├── terraform-provider-libvirt_v0.9.8
#                     └── (Provider パッケージに含まれるその他のファイル)
RUN terraform providers mirror -platform=linux_amd64 /opt/terraform/providers && \
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
COPY terraformrc /etc/terraformrc
RUN chmod 444 /etc/terraformrc

# 設定ファイルのパスを固定
ENV TF_CLI_CONFIG_FILE=/etc/terraformrc

WORKDIR /workspace
CMD ["/bin/bash"]
