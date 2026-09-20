#!/bin/sh
# ==============================================================================
# stop-containers.sh — Stop all running Docker containers and record their IDs
#                     so they can be restarted by start-containers.sh.
#
# Intended use: pre-backup script for Synology Active Backup for Business.
#
# Usage: sudo ./stop-containers.sh
# ==============================================================================

# Synology Active Backup invokes pre/post scripts under /bin/sh (dash),
# ignoring the shebang. Re-exec under bash so pipefail / [[ / etc. work.
[ -z "${BASH_VERSION:-}" ] && exec /bin/bash "$0" "$@"

LOG_DIR="/var/log/docker-backups"
mkdir -p "${LOG_DIR}"
exec >>"${LOG_DIR}/stop-debug.log" 2>&1
echo "=== $(date) === PID=$$ USER=$(whoami) SHELL=${SHELL:-?} PATH=${PATH}"

set -euo pipefail

STATE_FILE="/var/run/docker-backup-running-containers"
LOG_FILE="${LOG_DIR}/stop-$(date +%Y-%m-%dT%H-%M-%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
die() { log "ERROR: $*"; exit 1; }

command -v docker >/dev/null 2>&1 || die "'docker' not found in PATH"

if [[ -f "${STATE_FILE}" ]]; then
    log "WARNING: ${STATE_FILE} already exists — a previous stop was not paired"
    log "         with a start. Overwriting with the current running set."
fi

RUNNING_CONTAINERS="$(docker ps --quiet | tr '\n' ' ')"
RUNNING_COUNT=$(echo "${RUNNING_CONTAINERS}" | wc -w)

log "Found ${RUNNING_COUNT} running containers."

# Always write the state file (even if empty) so the post-script can detect
# that the pre-script ran successfully.
echo "${RUNNING_CONTAINERS}" > "${STATE_FILE}"

if [[ "${RUNNING_COUNT}" -eq 0 ]]; then
    log "Nothing to stop."
    exit 0
fi

# shellcheck disable=SC2086
docker stop ${RUNNING_CONTAINERS} >/dev/null
log "Stopped ${RUNNING_COUNT} containers."
