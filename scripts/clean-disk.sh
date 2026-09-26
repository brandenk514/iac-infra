#!/bin/sh
# ==============================================================================
# clean-disk.sh — Monitor the disk holding the Transmission downloads dir and,
#                 when usage is at or above the threshold, delete completed
#                 files older than MIN_AGE_HOURS (inside the category subdirs:
#                 books, movies, music, tv) and prune the now-empty torrent
#                 folders left behind.
#
# Separately, when the Transmission "incomplete" dir (in-progress downloads)
# grows past INCOMPLETE_MAX_GB, old files inside it are also deleted —
# regardless of overall disk usage.
#
# Sends a Discord notification on success or failure. No-op runs (usage below
# the threshold) exit silently — this script is meant to run frequently
# (every 15–30 min) and must not spam Discord.
#
# Intended host: pterodactyl — the downloads dir is
#   /mnt/r5-dstor/dl-repo
# (the host path Transmission's /data is mounted from, see
#  opentofu/pterodactyl/transmission.tf). Completed files land directly in
#   books/ movies/ music/ tv/ subdirectories of that dir.
#
# Usage:
#   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/... ./clean-disk.sh
#
# Cron example (every 30 minutes):
#   */30 * * * * DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/... /usr/local/bin/clean-disk.sh
#
# All configuration is overridable via environment variables:
#   DISK_PATH       Path whose filesystem usage is probed (default /mnt/r5-dstor/dl-repo)
#   DOWNLOADS_DIR   The Transmission downloads dir (default $DISK_PATH); must
#                   contain the category subdirs — set it to a subdir if the
#                   categories live elsewhere
#   THRESHOLD       % usage at which to start cleaning (default 90)
#   MIN_AGE_HOURS   Only delete files at least this old (default 24)
#   CATEGORIES      Category subdirs (default "books movies music tv");
#                   any other subdir present in DOWNLOADS_DIR is also cleaned
#   INCOMPLETE_DIR  Transmission "incomplete" dir (default $DISK_PATH/incomplete)
#   INCOMPLETE_MAX_GB  Clean the incomplete dir when larger than this, in GiB
#                      (default 100)
#   LOG_FILE        Log destination (default /var/log/clean-disk.log)
#   DISCORD_WEBHOOK_URL   Discord webhook (unset = notifications skipped)
# ==============================================================================

# Target host: Ubuntu (dash as /bin/sh, GNU coreutils/findutils).
# Some schedulers invoke this under /bin/sh (dash) and ignore the shebang.
# Re-exec under bash so pipefail / [[ / etc. work.
[ -z "${BASH_VERSION:-}" ] && exec /bin/bash "$0" "$@"

set -euo pipefail

# ── Configuration (all overridable via environment) ──────────────────────────
DISK_PATH="${DISK_PATH:-/mnt/r5-dstor/dl-repo}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-${DISK_PATH}}"
THRESHOLD="${THRESHOLD:-90}"
MIN_AGE_HOURS="${MIN_AGE_HOURS:-24}"
CATEGORIES="${CATEGORIES:-books movies music tv}"
INCOMPLETE_DIR="${INCOMPLETE_DIR:-${DISK_PATH}/incomplete}"
INCOMPLETE_MAX_GB="${INCOMPLETE_MAX_GB:-100}"
LOG_FILE="${LOG_FILE:-/var/log/clean-disk.log}"

# Discord webhook (set here or export DISCORD_WEBHOOK_URL before running)
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$(dirname "${LOG_FILE}")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }

# Disk usage at the time the run started — reported in failure notifications
# so the operator knows whether the disk is still full.
USAGE_BEFORE=""

