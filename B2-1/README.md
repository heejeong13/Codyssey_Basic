# 나만의 용돈기입장

파일 기반으로 거래 내역을 관리하는 Python 콘솔 가계부입니다. 거래 추가·조회·검색·수정·삭제뿐 아니라 월별 요약, 예산, 카테고리, CSV 가져오기와 내보내기를 지원합니다.

데이터는 프로그램을 종료해도 유지되며, 거래 목록과 검색은 전체 거래 파일을 한 번에 메모리에 올리지 않고 제너레이터로 처리합니다.

## 개발 환경

- Python 3.10 이상
- Python 표준 라이브러리만 사용
- 외부 패키지 설치 불필요

## 실행 방법

프로젝트 최상위 폴더에서 다음 형식으로 실행합니다.

```bash
python -m budget_app <command> [options]
```

전체 도움말은 다음과 같이 확인합니다.

```bash
python -m budget_app --help
```

각 명령에도 `--help`를 사용할 수 있습니다.

```bash
python -m budget_app add --help
python -m budget_app search --help
python -m budget_app budget set --help
python -m budget_app category remove --help
```

모든 옵션 이름은 리눅스 명령행 표준에 맞춰 `--`로 시작합니다.

## 저장 위치와 형식

기본 데이터 폴더는 프로젝트 실행 위치의 `./data`입니다. 다른 위치를 사용하려면 전역 `--data-dir` 옵션을 지정합니다.

```bash
python -m budget_app --data-dir ./my_data list
```

데이터는 다음 세 개의 JSONL 파일에 나누어 영구 저장됩니다.

| 파일 | 내용 |
| --- | --- |
| `data/transactions.jsonl` | 거래 내역 |
| `data/categories.jsonl` | 카테고리 목록 |
| `data/budgets.jsonl` | 월별 예산 |

JSONL은 한 줄에 하나의 JSON 객체를 저장하는 형식입니다. 데이터 폴더나 파일이 없으면 최초 실행 시 자동으로 생성합니다. 카테고리 파일이 비어 있으면 기본 카테고리를 자동 등록합니다.

기본 카테고리는 다음과 같습니다.

- `food`
- `transport`
- `rent`
- `salary`
- `etc`

## 거래 데이터 모델

거래 내역은 다음 필드로 구성됩니다.

| 필드 | 필수 | 설명 |
| --- | --- | --- |
| `id` | Y | 자동 생성되는 고유 ID |
| `type` | Y | `income` 또는 `expense` |
| `date` | Y | `YYYY-MM-DD` 형식의 날짜 |
| `amount` | Y | 0보다 큰 정수 금액 |
| `category` | Y | 등록된 카테고리 |
| `memo` | N | 거래 메모 |
| `tags` | N | 거래 태그 목록 |

날짜 형식 오류, 0 이하의 금액, 허용되지 않은 거래 타입, 존재하지 않는 카테고리는 저장하지 않습니다. 대화형 입력에서는 오류 이유를 안내한 후 다시 입력받습니다.

## 주요 명령

### 1. 거래 추가: `add`

날짜, 타입, 카테고리, 금액, 메모, 태그를 대화형으로 입력합니다. 태그가 여러 개라면 쉼표로 구분합니다. 저장에 성공하면 생성된 거래 ID를 출력합니다.

```bash
python -m budget_app add
```

입력 예시:

```text
날짜(YYYY-MM-DD): 2026-09-25
타입(income/expense): expense
카테고리: food
금액: 12000
메모(선택): 점심
태그(선택, 쉼표 구분): 식사,회사
```

등록되지 않은 카테고리는 사용할 수 없습니다. 먼저 `category add`로 카테고리를 추가해야 합니다.

### 2. 거래 목록: `list`

거래를 최신순으로 출력합니다. 기본 출력 건수는 20건이며 `--limit`으로 변경할 수 있습니다.

```bash
python -m budget_app list
python -m budget_app list --limit 10
```

거래 파일은 제너레이터로 스트리밍하여 처리합니다.

