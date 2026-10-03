"""내장 dict 없이 구현한 체이닝 방식 해시맵."""

from doubly_linked_list import DoublyLinkedList


class HashEntry:
    """해시 버킷에 저장되는 키-값 엔트리."""

    def __init__(self, key, value):
        self.key = key
        self.value = value


class HashMap:
    """FNV-1a 해시와 연결 리스트 체이닝을 사용하는 해시맵."""

    _MAX_LOAD_FACTOR = 0.75

    def __init__(self, initial_capacity=8):
        if initial_capacity < 1:
            initial_capacity = 1
        self._buckets = [None] * initial_capacity
        self._size = 0

    def _hash(self, key):
        """문자열의 UTF-8 바이트에 64비트 FNV-1a 해시를 적용한다."""
        hash_value = 14695981039346656037
        for byte in key.encode("utf-8"):
            hash_value ^= byte
            hash_value = (hash_value * 1099511628211) & 0xFFFFFFFFFFFFFFFF
        return hash_value

    def _bucket_index(self, key):
        return self._hash(key) % len(self._buckets)

    def _find_node(self, key):
        bucket = self._buckets[self._bucket_index(key)]
        if bucket is None:
            return None

        node = bucket.head
        while node is not None:
            if node.data.key == key:
                return node
            node = node.next
        return None

    def put(self, key, value):
        node = self._find_node(key)
        if node is not None:
            old_value = node.data.value
            node.data.value = value
            return old_value

        index = self._bucket_index(key)
        if self._buckets[index] is None:
            self._buckets[index] = DoublyLinkedList()
        self._buckets[index].insert_back(HashEntry(key, value))
        self._size += 1

        if self._size / len(self._buckets) > self._MAX_LOAD_FACTOR:
            self._resize(len(self._buckets) * 2)
        return None

    def get(self, key):
        node = self._find_node(key)
        if node is None:
            return None
        return node.data.value

    def remove(self, key):
        index = self._bucket_index(key)
        bucket = self._buckets[index]
        if bucket is None:
            return None

        node = bucket.head
        while node is not None:
            if node.data.key == key:
                value = node.data.value
                bucket.remove_node(node)
                self._size -= 1
                if bucket.size() == 0:
                    self._buckets[index] = None
                return value
            node = node.next
        return None

    def contains(self, key):
        return self._find_node(key) is not None

    def keys(self):
        result = []
        for bucket in self._buckets:
            if bucket is None:
                continue
            node = bucket.head
            while node is not None:
                result.append(node.data.key)
                node = node.next
        return result

    def size(self):
        return self._size

    def _resize(self, new_capacity):
        old_buckets = self._buckets
        self._buckets = [None] * new_capacity

        for bucket in old_buckets:
            if bucket is None:
                continue
            node = bucket.head
            while node is not None:
                entry = node.data
                index = self._bucket_index(entry.key)
                if self._buckets[index] is None:
                    self._buckets[index] = DoublyLinkedList()
                self._buckets[index].insert_back(entry)
                node = node.next
