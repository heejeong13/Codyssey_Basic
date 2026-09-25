#!/usr/bin/env bash

set -u
umask 002

# agent-leak-app process monitor
APP_PROCESS_NAME="${APP_PROCESS_NAME:-agent-leak-app-arm64}"
APP_PORT="${AGENT_PORT:-15034}"
LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
LOG_FILE="${LOG_DIR}/monitor.log"

CPU_THRESHOLD="${CPU_THRESHOLD:-20}"
MEM_THRESHOLD="${MEM_THRESHOLD:-10}"
DISK_THRESHOLD="${DISK_THRESHOLD:-80}"
MAX_LOG_SIZE_MB="${MAX_LOG_SIZE_MB:-10}"
MAX_BACKUPS="${MAX_BACKUPS:-10}"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

manage_log() {
    local max_size_bytes current_size_bytes backup_count oldest_backup backup_file
    max_size_bytes=$((MAX_LOG_SIZE_MB * 1024 * 1024))
    current_size_bytes=$(stat -c %s "$LOG_FILE")

    if (( current_size_bytes < max_size_bytes )); then
        return
    fi

    backup_count=$(find "$LOG_DIR" -maxdepth 1 -type f -name 'monitor-*.log' | wc -l)
    while (( backup_count >= MAX_BACKUPS )); do
        oldest_backup=$(find "$LOG_DIR" -maxdepth 1 -type f -name 'monitor-*.log' -printf '%T@ %p\n' \
            | sort -n | head -n 1 | cut -d' ' -f2-)
        if [[ -n "$oldest_backup" ]]; then
            rm -f -- "$oldest_backup"
        fi
        backup_count=$(find "$LOG_DIR" -maxdepth 1 -type f -name 'monitor-*.log' | wc -l)
    done

    backup_file="${LOG_DIR}/monitor-$(date +'%Y-%m-%d-%H-%M-%S').log"
    mv -- "$LOG_FILE" "$backup_file"
    touch "$LOG_FILE"
}

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
matching_pids=$(pgrep -f "${APP_PROCESS_NAME}" || true)
process_pid=""
if [[ -n "$matching_pids" ]]; then
    # The packaged executable keeps a small boot wrapper and starts the actual
    # worker as a child with the same command name. Select the largest RSS so
    # monitoring follows the worker rather than the waiting wrapper.
    pid_list=$(printf '%s\n' "$matching_pids" | paste -sd, -)
    process_pid=$(ps -o pid=,rss= -p "$pid_list" \
        | sort -k2,2nr | awk 'NR == 1 {print $1}')
fi

if [[ -z "$process_pid" ]]; then
    printf '[%s] PROCESS:%s STATUS:DOWN\n' "$timestamp" "$APP_PROCESS_NAME" | tee -a "$LOG_FILE"
    exit 1
fi

port_state="NOT_LISTENING"
if ss -tln | grep -qE "[:.]${APP_PORT}[[:space:]]"; then
    port_state="LISTENING"
fi

# ps reports process CPU percentage and resident set size (RSS) in KiB.
read -r process_cpu process_mem_kib process_state thread_count < <(
    ps -p "$process_pid" -o %cpu=,rss=,stat=,nlwp= | awk '{$1=$1; print}'
)
process_mem_mib=$(awk -v rss="$process_mem_kib" 'BEGIN {printf "%.1f", rss / 1024}')
disk_usage=$(df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')

log_msg=$(printf '[%s] PROCESS:%s PID:%s CPU:%s%% RSS:%sMiB STATE:%s THREADS:%s PORT:%s DISK_USED:%s%%' \
    "$timestamp" "$APP_PROCESS_NAME" "$process_pid" "$process_cpu" "$process_mem_mib" \
    "$process_state" "$thread_count" "$port_state" "$disk_usage")
printf '%s\n' "$log_msg" | tee -a "$LOG_FILE"

cpu_int=${process_cpu%.*}
mem_int=${process_mem_mib%.*}
if (( cpu_int > CPU_THRESHOLD )); then
    printf '[WARNING] Process CPU threshold exceeded (%s%% > %s%%)\n' "$process_cpu" "$CPU_THRESHOLD"
fi
if (( mem_int > MEM_THRESHOLD )); then
    printf '[WARNING] Process RSS threshold exceeded (%sMiB > %sMiB)\n' "$process_mem_mib" "$MEM_THRESHOLD"
fi
if (( disk_usage > DISK_THRESHOLD )); then
    printf '[WARNING] Disk threshold exceeded (%s%% > %s%%)\n' "$disk_usage" "$DISK_THRESHOLD"
fi
if [[ "$port_state" != "LISTENING" ]]; then
    printf '[WARNING] Port %s is not listening\n' "$APP_PORT"
fi

manage_log
