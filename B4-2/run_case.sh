#!/usr/bin/env bash

set -u

case_name=$1
memory_limit=$2
cpu_limit=$3
multi_thread=$4
duration=$5
container="agent-${case_name}"
evidence_dir="$(pwd)/evidence/${case_name}"

mkdir -p "$evidence_dir"
find "$evidence_dir" -maxdepth 1 -type f -delete
docker rm -f "$container" >/dev/null 2>&1 || true

started_epoch=$(date +%s)
docker run -d --name "$container" --platform linux/arm64 \
    -e MEMORY_LIMIT="$memory_limit" \
    -e CPU_MAX_OCCUPY="$cpu_limit" \
    -e MULTI_THREAD_ENABLE="$multi_thread" \
    agent-leak-lab:arm64 > "$evidence_dir/container-id.txt"

{
    printf 'CASE=%s MEMORY_LIMIT=%s CPU_MAX_OCCUPY=%s MULTI_THREAD_ENABLE=%s\n' \
        "$case_name" "$memory_limit" "$cpu_limit" "$multi_thread"
    printf 'HOST_STARTED_AT=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
} > "$evidence_dir/config.txt"

for ((second = 1; second <= duration; second++)); do
    running=$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || printf 'false')
    if [[ "$running" != "true" ]]; then
        break
    fi
    docker exec "$container" ./monitor.sh >> "$evidence_dir/monitor.log" 2>&1 || true
    docker exec "$container" ps -eLo pid,lwp,psr,pcpu,pmem,rss,stat,wchan:24,comm \
        >> "$evidence_dir/threads.log" 2>&1 || true
    sleep 1
done

finished_epoch=$(date +%s)
docker logs --timestamps "$container" > "$evidence_dir/app.log" 2>&1 || true
docker inspect "$container" > "$evidence_dir/inspect.json" 2>&1 || true
docker inspect -f 'STATUS={{.State.Status}} EXIT_CODE={{.State.ExitCode}} OOM_KILLED={{.State.OOMKilled}} FINISHED_AT={{.State.FinishedAt}}' \
    "$container" > "$evidence_dir/result.txt" 2>&1 || true
printf 'OBSERVED_SECONDS=%s\n' "$((finished_epoch - started_epoch))" >> "$evidence_dir/result.txt"

printf '%s: ' "$case_name"
cat "$evidence_dir/result.txt"
