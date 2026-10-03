#!/usr/bin/env bash
set -euo pipefail

# 이 스크립트는 학습 환경이 올바르게 만들어졌는지 확인할 요약 정보를 내보낸다.
# SQL 원문은 숨기고 PostgreSQL 버전, public 테이블, 인덱스 실행 결과만 저장한다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [[ ! -f "$PROJECT_ROOT/.pg_env" ]]; then
  echo "[ERROR] .pg_env not found. Run: make install"
  exit 1
fi
source "$PROJECT_ROOT/.pg_env"

mkdir -p "$PROJECT_ROOT/results"

echo "[1/1] 환경 요약을 results/export_summary.txt에 저장합니다."
{
  echo "LCK PostgreSQL 환경 요약"
  echo
  echo "[PostgreSQL 버전]"
  "$POSTGRES_BIN/psql" -X -q -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    -c "SELECT version();"
  echo
  echo "[생성된 테이블]"
  "$POSTGRES_BIN/psql" -X -q -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    -c "\\dt"
  echo
  echo "[생성된 인덱스]"
  "$POSTGRES_BIN/psql" -X -q -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    -c "SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' ORDER BY tablename, indexname;"
} > "$PROJECT_ROOT/results/export_summary.txt"

echo "[DONE] 환경 요약 로그를 저장했습니다."