# Send a Discord embed notification
#   $1 = "success" | "failure"
#   $2 = description text (Discord markdown)
notify_discord() {
    [[ -z "${DISCORD_WEBHOOK_URL}" ]] && return 0  # silently skip if not configured

    local status="${1}"
    local description="${2}"
    local color title emoji

    if [[ "${status}" == "success" ]]; then
        color=3066993   # green
        title="Disk Cleanup Complete"
        emoji="✅"
    else
        color=15158332  # red
        title="Disk Cleanup Failed"
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
      { "name": "Host", "value": "$(hostname)", "inline": true },
      { "name": "Disk", "value": "${DISK_PATH}", "inline": true }
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

# Explicit fatal error. `exit` does not fire the ERR trap, so notify here.
die() {
    log "ERROR: $*"
    notify_discord "failure" "Cleanup was aborted: ${*}. Disk usage at abort: **${USAGE_BEFORE:-unknown}%**. Log: \`${LOG_FILE}\`"
    exit 1
}

# Trap unexpected exits: notify, then bail. (No containers to restore here.)
_on_error() {
    local exit_code=$?
    # Deliberately NOT using log(): if the log path is unwritable, log() would
    # fail inside the trap and mask the real error.
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: clean-disk failed (exit ${exit_code}, line ${1:-?})" >&2
    notify_discord "failure" "Cleanup failed at line **${1:-?}** with exit code **${exit_code}**. Disk usage: **${USAGE_BEFORE:-unknown}%** — the disk may still be full. Log: \`${LOG_FILE}\`"
    exit 1
}
trap '_on_error ${LINENO}' ERR

# Filesystem usage (percent) of the filesystem containing the given path.
disk_usage_pct() {
    df -P "$1" | awk 'NR==2 {print $5}' | tr -dc '0-9'
}

# Human-readable byte count (avoid numfmt — not present on all hosts).
human_bytes() {
    local bytes="${1}"
    if (( bytes >= 1073741824 )); then
        awk -v b="${bytes}" 'BEGIN { printf "%.1f GiB", b/1073741824 }'
    elif (( bytes >= 1048576 )); then
        awk -v b="${bytes}" 'BEGIN { printf "%.1f MiB", b/1048576 }'
    elif (( bytes >= 1024 )); then
        awk -v b="${bytes}" 'BEGIN { printf "%.1f KiB", b/1024 }'
    else
        echo "${bytes} B"
    fi
}

# Incomplete-dir cleanup — runs on every invocation, independent of the disk
# threshold. Trigger: dir size > INCOMPLETE_MAX_GB. Deletes files older than
# MIN_AGE_HOURS (in-progress but stalled torrents) and prunes empty subdirs.
INCOMPLETE_TRIGGERED=0
INCOMPLETE_DELETED=0
INCOMPLETE_BEFORE_HUMAN=""
INCOMPLETE_AFTER_HUMAN=""

clean_incomplete_dir() {
    if [[ ! -d "${INCOMPLETE_DIR}" ]]; then
        log "Incomplete dir not found: ${INCOMPLETE_DIR} — skipping."
        return 0
    fi

    local bytes_now max_bytes
    bytes_now="$(du -sb "${INCOMPLETE_DIR}" | awk '{print $1}')"
    max_bytes=$(( INCOMPLETE_MAX_GB * 1073741824 ))

    if (( bytes_now < max_bytes )); then
        log "Incomplete dir is $(human_bytes "${bytes_now}") (limit ${INCOMPLETE_MAX_GB} GiB) — nothing to do."
        return 0
    fi

    INCOMPLETE_TRIGGERED=1
    INCOMPLETE_BEFORE_HUMAN="$(human_bytes "${bytes_now}")"
    log "Incomplete dir is ${INCOMPLETE_BEFORE_HUMAN} (limit ${INCOMPLETE_MAX_GB} GiB) — deleting files older than ${MIN_AGE_HOURS}h"

    local n bytes_after
    n="$(find "${INCOMPLETE_DIR}" -mindepth 1 -type f -mmin +"${MIN_AGE_MINUTES}" -delete -print | wc -l | tr -d '[:space:]')"
    find "${INCOMPLETE_DIR}" -mindepth 1 -type d -empty -delete
    INCOMPLETE_DELETED="${n}"

    bytes_after="$(du -sb "${INCOMPLETE_DIR}" | awk '{print $1}')"
    (( bytes_after > bytes_now )) && bytes_after="${bytes_now}"
    INCOMPLETE_AFTER_HUMAN="$(human_bytes "${bytes_after}")"
    log "  incomplete: deleted ${n} file(s), dir is now ${INCOMPLETE_AFTER_HUMAN}"
}

# ── Validate configuration ───────────────────────────────────────────────────
[[ "${THRESHOLD}" =~ ^[0-9]+$ ]] || die "THRESHOLD must be a whole number (got: ${THRESHOLD})"
[[ "${MIN_AGE_HOURS}" =~ ^[0-9]+$ ]] || die "MIN_AGE_HOURS must be a whole number (got: ${MIN_AGE_HOURS})"
[[ "${INCOMPLETE_MAX_GB}" =~ ^[0-9]+$ ]] || die "INCOMPLETE_MAX_GB must be a whole number (got: ${INCOMPLETE_MAX_GB})"

command -v df   >/dev/null 2>&1 || die "'df' not found in PATH"
command -v find >/dev/null 2>&1 || die "'find' not found in PATH"
command -v du   >/dev/null 2>&1 || die "'du' not found in PATH"

# ── 1. Probe disk usage ──────────────────────────────────────────────────────
[[ -d "${DISK_PATH}" ]] || die "Disk path not found: ${DISK_PATH}"

USAGE_BEFORE="$(disk_usage_pct "${DISK_PATH}")"
log "Disk usage at ${DISK_PATH}: ${USAGE_BEFORE}% (threshold: ${THRESHOLD}%)"

MIN_AGE_MINUTES=$(( MIN_AGE_HOURS * 60 ))

# ── 2. Incomplete dir (runs even below the disk threshold) ─────────────────
clean_incomplete_dir

if [[ "${USAGE_BEFORE}" -lt "${THRESHOLD}" ]]; then
    log "Below threshold — nothing to do in the downloads dir."
    if [[ "${INCOMPLETE_TRIGGERED}" -eq 1 ]]; then
        notify_discord "success" "Incomplete dir \`${INCOMPLETE_DIR}\` was ${INCOMPLETE_BEFORE_HUMAN} (limit ${INCOMPLETE_MAX_GB} GiB) — deleted **${INCOMPLETE_DELETED}** file(s) older than ${MIN_AGE_HOURS}h, now ${INCOMPLETE_AFTER_HUMAN}. Disk usage: **${USAGE_BEFORE}%** (below the ${THRESHOLD}% threshold)."
    fi
    # Clean path — don't let the ERR trap fire on exit.
    trap - ERR
    exit 0
fi

[[ -d "${DOWNLOADS_DIR}" ]] || die "Downloads dir not found: ${DOWNLOADS_DIR}"

# ── 2. Resolve category dirs ─────────────────────────────────────────────────
# Clean the configured categories plus any other subdir that exists in
# DOWNLOADS_DIR, so newly added categories are picked up automatically.
# The category dirs themselves are NEVER deleted (persistent structure).
CATEGORIES_CLEAN=()
CAT_SEEN=""
add_category() {
    local base="${1}"
    # The incomplete dir has its own 100 GiB-triggered cleanup — exclude it
    # from the threshold-driven category cleanup.
    if [[ "$(basename "${INCOMPLETE_DIR}")" == "${base}" ]]; then return 0; fi
    case " ${CAT_SEEN} " in *" ${base} "*) return 0 ;; esac
    if [[ ! -d "${DOWNLOADS_DIR}/${base}" ]]; then return 0; fi
    CAT_SEEN="${CAT_SEEN:+${CAT_SEEN} }${base}"
    CATEGORIES_CLEAN+=("${base}")
}

