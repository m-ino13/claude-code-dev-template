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

USER node
WORKDIR /home/node/
