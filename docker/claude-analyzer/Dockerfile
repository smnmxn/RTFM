FROM node:20-slim

# Install git and other dependencies
RUN apt-get update && apt-get install -y \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user
RUN useradd -m -s /bin/bash analyzer

# Create directories and set permissions
RUN mkdir -p /output /repo && chown -R analyzer:analyzer /output /repo

# Copy analysis script and make executable by all
COPY --chmod=755 analyze.sh /analyze.sh

# Switch to non-root user
USER analyzer

# Set working directory
WORKDIR /repo

ENTRYPOINT ["/analyze.sh"]
