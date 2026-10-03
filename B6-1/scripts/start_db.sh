#!/usr/bin/env bash
set -euo pipefail

# 이 스크립트는 프로젝트 전용 PostgreSQL 서버를 시작한다.
# 처음 실행하면 .postgres_data를 초기화하고, localhost:5433에서 서버를 연다.
# 마지막으로 b5_1_db가 없을 때만 생성해 반복 실행해도 기존 데이터를 보존한다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

echo "[1/4] PostgreSQL 접속 환경과 설치를 확인합니다."
if [[ ! -f "$PROJECT_ROOT/.pg_env" ]]; then
  echo "[ERROR] .pg_env not found. Run: make install"
  exit 1
fi
source "$PROJECT_ROOT/.pg_env"

if [[ ! -x "$POSTGRES_BIN/pg_ctl" ]]; then
  echo "[ERROR] PostgreSQL 16 명령어를 찾을 수 없습니다."
  echo "Run: make install"
  exit 1
fi

echo "[2/4] 데이터 저장 폴더를 확인합니다."
if [[ ! -f "$PGDATA/PG_VERSION" ]]; then
  # initdb는 테이블 데이터와 서버 설정이 저장될 새 PostgreSQL 클러스터를 만든다.
  # --auth=trust는 이 컴퓨터의 학습용 서버에서 비밀번호 없이 접속하게 한다.
  mkdir -p "$PGDATA"
  "$POSTGRES_BIN/initdb" \
    -D "$PGDATA" \
    --username="$PGUSER" \
    --auth=trust \
    --encoding=UTF8 \
    --locale=C
else
  echo "[INFO] 기존 .postgres_data를 사용합니다."
fi

echo "[3/4] localhost:${PGPORT}에서 PostgreSQL 서버를 시작합니다."
if "$POSTGRES_BIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
  echo "[INFO] PostgreSQL 서버가 이미 실행 중입니다."
else
  # 다른 프로그램이 같은 TCP 포트를 사용하면 PostgreSQL을 시작할 수 없으므로 먼저 확인한다.
  if lsof -nP -iTCP:"$PGPORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "[ERROR] TCP 포트 ${PGPORT}를 다른 프로그램이 사용 중입니다."
    echo "해당 프로그램을 종료한 뒤 다시 실행하세요: make start"
    exit 1
  fi

  # -D는 데이터 폴더, -l은 서버 로그, -o는 서버에 전달하는 접속 옵션이다.
  # -h localhost를 사용하므로 클라이언트는 Unix socket이 아닌 TCP로 접속한다.
  "$POSTGRES_BIN/pg_ctl" \
    -D "$PGDATA" \
    -l "$PGDATA/server.log" \
    -o "-h localhost -p $PGPORT" \
    -w \
    start
fi

# pg_isready가 실패하면 프로세스는 있어도 TCP 접속을 받을 준비가 되지 않은 상태다.
if ! "$POSTGRES_BIN/pg_isready" \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" >/dev/null; then
  echo "[ERROR] localhost:${PGPORT}에서 PostgreSQL에 접속할 수 없습니다."
  echo "서버 로그를 확인하세요: $PGDATA/server.log"
  exit 1
fi

echo "[4/4] $PGDATABASE 데이터베이스를 확인합니다."
# 관리용 postgres DB에서 이름이 정확히 일치하는 DB가 있는지 숫자로 조회한다.
if [[ "$("$POSTGRES_BIN/psql" \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  -d postgres \
  -tAc "SELECT 1 FROM pg_database WHERE datname = '$PGDATABASE';")" != "1" ]]; then
  "$POSTGRES_BIN/createdb" \
    -h "$PGHOST" \
    -p "$PGPORT" \
    -U "$PGUSER" \
    "$PGDATABASE"
else
  echo "[INFO] $PGDATABASE 데이터베이스가 이미 존재합니다."
fi

echo "[DONE] PostgreSQL 서버를 사용할 수 있습니다."
