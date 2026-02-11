#!/usr/bin/env bash
#
# setup-backups.sh — One-time backup setup for SupportPages
#
# Run this on the server to configure Borg backups to a Hetzner Storage Box.
# It handles everything: installing packages, generating keys, initializing
# the Borg repository, creating the env file, and setting up cron.
#
# Usage (from your local machine):
#   scp scripts/setup-backups.sh root@host.supportpages.io:~/
#   ssh root@host.supportpages.io ./setup-backups.sh
#
# After running, fill in the remaining values in /etc/backup-supportpages.env:
#   - HETZNER_API_TOKEN  (Cloud Console → Security → API Tokens)
#   - HETZNER_SERVER_ID  (from the console URL)
#   - POSTMARK_API_TOKEN
#   - BACKUP_ALERT_EMAIL
#
# Manual backup operations (via SSH):
#   ssh root@host.supportpages.io /usr/local/bin/backup-supportpages.sh
#   ssh root@host.supportpages.io "source /etc/backup-supportpages.env && borg list"
#   ssh root@host.supportpages.io /usr/local/bin/hetzner-snapshot.sh
#

set -euo pipefail

STORAGE_BOX_USER="u543860"
STORAGE_BOX_HOST="u543860.your-storagebox.de"
SSH_KEY_PATH="/root/.ssh/storagebox"
ENV_FILE="/etc/backup-supportpages.env"

echo "============================================"
echo "  SupportPages Backup Setup"
echo "============================================"
echo ""

# ── 1. Install borgbackup ────────────────────────────────────────────────────

if command -v borg &>/dev/null && command -v jq &>/dev/null; then
  echo "[OK] borgbackup already installed ($(borg --version))"
  echo "[OK] jq already installed"
else
  echo "Installing borgbackup and jq..."
  apt update -qq && apt install -y borgbackup jq
  echo "[OK] borgbackup installed ($(borg --version))"
  echo "[OK] jq installed"
fi
echo ""

# ── 2. Generate SSH key for Storage Box ──────────────────────────────────────

if [[ -f "$SSH_KEY_PATH" ]]; then
  echo "[OK] SSH key already exists at $SSH_KEY_PATH"
else
  echo "Generating SSH key for Storage Box..."
  ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
  echo "[OK] SSH key generated at $SSH_KEY_PATH"
fi
echo ""

# ── 3. Install SSH key on Storage Box ────────────────────────────────────────

echo "The public key needs to be installed on the Storage Box."
echo "Public key:"
echo ""
cat "${SSH_KEY_PATH}.pub"
echo ""

read -rp "Install this key on the Storage Box now? (y/N) " install_key
if [[ "$install_key" == "y" || "$install_key" == "Y" ]]; then
  echo "Installing key on Storage Box (you'll be prompted for the password)..."
  cat "${SSH_KEY_PATH}.pub" | ssh -p 23 "${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}" install-ssh-key
  echo "[OK] Key installed"
else
  echo "Skipping. Install it manually:"
  echo "  cat ${SSH_KEY_PATH}.pub | ssh -p 23 ${STORAGE_BOX_USER}@${STORAGE_BOX_HOST} install-ssh-key"
fi
echo ""

# ── 4. Initialize Borg repository ───────────────────────────────────────────

export BORG_RSH="ssh -p 23 -i ${SSH_KEY_PATH}"
export BORG_REPO="ssh://${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}/./backups/supportpages"

# Check if repo already exists
if borg list &>/dev/null 2>&1; then
  echo "[OK] Borg repository already initialized at $BORG_REPO"
  echo "     (Using existing BORG_PASSPHRASE from $ENV_FILE if present)"

  if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
    export BORG_PASSPHRASE
  fi
