"""O(1) 삽입, 삭제, 이동을 제공하는 이중 연결 리스트."""


class Node:
    """리스트의 한 노드이며 양쪽 이웃과 사용자 데이터를 보관한다."""

    def __init__(self, data):
        self.prev = None
        self.next = None
        self.data = data


class DoublyLinkedList:
    """머리와 꼬리를 직접 관리하는 이중 연결 리스트."""

    def __init__(self):
        self.head = None
        self.tail = None
        self._size = 0

    def insert_front(self, data):
        node = Node(data)
        node.next = self.head

        if self.head is None:
            self.tail = node
        else:
            self.head.prev = node

        self.head = node
        self._size += 1
        return node

    def insert_back(self, data):
        node = Node(data)
        node.prev = self.tail

        if self.tail is None:
            self.head = node
        else:
            self.tail.next = node

        self.tail = node
        self._size += 1
        return node

    def remove_front(self):
        if self.head is None:
            return None
        return self.remove_node(self.head)

    def remove_back(self):
        if self.tail is None:
            return None
        return self.remove_node(self.tail)

    def remove_node(self, node):
        """주어진 노드를 O(1)에 분리하고 그 데이터를 반환한다."""
        if node is None:
            return None

        if node.prev is None:
            self.head = node.next
        else:
            node.prev.next = node.next

        if node.next is None:
            self.tail = node.prev
        else:
            node.next.prev = node.prev

        node.prev = None
        node.next = None
        self._size -= 1
        return node.data

    def move_to_front(self, node):
        """기존 노드 객체를 유지한 채 O(1)에 맨 앞으로 옮긴다."""
        if node is None or node is self.head:
            return node

        if node.prev is not None:
            node.prev.next = node.next
        if node.next is not None:
            node.next.prev = node.prev
        else:
            self.tail = node.prev

        node.prev = None
        node.next = self.head
        self.head.prev = node
        self.head = node
        return node

    def size(self):
        return self._size
