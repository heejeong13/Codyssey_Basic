# LCK PostgreSQL 학습 프로젝트

LCK 리그 데이터를 바탕으로 테이블 설계부터 데이터 입력과 SQL 조회까지 경험하는 PostgreSQL 실습 프로젝트입니다. 팀, 선수, 소속 이력, 대회와 우승 기록의 관계를 PK와 FK로 표현하고, SELECT, JOIN, GROUP BY, 서브쿼리, UPDATE, DELETE 및 인덱스를 활용해 실제 데이터 요구사항을 해결합니다. 이를 통해 관계형 데이터베이스의 구조, 데이터 무결성과 조인 기반 조회 방식을 학습합니다.

## 먼저 알아둘 두 폴더

`Postgres.app`은 PostgreSQL 서버를 실행하기 위한 프로그램과 `psql`, `initdb`, `pg_ctl` 같은 명령어가 들어 있는 macOS 앱입니다. `make install`이 다음 위치에 설치합니다.

```text
~/Applications/Postgres.app
```

`.postgres_data`는 이 프로젝트가 만든 실제 데이터베이스 파일과 서버 설정을 저장하는 폴더입니다. 이를 PostgreSQL에서는 `PGDATA`라고 부릅니다.

```text
프로젝트/.postgres_data
```

Postgres.app을 책상이라고 본다면 `.postgres_data`는 그 위에서 작성한 문서를 넣는 서랍에 가깝습니다. 프로그램과 실제 데이터를 분리하므로 다른 PostgreSQL 서버와 섞이지 않는 프로젝트 전용 환경을 만들 수 있습니다.

## 전체 실행 흐름

```text
Postgres.app 설치
        ↓
PostgreSQL 16 명령어 사용 가능
        ↓
.postgres_data 생성
        ↓
localhost:5433 PostgreSQL 서버 실행
        ↓
b5_1_db 데이터베이스 생성
        ↓
SQL 파일 실행
        ↓
테이블과 데이터 및 조회 결과 생성
```

이 프로젝트는 Unix socket 경로를 별도로 만들지 않습니다. 모든 클라이언트는 `localhost:5433`으로 TCP 접속하므로 접속 주소가 Makefile, Bash, VS Code에서 같습니다.

## 관리하는 LCK 데이터

대상 팀은 2026년 LCK의 다음 10개 팀입니다.

- T1 (`T1`)
- Gen.G (`GEN`)
- Dplus KIA (`DK`)
- Hanwha Life Esports (`HLE`)
- KT Rolster (`KT`)
- BNK FearX (`BFX`)
- DN SOOPers (`DNS`)
- Kiwoom DRX (`KRX`)
- Nongshim RedForce (`NS`)
- Hanjin BRION (`BRO`)

선수 이력 범위는 기존 T1, Gen.G, Dplus KIA, Hanwha Life Esports, KT Rolster 5개 팀입니다. 2020년부터 데이터 기준일까지 이 팀들의 공식 LCK 1군 주전, 후보, 시즌 중 영입 및 공식 콜업 이력이 확인되는 경우 포함했습니다. 새로 추가한 나머지 5개 팀은 과제 조건에 따라 팀 기본정보만 저장하고 선수 이력은 넣지 않았습니다. 2군이나 아카데미에만 소속된 선수, 연습생, 코치, 감독, 분석관과 기타 비선수 스태프는 제외합니다.

선수는 `player`에 소환사명, 실제 이름과 대표 포지션을 한 번만 저장하고 팀 이동이나 재합류 기간은 `player_team_history`에 별도 행으로 저장합니다. 생일과 데뷔일은 관리 범위에서 제외했습니다. 포지션 변경 사례는 이 과제에서 대표 공식 포지션 하나로 단순화합니다. 현재 소속은 별도 참/거짓 컬럼 없이 `left_date IS NULL`로 판단합니다.

대회는 2020년부터 2026년 7월 19일까지 종료된 공식 LCK 최상위 국내 대회를 기록합니다. World Championship, MSI, KeSPA Cup, LCK Challengers League와 친선 행사는 포함하지 않습니다. 2026년 정규 시즌은 기준일에 진행 중이므로 아직 대회 및 우승 데이터에 넣지 않았습니다.

