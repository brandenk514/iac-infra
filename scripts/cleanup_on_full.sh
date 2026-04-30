#!/usr/bin/env bash
set -euo pipefail

# cleanup_on_full.sh
# Remove all files from three specified directories when a mountpoint reaches a threshold usage.
# Safe by default: runs as a dry-run unless invoked with --execute.
#
# Usage examples:
#  Dry-run (safe):
#    ./scripts/cleanup_on_full.sh -m /mnt/storage -d /mnt/storage/dir1 -d /mnt/storage/dir2 -d /mnt/storage/dir3
#
#  Execute (actually remove contents):
#    ./scripts/cleanup_on_full.sh --execute -m /mnt/storage -d /mnt/storage/dir1 -d /mnt/storage/dir2 -d /mnt/storage/dir3
#
#  Cron example (run every 5 minutes, actually delete when threshold reached):
#    */5 * * * * /home/uac-admin/code/docker-compose-infra/scripts/cleanup_on_full.sh --execute -m /mnt/storage -d /mnt/storage/dir1 -d /mnt/storage/dir2 -d /mnt/storage/dir3 >> /var/log/cleanup_on_full.log 2>&1


PROGNAME=$(basename "$0")
THRESHOLD=95
DRY_RUN=1
VERBOSE=0
LOCKFILE="/var/lock/cleanup_on_full.lock"
LOGFILE="/var/log/cleanup_on_full.log"
# Discord webhook (can be provided via -w/--webhook or env var DISCORD_WEBHOOK_URL)
WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
PURGED=0

print_help() {
  cat <<EOF
Usage: $PROGNAME [OPTIONS]

Options:
  -m, --mount PATH      Mount point to monitor (required)
  -d, --dir PATH        Directory to purge when threshold reached. Repeatable (required exactly 3 times)
  -t, --threshold N     Usage percent threshold (default: ${THRESHOLD})
  -e, --execute         Actually remove files (if not set, script runs in dry-run mode)
  -v, --verbose         Verbose output
  -h, --help            Show this help

Example:
  $PROGNAME -m /mnt/storage -d /mnt/storage/dir1 -d /mnt/storage/dir2 -d /mnt/storage/dir3 -e
EOF
}

log() {
  local msg="$1"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if [ -w "$(dirname "$LOGFILE")" ] || [ -w "$LOGFILE" ] || [ -w /tmp ]; then
    echo "${ts} ${msg}" | tee -a "$LOGFILE"
  else
    echo "${ts} ${msg}"
  fi
}

fatal() {
  log "ERROR: $1"
  exit 1
}


# Escape string for embedding in a JSON string value (basic)
escape_json() {
  # replace backslash, double-quote, and newlines
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g'
}


# Send a simple message to configured Discord webhook (non-blocking)
send_discord() {
  local status="$1"
  local msg="$2"
  if [ -z "${WEBHOOK_URL:-}" ]; then
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    log "WARNING: curl not found; cannot send Discord webhook"
    return 0
  fi
  local esc
  esc=$(escape_json "${msg}")
  local payload
  payload="{\"content\":\"[cleanup] ${status}: ${esc}\"}"
  # fire-and-forget; suppress any error
  curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL" >/dev/null 2>&1 || true
}

# Parse arguments
DIRS=()
MOUNTPOINT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -m|--mount)
      shift; MOUNTPOINT="$1";;
    -w|--webhook)
      shift; WEBHOOK_URL="$1";;
    -d|--dir)
      shift; DIRS+=("$1");;
    -t|--threshold)
      shift; THRESHOLD="$1";;
    -e|--execute)
      DRY_RUN=0;;
    -v|--verbose)
      VERBOSE=1;;
    -h|--help)
      print_help; exit 0;;
    --)
      shift; break;;
    *)
      echo "Unknown arg: $1"; print_help; exit 2;;
  esac
  shift
done

if [ -z "$MOUNTPOINT" ]; then
  print_help
  fatal "Mount point is required (-m)"
fi

if [ "${#DIRS[@]}" -ne 3 ]; then
  print_help
  fatal "Please provide exactly 3 directories (-d). Provided: ${#DIRS[@]}"
