# Mini Redis 과제 체크리스트

## 기본 자료구조

- [x] `prev`, `next`, `data`를 갖는 이중 연결 리스트 노드
- [x] `insert_front`, `insert_back`, `remove_front`, `remove_back`
- [x] `remove_node`, `move_to_front`
- [x] 연결 리스트 삽입·삭제·이동 O(1)
- [x] 직접 설계한 FNV-1a 문자열 해시 함수
- [x] 이중 연결 리스트 체이닝을 이용한 충돌 해결
- [x] 해시맵 `put`, `get`, `remove`, `contains`, `keys`, `size`
- [x] 로드 팩터 0.75 초과 시 버킷 2배 확장
- [x] 최소 힙 `push`, `pop`, `peek`, `size`
- [x] 최소 힙 `_heapify_up`, `_heapify_down`
- [x] `(expire_at, key)` TTL 요소 처리
- [x] `dict`, `set`, `collections`, `heapq` 미사용

## String 명령어

- [x] `SET`
- [x] `GET`
- [x] `DEL`
- [x] `EXISTS`
- [x] `DBSIZE`
- [x] `KEYS`
- [x] 키 기반 명령 전 만료 데이터 정리
- [x] 기존 키를 `SET`으로 덮어쓸 때 TTL 초기화
- [x] Redis 스타일 결과 출력

## 메모리와 LRU

- [x] `CONFIG SET maxmemory bytes`
- [x] `INFO memory`
- [x] UTF-8 키·값 바이트 길이에 따른 `used_memory` 계산
- [x] 해시맵과 이중 연결 리스트를 조합한 O(1) LRU 갱신
- [x] `SET` 후 제한 이하가 될 때까지 LRU 키 제거
- [x] 제거할 때 `used_memory` 감소 및 `evicted_keys` 증가
- [x] 단일 엔트리가 제한보다 크면 저장하지 않고 OOM 반환
- [x] `maxmemory = 0` 무제한 처리

## TTL

- [x] `EXPIRE`
- [x] `TTL`
- [x] 0 이하 TTL 즉시 만료
- [x] 없는 키, TTL 없는 키, TTL 있는 키 반환값 구분
- [x] 최소 힙으로 가장 빠른 만료 확인
- [x] TTL 재설정 및 삭제 시 lazy deletion 처리
- [x] 만료 삭제 시 데이터·LRU·메모리 사용량 동기화

## CLI와 오류

- [x] `mini-redis>` REPL
- [x] `exit`, `quit` 종료
- [x] 대소문자를 구분하지 않는 명령어
- [x] 큰따옴표로 감싼 공백 포함 값
- [x] 알 수 없는 명령 오류
- [x] 인자 개수 오류
- [x] 정수 변환 및 범위 오류
- [x] OOM 오류

## 문서와 검증

- [x] 핵심 클래스 및 함수 docstring
- [x] 실행 방법 및 명령어 문서화
- [x] 해시맵, LRU, TTL 힙 동작 원리 문서화
- [x] 시간 복잡도 문서화
- [x] `unittest` 자료구조 및 명령 테스트
- [x] 실제 CLI 시나리오 검증
