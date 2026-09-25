# agent-leak-app 시스템 장애 분석 리포트

## 실험 개요

Linux ARM64용 `agent-leak-app-arm64`를 Docker의 일반 사용자(`agent-admin`, uid 1001)로 실행하고,
OOM 보호 종료, CPU 과점유 보호 종료, 교착상태를 각각 재현했다.

| 항목 | 내용 |
|---|---|
| 실행 환경 | Docker Desktop 29.6.1, Ubuntu 24.04, Linux/aarch64 |
| 수집 시각 | 2026-09-25 16:30~16:32 UTC |
| 대상 | `agent-leak-app-arm64`, port 15034 |
| 분석 방법 | 애플리케이션 로그, `monitor.sh`, `ps -L`, 컨테이너 상태 |

## 실험 결과 요약

| Case | Before | After | 결과 |
|---|---|---|---|
| OOM | `MEMORY_LIMIT=50`, 6초 후 exit 1 | `MEMORY_LIMIT=100`, 12초 후 exit 1 | 한도 상향은 생존 시간만 증가시킴 |
| CPU | `CPU_MAX_OCCUPY=100`, 50.19%에서 exit 1 | `CPU_MAX_OCCUPY=10`, 42초 후에도 실행 중 | 낮은 상한에서 cooldown 동작 |
| Deadlock | `MULTI_THREAD_ENABLE=true`, 로그와 자원 변화 정지 | `false`, 로그와 RSS 변화 지속 | 단일 스레드 모드에서 순환 대기 회피 |

---

# [Bug] OOM 보호 정책 - 누적 힙이 한도에 도달하면 프로세스가 자체 종료됨

## 1. Description (현상 설명)

`MULTI_THREAD_ENABLE=false`, `CPU_MAX_OCCUPY=100` 조건에서 메모리 워커가 약 3초마다
25MB씩 힙을 누적했다. `MEMORY_LIMIT=50`에서는 시작 약 6초 후 50MB에 도달하며
프로세스가 exit code 1로 종료됐다.

- 발생 시각: 2026-09-25 16:30:38 UTC부터 관찰
- 대상 워커 PID: 13
- 종료 상태: `STATUS=exited`, `EXIT_CODE=1`, `OOM_KILLED=false`

## 2. Evidence & Logs (증거 자료)

### 애플리케이션 로그

```text
2026-09-25 16:30:40,476 [INFO] [MemoryWorker] Current Heap: 25MB
2026-09-25 16:30:43,496 [INFO] [MemoryWorker] Current Heap: 50MB
2026-09-25 16:30:43,496 [CRITICAL] [MemoryGuard] Memory limit exceeded (50MB >= 50MB) / (Recommend Over 256MB)
2026-09-25 16:30:43,496 [CRITICAL] [MemoryGuard] Self-terminating process 13 to prevent system instability.
```

원본: [`evidence/oom-before/app.log`](evidence/oom-before/app.log)

### monitor.sh 관제 로그

```text
[2026-09-25 16:30:38] PROCESS:agent-leak-app-arm64 PID:13 CPU:75.0% RSS:12.3MiB STATE:R THREADS:1 PORT:NOT_LISTENING
[2026-09-25 16:30:40] PROCESS:agent-leak-app-arm64 PID:13 CPU:1.6% RSS:41.6MiB STATE:SN THREADS:1 PORT:LISTENING
[2026-09-25 16:30:43] PROCESS:agent-leak-app-arm64 PID:13 CPU:0.8% RSS:41.6MiB STATE:SN THREADS:1 PORT:LISTENING
```

애플리케이션이 기록한 논리 힙과 OS의 RSS는 측정 범위가 다르므로 값이 정확히 같을 필요는 없다.
하지만 힙 누적, RSS 상승, 임계치 도달, 프로세스 종료가 같은 타임라인에서 확인된다.

원본: [`evidence/oom-before/monitor.log`](evidence/oom-before/monitor.log),
[`evidence/oom-before/result.txt`](evidence/oom-before/result.txt)

## 3. Root Cause Analysis (원인 분석)

