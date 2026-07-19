# 이 Makefile은 긴 스크립트 경로를 외우지 않고 프로젝트를 실행하도록 돕는다.
# 각 명령은 scripts 폴더의 한 가지 역할만 실행하므로 흐름을 따라가기 쉽다.

# target 이름과 같은 파일이 생겨도 명령이 항상 실행되도록 가상 target으로 선언한다.
.PHONY: help install start stop reset setup all logs psql uninstall

# 값을 따로 전달하지 않았을 때 사용할 Postgres.app과 PostgreSQL 기본 버전이다.
# 명령 뒤에 POSTGRES_APP_VERSION 또는 POSTGRES_MAJOR를 적으면 필요한 값만 바꿀 수 있다.
POSTGRES_APP_VERSION ?= 2.9.5
POSTGRES_MAJOR ?= 16

# make만 입력했을 때 실행할 기본 도움말이다.
help:
	@echo "LCK PostgreSQL 과제 명령어"
	@echo "  make install   - Install Postgres.app 2.9.5 with PostgreSQL 16"
	@echo "  make install POSTGRES_APP_VERSION=2.9.5 POSTGRES_MAJOR=16"
	@echo "  make start     - Start PostgreSQL and create b5_1_db if needed"
	@echo "  make stop      - Stop PostgreSQL without deleting data"
	@echo "  make reset     - Drop and recreate an empty b5_1_db"
	@echo "  make setup     - Reset DB, then create schema and seed data"
	@echo "  make all       - Reset DB and run every SQL file and log export"
	@echo "  make logs      - Export PostgreSQL, table, and index information"
	@echo "  make psql      - Open an interactive b5_1_db terminal"
	@echo "  make uninstall - Remove project DB data and Postgres.app"

# 기본값은 Postgres.app 2.9.5와 PostgreSQL 16이다.
# 두 Make 변수를 함께 또는 하나씩 전달해 다운로드할 조합을 선택할 수 있다.
# 설치만 수행하며 PostgreSQL 서버나 데이터베이스는 아직 만들지 않는다.
install:
	@POSTGRES_APP_VERSION="$(POSTGRES_APP_VERSION)" \
	POSTGRES_MAJOR="$(POSTGRES_MAJOR)" \
	./scripts/install_postgresql.sh

# 프로젝트 전용 데이터 폴더를 준비하고 localhost:5433 서버를 시작한다.
start:
	@./scripts/start_db.sh

# 서버만 종료하고 .postgres_data의 실제 데이터는 보존한다.
stop:
	@./scripts/stop_db.sh

# 서버를 시작한 뒤 기존 DB를 삭제하고 빈 b5_1_db를 다시 만든다.
reset:
	@./scripts/reset_db.sh

# 빈 DB에 테이블과 초기 데이터만 입력한다. 조회 실습은 실행하지 않는다.
setup:
	@./scripts/setup_db.sh

# 매번 DB를 초기화하고 스키마, 데이터, 필수/보너스 쿼리를 모두 실행한다.
all:
	@./scripts/run_all.sh

# 현재 서버 버전, 테이블, 인덱스를 results/export_summary.txt에 기록한다.
logs:
	@./scripts/export_logs.sh

# .pg_env의 TCP 접속 정보로 대화형 psql을 연다.
psql:
	@PROJECT_ROOT="$$(pwd -P)"; \
	if [ ! -f "$$PROJECT_ROOT/.pg_env" ]; then \
		echo "[ERROR] .pg_env not found. Run: make install"; exit 1; \
	fi; \
	. "$$PROJECT_ROOT/.pg_env"; \
	"$$POSTGRES_BIN/psql" -h "$$PGHOST" -p "$$PGPORT" -U "$$PGUSER" -d "$$PGDATABASE"

# 서버를 멈춘 뒤 프로젝트 DB 파일과 ~/Applications/Postgres.app을 제거한다.
uninstall:
	@./scripts/uninstall.sh
