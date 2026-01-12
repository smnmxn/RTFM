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
RUN mkdir -p /output /repo /input && chown -R analyzer:analyzer /output /repo /input

# Copy analysis scripts and make executable by all
COPY --chmod=755 analyze.sh /analyze.sh
COPY --chmod=755 analyze_pr.sh /analyze_pr.sh
COPY --chmod=755 analyze_commit.sh /analyze_commit.sh
COPY --chmod=755 generate_article.sh /generate_article.sh
COPY --chmod=755 generate_project_recommendations.sh /generate_project_recommendations.sh
COPY --chmod=755 generate_section_recommendations.sh /generate_section_recommendations.sh
COPY --chmod=755 suggest_sections.sh /suggest_sections.sh

# Switch to non-root user
USER analyzer

# Set working directory
WORKDIR /repo

ENTRYPOINT ["/analyze.sh"]
