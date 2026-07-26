#!/bin/bash

IMAGE=alma9-ansible-env

podman run --rm -it \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    -v "$(pwd)":/workspace:Z \
    -v "$HOME/.ssh":/root/.ssh:Z \
    "$IMAGE" "$@"
