#!/bin/bash
set -euo pipefail

readonly IMAGE=terraform

# スクリプトの配置ディレクトリをコンテナの /workspace に対応させる。
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CURRENT_DIR="$(pwd -P)"

# カレントディレクトリがマウント対象の配下にある場合だけ、
# スクリプト配置ディレクトリからの差分をコンテナ内の作業ディレクトリに反映する。
WORKDIR_ARGS=()
if [[ "$CURRENT_DIR" == "$SCRIPT_DIR" || "$CURRENT_DIR" == "$SCRIPT_DIR/"* ]]; then
    readonly CURRENT_RELATIVE_DIR="${CURRENT_DIR#"$SCRIPT_DIR"}"
    readonly WORKDIR="/workspace${CURRENT_RELATIVE_DIR}"
    WORKDIR_ARGS=(-w "$WORKDIR")
fi

# docker コマンドがない場合は podman に処理を転送する関数を作る
if ! command -v docker &> /dev/null; then
    docker() {
        podman "$@"
    }
fi

# host ネットワークを使うため、--network host を指定する
# スクリプト配置ディレクトリを /workspace にマウントし、そこからの差分を -w に反映する。
docker run --rm -it \
    --network host \
    -v "$SCRIPT_DIR":/workspace:Z \
    -v "$HOME/.ssh":/root/.ssh:Z \
    "${WORKDIR_ARGS[@]}" \
    "$IMAGE" "$@"