메모리 워커가 만든 객체를 해제하지 않고 참조를 유지하여 힙이 25MB 단위로 계속 증가하는
메모리 누수 패턴이다. 이 상태가 지속되면 프로세스 RSS와 시스템 메모리 압력이 함께 상승한다.

이번 종료 주체는 Linux OOM Killer가 아니다. 컨테이너 상태가 `OOM_KILLED=false`이고,
종료 직전 `MemoryGuard`가 한도 초과와 self-termination을 명시했다. 즉 애플리케이션의
보호 정책이 시스템 전체의 메모리 고갈 전에 의도적으로 프로세스를 종료했다.

## 4. Workaround & Verification (조치 및 검증)

`MEMORY_LIMIT`를 50MB에서 100MB로 올리고 나머지 조건을 동일하게 유지했다.

| 구분 | MEMORY_LIMIT | 힙 로그 | 관측 RSS | 종료까지 관측 시간 |
|---|---:|---|---:|---:|
| Before | 50MB | 25 → 50MB | 12.3 → 41.6MiB | 6초 |
| After | 100MB | 25 → 50 → 75 → 100MB | 9.4 → 91.6MiB | 12초 |

After에서도 100MB 도달 시 같은 `MemoryGuard` 종료가 발생했다. 따라서 한도 상향은
생존 시간을 약 2배 늘리는 임시 조치일 뿐 근본 해결은 아니다.

After 원본: [`evidence/oom-after/app.log`](evidence/oom-after/app.log),
[`evidence/oom-after/monitor.log`](evidence/oom-after/monitor.log),
[`evidence/oom-after/result.txt`](evidence/oom-after/result.txt)

근본 조치로는 누적 컬렉션의 보존 필요성을 검토하고 처리 완료 데이터의 참조를 제거해야 한다.
운영 환경에서는 RSS 절대값뿐 아니라 `MiB/min` 증가율 경보를 추가해 장애를 조기에 탐지해야 한다.

---

# [Bug] CPU Latency - 높은 점유 허용값에서 안전 상한 초과 후 프로세스 종료

## 1. Description (현상 설명)

`MEMORY_LIMIT=512`, `MULTI_THREAD_ENABLE=false`, `CPU_MAX_OCCUPY=100`으로 실행하자
CPU 워커의 부하가 5.00%에서 지속 상승했다. 내부 안전 상한인 약 50%를 넘은 직후
`CPU Threshold Violated!`를 남기고 exit code 1로 종료됐다.

- 발생 시각: 2026-09-25 16:30:37~16:31:11 UTC
- 대상 워커 PID: 7
- 종료 상태: `STATUS=exited`, `EXIT_CODE=1`, `OOM_KILLED=false`

## 2. Evidence & Logs (증거 자료)

### 애플리케이션 로그

```text
2026-09-25 16:30:39,997 [INFO] [CpuWorker] Current Load: 5.00%
2026-09-25 16:30:49,347 [INFO] [CpuWorker] Current Load: 22.56%
2026-09-25 16:30:58,717 [INFO] [CpuWorker] Current Load: 38.91%
2026-09-25 16:31:04,954 [INFO] [CpuWorker] Current Load: 48.95%
2026-09-25 16:31:11,207 [INFO] [CpuWorker] Current Load: 50.19%
2026-09-25 16:31:11,309 [CRITICAL] [CpuWorker] CPU Threshold Violated! (50.19%).
```

원본: [`evidence/cpu-before/app.log`](evidence/cpu-before/app.log)

### ps 스레드 스냅샷

```text
PID LWP PSR %CPU %MEM RSS   STAT WCHAN      COMMAND
7   7   6   33.3 0.2 16952 SN   do_select  agent-leak-app-
```

1초 간격 표본 중 OS가 보고한 프로세스 사용률은 33.3%까지 관측됐다. 앱의 50.19%는
내부 워커가 계산한 순간 부하이고, `ps %CPU`는 샘플 또는 누적 구간의 평균이므로 값이
다를 수 있다. 두 자료 모두 동일 프로세스에서 발생한 부하 상승을 뒷받침한다.

