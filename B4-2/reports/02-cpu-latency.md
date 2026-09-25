# [Bug] CPU Latency - 높은 점유 허용값에서 안전 상한 초과 후 프로세스 종료

## 1. Description (현상 설명)

`MEMORY_LIMIT=512`, `MULTI_THREAD_ENABLE=false`, `CPU_MAX_OCCUPY=100`으로 실행하자
CPU 워커의 부하가 5.00%에서 지속 상승했습니다. 내부 안전 상한인 약 50%를 넘은 직후
`CPU Threshold Violated!`를 남기고 exit code 1로 종료됐습니다.

- 발생 시각: 2026-09-25 16:30:37~16:31:11 UTC
- 대상 워커 PID: 7
- 종료 상태: `STATUS=exited`, `EXIT_CODE=1`, `OOM_KILLED=false`

## 2. Evidence & Logs (증거 자료)

### 앱 로그의 부하 상승 및 종료

```text
16:30:39 [CpuWorker] Current Load: 5.00%
16:30:49 [CpuWorker] Current Load: 22.56%
16:30:58 [CpuWorker] Current Load: 38.91%
16:31:04 [CpuWorker] Current Load: 48.95%
16:31:11 [CpuWorker] Current Load: 50.19%
16:31:11 [CRITICAL] [CpuWorker] CPU Threshold Violated! (50.19%).
```

원본: [`evidence/cpu-before/app.log`](../evidence/cpu-before/app.log)

### ps 스레드 스냅샷

```text
PID LWP PSR %CPU %MEM RSS   STAT WCHAN      COMMAND
7   7   6   33.3 0.2 16952 SN   do_select  agent-leak-app-
```

1초 간격 표본 중 OS가 보고한 프로세스 사용률은 33.3%까지 관측됐습니다. 앱의 50.19%는
내부 워커가 계산한 순간 부하이고, `ps %CPU`는 샘플/누적 구간의 평균이므로 값이 다를 수
있습니다. 두 자료 모두 동일 PID의 부하 상승을 뒷받침합니다.

원본: [`evidence/cpu-before/threads.log`](../evidence/cpu-before/threads.log),
[`evidence/cpu-before/result.txt`](../evidence/cpu-before/result.txt)

> 이 바이너리 빌드는 literal `WATCHDOG` 또는 `SIGTERM` 문구를 출력하지 않았습니다.
> 실제 증거는 `CPU Threshold Violated!` 직후 컨테이너가 exit 1로 바뀐 것입니다.

## 3. Root Cause Analysis (원인 분석)

`CPU_MAX_OCCUPY=100`은 앱이 권고하는 50% 이하 범위를 벗어납니다. 워커가 부하를 계속
증가시키면서 다른 프로세스가 스케줄될 CPU 시간을 줄이고 응답 지연을 유발할 수 있어,
내부 보호 로직이 약 50%에서 위반을 감지하고 프로세스를 종료한 것으로 판단됩니다.

이는 시스템 전체 부하만의 문제가 아닙니다. 앱 로그는 `CpuWorker` 부하의 단조 증가를,
`ps -L`은 PID 7의 CPU 사용을 직접 보여주므로 특정 프로세스에서 발생한 과점유입니다.

## 4. Workaround & Verification (조치 및 검증)

`CPU_MAX_OCCUPY`를 100%에서 10%로 낮추고 다른 조건을 유지했습니다.

| 구분 | CPU_MAX_OCCUPY | 관찰 결과 | 최종 상태 |
|---|---:|---|---|
| Before | 100% | 5.00 → 50.19%, 임계치 위반 | 약 35초 후 exit 1 |
| After | 10% | 5~10% 피크와 cooldown 반복 | 42초 관찰 후에도 running |

After 로그에는 5.00%, 10.00%, 8.46%, 6.32%처럼 부하가 상한 내에서 오르내리는 패턴이
남았고 보호 종료가 발생하지 않았습니다.

After 원본: [`evidence/cpu-after/app.log`](../evidence/cpu-after/app.log),
[`evidence/cpu-after/monitor.log`](../evidence/cpu-after/monitor.log),
[`evidence/cpu-after/result.txt`](../evidence/cpu-after/result.txt)

근본 조치로는 CPU 집약 작업을 작은 단위로 나누어 양보 지점을 만들고, 요청률 제한 및
작업 큐를 적용하며, 운영 환경에서는 프로세스별 CPU 지속 시간과 응답 지연을 함께
경보해야 합니다.

