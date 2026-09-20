#!/bin/sh
# ==============================================================================
# start-containers.sh — Restart the Docker containers recorded by
#                       stop-containers.sh.
#
# Intended use: post-backup script for Synology Active Backup for Business.
#
# Usage: sudo ./start-containers.sh
# ==============================================================================

# Synology Active Backup invokes pre/post scripts under /bin/sh (dash),
# ignoring the shebang. Re-exec under bash so pipefail / [[ / etc. work.
[ -z "${BASH_VERSION:-}" ] && exec /bin/bash "$0" "$@"

LOG_DIR="/var/log/docker-backups"
mkdir -p "${LOG_DIR}"
exec >>"${LOG_DIR}/start-debug.log" 2>&1
echo "=== $(date) === PID=$$ USER=$(whoami) SHELL=${SHELL:-?} PATH=${PATH}"

set -euo pipefail

STATE_FILE="/var/run/docker-backup-running-containers"
LOG_FILE="${LOG_DIR}/start-$(date +%Y-%m-%dT%H-%M-%S).log"

# ── Discord webhook (set here or export DISCORD_WEBHOOK_URL before running) ────
DISCORD_WEBHOOK_URL=""

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
die() { log "ERROR: $*"; notify_discord "failure" "$*"; exit 1; }

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
        title="Containers Started"
        emoji="✅"
    else
        color=15158332  # red
        title="Container Start Failed"
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
    curl -s -o /dev/null -X POST \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "${DISCORD_WEBHOOK_URL}" || log "WARNING: Discord notification failed to send."
}

# Trap unexpected exits and notify
_on_error() {
    local exit_code=$?
    local line_no=${1:-}
    log "ERROR: Script exited unexpectedly (exit ${exit_code}, line ${line_no})"
    notify_discord "failure" "The start script exited unexpectedly at line **${line_no}** with exit code **${exit_code}**. Check the log for details."
}
trap '_on_error ${LINENO}' ERR

command -v docker >/dev/null 2>&1 || die "'docker' not found in PATH"

[[ -f "${STATE_FILE}" ]] || die "State file not found: ${STATE_FILE}. Did stop-containers.sh run?"

RUNNING_CONTAINERS="$(tr -d '\n' < "${STATE_FILE}")"
RUNNING_COUNT=$(echo "${RUNNING_CONTAINERS}" | wc -w)

log "Found ${RUNNING_COUNT} containers to restart."

if [[ "${RUNNING_COUNT}" -eq 0 ]]; then
    log "Nothing to start."
    rm -f "${STATE_FILE}"
    notify_discord "success" "No containers needed to be restarted (state file was empty)."
    trap - ERR
    exit 0
fi

# shellcheck disable=SC2086
docker start ${RUNNING_CONTAINERS} >/dev/null
log "Started ${RUNNING_COUNT} containers."

rm -f "${STATE_FILE}"

notify_discord "success" "Successfully restarted **${RUNNING_COUNT}** containers after backup."

# Disable ERR trap — we're done
trap - ERR
