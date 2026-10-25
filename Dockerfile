FROM node:20-bookworm-slim

# curl / ca-certificates はネイティブインストーラの取得に必要
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    openssh-client \
    git \
    sudo \
    vim-tiny \
 && rm -rf /var/lib/apt/lists/*

# permission setting for volume
RUN mkdir -p /home/node/.claude \
    && chown -R node:node /home/node/.claude

# node has no password set, so plain sudo would prompt for one it can never satisfy.
# Allow passwordless sudo instead (safe here: privilege escalation is contained to this container).
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node \
    && chmod 0440 /etc/sudoers.d/node

USER node
WORKDIR /home/node/

# install Claude Code (native installer, as node user -> auto-updates itself)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/node/.local/bin:${PATH}"