fi

# Ensure commands exist
command -v df >/dev/null 2>&1 || fatal "df not found"
command -v realpath >/dev/null 2>&1 || fatal "realpath not found"
command -v find >/dev/null 2>&1 || fatal "find not found"
command -v flock >/dev/null 2>&1 || true

# Create lockfile dir if needed
mkdir -p "$(dirname "$LOCKFILE")" 2>/dev/null || true

# Acquire lock to prevent concurrent runs
exec 200>"$LOCKFILE"
if ! flock -n 200; then
  log "Another instance is running (lockfile: $LOCKFILE). Exiting."
  exit 0
fi

log "Starting check: mount=$MOUNTPOINT threshold=${THRESHOLD}% dry-run=$DRY_RUN"

# Verify mountpoint exists and is a mount
if [ ! -d "$MOUNTPOINT" ]; then
  fatal "Mount point '$MOUNTPOINT' does not exist or is not a directory"
fi

if ! mountpoint -q "$MOUNTPOINT"; then
  # mountpoint command may not exist on some systems; fall back to checking df output
  if ! df -P "$MOUNTPOINT" >/dev/null 2>&1; then
    fatal "'$MOUNTPOINT' does not appear to be a mount point"
  fi
fi

# Get usage percent (strip %)
USAGE_PCT=$(df -P --output=pcent "$MOUNTPOINT" 2>/dev/null | tail -n1 | tr -d ' %') || true
if [ -z "$USAGE_PCT" ]; then
  # portable fallback
  USAGE_PCT=$(df -P "$MOUNTPOINT" | tail -n1 | awk '{print $5}' | tr -d '%') || true
fi

if [ -z "$USAGE_PCT" ]; then
  fatal "Unable to determine usage for mountpoint '$MOUNTPOINT'"
fi

log "Current usage: ${USAGE_PCT}%"

if [ "$USAGE_PCT" -lt "$THRESHOLD" ]; then
  log "Usage ${USAGE_PCT}% is below threshold ${THRESHOLD}%. No action needed."
  exit 0
fi

log "Threshold reached (usage ${USAGE_PCT}% >= ${THRESHOLD}%). Preparing to purge contents of target directories."

# For each directory: ensure it exists and is on the same filesystem as the mountpoint
MOUNT_REAL=$(realpath -e "$MOUNTPOINT") || fatal "Failed to resolve mountpoint realpath"

for dir in "${DIRS[@]}"; do
  if [ ! -e "$dir" ]; then
    log "WARNING: target directory '$dir' does not exist — skipping"
    continue
  fi
  dir_real=$(realpath -e "$dir")
  case "$dir_real" in
    "$MOUNT_REAL"* )
      if [ $VERBOSE -eq 1 ]; then log "Directory '$dir_real' is under mountpoint; OK"; fi
      ;;
    *)
      log "WARNING: directory '$dir_real' is not under mountpoint '$MOUNT_REAL' — skipping for safety"
      continue
      ;;
  esac

  # Show what will be removed in dry-run mode
  if [ $DRY_RUN -eq 1 ]; then
    log "DRY-RUN: Would remove contents of: $dir_real"
    find "$dir_real" -mindepth 1 -maxdepth 1 -print | sed 's/^/  /'
  else
    log "Removing contents of: $dir_real"
    # Use find to remove items at depth 1 (files and directories). This preserves the target directory itself.
    if find "$dir_real" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
      # Remove with find -exec to handle many entries safely
      find "$dir_real" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      log "Removed contents of: $dir_real"
      PURGED=1
    else
      log "No content to remove in: $dir_real"
    fi
  fi
done

if [ $DRY_RUN -eq 1 ]; then
  log "Dry-run complete. Rerun with --execute to actually delete files."
else
  log "Purge complete."
  # Only notify via Discord if actual files were purged
  if [ "$PURGED" -eq 1 ] && [ -n "${WEBHOOK_URL:-}" ]; then
    send_discord "COMPLETE" "Purge completed for mount ${MOUNTPOINT}. Usage ${USAGE_PCT}%. Purged directories: ${DIRS[*]}"
  fi
fi

exit 0