for c in ${CATEGORIES}; do add_category "${c}"; done
while IFS= read -r d; do
    add_category "$(basename "${d}")"
done < <(find "${DOWNLOADS_DIR}" -mindepth 1 -maxdepth 1 -type d)

log "Cleaning ${#CATEGORIES_CLEAN[@]} category dir(s): ${CATEGORIES_CLEAN[*]:-<none>}"
[[ "${#CATEGORIES_CLEAN[@]}" -gt 0 ]] || die "No category subdirectories found under ${DOWNLOADS_DIR} — refusing to delete from the downloads root"

# ── 3. Delete old completed files + empty torrent folders ───────────────────
BYTES_BEFORE="$(du -sb "${DOWNLOADS_DIR}" | awk '{print $1}')"

TOTAL_FILES=0
for cat in "${CATEGORIES_CLEAN[@]}"; do
    n="$(find "${DOWNLOADS_DIR}/${cat}" -mindepth 1 -type f -mmin +"${MIN_AGE_MINUTES}" -delete -print | wc -l | tr -d '[:space:]')"
    # Prune the now-empty per-torrent folders (category dir itself is kept).
    find "${DOWNLOADS_DIR}/${cat}" -mindepth 1 -type d -empty -delete
    TOTAL_FILES=$(( TOTAL_FILES + n ))
    log "  ${cat}: deleted ${n} file(s) older than ${MIN_AGE_HOURS}h"
