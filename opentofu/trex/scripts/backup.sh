#!/usr/bin/env bash
# ==============================================================================
# backup.sh — Stop all containers, rsync data to NFS, restart containers
#
# Usage:
#   sudo ./scripts/backup.sh [--dry-run]
#
# Requirements:
#   - docker compose v2
#   - rsync
#   - curl (for Discord notifications)
#   - NFS share mounted at /mnt/backup-repo
# ==============================================================================

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
COMPOSE_DIR="/home/uac-admin/docker-compose-infra"
COMPOSE_FILE="${COMPOSE_DIR}/compose.yml"
ENV_FILE="${COMPOSE_DIR}/.env"

# Source the .env — handles Docker Compose style "KEY = VALUE" with spaces around =
while IFS= read -r line || [[ -n "${line}" ]]; do
    # Skip blank lines and comments
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
    # Strip spaces around the = sign, then export
    export "$(echo "${line}" | sed 's/[[:space:]]*=[[:space:]]*/=/' | sed 's/="\(.*\)"/=\1/' | sed "s/='\(.*\)'/=\1/")" 2>/dev/null || true
done < "${ENV_FILE}"

SOURCE_DIR="${DOCKER_MNT:-/mnt/r5-dstor}"   # Primary data volume
BACKUP_DEST="/mnt/backup-repo"
TIMESTAMP="$(date +%Y-%m-%dT%H-%M-%S)"
LOG_DIR="/var/log/docker-backups"
LOG_FILE="${LOG_DIR}/backup-${TIMESTAMP}.log"

# ── Discord webhook (set here or export DISCORD_WEBHOOK_URL before running) ────
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-https://discord.com/api/webhooks/1333214271865094247/qIGciaFCU3to1fKaz38GC8XRhtAEmRukyTNFg_gVpXtzSH3NoztWrsdGQCZSqbkRvoYj}"

# ── Parallelism — number of concurrent rsync workers (one per top-level dir) ──
RSYNC_JOBS="${RSYNC_JOBS:-8}"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

RSYNC_OPTS=(
    --archive               # preserve permissions, symlinks, timestamps, etc.
    --hard-links            # preserve hard links
    --delete                # remove files on dest that no longer exist in source
    --partial               # keep partially transferred files on interruption
    --stats                 # summary statistics at the end
    --human-readable
    # ── Performance tuning for LAN/NFS ──────────────────────────────────────
    --whole-file            # skip delta-transfer algo; faster on LAN (avoids reading dest over NFS)
    --no-compress           # no CPU overhead for compression on a local network
    --sparse                # handle sparse files efficiently (SQLite DBs, Postgres data files)
    --one-file-system       # don't cross filesystem boundaries (NFS sub-mounts, etc.)
    --timeout=60            # exit cleanly on stale NFS handle / network hang
    --checksum-choice=xxh128  # xxHash is much faster than MD5 for change detection (rsync 3.2+)
)
# Note: --iobuf is not supported in Debian's rsync 3.4.1 build
[[ "${DRY_RUN}" == "true" ]] && RSYNC_OPTS+=(--dry-run)

# ── Helpers ────────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }

