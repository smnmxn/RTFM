#!/bin/bash

# Docker entrypoint script for Claude analyzer container
# Handles OAuth authentication setup before running the main command

set -e

# Setup authentication from OAuth token if provided
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    echo "Setting up Claude CLI authentication from OAuth token..."

    mkdir -p ~/.claude

    # Create credentials file
    cat > ~/.claude/.credentials.json << EOF
{
  "claudeAiOauth": {
    "accessToken": "$CLAUDE_CODE_OAUTH_TOKEN",
    "refreshToken": "$CLAUDE_CODE_OAUTH_TOKEN",
    "expiresAt": "2099-12-31T23:59:59.999Z",
    "scopes": ["read", "write"],
    "subscriptionType": "max"
  }
}
EOF

    # Create config file if it doesn't exist
    if [ ! -f ~/.claude.json ]; then
        cat > ~/.claude.json << EOF
{
  "hasCompletedOnboarding": true,
  "hasAvailableSubscription": true
}
EOF
    fi

    chmod 600 ~/.claude/.credentials.json
    [ -f ~/.claude.json ] && chmod 600 ~/.claude.json

    echo "OAuth authentication setup complete"
fi

# Execute the command passed to docker run
exec "$@"
