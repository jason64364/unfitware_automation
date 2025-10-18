#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${USERNAME:-dev}"
USER_PASS="${PASSWORD:-changeme}"

# Ensure user exists (image creates it; keep idempotent)
if ! id "$USER_NAME" &>/dev/null; then
  useradd -m -s /bin/bash "$USER_NAME"
  adduser "$USER_NAME" sudo
fi

# Set password so integrated terminal/sudo feel normal
echo "${USER_NAME}:${USER_PASS}" | chpasswd

# Ensure data/config dirs are owned by the dev user
mkdir -p /home/${USER_NAME}/.local/share/code-server /home/${USER_NAME}/.config/code-server /home/${USER_NAME}/workspace
chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}

# code-server reads PASSWORD env var when --auth=password is used
export PASSWORD="${USER_PASS}"

# Drop to non-root and start code-server
exec su - "${USER_NAME}" -c "code-server \
  --bind-addr 127.0.0.1:8085 \
  --auth password \
  --disable-telemetry \
  /home/${USER_NAME}/workspace"
