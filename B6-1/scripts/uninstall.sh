#!/usr/bin/env bash
set -euo pipefail

# 이 스크립트는 설치부터 다시 시연할 수 있도록 프로젝트 DB 환경을 완전히 제거한다.
# sql, results, README, Makefile, scripts는 과제 소스이므로 삭제하지 않는다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

echo "[WARNING] 다음 항목을 삭제합니다."
echo "  $PROJECT_ROOT/.postgres_data"
echo "  $PROJECT_ROOT/.pg_env"
echo "  $PROJECT_ROOT/.downloads"
echo "  $HOME/Applications/Postgres.app"

# 환경 파일과 pg_ctl이 남아 있을 때만 프로젝트 서버 종료를 시도한다.
if [[ -f "$PROJECT_ROOT/.pg_env" ]]; then
  source "$PROJECT_ROOT/.pg_env"
  if [[ -x "$POSTGRES_BIN/pg_ctl" ]] \
    && [[ -f "$PGDATA/PG_VERSION" ]] \
    && "$POSTGRES_BIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
    echo "[1/2] 삭제 전에 프로젝트 전용 PostgreSQL 서버를 종료합니다."
    "$POSTGRES_BIN/pg_ctl" -D "$PGDATA" -m fast -w stop
  else
    echo "[INFO] 실행 중인 프로젝트 서버가 없습니다."
  fi
fi

echo "[2/2] 설치 파일과 프로젝트 데이터 파일을 삭제합니다."
# 대상은 위에서 계산한 네 개의 명확한 경로로 제한한다.
rm -rf \
  "$PROJECT_ROOT/.postgres_data" \
  "$PROJECT_ROOT/.downloads" \
  "$HOME/Applications/Postgres.app"
rm -f "$PROJECT_ROOT/.pg_env"

echo "[DONE] PostgreSQL 과제 환경을 제거했습니다."
