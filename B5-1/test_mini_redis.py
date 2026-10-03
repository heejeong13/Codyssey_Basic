"""Mini Redis 자료구조와 명령 동작 테스트."""

import unittest

from doubly_linked_list import DoublyLinkedList
from hash_map import HashMap
from min_heap import MinHeap
from mini_redis import INTEGER_ERROR, OOM_ERROR, MiniRedis


class FakeClock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


class DoublyLinkedListTests(unittest.TestCase):
    def test_insert_remove_and_move_are_consistent(self):
        linked = DoublyLinkedList()
        one = linked.insert_back("one")
        two = linked.insert_back("two")
        linked.insert_front("zero")

        linked.move_to_front(two)
        self.assertEqual(linked.head.data, "two")
        self.assertEqual(linked.tail.data, "one")
        self.assertEqual(linked.remove_front(), "two")
        self.assertEqual(linked.remove_back(), "one")
        self.assertEqual(linked.size(), 1)


class HashMapTests(unittest.TestCase):
    def test_put_update_remove_and_resize(self):
        mapping = HashMap(initial_capacity=2)
        for index in range(30):
            mapping.put("key-" + str(index), "value-" + str(index))

        self.assertEqual(mapping.size(), 30)
        for index in range(30):
            self.assertEqual(mapping.get("key-" + str(index)), "value-" + str(index))

        self.assertEqual(mapping.put("key-2", "changed"), "value-2")
        self.assertEqual(mapping.remove("key-2"), "changed")
        self.assertFalse(mapping.contains("key-2"))

    def test_collisions_are_resolved_by_chaining(self):
        class CollidingHashMap(HashMap):
            def _hash(self, key):
                return 0

        mapping = CollidingHashMap(initial_capacity=8)
        mapping.put("a", "A")
        mapping.put("b", "B")
        mapping.put("c", "C")
        self.assertEqual(mapping.get("a"), "A")
        self.assertEqual(mapping.get("b"), "B")
        self.assertEqual(mapping.remove("b"), "B")
        self.assertEqual(mapping.get("c"), "C")


class MinHeapTests(unittest.TestCase):
    def test_items_pop_in_ascending_order(self):
        heap = MinHeap()
        for item in ((5, "e"), (1, "a"), (3, "c"), (2, "b")):
            heap.push(item)
        self.assertEqual([heap.pop(), heap.pop(), heap.pop(), heap.pop()], [
            (1, "a"),
            (2, "b"),
            (3, "c"),
            (5, "e"),
        ])
        self.assertIsNone(heap.pop())


class MiniRedisTests(unittest.TestCase):
    def setUp(self):
        self.clock = FakeClock()
        self.redis = MiniRedis(clock=self.clock)

    def test_string_commands_and_utf8_memory(self):
        self.assertEqual(self.redis.execute(["SET", "이름", "희정"]), "OK")
        self.assertEqual(self.redis.execute(["GET", "이름"]), '"희정"')
        self.assertEqual(self.redis.execute(["EXISTS", "이름"]), "(integer) 1")
        self.assertEqual(self.redis.used_memory, 12)
        self.assertEqual(self.redis.execute(["DBSIZE"]), "(integer) 1")
        self.assertIn('"이름"', self.redis.execute(["KEYS"]))
        self.assertEqual(self.redis.execute(["DEL", "이름"]), "(integer) 1")
        self.assertEqual(self.redis.execute(["GET", "이름"]), "(nil)")

    def test_get_changes_lru_eviction_order(self):
        self.redis.execute(["CONFIG", "SET", "maxmemory", "6"])
        self.redis.execute(["SET", "a", "1"])
        self.redis.execute(["SET", "b", "2"])
        self.redis.execute(["GET", "a"])
        self.redis.execute(["SET", "cc", "33"])

        self.assertEqual(self.redis.execute(["EXISTS", "a"]), "(integer) 1")
        self.assertEqual(self.redis.execute(["EXISTS", "b"]), "(integer) 0")
        self.assertEqual(self.redis.evicted_keys, 1)
        self.assertEqual(self.redis.used_memory, 6)

    def test_lowering_limit_does_not_evict_until_set(self):
        self.redis.execute(["SET", "aa", "11"])
        self.redis.execute(["SET", "bb", "22"])
        self.redis.execute(["CONFIG", "SET", "maxmemory", "4"])
        self.assertEqual(self.redis.execute(["DBSIZE"]), "(integer) 2")

        self.redis.execute(["SET", "c", "3"])
        self.assertLessEqual(self.redis.used_memory, 4)
        self.assertEqual(self.redis.evicted_keys, 2)

    def test_oversized_entry_preserves_existing_value_and_ttl(self):
        self.redis.execute(["SET", "a", "old"])
        self.redis.execute(["EXPIRE", "a", "10"])
        self.redis.execute(["CONFIG", "SET", "maxmemory", "4"])

        self.assertEqual(self.redis.execute(["SET", "a", "large"]), OOM_ERROR)
        self.assertEqual(self.redis.execute(["GET", "a"]), '"old"')
        self.assertEqual(self.redis.execute(["TTL", "a"]), "(integer) 10")

    def test_overwrite_clears_ttl(self):
        self.redis.execute(["SET", "a", "one"])
        self.redis.execute(["EXPIRE", "a", "5"])
        self.redis.execute(["SET", "a", "two"])
        self.clock.advance(6)
        self.assertEqual(self.redis.execute(["GET", "a"]), '"two"')
        self.assertEqual(self.redis.execute(["TTL", "a"]), "(integer) -1")

    def test_expiration_and_lazy_deletion(self):
        self.redis.execute(["SET", "a", "one"])
        self.redis.execute(["EXPIRE", "a", "5"])
        self.clock.advance(2)
        self.redis.execute(["EXPIRE", "a", "10"])
        self.clock.advance(4)

        self.assertEqual(self.redis.execute(["GET", "a"]), '"one"')
        self.assertEqual(self.redis.execute(["TTL", "a"]), "(integer) 6")
        self.clock.advance(6)
        self.assertEqual(self.redis.execute(["GET", "a"]), "(nil)")
        self.assertEqual(self.redis.execute(["TTL", "a"]), "(integer) -2")
        self.assertEqual(self.redis.used_memory, 0)

    def test_non_positive_expire_deletes_immediately(self):
        self.redis.execute(["SET", "a", "one"])
        self.assertEqual(self.redis.execute(["EXPIRE", "a", "0"]), "(integer) 1")
        self.assertEqual(self.redis.execute(["EXISTS", "a"]), "(integer) 0")
        self.assertEqual(self.redis.execute(["EXPIRE", "missing", "2"]), "(integer) 0")

    def test_info_keys_and_errors(self):
        self.assertEqual(self.redis.execute(["KEYS"]), "(empty array)")
        self.assertEqual(
            self.redis.execute(["CONFIG", "SET", "maxmemory", "bad"]),
            INTEGER_ERROR,
        )
        self.assertEqual(
            self.redis.execute(["CONFIG", "SET", "maxmemory", "-1"]),
            INTEGER_ERROR,
        )
        self.assertIn("used_memory:0", self.redis.execute(["INFO", "memory"]))
        self.assertEqual(
            self.redis.execute(["NOPE"]),
            "(error) ERR unknown command 'nope'",
        )
        self.assertEqual(
            self.redis.execute(["GET"]),
            "(error) ERR wrong number of arguments for 'get' command",
        )


if __name__ == "__main__":
    unittest.main()
