# check=skip=SecretsUsedInArgOrEnv

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    USERNAME=dev \
    PASSWORD=changeme \
    SHELL=/bin/bash

# Create non-root sudo user
RUN mkdir -p /etc/sudoers.d
RUN useradd -m -s /bin/bash ${USERNAME} && \
    echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-nopasswd && \
    adduser ${USERNAME} sudo

# Install code-server (VS Code in browser)
# https://github.com/coder/code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Pre-create workspace dir
RUN mkdir -p /home/${USERNAME}/workspace && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Optional: preinstall useful extensions (add/remove as you like)
# (Python, Docker, Terraform, YAML, GitLens, Prettier, AWS Toolkit)
USER ${USERNAME}
RUN code-server --install-extension ms-python.python && \
    code-server --install-extension ms-python.vscode-pylance && \
    code-server --install-extension ms-azuretools.vscode-docker && \
    code-server --install-extension hashicorp.terraform && \
    code-server --install-extension redhat.vscode-yaml && \
    code-server --install-extension eamodio.gitlens && \
    code-server --install-extension esbenp.prettier-vscode && \
    code-server --install-extension amazonwebservices.aws-toolkit-vscode || true
USER root

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown ${USERNAME}:${USERNAME} /entrypoint.sh

# Base packages & dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg lsb-release \
    sudo git vim nano tzdata unzip zip \
    build-essential pkg-config \
    python3 python3-pip python3-venv \
    nodejs npm \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 8080
WORKDIR /home/${USERNAME}/workspace
CMD ["/entrypoint.sh"]
