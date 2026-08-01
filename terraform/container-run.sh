#!/bin/bash

IMAGE=terraform

# docker コマンドがない場合は podman に処理を転送する関数を作る
if ! command -v docker &> /dev/null; then
    docker() {
        podman "$@"
    }
fi

docker run --rm -it \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    -v "$(pwd)":/workspace:Z \
    -v "$HOME/.ssh":/root/.ssh:Z \
    "$IMAGE" "$@"
