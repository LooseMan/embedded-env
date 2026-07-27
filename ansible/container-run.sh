#!/bin/bash

IMAGE=verify

docker run --rm -it \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    -v "$(pwd)":/workspace:Z \
    -v "$HOME/.ssh":/root/.ssh:Z \
    "$IMAGE" "$@"