done

# Old files sitting directly in the downloads root are left untouched (they
# never routed to a category) but flagged for the operator.
STRAY_OLD="$(find "${DOWNLOADS_DIR}" -maxdepth 1 -type f -mmin +"${MIN_AGE_MINUTES}" | wc -l | tr -d '[:space:]')"
if [[ "${STRAY_OLD}" -gt 0 ]]; then
    log "  WARNING: ${STRAY_OLD} old file(s) sit directly in ${DOWNLOADS_DIR} (no category dir) — left untouched"
fi
# ── 4. Measure results ───────────────────────────────────────────────────────
BYTES_AFTER="$(du -sb "${DOWNLOADS_DIR}" | awk '{print $1}')"
BYTES_FREED=$(( BYTES_BEFORE - BYTES_AFTER ))
if [[ "${BYTES_FREED}" -lt 0 ]]; then BYTES_FREED=0; fi
FREED_HUMAN="$(human_bytes "${BYTES_FREED}")"

USAGE_AFTER="$(disk_usage_pct "${DISK_PATH}")"
log "Done. Files deleted: ${TOTAL_FILES}. Space freed: ${FREED_HUMAN}. Usage: ${USAGE_BEFORE}% → ${USAGE_AFTER}%"

# ── 5. Notify ────────────────────────────────────────────────────────────────
if [[ "${TOTAL_FILES}" -eq 0 && "${INCOMPLETE_TRIGGERED}" -eq 0 ]]; then
    # Disk is over the threshold but there was nothing eligible to delete —
    # the space is being used by something else. That needs attention.
    notify_discord "failure" "Disk usage reached **${USAGE_BEFORE}%** (threshold ${THRESHOLD}%) but **no files** were eligible for deletion (min age ${MIN_AGE_HOURS}h). The space is used by something else — manual investigation needed. Log: \`${LOG_FILE}\`"
    trap - ERR
    exit 1
fi

description=""
if [[ "${TOTAL_FILES}" -gt 0 ]]; then
    description="Freed **${FREED_HUMAN}** by deleting **${TOTAL_FILES}** completed file(s) older than ${MIN_AGE_HOURS}h from \`${DOWNLOADS_DIR}\`."
    if [[ "${STRAY_OLD}" -gt 0 ]]; then
        description="${description} Note: **${STRAY_OLD}** old file(s) sit directly in the downloads root (no category dir) and were left untouched."
    fi
fi
if [[ "${INCOMPLETE_TRIGGERED}" -eq 1 ]]; then
    description="${description:+${description} }Also cleaned the incomplete dir \`${INCOMPLETE_DIR}\` (${INCOMPLETE_BEFORE_HUMAN}, limit ${INCOMPLETE_MAX_GB} GiB) — deleted **${INCOMPLETE_DELETED}** file(s) older than ${MIN_AGE_HOURS}h, now ${INCOMPLETE_AFTER_HUMAN}."
fi
description="${description} Disk usage: **${USAGE_BEFORE}% → ${USAGE_AFTER}%**."
notify_discord "success" "${description}"

# Clean path — don't let the ERR trap fire on exit.
trap - ERR
exit 0
