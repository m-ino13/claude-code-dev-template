FROM node:20-bookworm-slim

RUN apt update && apt install -y \
    openssh-client \
    git \
    sudo \
    vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# permission setting for volume
RUN mkdir -p /home/node/.claude \
    && chown -R node:node /home/node/.claude

# node has no password set, so plain sudo would prompt for one it can never satisfy.
# Allow passwordless sudo instead (safe here: privilege escalation is contained to this container).
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node \
    && chmod 0440 /etc/sudoers.d/node

USER node
WORKDIR /home/node/
