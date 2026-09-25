# agent-leak-app 장애 분석 실습

Linux ARM64용 `agent-leak-app-arm64`를 Docker의 일반 사용자(`agent-admin`, uid 1001)로 실행하고,
OOM 보호 종료, CPU 과점유 보호 종료, 교착상태를 각각 재현한 결과입니다.

## 제출 결과물

- [통합 장애 분석 리포트](INCIDENT_REPORTS.md)
- [OOM Crash 이슈 리포트](reports/01-oom-crash.md)
- [CPU Latency 이슈 리포트](reports/02-cpu-latency.md)
- [Deadlock 이슈 리포트](reports/03-deadlock.md)
- `evidence/`: 각 실험의 환경값, 애플리케이션 로그, 관제 로그, 스레드 스냅샷, 컨테이너 종료 상태
- `monitor.sh`: 실제 워커 PID를 식별하여 CPU, RSS, 상태, 스레드 수, 포트를 기록하는 관제 스크립트
- `run_case.sh`: 같은 방법으로 실험을 다시 수행하는 자동화 스크립트

## 재현 환경

- Host: macOS ARM64
- Runtime: Docker Desktop 29.6.1, Linux/aarch64
- Image: Ubuntu 24.04
- App port: 15034
- App account: `agent-admin` (non-root)

이미지는 다음 명령으로 빌드합니다.

```bash
docker build --platform linux/arm64 -t agent-leak-lab:arm64 .
```

각 비교 실험은 다음과 같이 재현할 수 있습니다.

```bash
./run_case.sh oom-before 50 100 false 30
./run_case.sh oom-after 100 100 false 30
./run_case.sh cpu-before 512 100 false 40
./run_case.sh cpu-after 512 10 false 35
./run_case.sh deadlock-before 512 10 true 25
./run_case.sh deadlock-after 512 10 false 25
```

`run_case.sh`의 마지막 숫자는 최대 관찰 시간(초)입니다. 관찰 종료 시 살아 있는 컨테이너는
후속 조사를 위해 자동으로 삭제하지 않습니다.

## 핵심 결과

| Case | Before | After | 결과 |
|---|---|---|---|
| OOM | `MEMORY_LIMIT=50`, 6초 후 exit 1 | `MEMORY_LIMIT=100`, 12초 후 exit 1 | 한도 2배 상향 시 생존 시간도 약 2배 증가. 누수 자체는 지속 |
| CPU | `CPU_MAX_OCCUPY=100`, 50.19%에서 exit 1 | `CPU_MAX_OCCUPY=10`, 42초 시점 running | 낮은 상한에서 피크/쿨다운이 반복되어 보호 종료 회피 |
| Deadlock | `MULTI_THREAD_ENABLE=true`, PID 유지·로그 정지 | `false`, 30초 동안 로그/RSS 변화 지속 | 단일 스레드 모드에서 순환 대기 회피 |

> 컨테이너의 `OOM_KILLED=false`는 커널/컨테이너 OOM Killer가 종료한 것이 아니라
> 애플리케이션 내부 보호 정책이 스스로 종료했다는 근거입니다.
