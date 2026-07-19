#!/usr/bin/env bash
set -euo pipefail

# 이 스크립트는 선택한 PostgreSQL이 포함된 Postgres.app을 설치하고 .pg_env를 만든다.
# 값을 지정하지 않으면 Postgres.app 2.9.5와 PostgreSQL 16을 기본으로 사용한다.
# 두 값은 POSTGRES_APP_VERSION과 POSTGRES_MAJOR로 서로 독립적으로 바꿀 수 있다.
# 서버 시작과 데이터베이스 생성은 하지 않으며, 그 작업은 make start가 담당한다.
# DMG를 마운트했다면 성공과 실패에 관계없이 trap으로 반드시 해제한다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
POSTGRES_APP="$HOME/Applications/Postgres.app"
MOUNT_POINT=""
POSTGRES_APP_VERSION="${POSTGRES_APP_VERSION:-2.9.5}"
POSTGRES_MAJOR="${POSTGRES_MAJOR:-16}"

# 중간에 오류가 나도 마운트된 설치 디스크가 Finder에 남지 않게 정리한다.
unmount_dmg() {
  if [[ -n "$MOUNT_POINT" ]] && mount | grep -Fq "on $MOUNT_POINT "; then
    hdiutil detach "$MOUNT_POINT" >/dev/null
  fi
}
trap unmount_dmg EXIT

echo "[1/6] 다운로드 폴더를 준비합니다."
# 설치 파일은 프로젝트 안에 보관해 uninstall 때 함께 정리할 수 있게 한다.
mkdir -p "$PROJECT_ROOT/.downloads"

