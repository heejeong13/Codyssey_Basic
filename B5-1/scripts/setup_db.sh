#!/usr/bin/env bash
set -euo pipefail

# 이 스크립트는 DB를 초기화하고 테이블과 초기 데이터까지만 준비한다.
# 조회 및 변경 연습인 03_queries.sql과 04_bonus.sql은 실행하지 않는다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

echo "[1/3] 빈 데이터베이스를 준비합니다."
"$PROJECT_ROOT/scripts/reset_db.sh"
source "$PROJECT_ROOT/.pg_env"

echo "[2/3] 5개 테이블과 제약조건, 인덱스를 생성합니다."
# ON_ERROR_STOP은 SQL 오류가 발생했는데도 다음 파일을 계속 실행하는 일을 막는다.
"$POSTGRES_BIN/psql" \
  -X \
  -v ON_ERROR_STOP=1 \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  -d "$PGDATABASE" \
  -f "$PROJECT_ROOT/sql/01_schema.sql"

echo "[3/3] 실제 LCK 초기 데이터와 실습용 임시 이력을 입력합니다."
"$POSTGRES_BIN/psql" \
  -X \
  -v ON_ERROR_STOP=1 \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  -d "$PGDATABASE" \
  -f "$PROJECT_ROOT/sql/02_seed.sql"

echo "[DONE] 스키마와 초기 데이터가 준비되었습니다."
