#!/usr/bin/env bash
set -euo pipefail

# 이 스크립트는 과제 전체 과정을 처음부터 같은 순서로 실행한다.
# reset부터 시작하므로 여러 번 실행해도 같은 초기 데이터와 같은 조회 결과를 만든다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

echo "[1/5] 데이터베이스, 스키마, 초기 데이터를 다시 준비합니다."
"$PROJECT_ROOT/scripts/setup_db.sh"
source "$PROJECT_ROOT/.pg_env"

# 각 SQL 파일은 \o 명령으로 자신이 담당하는 결과 파일을 덮어쓴다.
# results의 사용자 파일은 삭제하지 않고 이번 실행 대상 파일만 새 내용으로 교체한다.
mkdir -p "$PROJECT_ROOT/results"

echo "[2/5] 핵심 조회 및 UPDATE/DELETE 실습을 실행합니다."
"$POSTGRES_BIN/psql" \
  -X \
  -v ON_ERROR_STOP=1 \
  -v results_dir="$PROJECT_ROOT/results" \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  -d "$PGDATABASE" \
  -f "$PROJECT_ROOT/sql/03_queries.sql"

echo "[3/5] 보너스 조회를 실행합니다."
"$POSTGRES_BIN/psql" \
  -X \
  -v ON_ERROR_STOP=1 \
  -v results_dir="$PROJECT_ROOT/results" \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  -d "$PGDATABASE" \
  -f "$PROJECT_ROOT/sql/04_bonus.sql"

echo "[4/5] PostgreSQL 환경 요약 로그를 생성합니다."
"$PROJECT_ROOT/scripts/export_logs.sh"

echo "[5/5] 생성된 테이블 수를 확인합니다."
TABLE_COUNT="$("$POSTGRES_BIN/psql" \
  -X \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  -d "$PGDATABASE" \
  -tAc "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';")"

if [[ "$TABLE_COUNT" != "5" ]]; then
  echo "[ERROR] public 스키마에 테이블이 5개가 아니라 ${TABLE_COUNT}개 있습니다."
  exit 1
fi

echo "[DONE] 전체 SQL 실행과 결과 저장이 완료되었습니다."
