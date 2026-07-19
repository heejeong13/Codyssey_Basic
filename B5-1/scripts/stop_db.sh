#!/usr/bin/env bash
set -euo pipefail

# 이 스크립트는 프로젝트 전용 PostgreSQL 서버만 안전하게 종료한다.
# .postgres_data와 데이터베이스는 삭제하지 않으므로 다음 시작 때 그대로 사용할 수 있다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

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

# 초기화된 데이터 폴더가 없으면 이 프로젝트 서버는 만들어진 적이 없으므로 정상 종료로 본다.
if [[ ! -f "$PGDATA/PG_VERSION" ]] || ! "$POSTGRES_BIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
  echo "[INFO] PostgreSQL 서버가 이미 종료되어 있습니다."
  exit 0
fi

echo "[1/1] 프로젝트 전용 PostgreSQL 서버를 종료합니다."
# fast 모드는 연결을 정리하고 진행 중인 트랜잭션을 중단한 뒤 데이터 파일을 안전하게 기록한다.
"$POSTGRES_BIN/pg_ctl" \
  -D "$PGDATA" \
  -m fast \
  -w \
  stop

echo "[DONE] 데이터는 보존하고 서버만 종료했습니다."
