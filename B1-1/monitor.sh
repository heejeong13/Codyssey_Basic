#!/bin/bash

umask 002
# ==============================================================================
# 시스템 관제 자동화 스크립트 (monitor.sh)
# ==============================================================================

# --- 설정 변수 ---
APP_PROCESS_NAME="${APP_PROCESS_NAME:-agent_app}"       # 감시할 프로세스 이름
APP_PORT="${AGENT_PORT:-15034}"                             # 감시할 TCP 포트
LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"          # 로그 파일 저장 위치
LOG_FILE="$LOG_DIR/monitor.log"                         # 로그 파일 명
APP_HOME="${AGENT_HOME:-/home/agent-admin/agent-app}"   # 프로그램 저장 위치
APP_PATH="$APP_HOME/$APP_NAME"

# 임계값 설정
CPU_THRESHOLD=20
MEM_THRESHOLD=10
DISK_THRESHOLD=80
MAX_LOG_SIZE_MB=10
MAX_BACKUPS=10

# --- 함수 정의 ---

# 로그 기록 함수
manage_log() {
    # 10mb 계산
    local max_size_bytes=$((MAX_LOG_SIZE_MB * 1024 * 1024))
    # 현재 로그 파일의 크기 확인
    local current_size_bytes=$(stat -c %s "$LOG_FILE")

    if (( current_size_bytes < max_size_bytes )); then
        return
    fi

    # 1. 현재 백업 파일들의 목록을 가져와 개수를 센다.
    # 'grep -v'를 이용해 목록에서 현재 로그 파일(monitor.log)은 제외한다.
    local backup_files_list
    backup_files_list=$(ls -1 "${LOG_DIR}"/monitor-*.log 2>/dev/null | grep -v "${LOG_FILE}$")
    
    local backup_count
    # backup_files_list가 비어있지 않을 때만 wc -l 실행
    if [ -n "$backup_files_list" ]; then
        backup_count=$(echo "$backup_files_list" | wc -l)
    else
        backup_count=0
    fi

    # 2. 백업 파일 개수가 최대치에 도달했거나 넘었으면, 가장 오래된 파일을 삭제한다.
    while (( backup_count >= MAX_BACKUPS )); do
        # 3. 가장 오래된 파일 찾기: 목록을 정렬(sort)했을 때 첫 번째 줄(head -n 1)에 오는 파일
        local oldest_backup
        oldest_backup=$(echo "$backup_files_list" | sort | head -n 1)
        
        if [ -n "$oldest_backup" ]; then
            echo "Max backups (${MAX_BACKUPS}) reached. Deleting oldest: ${oldest_backup}"
            rm -f "$oldest_backup"
        fi
        
        # 삭제 후 목록과 개수를 다시 계산하여 루프 조건을 확인
        backup_files_list=$(ls -1 "${LOG_DIR}"/monitor-*.log 2>/dev/null | grep -v "${LOG_FILE}$")
        if [ -n "$backup_files_list" ]; then
            backup_count=$(echo "$backup_files_list" | wc -l)
        else
            backup_count=0
        fi
    done

    # 4. 현재 로그 파일을 백업
    local backup_file="${LOG_DIR}/monitor-$(date +'%Y-%m-%d-%H-%M-%S').log"
    echo "Log size exceeds ${MAX_LOG_SIZE_MB}MB. Rotating log to ${backup_file}"
    
    mv "$LOG_FILE" "$backup_file"
    touch "$LOG_FILE"
}

# --- 스크립트 시작 ---
echo "====== SYSTEM MONITOR RESULT ======"
echo

# --- 1. Health Check (실패 시 종료) ---
echo "[HEALTH CHECK]"

# 프로세스 확인
process_pid=$(pgrep -f "$APP_PROCESS_NAME" | xargs)
if [ -z "$process_pid" ]; then
    echo "Checking process '$APP_PROCESS_NAME'... [FAIL]"
    echo "[CRITICAL] Process '$APP_PROCESS_NAME' is not running."
    exit 1
else
    echo "Checking process '$APP_PROCESS_NAME'... [OK] (PID: $process_pid)"
fi

# 포트 확인
if ss -tln | grep -q ":$APP_PORT"; then
    echo "Checking port $APP_PORT... [OK]"
else
    echo "Checking port $APP_PORT... [FAIL]"
    echo "[CRITICAL] Port $APP_PORT is not in LISTEN state."
    exit 1
fi

echo

# --- 2. 상태 점검(경고만 출력) ---
# 방화벽 활성화 상태 점검
firewall_active=false
if command -v ufw > /dev/null && ufw status | grep -q "Status: active"; then
    firewall_active=true
elif command -v firewall-cmd > /dev/null && firewall-cmd --state | grep -q "running"; then
    firewall_active=true
fi

if [ "$firewall_active" = false ]; then
    echo "[WARNING] Firewall is not active."
fi

# --- 3. 자원 수집 ---
echo "[RESOURCE MONITORING]"

# CPU 사용률 (%) - 유휴(idle) CPU를 100에서 뺀 값
cpu_idle=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/")
cpu_usage=$(echo "100 - $cpu_idle" | bc)

# 메모리 사용률 (%)
mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')

# 디스크 사용률 (%) - Root('/') 파티션 기준
disk_usage=$(df / | grep / | awk '{print $5}' | sed 's/%//g')

# 수집된 자원 정보 출력
printf "CPU Usage : %.1f%%\n" "$cpu_usage"
printf "MEM Usage : %.1f%%\n" "$mem_usage"
printf "DISK Used : %s%%\n" "$disk_usage"
echo

# --- 4. 임계값 경고(경고만 출력) ---
# 정수 비교를 위해 소수점 버림
cpu_usage_int=${cpu_usage%.*}
mem_usage_int=${mem_usage%.*}
disk_usage_int=${disk_usage%.*}

if [ "$cpu_usage_int" -gt "$CPU_THRESHOLD" ]; then
    echo "[WARNING]CPU threshold exceeded (${cpu_usage}% > ${CPU_THRESHOLD}%)"
fi
if [ "$mem_usage_int" -gt "$MEM_THRESHOLD" ]; then
    echo "[WARNING]MEM threshold exceeded (${mem_usage}% > ${MEM_THRESHOLD}%)"
fi
if [ "$disk_usage_int" -gt "$DISK_THRESHOLD" ]; then
    echo "[WARNING]MEM threshold exceeded (${disk_usage}% > ${DISK_THRESHOLD}%)"
fi

# --- 5. 로그 기록 ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_MSG="[${TIMESTAMP}] PID:${process_pid} CPU:${cpu_usage}% MEM:${mem_usage}% DISK_USED:${disk_usage}%"
echo "$LOG_MSG" >> "$LOG_FILE"

manage_log