else
  # Generate passphrase
  PASSPHRASE=$(openssl rand -base64 32)
  export BORG_PASSPHRASE="$PASSPHRASE"

  echo "============================================"
  echo "  SAVE THIS PASSPHRASE IN YOUR PASSWORD MANAGER"
  echo "  (it will not be shown again)"
  echo ""
  echo "  $PASSPHRASE"
  echo "============================================"
  echo ""

  read -rp "Have you saved the passphrase? (y/N) " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborting. Run this script again when ready."
    exit 1
  fi

  echo "Creating directory on Storage Box..."
  ssh -p 23 -i "$SSH_KEY_PATH" "${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}" "mkdir -p backups/supportpages"

  echo "Initializing Borg repository at $BORG_REPO..."
  borg init --encryption=repokey
  echo "[OK] Borg repository initialized"
  echo ""

  # Export the key
  borg key export "$BORG_REPO" /root/borg-key-backup.txt
  echo "[OK] Key exported to /root/borg-key-backup.txt"
  echo "     Save this file in your password manager alongside the passphrase."
fi
echo ""

# ── 5. Create env file ──────────────────────────────────────────────────────

if [[ -f "$ENV_FILE" ]]; then
  echo "[OK] Environment file already exists at $ENV_FILE"
  echo "     (Not overwriting. Delete it and re-run to regenerate.)"
else
  cat > "$ENV_FILE" << EOF
BORG_RSH="ssh -p 23 -i ${SSH_KEY_PATH}"
BORG_REPO="ssh://${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}/./backups/supportpages"
BORG_PASSPHRASE="${BORG_PASSPHRASE}"
HETZNER_API_TOKEN=""
HETZNER_SERVER_ID=""
POSTMARK_API_TOKEN=""
BACKUP_ALERT_EMAIL=""
EOF
  chmod 600 "$ENV_FILE"
  echo "[OK] Environment file created at $ENV_FILE"
fi
echo ""

# ── 6. Set up cron jobs ─────────────────────────────────────────────────────

echo "Setting up cron jobs..."
crontab -l 2>/dev/null | grep -v backup-supportpages | grep -v hetzner-snapshot | {
  cat
  echo "0 3 * * * /usr/local/bin/backup-supportpages.sh"
  echo "0 5 * * 0 /usr/local/bin/hetzner-snapshot.sh"
} | crontab -
echo "[OK] Cron jobs installed:"
echo "     - Daily Borg backup at 03:00"
echo "     - Weekly Hetzner snapshot at 05:00 on Sundays"
echo ""

# ── 7. Test backup (optional) ───────────────────────────────────────────────

read -rp "Run a test backup now? (y/N) " run_test
if [[ "$run_test" == "y" || "$run_test" == "Y" ]]; then
  if [[ -x /usr/local/bin/backup-supportpages.sh ]]; then
    echo "Running test backup..."
    /usr/local/bin/backup-supportpages.sh
    echo ""
    echo "[OK] Test backup completed. Verify with:"
    echo "     source $ENV_FILE && borg list"
  else
    echo "Backup script not found at /usr/local/bin/backup-supportpages.sh"
    echo "Deploy with 'kamal deploy' first (scripts are synced via post-deploy hook),"
    echo "then run: /usr/local/bin/backup-supportpages.sh"
  fi
else
  echo "Skipping test backup."
  echo "After deploying with 'kamal deploy', run manually:"
  echo "  /usr/local/bin/backup-supportpages.sh"
fi
echo ""

# ── Done ─────────────────────────────────────────────────────────────────────

echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Fill in remaining values in $ENV_FILE:"
echo "     - HETZNER_API_TOKEN  (Cloud Console → Security → API Tokens)"
echo "     - HETZNER_SERVER_ID  (from the console URL)"
echo "     - POSTMARK_API_TOKEN"
echo "     - BACKUP_ALERT_EMAIL"
echo "  2. Run 'kamal deploy' to sync backup scripts to /usr/local/bin/"
echo "  3. Test: /usr/local/bin/backup-supportpages.sh"
echo ""
