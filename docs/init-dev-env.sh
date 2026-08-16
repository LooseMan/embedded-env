#!/bin/bash

SSH_USER="user"
SSH_HOST="192.168.17.134"
SSH_CONFIG="${HOME}/.ssh/config"

GIT_USER="LooseMan"
GIT_EMAIL="46617161+LooseMan@users.noreply.github.com"

remote_command() {
	echo "ssh ${SSH_USER}@${SSH_HOST} $@"
	# -qオプションを付与して、sshコマンドの出力を抑制します。
	# -tオプションを付与して、リモートホストでのコマンド実行時に疑似端末を割り当てます。(sudoコマンドを使用する場合に必要)
	ssh -qt ${SSH_USER}@${SSH_HOST} "$@"
}

main() {
	# Copy SSH key to remote host if not already copied
	ssh-copy-id ${SSH_USER}@${SSH_HOST}
	if [ $? -ne 0 ]; then
		echo "Failed to copy SSH key to remote host"
		exit 1
	fi

	# add SSH config for remote host if not already added
	if ! grep -q "Host ${SSH_HOST}" ${SSH_CONFIG}; then
		echo "Adding SSH config for remote host"
		# ヒアドキュメントを使用して、複数行の文字列を一度に追加することもできます。
		cat >> ${SSH_CONFIG} <<EOF

Host ${SSH_HOST}
  User ${SSH_USER}
EOF
	fi

	# Install Git on remote host if not already installed
	remote_command "if ! command -v git &> /dev/null; then sudo dnf install -y git; fi"
	if [ $? -ne 0 ]; then
		echo "Failed to install Git on remote host"
		exit 1
	fi
	# show Git version on remote host
	remote_command "git --version"

	# Set Git user name and email on remote host
	remote_command "git config --global user.name $GIT_USER" && \
	remote_command "git config --global user.email $GIT_EMAIL"
	if [ $? -ne 0 ]; then
		echo "Failed to set Git user name and email on remote host"
		exit 1
	fi
	# Show Git configuration on remote host
	remote_command "git config --global --list"
}

main "$@"