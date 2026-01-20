FROM node:20-slim

# Install git, jq, Chromium, fonts, and dependencies for Puppeteer
RUN apt-get update && apt-get install -y \
    git \
    jq \
    ca-certificates \
    chromium \
    fonts-recommended \
    fonts-liberation \
    fonts-noto-core \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    && rm -rf /var/lib/apt/lists/*

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV NODE_PATH=/usr/local/lib/node_modules

# Install Claude Code CLI, Puppeteer, and jsdom globally
RUN npm install -g @anthropic-ai/claude-code puppeteer jsdom

# Create non-root user
RUN useradd -m -s /bin/bash analyzer

# Create directories and set permissions
RUN mkdir -p /output /output/images /output/html /repo /input && chown -R analyzer:analyzer /output /repo /input

# Copy analysis scripts and make executable by all
COPY --chmod=755 analyze.sh /analyze.sh
COPY --chmod=755 analyze_pr.sh /analyze_pr.sh
COPY --chmod=755 analyze_commit.sh /analyze_commit.sh
COPY --chmod=755 generate_article.sh /generate_article.sh
COPY --chmod=755 generate_project_recommendations.sh /generate_project_recommendations.sh
COPY --chmod=755 generate_section_recommendations.sh /generate_section_recommendations.sh
COPY --chmod=755 generate_all_recommendations.sh /generate_all_recommendations.sh
COPY --chmod=755 suggest_sections.sh /suggest_sections.sh
COPY --chmod=755 generate_css.sh /generate_css.sh
COPY --chmod=755 render_mockup.sh /render_mockup.sh
COPY --chmod=644 render_mockup.js /render_mockup.js
COPY --chmod=755 validate_html.js /validate_html.js

# Switch to non-root user
USER analyzer

# Set working directory
WORKDIR /repo

ENTRYPOINT ["/analyze.sh"]
