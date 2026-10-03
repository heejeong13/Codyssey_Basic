"""Mini Redis 명령행 REPL 진입점."""

import shlex

from mini_redis import MiniRedis


def main():
    redis = MiniRedis()

    while True:
        try:
            line = input("mini-redis> ")
        except (EOFError, KeyboardInterrupt):
            print()
            break

        stripped = line.strip()
        if not stripped:
            continue
        if stripped.lower() in ("exit", "quit"):
            break

        try:
            arguments = shlex.split(stripped)
        except ValueError:
            print("(error) ERR syntax error")
            continue

        result = redis.execute(arguments)
        if result is not None:
            print(result)


if __name__ == "__main__":
    main()
