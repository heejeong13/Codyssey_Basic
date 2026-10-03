"""TTL 만료 순서를 관리하는 배열 기반 최소 힙."""


class MinHeap:
    """비교 가능한 요소를 저장하는 최소 힙."""

    def __init__(self):
        self._items = []

    def push(self, item):
        self._items.append(item)
        self._heapify_up(len(self._items) - 1)

    def pop(self):
        if not self._items:
            return None

        root = self._items[0]
        last = self._items.pop()
        if self._items:
            self._items[0] = last
            self._heapify_down(0)
        return root

    def peek(self):
        if not self._items:
            return None
        return self._items[0]

    def size(self):
        return len(self._items)

    def _heapify_up(self, index):
        while index > 0:
            parent = (index - 1) // 2
            if self._items[parent] <= self._items[index]:
                break
            self._items[parent], self._items[index] = (
                self._items[index],
                self._items[parent],
            )
            index = parent

    def _heapify_down(self, index):
        length = len(self._items)
        while True:
            left = index * 2 + 1
            right = left + 1
            smallest = index

            if left < length and self._items[left] < self._items[smallest]:
                smallest = left
            if right < length and self._items[right] < self._items[smallest]:
                smallest = right
            if smallest == index:
                return

            self._items[index], self._items[smallest] = (
                self._items[smallest],
                self._items[index],
            )
            index = smallest
