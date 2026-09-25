# [Bug] OOM 보호 정책 - 누적 힙이 한도에 도달하면 프로세스가 자체 종료됨

## 1. Description (현상 설명)

`MULTI_THREAD_ENABLE=false`, `CPU_MAX_OCCUPY=100` 조건에서 메모리 워커가 약 3초마다
25MB씩 힙을 누적했습니다. `MEMORY_LIMIT=50`에서는 시작 약 6초 후 50MB에 도달하며
프로세스가 exit code 1로 종료됐습니다.

- 발생 시각: 2026-09-25 16:30:38 UTC부터 관찰
- 대상 워커 PID: 13
- 종료 상태: `STATUS=exited`, `EXIT_CODE=1`, `OOM_KILLED=false`

## 2. Evidence & Logs (증거 자료)

### 앱 로그

```text
2026-09-25 16:30:40,476 [INFO] [MemoryWorker] Current Heap: 25MB
2026-09-25 16:30:43,496 [INFO] [MemoryWorker] Current Heap: 50MB
2026-09-25 16:30:43,496 [CRITICAL] [MemoryGuard] Memory limit exceeded (50MB >= 50MB) / (Recommend Over 256MB)
2026-09-25 16:30:43,496 [CRITICAL] [MemoryGuard] Self-terminating process 13 to prevent system instability.
```

원본: [`evidence/oom-before/app.log`](../evidence/oom-before/app.log)

### monitor.sh 관제

```text
[2026-09-25 16:30:38] ... PID:13 ... RSS:12.3MiB STATE:R ...
[2026-09-25 16:30:40] ... PID:13 ... RSS:41.6MiB STATE:SN ... PORT:LISTENING ...
[2026-09-25 16:30:43] ... PID:13 ... RSS:41.6MiB STATE:SN ... PORT:LISTENING ...
```

애플리케이션이 기록한 논리 힙 50MB와 OS의 RSS는 측정 대상과 단위가 다르므로 정확히
같은 값일 필요는 없습니다. 하지만 힙 누적 로그, RSS 상승, 임계치 도달, 즉시 종료가 같은
타임라인에 존재합니다.

원본: [`evidence/oom-before/monitor.log`](../evidence/oom-before/monitor.log),
[`evidence/oom-before/result.txt`](../evidence/oom-before/result.txt)

## 3. Root Cause Analysis (원인 분석)

메모리 워커가 만든 객체를 해제하지 않고 참조를 유지하여 힙이 25MB 단위로 계속
증가하는 누수 패턴입니다. 이 상태가 지속되면 프로세스 RSS와 시스템 메모리 압력이 함께
상승할 수 있습니다.

이번 종료 주체는 Linux OOM Killer가 아닙니다. 컨테이너 상태가 `OOM_KILLED=false`이고,
종료 직전 `MemoryGuard`가 한도 초과와 self-termination을 명시했습니다. 즉 애플리케이션의
보호 정책이 시스템 전체의 메모리 고갈 전에 의도적으로 exit 1을 발생시켰습니다.

## 4. Workaround & Verification (조치 및 검증)

`MEMORY_LIMIT`를 50MB에서 100MB로 올리고 나머지 조건을 동일하게 유지했습니다.

| 구분 | MEMORY_LIMIT | 힙 로그 | 관측 RSS | 종료까지 관측 시간 |
|---|---:|---|---:|---:|
| Before | 50MB | 25 → 50MB | 12.3 → 41.6MiB | 6초 |
| After | 100MB | 25 → 50 → 75 → 100MB | 9.4 → 91.6MiB | 12초 |

After에서도 100MB 도달 시 같은 `MemoryGuard` 종료가 발생했습니다. 따라서 한도 상향은
생존 시간을 약 2배 늘리는 임시 조치일 뿐 근본 해결은 아닙니다.

After 원본: [`evidence/oom-after/app.log`](../evidence/oom-after/app.log),
[`evidence/oom-after/monitor.log`](../evidence/oom-after/monitor.log),
[`evidence/oom-after/result.txt`](../evidence/oom-after/result.txt)

근본 조치로는 누적 컬렉션의 보존 필요성을 검토하고, 처리 완료 데이터의 참조를 제거하며,
장시간 부하 테스트에서 RSS 기울기와 객체 수를 함께 추적해야 합니다. 운영 환경에서는
RSS 절대값뿐 아니라 `MiB/min` 증가율 경보도 추가해야 조기 탐지가 가능합니다.

