# [Bug] Deadlock - 두 워커의 역순 락 획득으로 PID만 살아 있는 무응답 상태 발생

## 1. Description (현상 설명)

`MULTI_THREAD_ENABLE=true`에서 두 워커가 서로 다른 락을 먼저 획득한 뒤 상대가 가진 락을
요청했습니다. 2026-09-25 16:31:49 UTC의 `WAITING ... BLOCKED` 이후 앱 로그가 멈췄지만,
30초 관찰 종료 시점에도 PID 13과 포트는 유지됐습니다.

- 조건: `MEMORY_LIMIT=512`, `CPU_MAX_OCCUPY=10`, `MULTI_THREAD_ENABLE=true`
- 대상 워커 PID: 13
- 관찰 종료 상태: `STATUS=running`, `EXIT_CODE=0`

## 2. Evidence & Logs (증거 자료)

### 순환 대기 로그

```text
16:31:47 [Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
16:31:47 [Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
16:31:49 [Worker-Thread-1] Need resource [Socket_Pool_B] to finish job.
16:31:49 [Worker-Thread-2] Need resource [Shared_Memory_A] to write logs.
16:31:49 [Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
16:31:49 [Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
```

원본: [`evidence/deadlock-before/app.log`](../evidence/deadlock-before/app.log)

### PID, CPU/MEM 정체 및 락 대기

관찰 말미의 스냅샷은 반복해서 같은 상태를 보였습니다.

```text
PID  LWP  %CPU RSS   STAT WCHAN             COMMAND
13   13   0.1  17020 SNl  futex_wait_queue  agent-leak-app-
13   230  0.0  17020 SNl  futex_wait_queue  agent-leak-app-
13   231  0.0  17020 SNl  futex_wait_queue  agent-leak-app-
```

`monitor.sh`도 마지막 세 표본에서 PID 13, CPU 0.1%, RSS 16.6MiB, 스레드 3개,
`PORT:LISTENING`을 동일하게 기록했습니다. 즉 종료가 아니라 futex 락 대기 상태입니다.

원본: [`evidence/deadlock-before/threads.log`](../evidence/deadlock-before/threads.log),
[`evidence/deadlock-before/monitor.log`](../evidence/deadlock-before/monitor.log),
[`evidence/deadlock-before/result.txt`](../evidence/deadlock-before/result.txt)

## 3. Root Cause Analysis (원인 분석)

대기 그래프는 다음과 같습니다.

```text
Thread-1 --waits for--> Socket_Pool_B --held by--> Thread-2
Thread-2 --waits for--> Shared_Memory_A --held by--> Thread-1
```

교착상태의 네 조건이 모두 성립합니다.

1. 상호 배제: 각 락은 한 번에 한 스레드만 보유합니다.
2. 점유 대기: 각 스레드는 한 락을 보유한 채 다른 락을 기다립니다.
3. 비선점: 다른 스레드가 보유한 락을 강제로 회수하지 못합니다.
4. 순환 대기: Thread-1 → Thread-2 → Thread-1의 폐쇄 고리가 생겼습니다.

그래서 프로세스와 포트는 살아 있지만 작업 진행, RSS 변화, 로그 출력이 모두 멈췄습니다.

## 4. Workaround & Verification (조치 및 검증)

`MULTI_THREAD_ENABLE=false`로 바꾸고 나머지 조건을 동일하게 유지했습니다.

| 구분 | MULTI_THREAD_ENABLE | 30초 관찰 결과 |
|---|---|---|
| Before | true | 16:31:49 이후 로그 정지, RSS 16.6MiB 고정, 3개 스레드 futex 대기 |
| After | false | 로그가 16:32:06까지 계속됨, Heap 25 → 225MB, RSS 12.3 → 241.8MiB |

After에서도 PID 13은 살아 있었지만 메모리/CPU 워커 로그와 RSS 변화가 계속되어
무응답 상태가 아니었습니다.

After 원본: [`evidence/deadlock-after/app.log`](../evidence/deadlock-after/app.log),
[`evidence/deadlock-after/monitor.log`](../evidence/deadlock-after/monitor.log),
[`evidence/deadlock-after/threads.log`](../evidence/deadlock-after/threads.log)

`MULTI_THREAD_ENABLE=false`는 동시성을 포기하는 임시 회피책입니다. 근본 해결은 모든
스레드가 락을 동일한 전역 순서(예: `Shared_Memory_A` 후 `Socket_Pool_B`)로 획득하게 하고,
가능하면 타임아웃을 둔 `try-lock`과 실패 시 롤백을 적용하는 것입니다.