### 3. 거래 검색: `search`

기간, 카테고리, 타입, 메모 키워드, 태그로 거래를 검색합니다. 여러 조건을 함께 지정하면 모든 조건을 만족하는 거래만 최신순으로 출력합니다.

```bash
python -m budget_app search --from 2026-09-01 --to 2026-09-30
python -m budget_app search --category food --type expense
python -m budget_app search --q 점심 --tag 회사
```

지원 옵션:

| 옵션 | 설명 |
| --- | --- |
| `--from YYYY-MM-DD` | 검색 시작일 |
| `--to YYYY-MM-DD` | 검색 종료일 |
| `--category NAME` | 카테고리 |
| `--type TYPE` | `income` 또는 `expense` |
| `--q KEYWORD` | 메모에 포함된 키워드 |
| `--tag TAG` | 태그 |

검색도 거래 파일 전체를 한 번에 불러오지 않고 제너레이터로 처리합니다.

### 4. 월별 요약: `summary`

지정한 달의 총수입, 총지출, 잔액과 카테고리별 지출 합계 상위 N개를 출력합니다.

```bash
python -m budget_app summary --month 2026-09
python -m budget_app summary --month 2026-09 --top 3
```

해당 월에 거래가 없으면 `데이터 없음`을 출력합니다. 월 예산이 등록되어 있으면 지출 기준 예산 사용률을 함께 보여주며, 지출이 예산보다 크면 초과 경고를 출력합니다.

### 5. 예산 설정 및 조회: `budget`

월별 예산을 설정하거나 조회합니다. 금액은 0보다 큰 정수여야 합니다. 같은 달의 예산을 다시 설정하면 기존 값을 변경합니다.

```bash
python -m budget_app budget set --month 2026-09 --amount 500000
python -m budget_app budget get --month 2026-09
```

설정한 예산은 `summary` 결과의 사용률 및 초과 여부 계산에 사용됩니다.

### 6. 카테고리 관리: `category`

카테고리를 추가하고, 목록을 조회하고, 삭제합니다. 추가와 삭제는 기본 입력 원칙에 따라 대화형으로 처리합니다.

```bash
python -m budget_app category add
python -m budget_app category list
python -m budget_app category remove
```

`category add`는 추가할 카테고리 이름을, `category remove`는 삭제할 카테고리 이름을 실행 후 입력받습니다.

이미 존재하는 카테고리는 중복 추가할 수 없습니다. 거래에서 사용 중인 카테고리는 삭제할 수 없으며, 관련 거래를 먼저 수정하거나 삭제해야 합니다.

### 7. 거래 수정: `update`

이 프로젝트의 거래 수정 방식은 **옵션 방식**으로 고정합니다. 거래 ID와 변경할 필드만 지정합니다.

```bash
python -m budget_app update --id <거래-ID> --amount 15000
python -m budget_app update --id <거래-ID> --category transport --memo 택시
python -m budget_app update --id <거래-ID> --tags 야근,교통
```

지원 옵션:

| 옵션 | 설명 |
| --- | --- |
| `--id ID` | 수정할 거래 ID, 필수 |
| `--date YYYY-MM-DD` | 변경할 날짜 |
| `--type TYPE` | 변경할 거래 타입 |
| `--category NAME` | 변경할 카테고리 |
| `--amount AMOUNT` | 변경할 금액 |
| `--memo TEXT` | 변경할 메모 |
| `--tags TAGS` | 쉼표로 구분한 태그 |

존재하지 않는 ID를 입력하면 거래가 없다는 메시지와 해결 방법을 출력합니다. 수정 시 거래 파일은 전체 재작성 방식으로 반영합니다.

### 8. 거래 삭제: `delete`

ID로 거래 한 건을 삭제합니다.

```bash
python -m budget_app delete --id <거래-ID>
```

존재하지 않는 ID는 오류 메시지로 안내합니다. 삭제 시 거래 파일은 전체 재작성 방식으로 반영합니다.

### 9. CSV 가져오기 및 내보내기: `import`, `export`

