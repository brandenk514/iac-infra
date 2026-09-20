#!/bin/sh
# ==============================================================================
# backup-containers.sh — Stop running containers, rsync /mnt/r5-dstor/ to one
#                        or more backup destinations (local mounts / NFS),
#                        restart the containers, and send a Discord
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

SOURCE_DIR="/mnt/r5-dstor/containers"
# Backup destinations — either an already-mounted path (recommended) or an
# nfs:// URI, e.g. "nfs://nas.local/volumes1/backup".
DEST_DIRS=(
    "/mnt/container-backups"
    "/mnt/secondary-backup"
)

# Paths under the source that should NOT be backed up here (handled elsewhere).
RSYNC_EXCLUDES=(
    "--exclude=lost+found"
    "--exclude=.cache"
    "--exclude=.tmp"
    "--exclude=.temp"
    "--exclude=.Trash"
    "--exclude=.Trash-1000"
    "--exclude=.Trash-0"
)

# Discord webhook (set here or export DISCORD_WEBHOOK_URL before running)
DISCORD_WEBHOOK_URL=""
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }

# Explicit fatal error. Unlike the ERR trap, `exit` does not fire it, so
# handle container restore + Discord notification here directly.
die() {
    log "ERROR: $*"
    if [[ -f "${STATE_FILE}" ]]; then
        restore_containers
        local reason="${*}"
        notify_discord "failure" "The backup failed: ${reason}. Containers were restored. Check the log for details."
    fi
    exit 1
}

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

# ── 2. Rsync the volumes to each backup destination ─────────────────────────
[[ -d "${SOURCE_DIR%/}" ]] || die "Source directory not found: ${SOURCE_DIR}"
[[ "${#DEST_DIRS[@]}" -gt 0 ]] || die "No backup destinations configured (DEST_DIRS is empty)"

# Comma-space join that works on bash < 5.1 (IFS multi-char join is 5.1+)
DEST_SUMMARY=""
for _d in "${DEST_DIRS[@]}"; do
    DEST_SUMMARY+="${DEST_SUMMARY:+, }${_d}"
done

# Shared rsync options for every destination.
#   --inplace          Write directly into the target file instead of temp file
#                      + rename. On SMB/CIFS destinations the rename is an
#                      expensive extra round-trip per file; big speedup.
#                      Trade-off: an interrupted transfer leaves a partial
#                      file (mitigated by --partial for resumable re-runs).
#   --omit-dir-times   Don't re-set mtime on directories. With -a this would
#                      issue a metadata call per directory on the network
#                      destination even when nothing changed.
#   --partial          Keep partially transferred files so a re-run resumes.
#
# NOTE on mtimes: if backup time stays high, run once with
# `--checksum` instead of the default size+mtime quick check. If that is
# dramatically faster, it means mtimes are unreliable (apps touching files,
# SMB timestamp granularity) and you may want `--size-only` permanently —
# but only if nothing in the volumes rewrites files in place without a size
# change (databases do this), otherwise changed files get missed.
RSYNC_OPTS=(
    -aH
    --delete
    --no-owner --no-group
    --partial
    --inplace
    --omit-dir-times
    --stats
)

# Run all destination rsyncs in parallel (they are independent), then wait.
rsync_fail=0
declare -a pids=()
for dest in "${DEST_DIRS[@]}"; do
    # If the destination is a mount path, make sure it's actually reachable.
    if [[ "${dest}" != nfs://* ]]; then
        dest_path="${dest%/}/.backup-probe"
        touch "${dest_path}" 2>/dev/null || die "Destination not writable (NFS mounted?): ${dest}"
        rm -f "${dest_path}"
    fi

    log "Rsyncing ${SOURCE_DIR} -> ${dest}"
    (
        # shellcheck disable=SC2086
        # -aH but NOT -A/-X (no ACLs/xattrs) and --no-owner/--no-group:
        #   The backup destinations are CIFS/SMB (and the source is r5-dstor), which
        #   reject chown/POSIX-ACL/setxattr even for root ("Operation not permitted").
        #   -a implies -o/-g, so without the overrides every file fails chown and
        #   rsync exits 23, tripping pipefail + the ERR trap. Exact uid/gid don't
        #   matter for container volumes that will be restored onto a fresh host, so
        #   let the destination assign ownership. Perms, times, symlinks, hardlinks
        #   and file content are still preserved.
        rsync "${RSYNC_OPTS[@]}" \
            "${RSYNC_EXCLUDES[@]}" \
            "${SOURCE_DIR}" \
            "${dest}" \
            2>&1 | tee -a "${LOG_FILE}"
    ) &
    pids+=("$!")
done

for i in "${!pids[@]}"; do
    if wait "${pids[$i]}"; then
        log "Rsync to ${DEST_DIRS[$i]} complete."
    else
        log "ERROR: rsync to ${DEST_DIRS[$i]} failed."
        rsync_fail=1
    fi
done
[[ "${rsync_fail}" -eq 0 ]] || die "One or more rsync runs failed"

# ── 3. Restart the containers ────────────────────────────────────────────────
if [[ "${RUNNING_COUNT}" -gt 0 ]]; then
    # shellcheck disable=SC2086
    docker start ${RUNNING_CONTAINERS} >/dev/null
    log "Restarted ${RUNNING_COUNT} containers."
fi
rm -f "${STATE_FILE}"

# ── 4. Notify ────────────────────────────────────────────────────────────────
notify_discord "success" "Backed up **${SOURCE_DIR}** to **${DEST_SUMMARY}**. **${RUNNING_COUNT}** containers were stopped and restarted."

# Clean path — don't let the ERR trap fire on exit
trap - ERR
exit 0
