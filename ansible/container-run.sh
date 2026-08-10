#!/bin/bash

IMAGE=ansible

# docker コマンドがない場合は podman に処理を転送する関数を作る
if ! command -v docker &> /dev/null; then
    docker() {
        podman "$@"
    }
fi

# 本ファイルのパスに移動する
cd "$(dirname "$0")"

# host ネットワークを使うため、--network host を指定する
# -w /workspace は、コンテナ内の作業ディレクトリをホスト側のカレントディレクトリに合わせるため
docker run --rm -it \
    --network host \
    -v "$(pwd)":/workspace:Z \
    -v "$HOME/.ssh":/root/.ssh:Z \
    -w /workspace \
    "$IMAGE" "$@"