원본: [`evidence/cpu-before/threads.log`](evidence/cpu-before/threads.log),
[`evidence/cpu-before/result.txt`](evidence/cpu-before/result.txt)

> 이 바이너리 빌드는 `WATCHDOG` 또는 `SIGTERM` 문구를 출력하지 않았다. 실제 증거는
> `CPU Threshold Violated!` 직후 컨테이너 상태가 exit 1로 변경된 것이다.

## 3. Root Cause Analysis (원인 분석)

`CPU_MAX_OCCUPY=100`은 애플리케이션이 권고하는 50% 이하 범위를 벗어난다. 워커가
부하를 계속 증가시키면서 다른 프로세스가 스케줄될 CPU 시간을 줄이고 응답 지연을
유발할 수 있어, 내부 보호 로직이 약 50%에서 위반을 감지하고 프로세스를 종료한 것으로 판단된다.

앱 로그는 `CpuWorker` 부하의 단조 증가를 보여주며, `ps -L`은 PID 7의 CPU 사용을
직접 보여준다. 따라서 시스템 전체 부하가 아니라 특정 프로세스에서 발생한 과점유다.

## 4. Workaround & Verification (조치 및 검증)

`CPU_MAX_OCCUPY`를 100%에서 10%로 낮추고 다른 조건을 유지했다.

| 구분 | CPU_MAX_OCCUPY | 관찰 결과 | 최종 상태 |
|---|---:|---|---|
| Before | 100% | 5.00 → 50.19%, 임계치 위반 | 약 35초 후 exit 1 |
| After | 10% | 5~10% 피크와 cooldown 반복 | 42초 관찰 후에도 running |

After 로그에는 5.00%, 10.00%, 8.46%, 6.32%처럼 부하가 상한 내에서 오르내리는
패턴이 남았고 보호 종료가 발생하지 않았다.

After 원본: [`evidence/cpu-after/app.log`](evidence/cpu-after/app.log),
[`evidence/cpu-after/monitor.log`](evidence/cpu-after/monitor.log),
[`evidence/cpu-after/result.txt`](evidence/cpu-after/result.txt)

근본 조치로는 CPU 집약 작업을 작은 단위로 나누어 양보 지점을 만들고, 요청률 제한과
작업 큐를 적용해야 한다. 운영 환경에서는 프로세스별 CPU 지속 시간과 응답 지연을 함께 경보해야 한다.

---

# [Bug] Deadlock - 두 워커의 역순 락 획득으로 PID만 살아 있는 무응답 상태 발생

## 1. Description (현상 설명)

`MULTI_THREAD_ENABLE=true`에서 두 워커가 서로 다른 락을 먼저 획득한 뒤 상대가 가진 락을
요청했다. 2026-09-25 16:31:49 UTC의 `WAITING ... BLOCKED` 이후 앱 로그가 멈췄지만,
30초 관찰 종료 시점에도 PID 13과 포트는 유지됐다.

- 조건: `MEMORY_LIMIT=512`, `CPU_MAX_OCCUPY=10`, `MULTI_THREAD_ENABLE=true`
- 대상 워커 PID: 13
- 관찰 종료 상태: `STATUS=running`, `EXIT_CODE=0`

## 2. Evidence & Logs (증거 자료)

### 순환 대기 로그

```text
2026-09-25 16:31:47,669 [Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-09-25 16:31:47,669 [Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-09-25 16:31:49,686 [Worker-Thread-1] Need resource [Socket_Pool_B] to finish job.
2026-09-25 16:31:49,686 [Worker-Thread-2] Need resource [Shared_Memory_A] to write logs.
2026-09-25 16:31:49,686 [Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
2026-09-25 16:31:49,686 [Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
```

원본: [`evidence/deadlock-before/app.log`](evidence/deadlock-before/app.log)

### PID, CPU/MEM 정체 및 락 대기

관찰 말미의 스냅샷은 반복해서 같은 상태를 보였다.