CSV 파일의 거래를 일괄 등록합니다.

```bash
python -m budget_app import --from ./transactions.csv
```

가져온 거래에는 새로운 고유 ID를 생성합니다. 모든 행을 먼저 검증하며, 잘못된 행이 하나라도 있으면 일부 데이터만 저장하지 않고 전체 가져오기를 취소합니다. 완료 시 처리 건수를 출력합니다.

조건에 맞는 거래를 CSV 파일로 내보냅니다.

```bash
python -m budget_app export --out ./september.csv --month 2026-09
python -m budget_app export --out ./period.csv --from 2026-09-01 --to 2026-09-30
```

`export`에는 `--month` 또는 날짜 범위 조건을 반드시 지정해야 합니다. 날짜 범위는 `--from`과 `--to`를 함께 사용합니다. 완료 시 내보낸 거래 건수와 생성된 파일 경로를 출력합니다.

#### CSV 스키마

CSV 파일은 UTF-8 인코딩과 헤더를 사용하며 열 이름은 다음과 같이 고정합니다.

| 열 | 필수 | 설명 |
| --- | --- | --- |
| `date` | Y | `YYYY-MM-DD` |
| `type` | Y | `income` 또는 `expense` |
| `category` | Y | 등록된 카테고리 |
| `amount` | Y | 0보다 큰 정수 |
| `memo` | N | 문자열 |
| `tags` | N | 쉼표로 구분한 문자열 |

예시:

```csv
date,type,category,amount,memo,tags
2026-09-25,expense,food,12000,점심,"식사,회사"
2026-09-25,income,salary,2500000,9월 급여,급여
```

## 오류 처리와 종료 코드

사용자 입력이나 파일에 문제가 있으면 Python 스택 트레이스를 노출하지 않고 다음 내용을 출력합니다.

- 오류가 발생한 원인
- 사용자가 문제를 해결할 수 있는 힌트

정상적으로 처리되면 종료 코드 `0`, 오류가 발생하면 `0`이 아닌 종료 코드를 반환합니다.

## 프로그램 구조

프로그램은 책임에 따라 여러 모듈로 분리합니다.

| 영역 | 책임 |
| --- | --- |
| CLI | 명령과 옵션 해석, 대화형 입력, 결과 출력 |
| 모델 | `dataclass` 기반 데이터 구조 정의 |
| 저장소 | JSONL 파일 생성·조회·저장·재작성 |
| 서비스 | 입력 검증과 거래·예산·카테고리 업무 규칙 |
| 포맷터 | 사용자에게 보여 줄 출력 구성 |
| 데코레이터 | 공통 예외 처리 또는 실행 로그 분리 |

함수와 데이터 구조에는 타입 힌트를 적용합니다. 공통 예외 처리나 실행 기록 같은 반복 로직은 데코레이터로 분리해 실제 명령 처리에 적용합니다.

실제 파일 구성은 다음과 같습니다.

```text
budget_app/
├── __main__.py       # python -m budget_app 실행 진입점
├── cli.py            # 명령어·옵션·대화형 입력·결과 출력
├── decorators.py     # 공통 예외 처리 데코레이터
├── errors.py         # 사용자에게 안내할 오류 정의
├── formatters.py     # 콘솔 출력 문자열 구성
├── models.py         # dataclass 데이터 모델
├── repositories.py   # JSONL 파일 생성·조회·저장·재작성
└── services.py       # 검증과 업무 규칙
tests/                # 단위 테스트와 CLI 통합 테스트
```

## 테스트

표준 라이브러리 `unittest`로 전체 테스트를 실행합니다.

```bash
python -m unittest discover -v
```

## 구현 범위

이 프로젝트는 과제의 필수 기능만 구현합니다. 다음 보너스 기능은 구현 범위에 포함하지 않습니다.

- 백업 기능
- 반복 내역 자동 생성
- 별도의 콘솔 테이블 정렬 기능
- 임시 파일과 `rename`을 이용한 원자적 교체