echo "[2/6] 설치할 Postgres.app과 PostgreSQL 버전을 확인합니다."
# 두 값은 다운로드 URL과 파일 경로에 들어가므로 안전한 숫자 형식만 허용한다.
if [[ ! "$POSTGRES_APP_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "[ERROR] Postgres.app 버전 형식이 올바르지 않습니다: $POSTGRES_APP_VERSION"
  echo "Example: make install POSTGRES_APP_VERSION=2.9.5 POSTGRES_MAJOR=16"
  exit 1
fi

if [[ ! "$POSTGRES_MAJOR" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] PostgreSQL 메이저 버전은 숫자여야 합니다: $POSTGRES_MAJOR"
  echo "Example: make install POSTGRES_APP_VERSION=2.9.5 POSTGRES_MAJOR=16"
  exit 1
fi

DOWNLOAD_URL="https://github.com/PostgresApp/PostgresApp/releases/download/v${POSTGRES_APP_VERSION}/Postgres-${POSTGRES_APP_VERSION}-${POSTGRES_MAJOR}.dmg"
echo "[INFO] Postgres.app ${POSTGRES_APP_VERSION}, PostgreSQL ${POSTGRES_MAJOR} 조합을 사용합니다."

echo "[3/6] 현재 Postgres.app 설치를 확인합니다."
INSTALLED_VERSION=""
if [[ -f "$POSTGRES_APP/Contents/Info.plist" ]]; then
  # 앱의 Info.plist에서 Postgres.app 자체 버전을 읽어 요청 버전과 비교한다.
  INSTALLED_VERSION="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "$POSTGRES_APP/Contents/Info.plist" 2>/dev/null || true)"
fi

if [[ "$INSTALLED_VERSION" == "$POSTGRES_APP_VERSION" ]] \
  && [[ -x "$POSTGRES_APP/Contents/Versions/$POSTGRES_MAJOR/bin/postgres" ]]; then
  echo "[INFO] Postgres.app ${INSTALLED_VERSION}와 PostgreSQL ${POSTGRES_MAJOR} 버전이 이미 설치되어 있습니다."
  echo "[4/6] 같은 버전이므로 다운로드를 생략합니다."
  echo "[5/6] 같은 버전이므로 앱 교체를 생략합니다."
else
  echo "[4/6] Postgres.app ${POSTGRES_APP_VERSION}, PostgreSQL ${POSTGRES_MAJOR} 조합을 다운로드합니다."
  # 완료 전에는 .part 확장자를 사용해 중단된 파일을 정상 DMG로 오인하지 않게 한다.
  rm -f "$PROJECT_ROOT/.downloads/Postgres-${POSTGRES_APP_VERSION}-${POSTGRES_MAJOR}.dmg.part"
  if ! curl \
    --fail \
    --location \
    --output "$PROJECT_ROOT/.downloads/Postgres-${POSTGRES_APP_VERSION}-${POSTGRES_MAJOR}.dmg.part" \
    "$DOWNLOAD_URL"; then
    echo "[ERROR] 요청한 Postgres.app과 PostgreSQL 버전 조합을 찾거나 다운로드하지 못했습니다."
    echo "Run: make install"
    exit 1
  fi

  mv \
    "$PROJECT_ROOT/.downloads/Postgres-${POSTGRES_APP_VERSION}-${POSTGRES_MAJOR}.dmg.part" \
    "$PROJECT_ROOT/.downloads/Postgres-${POSTGRES_APP_VERSION}-${POSTGRES_MAJOR}.dmg"

  # hdiutil verify는 손상되거나 DMG 형식이 아닌 파일을 설치 전에 걸러낸다.
  if ! hdiutil verify "$PROJECT_ROOT/.downloads/Postgres-${POSTGRES_APP_VERSION}-${POSTGRES_MAJOR}.dmg" >/dev/null; then
    echo "[ERROR] 다운로드한 Postgres.app DMG 검증에 실패했습니다."
    echo "Run: make install"
    exit 1
  fi

  echo "[5/6] 검증된 Postgres.app을 ~/Applications에 설치합니다."
  mkdir -p "$HOME/Applications"

  # -nobrowse는 설치 디스크가 Finder 창으로 자동 열리지 않게 한다.
  MOUNT_POINT="$(hdiutil attach \
    -nobrowse \
    "$PROJECT_ROOT/.downloads/Postgres-${POSTGRES_APP_VERSION}-${POSTGRES_MAJOR}.dmg" \
    | awk '/\/Volumes\// {sub(/^.*\/Volumes\//, "/Volumes/"); print; exit}')"

  if [[ -z "$MOUNT_POINT" ]] \
    || [[ ! -x "$MOUNT_POINT/Postgres.app/Contents/Versions/$POSTGRES_MAJOR/bin/postgres" ]]; then
    echo "[ERROR] DMG에서 PostgreSQL ${POSTGRES_MAJOR}가 포함된 Postgres.app을 찾을 수 없습니다."
    echo "Run: make install"
    exit 1
  fi

  # 다운로드와 DMG 내부 검증을 마친 뒤에만 기존 앱을 제거한다.
  # ditto는 macOS 앱 번들의 권한과 내부 구조를 보존해 복사한다.
  rm -rf "$POSTGRES_APP"
  ditto "$MOUNT_POINT/Postgres.app" "$POSTGRES_APP"
fi

# 설치 결과가 요청한 PostgreSQL 메이저인지 실행 파일 자체의 버전 문자열로 확인한다.
if [[ ! -x "$POSTGRES_APP/Contents/Versions/$POSTGRES_MAJOR/bin/postgres" ]] \
  || [[ "$("$POSTGRES_APP/Contents/Versions/$POSTGRES_MAJOR/bin/postgres" --version)" != *" ${POSTGRES_MAJOR}."* ]]; then
  echo "[ERROR] 설치된 앱에서 PostgreSQL ${POSTGRES_MAJOR} 명령어를 확인하지 못했습니다."
  echo "Run: make install"
  exit 1
fi

echo "[6/6] 프로젝트 접속 설정인 .pg_env 파일을 생성합니다."
# $HOME은 .pg_env를 읽는 시점에 현재 사용자의 홈으로 확장되도록 그대로 기록한다.
cat > "$PROJECT_ROOT/.pg_env" <<EOF
# PostgreSQL 서버에 TCP로 접속할 로컬 주소
PGHOST="localhost"

# macOS의 기본 PostgreSQL 포트와 구분한 프로젝트 전용 포트
PGPORT="5433"

# 과제에서 사용하는 데이터베이스 이름
PGDATABASE="b5_1_db"

# 비밀번호 없이 로컬 서버에 접속할 현재 macOS 사용자 이름
PGUSER="$(whoami)"

# 테이블 데이터와 PostgreSQL 설정 파일이 저장되는 프로젝트 내부 폴더
PGDATA="$PROJECT_ROOT/.postgres_data"

# 선택한 PostgreSQL 메이저 버전의 명령어 경로
POSTGRES_BIN="\$HOME/Applications/Postgres.app/Contents/Versions/$POSTGRES_MAJOR/bin"
EOF

echo "[DONE] Postgres.app ${POSTGRES_APP_VERSION}와 PostgreSQL ${POSTGRES_MAJOR} 설치를 확인했습니다."
echo "[DONE] .pg_env 생성이 완료되었습니다."
echo "Next: make start"
