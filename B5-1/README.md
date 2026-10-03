# Mini Redis

Python 내장 `dict`, `set`, `collections`, `heapq` 없이 핵심 자료구조를 직접 구현한 CLI 기반 인메모리 Key-Value 저장소입니다. 네트워크 통신과 영속성은 포함하지 않습니다.

## 실행

Python 3.8 이상에서 외부 패키지 없이 실행할 수 있습니다.

```bash
python3 cli.py
```

```text
mini-redis> SET name "Alice Kim"
OK
mini-redis> GET name
"Alice Kim"
mini-redis> EXPIRE name 10
(integer) 1
mini-redis> TTL name
(integer) 10
mini-redis> quit
```

테스트 실행:

```bash
python3 -m unittest -v
```

## 지원 명령어

| 명령어 | 설명 |
| --- | --- |
| `SET key value` | 문자열 값을 저장하고 LRU를 갱신합니다. 기존 TTL은 제거합니다. |
| `GET key` | 값을 조회하고, 성공한 경우에만 LRU를 갱신합니다. |
| `DEL key` | 데이터와 LRU 및 TTL 정보를 함께 제거합니다. |
| `EXISTS key` | 키 존재 여부를 반환합니다. |
| `DBSIZE` | 만료 키를 정리한 뒤 현재 키 개수를 반환합니다. |
| `KEYS` | 만료 키를 제외한 전체 키를 반환합니다. |
| `CONFIG SET maxmemory bytes` | 바이트 단위 메모리 제한을 설정합니다. `0`은 무제한입니다. |
| `INFO memory` | 사용량, 제한, LRU 제거 횟수를 출력합니다. |
| `EXPIRE key seconds` | 키에 초 단위 TTL을 설정합니다. |
| `TTL key` | 남은 TTL을 반환합니다. |

`exit` 또는 `quit`을 입력하면 CLI가 종료됩니다. 명령어는 대소문자를 구분하지 않으며 큰따옴표로 공백이 있는 값을 입력할 수 있습니다.

## 파일 구조

- `doubly_linked_list.py`: LRU와 해시 버킷에 쓰이는 이중 연결 리스트
- `hash_map.py`: FNV-1a 해시 및 체이닝 방식 해시맵
- `min_heap.py`: TTL 만료 순서를 관리하는 최소 힙
- `mini_redis.py`: 명령 처리와 메모리·LRU·TTL 정책
- `cli.py`: 입력 파싱 및 REPL
- `test_mini_redis.py`: 자료구조와 명령 통합 테스트

## 자료구조 동작 원리

### 체이닝 해시맵

키를 UTF-8 바이트로 바꾼 뒤 FNV-1a 방식으로 직접 해시합니다. 해시값을 버킷 수로 나눈 나머지가 버킷 인덱스입니다. 서로 다른 키가 같은 인덱스를 얻으면 해당 버킷의 이중 연결 리스트에 함께 저장하여 충돌을 해결합니다.

`put`, `get`, `remove`, `contains`는 평균 O(1)입니다. 최악에는 하나의 버킷에 키가 몰려 O(N)이 될 수 있습니다. 로드 팩터가 0.75를 초과하면 버킷 배열을 두 배로 확장하고 모든 키를 새 인덱스로 재배치합니다.

### O(1) LRU 추적

이중 연결 리스트의 앞은 가장 최근 사용 키(MRU), 뒤는 가장 오래 사용하지 않은 키(LRU)입니다. 각 해시맵 값은 자신의 LRU 노드를 참조합니다. 따라서 `GET` 또는 `SET` 성공 시 해시 조회로 노드를 찾고, 이 노드를 리스트 앞으로 옮기는 과정이 O(1)입니다. 제거 대상 역시 리스트 꼬리에서 O(1)에 찾을 수 있습니다.

### 최소 힙 TTL 관리

힙에는 `(expire_at, key)`를 저장합니다. 가장 이른 만료 시각은 항상 루트에 있으므로 O(1)에 확인하고 O(log N)에 제거할 수 있습니다. 명령 실행 시 루트부터 현재 시각보다 이른 항목을 정리합니다.

같은 키의 TTL을 다시 설정하면 이전 힙 항목을 즉시 찾아 지우지 않습니다. 대신 데이터 레코드의 현재 만료 시각과 힙 항목을 비교해 일치하는 항목만 실제 만료로 처리하는 lazy deletion 방식을 사용합니다.

### 메모리 제한과 제거 흐름

메모리 사용량은 다음 공식만 사용하며 Python 객체나 버킷의 오버헤드는 제외합니다.

```text
used_memory = Σ(len(utf8(key)) + len(utf8(value)))
```

`SET` 흐름은 다음과 같습니다.

1. 만료된 키를 먼저 제거하고 그 크기를 `used_memory`에서 뺍니다.
2. 새 단일 엔트리가 `maxmemory`보다 크면 저장하지 않고 OOM을 반환합니다.
3. 값을 저장하거나 덮어쓰고 정확한 크기 차이를 `used_memory`에 반영합니다.
4. 저장한 키를 LRU 목록 맨 앞으로 이동합니다.
5. 제한을 초과했다면 목록 뒤에서 키를 제거하고 `evicted_keys`를 증가시킵니다.
6. `used_memory <= maxmemory`가 될 때까지 5번을 반복합니다.

`CONFIG SET maxmemory` 자체는 기존 키를 제거하지 않습니다. 요구사항에 따라 그다음 `SET`이 실행될 때 제한 초과분을 LRU 방식으로 제거합니다.

## 시간 복잡도

| 연산 | 평균 시간 복잡도 |
| --- | --- |
| 해시맵 조회·삽입·삭제 | O(1) |
| LRU 접근 갱신·꼬리 제거 | O(1) |
| TTL 힙 삽입·제거 | O(log N) |
| 가장 빠른 TTL 확인 | O(1) |
| `KEYS` | O(N) |
| 해시맵 확장 | O(N) |

만료 정리는 한 명령에서 여러 키를 삭제할 수 있지만 각 힙 항목은 한 번만 제거되므로 여러 명령에 걸친 분할 상환 비용으로 볼 수 있습니다.

## 평가 자료

- 구현 완료 여부는 `CHECKLIST.md`에서 확인할 수 있습니다.
- 평가 항목별 설명 답안과 확장 질문 답변은 `EVALUATION_ANSWERS.md`에 정리되어 있습니다.