2025년부터 사용된 연중 단일 LCK Season은 기존 SPRING 또는 SUMMER로 임의 분류하지 않고 `OTHER`로 저장합니다. 2026 LCK Cup처럼 종료되어 우승팀이 확정된 대회만 우승 이력을 저장합니다.

### 데이터 처리 기준

데이터 기준일은 **2026-07-19**입니다. 2026년 로스터와 진행 상황은 기준일 뒤 변경될 수 있습니다.

- 과거 DAMWON Gaming과 DWG KIA 기록은 같은 팀 계보인 현재의 `Dplus KIA`로 통합합니다.
- 지정된 다른 팀도 같은 팀 계보의 과거 명칭을 현재 대표 팀명으로 통합합니다.
- 서로 다른 법인이나 별도 팀은 임의로 합치지 않습니다.
- 소속 기간은 공식 로스터 등록 또는 발표 시점을 우선합니다.
- 선수 실제 이름은 공식 로스터에서 쓰는 로마자 표기로 저장합니다.
- 생년월일과 데뷔일은 player 테이블에서 관리하지 않습니다.
- 날짜가 명확하지 않은 소속 정보는 임의의 날짜를 생성하지 않는 방향을 우선합니다.

## 5개 테이블과 관계

| 테이블 | 역할 |
|---|---|
| `team` | 10개 LCK 팀의 현재 대표 이름, 약어, 상태 |
| `player` | 중복되지 않는 선수의 소환사명, 실제 이름, 대표 포지션 |
| `player_team_history` | 선수와 팀을 연결하는 소속 기간 |
| `tournament` | 종료된 공식 LCK 국내 최상위 대회 |
| `championship` | 종료된 대회의 우승팀 |

관계는 다음과 같습니다.

```text
team       1 ─── N player_team_history N ─── 1 player
team       1 ─── N championship
tournament 1 ─── 0..1 championship
```

대회 하나에는 우승 행이 없거나 하나만 존재합니다. 우승이 확정되지 않았거나 관리 대상 밖의 예외가 생길 수 있으므로 모든 대회에 championship 행을 강제하지 않습니다.

## 프로젝트 구조

```text
.
├── Makefile
├── README.md
├── sql/
│   ├── 01_schema.sql
│   ├── 02_seed.sql
│   ├── 03_queries.sql
│   └── 04_bonus.sql
├── scripts/
│   ├── install_postgresql.sh
│   ├── start_db.sh
│   ├── stop_db.sh
│   ├── reset_db.sh
│   ├── setup_db.sh
│   ├── run_all.sh
│   ├── export_logs.sh
│   └── uninstall.sh
└── results/
```

실행 과정에서 `.pg_env`, `.postgres_data/`, `.downloads/`가 자동 생성되며 Git에는 포함되지 않습니다.

## 설치와 실행

### 1. Postgres.app 설치

```bash
make install
```

이 명령은 기본값인 Postgres.app 2.9.5와 PostgreSQL 16 조합을 `~/Applications`에 설치하고 프로젝트용 `.pg_env`를 생성합니다. 이 단계에서는 서버, PGDATA, 데이터베이스를 아직 만들지 않습니다. 같은 조합이 이미 설치돼 있으면 다시 다운로드하지 않습니다.

Postgres.app 버전과 PostgreSQL 메이저 버전은 서로 독립적으로 지정할 수 있습니다.

```bash
make install POSTGRES_APP_VERSION=2.9.5 POSTGRES_MAJOR=16
```

`POSTGRES_APP_VERSION`은 Postgres.app 배포 버전이고 `POSTGRES_MAJOR`는 앱 안에서 사용할 PostgreSQL 메이저 버전입니다. 둘 중 하나만 전달하면 나머지는 Makefile 기본값을 사용합니다. 요청한 조합이 현재 설치와 다르면 새 DMG의 다운로드와 검증을 먼저 끝낸 후 기존 앱을 교체합니다.

### 2. 서버 시작

```bash
make start
```

처음 실행하면 프로젝트 안에 `.postgres_data`를 초기화합니다. 이어서 `localhost:5433`에서 프로젝트 전용 서버를 실행하고 `b5_1_db`가 없으면 생성합니다. 이미 서버나 DB가 있으면 오류를 내지 않고 기존 상태를 사용합니다.

