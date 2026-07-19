#!/usr/bin/env bash
set -euo pipefail

# 이 스크립트는 서버를 준비한 뒤 b5_1_db를 삭제하고 빈 데이터베이스로 다시 만든다.
# 스키마나 초기 데이터 SQL은 실행하지 않으며, 그 작업은 make setup과 make all이 담당한다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

echo "[1/3] PostgreSQL 서버를 준비합니다."
"$PROJECT_ROOT/scripts/start_db.sh"
source "$PROJECT_ROOT/.pg_env"

echo "[2/3] 기존 $PGDATABASE 데이터베이스를 삭제합니다."
# --force는 학습 중 남아 있는 해당 DB 연결을 종료해 reset을 반복 실행할 수 있게 한다.
"$POSTGRES_BIN/dropdb" \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  --if-exists \
  --force \
  "$PGDATABASE"

echo "[3/3] 빈 $PGDATABASE 데이터베이스를 다시 만듭니다."
"$POSTGRES_BIN/createdb" \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  "$PGDATABASE"

echo "[DONE] 빈 $PGDATABASE 데이터베이스가 준비되었습니다."
