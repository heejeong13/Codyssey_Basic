"""자료구조를 직접 조합해 만든 인메모리 문자열 Key-Value 저장소."""

import math
import time

from doubly_linked_list import DoublyLinkedList
from hash_map import HashMap
from min_heap import MinHeap


INTEGER_ERROR = "(error) ERR value is not an integer or out of range"
OOM_ERROR = "(error) OOM command not allowed when used_memory > 'maxmemory'"


class ValueRecord:
    """값과 해당 키의 TTL 및 LRU 노드를 한곳에 보관한다."""

    def __init__(self, value, lru_node, expire_at=None):
        self.value = value
        self.lru_node = lru_node
        self.expire_at = expire_at


class MiniRedis:
    """String, LRU 메모리 제한, TTL을 지원하는 Mini Redis 엔진."""

    def __init__(self, clock=None):
        self._data = HashMap()
        self._lru = DoublyLinkedList()
        self._expirations = MinHeap()
        self._clock = clock if clock is not None else time.time
        self.used_memory = 0
        self.maxmemory = 0
        self.evicted_keys = 0

    @staticmethod
    def _entry_size(key, value):
        return len(key.encode("utf-8")) + len(value.encode("utf-8"))

    @staticmethod
    def _quote(value):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return '"' + escaped + '"'

    def _purge_expired(self):
        """힙의 맨 앞부터 현재 시각까지 만료된 유효 엔트리를 삭제한다."""
        now = self._clock()
        while self._expirations.size() > 0:
            expire_at, key = self._expirations.peek()
            if expire_at > now:
                break

            self._expirations.pop()
            record = self._data.get(key)
            if record is not None and record.expire_at == expire_at:
                self._delete_key(key)

    def _delete_key(self, key, evicted=False):
        record = self._data.remove(key)
        if record is None:
            return False

        self._lru.remove_node(record.lru_node)
        self.used_memory -= self._entry_size(key, record.value)
        if evicted:
            self.evicted_keys += 1
        return True

    def _touch(self, record):
        self._lru.move_to_front(record.lru_node)

    def _evict_if_needed(self):
        while (
            self.maxmemory > 0
            and self.used_memory > self.maxmemory
            and self._lru.tail is not None
        ):
            self._delete_key(self._lru.tail.data, evicted=True)

    def set(self, key, value):
        self._purge_expired()
        new_size = self._entry_size(key, value)
        if self.maxmemory > 0 and new_size > self.maxmemory:
            return OOM_ERROR

        record = self._data.get(key)
        if record is None:
            node = self._lru.insert_front(key)
            self._data.put(key, ValueRecord(value, node))
            self.used_memory += new_size
        else:
            self.used_memory -= self._entry_size(key, record.value)
            record.value = value
            record.expire_at = None
            self.used_memory += new_size
            self._touch(record)

        self._evict_if_needed()
        return "OK"

    def get(self, key):
        self._purge_expired()
        record = self._data.get(key)
        if record is None:
            return "(nil)"
        self._touch(record)
        return self._quote(record.value)

    def delete(self, key):
        self._purge_expired()
        deleted = 1 if self._delete_key(key) else 0
        return "(integer) " + str(deleted)

    def exists(self, key):
        self._purge_expired()
        result = 1 if self._data.contains(key) else 0
        return "(integer) " + str(result)

    def dbsize(self):
        self._purge_expired()
        return "(integer) " + str(self._data.size())

    def keys(self):
        self._purge_expired()
        keys = self._data.keys()
        if not keys:
            return "(empty array)"
        lines = []
        for index, key in enumerate(keys, start=1):
            lines.append(str(index) + ". " + self._quote(key))
        return "\n".join(lines)

    def config_set_maxmemory(self, value):
        self._purge_expired()
        self.maxmemory = value
        return "OK"

    def info_memory(self):
        self._purge_expired()
        return (
            "used_memory:" + str(self.used_memory) + "\n"
            "maxmemory:" + str(self.maxmemory) + "\n"
            "evicted_keys:" + str(self.evicted_keys)
        )

    def expire(self, key, seconds):
        self._purge_expired()
        record = self._data.get(key)
        if record is None:
            return "(integer) 0"

        if seconds <= 0:
            self._delete_key(key)
            return "(integer) 1"

        expire_at = self._clock() + seconds
        record.expire_at = expire_at
        self._expirations.push((expire_at, key))
        return "(integer) 1"

    def ttl(self, key):
        self._purge_expired()
        record = self._data.get(key)
        if record is None:
            return "(integer) -2"
        if record.expire_at is None:
            return "(integer) -1"

        remaining = int(math.ceil(record.expire_at - self._clock()))
        return "(integer) " + str(max(0, remaining))

    @staticmethod
    def _wrong_arguments(command):
        return (
            "(error) ERR wrong number of arguments for '"
            + command.lower()
            + "' command"
        )

    @staticmethod
    def _parse_integer(value, allow_negative=True):
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            return None
        if not allow_negative and parsed < 0:
            return None
        return parsed

    def execute(self, arguments):
        """파싱된 CLI 토큰을 검증하고 알맞은 명령을 실행한다."""
        if not arguments:
            return None

        command = arguments[0].upper()
        if command == "SET":
            if len(arguments) != 3:
                return self._wrong_arguments(command)
            return self.set(arguments[1], arguments[2])
        if command == "GET":
            if len(arguments) != 2:
                return self._wrong_arguments(command)
            return self.get(arguments[1])
        if command == "DEL":
            if len(arguments) != 2:
                return self._wrong_arguments(command)
            return self.delete(arguments[1])
        if command == "EXISTS":
            if len(arguments) != 2:
                return self._wrong_arguments(command)
            return self.exists(arguments[1])
        if command == "DBSIZE":
            if len(arguments) != 1:
                return self._wrong_arguments(command)
            return self.dbsize()
        if command == "KEYS":
            if len(arguments) != 1:
                return self._wrong_arguments(command)
            return self.keys()
        if command == "CONFIG":
            if (
                len(arguments) != 4
                or arguments[1].upper() != "SET"
                or arguments[2].lower() != "maxmemory"
            ):
                return self._wrong_arguments(command)
            value = self._parse_integer(arguments[3], allow_negative=False)
            if value is None:
                return INTEGER_ERROR
            return self.config_set_maxmemory(value)
        if command == "INFO":
            if len(arguments) != 2 or arguments[1].lower() != "memory":
                return self._wrong_arguments(command)
            return self.info_memory()
        if command == "EXPIRE":
            if len(arguments) != 3:
                return self._wrong_arguments(command)
            seconds = self._parse_integer(arguments[2])
            if seconds is None:
                return INTEGER_ERROR
            return self.expire(arguments[1], seconds)
        if command == "TTL":
            if len(arguments) != 2:
                return self._wrong_arguments(command)
            return self.ttl(arguments[1])

        return "(error) ERR unknown command '" + arguments[0].lower() + "'"
