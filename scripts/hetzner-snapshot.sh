#!/usr/bin/env bash
#
# hetzner-snapshot.sh — Weekly Hetzner Cloud server snapshot
#
# Creates a full-server snapshot via the Hetzner Cloud API and cleans up
# old snapshots, keeping the last 4.
#
# Requires /etc/backup-supportpages.env with:
#   HETZNER_API_TOKEN="<hetzner-cloud-api-token>"
#   HETZNER_SERVER_ID="<server-id>"
#   POSTMARK_API_TOKEN="<postmark-token>"
#   BACKUP_ALERT_EMAIL="you@example.com"
#
# Setup:
#   1. Hetzner Cloud Console → Security → API Tokens → Generate (read/write)
#   2. Note server ID from the console URL
#   3. Add values to /etc/backup-supportpages.env
#   4. Add to cron: 0 5 * * 0 /usr/local/bin/hetzner-snapshot.sh
#
# Restore:
#   Hetzner Console → Images → Snapshots → select snapshot → "Create Server" or "Rebuild Server"
#

set -euo pipefail

ENV_FILE="/etc/backup-supportpages.env"
LOG_FILE="/var/log/hetzner-snapshot.log"
KEEP_SNAPSHOTS=4
SNAPSHOT_DESCRIPTION="supportpages-weekly-$(date +%Y-%m-%d)"

HETZNER_API="https://api.hetzner.cloud/v1"

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
  log "ERROR: Snapshot failed with exit code $exit_code"
  send_alert \
    "[SNAPSHOT FAILED] Hetzner snapshot — $(date +%Y-%m-%d)" \
    "The weekly Hetzner snapshot failed at $(date). Check $LOG_FILE on host.supportpages.io for details. Exit code: $exit_code"
  exit "$exit_code"
}

trap on_failure ERR

# ── Helper ───────────────────────────────────────────────────────────────────

hetzner_api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -sf -X "$method" \
    -H "Authorization: Bearer $HETZNER_API_TOKEN" \
    -H "Content-Type: application/json" \
    "${HETZNER_API}${endpoint}" \
    "$@"
}

# ── Load config ──────────────────────────────────────────────────────────────

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

# ── Create snapshot ──────────────────────────────────────────────────────────

log "=== Starting Hetzner snapshot ==="
log "Creating snapshot: $SNAPSHOT_DESCRIPTION"

RESPONSE=$(hetzner_api POST "/servers/${HETZNER_SERVER_ID}/actions/create_image" \
  -d "{\"description\": \"$SNAPSHOT_DESCRIPTION\", \"type\": \"snapshot\"}")

IMAGE_ID=$(echo "$RESPONSE" | jq -r '.image.id')
ACTION_ID=$(echo "$RESPONSE" | jq -r '.action.id')

if [[ -z "$IMAGE_ID" || "$IMAGE_ID" == "null" ]]; then
  log "ERROR: Failed to create snapshot. Response: $RESPONSE"
  exit 1
fi

log "Snapshot creation started (image_id=$IMAGE_ID, action_id=$ACTION_ID)"

# Wait for snapshot to complete (poll every 30s, timeout after 30 min)
MAX_WAIT=1800
WAITED=0
while [[ $WAITED -lt $MAX_WAIT ]]; do
  STATUS=$(hetzner_api GET "/actions/${ACTION_ID}" | jq -r '.action.status')
  if [[ "$STATUS" == "success" ]]; then
    log "Snapshot completed successfully"
    break
  elif [[ "$STATUS" == "error" ]]; then
    log "ERROR: Snapshot action failed"
    exit 1
  fi
  sleep 30
  WAITED=$((WAITED + 30))
  log "Waiting for snapshot... (${WAITED}s elapsed, status=$STATUS)"
done

if [[ $WAITED -ge $MAX_WAIT ]]; then
  log "WARNING: Timed out waiting for snapshot (${MAX_WAIT}s). It may still complete."
fi

# ── Clean up old snapshots ───────────────────────────────────────────────────

log "Cleaning up old snapshots (keeping last $KEEP_SNAPSHOTS)..."

# List all snapshots for this server, sorted by creation date (oldest first)
SNAPSHOTS=$(hetzner_api GET "/images?type=snapshot&sort=created:asc&status=available" \
  | jq -r --arg sid "$HETZNER_SERVER_ID" \
    '[.images[] | select(.created_from.id == ($sid | tonumber) and (.description | startswith("supportpages-weekly-")))] | .[].id')

SNAPSHOT_COUNT=$(echo "$SNAPSHOTS" | grep -c . || true)
log "Found $SNAPSHOT_COUNT matching snapshots"

if [[ $SNAPSHOT_COUNT -gt $KEEP_SNAPSHOTS ]]; then
  DELETE_COUNT=$((SNAPSHOT_COUNT - KEEP_SNAPSHOTS))
  DELETE_IDS=$(echo "$SNAPSHOTS" | head -n "$DELETE_COUNT")

  for SNAP_ID in $DELETE_IDS; do
    log "Deleting old snapshot: $SNAP_ID"
    hetzner_api DELETE "/images/${SNAP_ID}" > /dev/null
  done

  log "Deleted $DELETE_COUNT old snapshot(s)"
else
  log "No snapshots to clean up"
fi

log "=== Hetzner snapshot finished successfully ==="
