#!/bin/sh
# ==============================================================================
# backup-containers.sh — Stop running containers, rsync /mnt/r5-dstor/ to an
#                        NFS share, restart the containers, and send a Discord
#                        notification when complete.
#
# Intended use: scheduled (cron / task scheduler) backup of bind-mounted
#               container data volumes.
#
# NOTE: This script is independent of stop-containers.sh / start-containers.sh
#       but reuses the same state file, so the three can be mixed freely.
#
# Usage: sudo ./backup-containers.sh
# ==============================================================================

# Some schedulers invoke this under /bin/sh (dash) and ignore the shebang.
# Re-exec under bash so pipefail / [[ / etc. work.
[ -z "${BASH_VERSION:-}" ] && exec /bin/bash "$0" "$@"

LOG_DIR="/var/log/docker-backups"
mkdir -p "${LOG_DIR}"
exec >>"${LOG_DIR}/backup-debug.log" 2>&1
echo "=== $(date) === PID=$$ USER=$(whoami) SHELL=${SHELL:-?} PATH=${PATH}"

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
STATE_FILE="/var/run/docker-backup-running-containers"
LOG_FILE="${LOG_DIR}/backup-$(date +%Y-%m-%dT%H-%M-%S).log"

SOURCE_DIR="/mnt/r5-dstor/"
# NFS destination — either an already-mounted path (recommended) or an
# nfs:// URI, e.g. "nfs://nas.local/volumes1/backup".
DEST_DIR="nfs://nas.local/volumes1/backup/r5-dstor/"

# Paths under the source that should NOT be backed up here (handled elsewhere).
RSYNC_EXCLUDES=(
    "--exclude=containers"
)

# Discord webhook (set here or export DISCORD_WEBHOOK_URL before running)
DISCORD_WEBHOOK_URL=""
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
die() { log "ERROR: $*"; exit 1; }

# Send a Discord embed notification
#   $1 = "success" | "failure"
#   $2 = description text
notify_discord() {
    [[ -z "${DISCORD_WEBHOOK_URL}" ]] && return 0  # silently skip if not configured

    local status="${1}"
    local description="${2}"
    local color title emoji

    if [[ "${status}" == "success" ]]; then
        color=3066993   # green
        title="Backup Complete"
        emoji="✅"
    else
        color=15158332  # red
        title="Backup Failed"
        emoji="🚨"
    fi

    local payload
    payload=$(cat <<EOF
{
  "embeds": [{
    "title": "${emoji} ${title}",
    "description": "${description}",
    "color": ${color},
    "fields": [
      { "name": "Host",       "value": "$(hostname)",          "inline": true },
      { "name": "Containers", "value": "${RUNNING_COUNT:-0}",  "inline": true },
      { "name": "Log",        "value": "\`${LOG_FILE}\`",      "inline": false }
    ],
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }]
}
EOF
)
    curl -s -o /dev/null --max-time 15 -X POST \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "${DISCORD_WEBHOOK_URL}" || log "WARNING: Discord notification failed to send."
}

# Restart the containers we stopped (best-effort), used on the failure path.
restore_containers() {
    if [[ -f "${STATE_FILE}" ]]; then
        local containers
        containers="$(tr -d '\n' < "${STATE_FILE}")"
        if [[ -n "${containers}" ]]; then
            log "Restoring containers after failure..."
            # shellcheck disable=SC2086
            docker start ${containers} >/dev/null 2>&1 \
                || log "WARNING: Some containers failed to restart."
        fi
        rm -f "${STATE_FILE}"
    fi
}

# Trap unexpected exits: bring containers back up and notify.
_on_error() {
    local exit_code=$?
    local line_no=${1:-}
    log "ERROR: Backup failed (exit ${exit_code}, line ${line_no})"
    restore_containers
    notify_discord "failure" "The backup failed at line **${line_no}** with exit code **${exit_code}**. Containers were restored. Check the log for details."
}
trap '_on_error ${LINENO}' ERR

command -v docker >/dev/null 2>&1 || die "'docker' not found in PATH"
command -v rsync  >/dev/null 2>&1 || die "'rsync' not found in PATH"

# ── 1. Stop running containers and record their IDs ──────────────────────────
if [[ -f "${STATE_FILE}" ]]; then
    log "WARNING: ${STATE_FILE} already exists — a previous stop was not paired"
    log "         with a start. Overwriting with the current running set."
fi

RUNNING_CONTAINERS="$(docker ps --quiet | tr '\n' ' ')"
RUNNING_COUNT=$(echo "${RUNNING_CONTAINERS}" | wc -w)
log "Found ${RUNNING_COUNT} running containers."

echo "${RUNNING_CONTAINERS}" > "${STATE_FILE}"

if [[ "${RUNNING_COUNT}" -gt 0 ]]; then
    # shellcheck disable=SC2086
    docker stop ${RUNNING_CONTAINERS} >/dev/null
    log "Stopped ${RUNNING_COUNT} containers."
else
    log "No running containers to stop."
fi

# ── 2. Rsync the volumes to the NFS share ────────────────────────────────────
[[ -d "${SOURCE_DIR%/}" ]] || die "Source directory not found: ${SOURCE_DIR}"

# If the destination is a mount path, make sure it's actually reachable.
if [[ "${DEST_DIR}" != nfs://* ]]; then
    dest_path="${DEST_DIR%/}/.backup-probe"
    touch "${dest_path}" 2>/dev/null || die "Destination not writable (NFS mounted?): ${DEST_DIR}"
    rm -f "${dest_path}"
fi

log "Rsyncing ${SOURCE_DIR} -> ${DEST_DIR}"
# shellcheck disable=SC2086
rsync -aHAX --delete \
    "${RSYNC_EXCLUDES[@]}" \
    --stats \
    "${SOURCE_DIR}" \
    "${DEST_DIR}" \
    2>&1 | tee -a "${LOG_FILE}"
log "Rsync complete."

# ── 3. Restart the containers ────────────────────────────────────────────────
if [[ "${RUNNING_COUNT}" -gt 0 ]]; then
    # shellcheck disable=SC2086
    docker start ${RUNNING_CONTAINERS} >/dev/null
    log "Restarted ${RUNNING_COUNT} containers."
fi
rm -f "${STATE_FILE}"

# ── 4. Notify ────────────────────────────────────────────────────────────────
notify_discord "success" "Backed up **${SOURCE_DIR}** to **${DEST_DIR}**. **${RUNNING_COUNT}** containers were stopped and restarted."

# Clean path — don't let the ERR trap fire on exit
trap - ERR
exit 0