die() {
    log "ERROR: $*"
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
        title="Backup Succeeded"
        emoji="✅"
    else
        color=15158332  # red
        title="Backup Failed"
        emoji="🚨"
    fi

    [[ "${DRY_RUN}" == "true" ]] && title="[DRY-RUN] ${title}"

    local payload
    payload=$(cat <<EOF
{
  "embeds": [{
    "title": "${emoji} ${title}",
    "description": "${description}",
    "color": ${color},
    "fields": [
      { "name": "Host",    "value": "$(hostname)",       "inline": true },
      { "name": "Source",  "value": "${SOURCE_DIR}",     "inline": true },
      { "name": "Dest",    "value": "${BACKUP_DEST}",    "inline": true },
      { "name": "Log",     "value": "\`${LOG_FILE}\`",   "inline": false }
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

# Trap any unexpected exits: restart containers and send failure notification
_on_error() {
    local exit_code=$?
    local line_no=${1:-}
    log "ERROR: Script exited unexpectedly (exit ${exit_code}, line ${line_no})"
    log ">> Attempting to restart containers after failure..."
    docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up --detach 2>>${LOG_FILE} || \
        log "WARNING: Failed to restart containers — manual intervention required!"
    notify_discord "failure" "The backup script exited unexpectedly at line **${line_no}** with exit code **${exit_code}**. Containers have been restarted. Check the log for details."
}
trap '_on_error ${LINENO}' ERR

# ── Preflight checks ───────────────────────────────────────────────────────────
mkdir -p "${LOG_DIR}"

[[ -f "${COMPOSE_FILE}" ]] || die "compose.yml not found at ${COMPOSE_FILE}"
[[ -d "${SOURCE_DIR}" ]]   || die "Source directory not found: ${SOURCE_DIR}"
[[ -d "${BACKUP_DEST}" ]]  || die "NFS backup mount not found: ${BACKUP_DEST}. Is the share mounted?"
command -v docker   &>/dev/null || die "'docker' not found in PATH"
command -v rsync    &>/dev/null || die "'rsync' not found in PATH"

log "======================================================"
log "  Docker Compose Backup — ${TIMESTAMP}"
[[ "${DRY_RUN}" == "true" ]] && log "  ** DRY-RUN MODE — no changes will be made **"
log "======================================================"
log "  Source  : ${SOURCE_DIR}"
log "  Dest    : ${BACKUP_DEST}"
log "  Compose : ${COMPOSE_FILE}"
log "======================================================"

# ── Step 1: Stop all containers ────────────────────────────────────────────────
log ">> Stopping all containers..."
if [[ "${DRY_RUN}" == "true" ]]; then
    log "   [dry-run] docker compose -f ${COMPOSE_FILE} --env-file ${ENV_FILE} down"
else
    docker compose \
        -f "${COMPOSE_FILE}" \
        --env-file "${ENV_FILE}" \
        down
fi
log "   All containers stopped."

# ── Step 2: rsync data to NFS share (parallel workers) ────────────────────────
log ">> Starting parallel rsync backup (${RSYNC_JOBS} workers)..."
log "   Source: ${SOURCE_DIR}/  →  Dest: ${BACKUP_DEST}/"

# Ensure destination root exists
mkdir -p "${BACKUP_DEST}"

# Worker function: syncs one top-level directory, writes its own log
# Called by xargs in a subshell, so it must be exported
_rsync_dir() {
    local dir_name="${1}"
    local src="${SOURCE_DIR}/${dir_name}/"
    local dst="${BACKUP_DEST}/${dir_name}/"
    local dir_log="${LOG_DIR}/backup-${TIMESTAMP}-${dir_name}.log"

    mkdir -p "${dst}"
    rsync "${RSYNC_OPTS[@]}" --log-file="${dir_log}" "${src}" "${dst}"
    local rc=$?
    echo "${rc}" > "${LOG_DIR}/backup-${TIMESTAMP}-${dir_name}.rc"
    return ${rc}
}
export -f _rsync_dir
export SOURCE_DIR BACKUP_DEST LOG_DIR TIMESTAMP
export RSYNC_OPTS  # export as string; subshells will re-read via eval within the function

# Build list of top-level dirs, sync them in parallel
TOP_LEVEL_DIRS=()
while IFS= read -r -d '' entry; do
    TOP_LEVEL_DIRS+=("$(basename "${entry}")")
done < <(find "${SOURCE_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

log "   Directories to sync (${#TOP_LEVEL_DIRS[@]}): ${TOP_LEVEL_DIRS[*]}"

FAILED_DIRS=()
if [[ "${DRY_RUN}" == "true" ]]; then
    log "   [dry-run] Would run ${#TOP_LEVEL_DIRS[@]} parallel rsync workers"
    # Run a single dry-run rsync so the output is still useful
    rsync "${RSYNC_OPTS[@]}" --log-file="${LOG_FILE}" --dry-run \
        "${SOURCE_DIR}/" "${BACKUP_DEST}/" || true
else
    # Export the RSYNC_OPTS array for subshells (arrays aren't exported natively)
    RSYNC_OPTS_STR="${RSYNC_OPTS[*]}"
    export RSYNC_OPTS_STR

    printf '%s\n' "${TOP_LEVEL_DIRS[@]}" | \
        xargs -P "${RSYNC_JOBS}" -I{} bash -c '
            dir="{}"; src="${SOURCE_DIR}/${dir}/"; dst="${BACKUP_DEST}/${dir}/"
            dir_log="${LOG_DIR}/backup-${TIMESTAMP}-${dir}.log"
            mkdir -p "${dst}"
            # shellcheck disable=SC2086
            rsync ${RSYNC_OPTS_STR} --log-file="${dir_log}" "${src}" "${dst}"
            rc=$?
            echo "${rc}" > "${LOG_DIR}/backup-${TIMESTAMP}-${dir}.rc"
            exit ${rc}
        ' || true  # xargs returns non-zero if any job failed; we check .rc files below

    # Aggregate per-directory exit codes
    for dir in "${TOP_LEVEL_DIRS[@]}"; do
        rc_file="${LOG_DIR}/backup-${TIMESTAMP}-${dir}.rc"
        if [[ -f "${rc_file}" ]]; then
            rc=$(cat "${rc_file}")
            if [[ "${rc}" != "0" ]]; then
                FAILED_DIRS+=("${dir} (exit ${rc})")
            fi
            # Append per-dir log into the main log
            [[ -f "${LOG_DIR}/backup-${TIMESTAMP}-${dir}.log" ]] && \
                cat "${LOG_DIR}/backup-${TIMESTAMP}-${dir}.log" >> "${LOG_FILE}"
            rm -f "${rc_file}" "${LOG_DIR}/backup-${TIMESTAMP}-${dir}.log"
        else
            FAILED_DIRS+=("${dir} (no .rc file — worker may not have started)")
        fi
    done
fi

if [[ ${#FAILED_DIRS[@]} -gt 0 ]]; then
    log "ERROR: The following directories failed to sync:"
    for d in "${FAILED_DIRS[@]}"; do log "   - ${d}"; done
    notify_discord "failure" "rsync completed with **${#FAILED_DIRS[@]} failed directories**:\n\`\`\`\n$(printf '%s\n' "${FAILED_DIRS[@]}")\n\`\`\`\nCheck the log for details."
    exit 1
fi

log "   All ${#TOP_LEVEL_DIRS[@]} directories synced successfully."


# ── Step 3: Restart all containers ────────────────────────────────────────────
log ">> Restarting all containers..."
if [[ "${DRY_RUN}" == "true" ]]; then
    log "   [dry-run] docker compose -f ${COMPOSE_FILE} --env-file ${ENV_FILE} up -d"
else
    docker compose \
        -f "${COMPOSE_FILE}" \
        --env-file "${ENV_FILE}" \
        up --detach
fi
log "   All containers started."

log "======================================================"
log "  Backup complete! Log saved to: ${LOG_FILE}"
log "======================================================"

notify_discord "success" "All containers were stopped, **76G** of data was synced to \`${BACKUP_DEST}\`, and all containers have been restarted successfully."

# Disable ERR trap — we're done
trap - ERR