### 3. 전체 과제 실행

```bash
make all
```

기존 `b5_1_db`를 초기화하고 테이블 생성, 실제 LCK 데이터 입력, 핵심 16개 쿼리, 보너스 8개 쿼리, 환경 요약을 순서대로 실행합니다. 각 실행은 빈 DB에서 시작하고 해당 결과 파일을 덮어쓰므로 반복 결과가 같습니다. `results`에 사용자가 별도로 만든 파일은 삭제하지 않습니다.

## Make 명령어

| 명령 | 설명 |
|---|---|
| `make install` | Postgres.app 설치 및 `.pg_env` 생성 |
| `make start` | 서버 시작 및 DB가 없으면 생성 |
| `make stop` | 데이터를 보존하고 서버만 종료 |
| `make reset` | 기존 DB를 삭제하고 빈 `b5_1_db` 재생성 |
| `make setup` | reset 후 스키마와 초기 데이터만 입력 |
| `make all` | reset부터 모든 SQL과 로그 출력까지 실행 |
| `make logs` | 버전, 테이블, 인덱스를 환경 요약 파일로 저장 |
| `make psql` | 대화형 PostgreSQL 터미널 접속 |
| `make uninstall` | 프로젝트 DB 환경과 Postgres.app 완전 제거 |

`reset`은 빈 DB까지만 만들고, `setup`은 테이블과 초기 데이터까지만 만듭니다. 조회 결과까지 필요할 때는 `all`을 사용합니다.

## 접속 정보

터미널에서는 다음 명령으로 접속합니다.

```bash
make psql
```

접속 정보는 다음과 같습니다.

```text
Host: localhost
Port: 5433
Database: b5_1_db
User: 현재 macOS 사용자명
Password: 없음
```

VS Code PostgreSQL Extension에는 다음 값을 입력합니다.

```text
Host: localhost
Port: 5433
Database: b5_1_db
User: 현재 macOS 사용자명
Password: 비워 둠
SSL: 사용하지 않음
```

## 조회 결과와 변경 실습

핵심 쿼리 결과, 보너스 결과와 환경 요약은 `results/*.txt`에 저장됩니다. `results/export_summary.txt`에는 PostgreSQL 버전, 생성된 테이블과 인덱스 목록이 들어갑니다. 결과 파일에는 간단한 제목과 실행 결과만 있으며 SQL 원문은 들어가지 않습니다.

`02_seed.sql`에는 실제 데이터와 구분되는 Faker의 2099년 종료된 소속 이력 한 건이 UPDATE/DELETE 연습용으로 들어 있습니다. `03_queries.sql`은 그 행만 UPDATE한 뒤 결과를 확인하고 DELETE합니다. 실제 로스터는 바꾸지 않습니다. `make all`을 다시 실행하면 DB가 먼저 초기화되므로 같은 실습을 같은 결과로 반복할 수 있습니다.

## 보너스 실습

`04_bonus.sql`은 공식 보너스 3개만 PART 1~3으로 구분해 실행합니다.

- **PART 1:** 우승 이력이 없는 팀을 `LEFT JOIN`과 `NOT EXISTS`로 각각 조회하고 차이를 비교합니다.
- **PART 2:** 존재하지 않는 `player_id`로 FK 오류를 발생시키고 원인, 해결 방법, 저장 차단을 확인합니다.
- **PART 3:** 팀별 우승 TOP 3, 선수별 우승 TOP 5, 여러 팀 소속 선수를 핵심 지표로 정의합니다.

공식 보너스 결과는 `results/bonus_01_*.txt`, `bonus_02_*.txt`, `bonus_03_*.txt`에서 확인할 수 있습니다. 선수별 우승 횟수는 대회 종료일에 우승팀 소속 기간이 겹치는 선수를 기준으로 계산합니다.

## 전체 재설치 시연

```bash
make uninstall
make install
make all
```

> `make uninstall`은 `~/Applications/Postgres.app`도 삭제합니다.  
> 다른 프로젝트에서 동일한 Postgres.app을 사용 중이라면 실행에 주의하세요.

`make uninstall`은 `.postgres_data`, `.pg_env`, `.downloads`와 Postgres.app을 삭제하지만 SQL, 결과 파일, README, Makefile과 스크립트는 보존합니다.