```text
PID  LWP  %CPU RSS   STAT WCHAN             COMMAND
13   13   0.1  17020 SNl  futex_wait_queue  agent-leak-app-
13   230  0.0  17020 SNl  futex_wait_queue  agent-leak-app-
13   231  0.0  17020 SNl  futex_wait_queue  agent-leak-app-
```

`monitor.sh`도 마지막 세 표본에서 PID 13, CPU 0.1%, RSS 16.6MiB, 스레드 3개,
`PORT:LISTENING`을 동일하게 기록했다. 즉 프로세스가 종료된 것이 아니라 futex 락을
기다리며 멈춘 상태다.

원본: [`evidence/deadlock-before/threads.log`](evidence/deadlock-before/threads.log),
[`evidence/deadlock-before/monitor.log`](evidence/deadlock-before/monitor.log),
[`evidence/deadlock-before/result.txt`](evidence/deadlock-before/result.txt)

## 3. Root Cause Analysis (원인 분석)

대기 관계는 다음과 같다.

```text
Thread-1 --waits for--> Socket_Pool_B --held by--> Thread-2
Thread-2 --waits for--> Shared_Memory_A --held by--> Thread-1
```

교착상태의 네 조건이 모두 성립한다.

1. 상호 배제: 각 락은 한 번에 한 스레드만 보유한다.
2. 점유 대기: 각 스레드는 한 락을 보유한 채 다른 락을 기다린다.
3. 비선점: 다른 스레드가 보유한 락을 강제로 회수하지 못한다.
4. 순환 대기: Thread-1 → Thread-2 → Thread-1의 폐쇄 고리가 생겼다.

따라서 프로세스와 포트는 살아 있지만 작업 진행, RSS 변화, 로그 출력이 모두 멈췄다.

## 4. Workaround & Verification (조치 및 검증)

`MULTI_THREAD_ENABLE=false`로 바꾸고 나머지 조건을 동일하게 유지했다.

| 구분 | MULTI_THREAD_ENABLE | 30초 관찰 결과 |
|---|---|---|
| Before | true | 16:31:49 이후 로그 정지, RSS 16.6MiB 고정, 3개 스레드 futex 대기 |
| After | false | 로그가 16:32:06까지 계속됨, Heap 25 → 225MB, RSS 12.3 → 241.8MiB |

After에서도 PID 13은 살아 있었지만 메모리와 CPU 워커 로그 및 RSS 변화가 계속되어
무응답 상태가 아니었다.

After 원본: [`evidence/deadlock-after/app.log`](evidence/deadlock-after/app.log),
[`evidence/deadlock-after/monitor.log`](evidence/deadlock-after/monitor.log),
[`evidence/deadlock-after/threads.log`](evidence/deadlock-after/threads.log)

`MULTI_THREAD_ENABLE=false`는 동시성을 포기하는 임시 회피책이다. 근본 해결은 모든
스레드가 락을 동일한 전역 순서로 획득하게 하고, 가능한 경우 타임아웃을 둔 `try-lock`과
실패 시 롤백을 적용하는 것이다.

---

## 증거 파일 구성

각 실험 폴더에는 다음 파일이 저장되어 있다.

- `config.txt`: 실행 환경변수
- `app.log`: 애플리케이션 표준 출력과 오류
- `monitor.log`: 프로세스 CPU, RSS, 상태, 스레드 수, 포트 상태
- `threads.log`: `ps -L` 스레드 스냅샷
- `result.txt`: 종료 상태, exit code, 관찰 시간
- `inspect.json`: Docker 컨테이너 상태 원본

## 사용한 주요 진단 명령

```bash
pgrep -f agent-leak-app-arm64
ps -p <PID> -o %cpu=,rss=,stat=,nlwp=
ps -eLo pid,lwp,psr,pcpu,pmem,rss,stat,wchan:24,comm
ss -tln | grep :15034
```

`monitor.sh`는 작은 부트 래퍼와 실제 워커가 같은 프로세스 이름을 사용하는 점을 고려해,
동일 이름의 PID 중 RSS가 가장 큰 프로세스를 실제 관제 대상으로 선택한다.
