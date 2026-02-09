#!/usr/bin/env bash
#
# backup-supportpages.sh — Daily BorgBackup for SupportPages
#
# Backs up:
#   - PostgreSQL database (pg_dump from supportpages-db container)
#   - Active Storage files (rtfm_storage Docker volume)
#   - Analysis output (/var/supportpages/analysis)
#
# Requires /etc/backup-supportpages.env with:
#   BORG_RSH="ssh -p 23 -i /root/.ssh/storagebox"
#   BORG_REPO="ssh://uXXXXXX@uXXXXXX.your-storagebox.de/./backups/supportpages"
#   BORG_PASSPHRASE="<passphrase>"
#   POSTMARK_API_TOKEN="<postmark-token>"
#   BACKUP_ALERT_EMAIL="you@example.com"
#
# Setup:
#   1. Order Hetzner Storage Box (BX11), enable SSH + Borg support
#   2. ssh-keygen -t ed25519 -f /root/.ssh/storagebox -N ""
#   3. cat /root/.ssh/storagebox.pub | ssh -p 23 uXXXXXX@uXXXXXX.your-storagebox.de install-ssh-key
#   4. apt install -y borgbackup
#   5. borg init --encryption=repokey
#   6. borg key export $BORG_REPO /root/borg-key-backup.txt  (store offline!)
#   7. Create /etc/backup-supportpages.env (chmod 600)
#   8. Add to cron: 0 3 * * * /usr/local/bin/backup-supportpages.sh
#
# Restore PostgreSQL:
#   source /etc/backup-supportpages.env
#   borg list
#   cd /tmp && borg extract ::ARCHIVE_NAME tmp/supportpages-backup/database.dump
#   docker exec -i supportpages-db pg_restore \
#     -U supportpages -d supportpages_production --clean --if-exists \
#     < /tmp/tmp/supportpages-backup/database.dump
#
# Restore Active Storage:
#   source /etc/backup-supportpages.env
#   STORAGE_PATH=$(docker volume inspect rtfm_storage --format '{{ .Mountpoint }}')
#   cd / && borg extract ::ARCHIVE_NAME "$STORAGE_PATH"
#

set -euo pipefail

ENV_FILE="/etc/backup-supportpages.env"
LOG_FILE="/var/log/backup-supportpages.log"
DUMP_DIR="/tmp/supportpages-backup"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)

# ── Logging ──────────────────────────────────────────────────────────────────

log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

# ── Failure alerting ─────────────────────────────────────────────────────────

send_alert() {
  local subject="$1" body="$2"
  curl -s -X POST "https://api.postmarkapp.com/email" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "X-Postmark-Server-Token: $POSTMARK_API_TOKEN" \
    -d "{
      \"From\": \"notifications@supportpages.io\",
      \"To\": \"$BACKUP_ALERT_EMAIL\",
      \"Subject\": \"$subject\",
      \"TextBody\": \"$body\"
    }" >> "$LOG_FILE" 2>&1 || true
}

on_failure() {
  local exit_code=$?
  log "ERROR: Backup failed with exit code $exit_code"
  send_alert \
    "[BACKUP FAILED] SupportPages Borg backup — $(date +%Y-%m-%d)" \
    "The daily Borg backup failed at $(date). Check $LOG_FILE on host.supportpages.io for details. Exit code: $exit_code"
  exit "$exit_code"
}

trap on_failure ERR

# ── Load config ──────────────────────────────────────────────────────────────

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

export BORG_RSH
export BORG_REPO
export BORG_PASSPHRASE

# ── Main backup ──────────────────────────────────────────────────────────────

log "=== Starting backup ==="

# 1. Dump PostgreSQL
log "Dumping PostgreSQL..."
rm -rf "$DUMP_DIR"
mkdir -p "$DUMP_DIR"
docker exec supportpages-db pg_dump \
  -U supportpages -Fc supportpages_production \
  > "$DUMP_DIR/database.dump"
log "Database dump complete ($(du -h "$DUMP_DIR/database.dump" | cut -f1))"

# 2. Locate Active Storage volume
STORAGE_PATH=$(docker volume inspect rtfm_storage --format '{{ .Mountpoint }}')
log "Active Storage path: $STORAGE_PATH"

# 3. Create Borg archive
ARCHIVE_NAME="supportpages-${TIMESTAMP}"
log "Creating Borg archive: $ARCHIVE_NAME"

borg create \
  --compression zstd \
  --stats \
  --show-rc \
  "::${ARCHIVE_NAME}" \
  "$DUMP_DIR" \
  "$STORAGE_PATH" \
  /var/supportpages/analysis \
  2>&1 | tee -a "$LOG_FILE"

log "Archive created successfully"

# 4. Prune old archives
log "Pruning old archives..."
borg prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --stats \
  --show-rc \
  2>&1 | tee -a "$LOG_FILE"

borg compact 2>&1 | tee -a "$LOG_FILE"
log "Prune complete"

# 5. Integrity check on Sundays
if [[ $(date +%u) -eq 7 ]]; then
  log "Sunday — running borg check..."
  borg check --show-rc 2>&1 | tee -a "$LOG_FILE"
  log "Integrity check complete"
fi

# 6. Clean up
rm -rf "$DUMP_DIR"

log "=== Backup finished successfully ==="
