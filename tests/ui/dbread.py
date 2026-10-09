"""Read one bounded SQLite query as JSON without permitting database mutations."""
import argparse
import json
from pathlib import Path
import sqlite3
import sys
import time


def authorize(action, first, second, _database, _source):
    if action in (sqlite3.SQLITE_SELECT, sqlite3.SQLITE_READ, sqlite3.SQLITE_RECURSIVE):
        return sqlite3.SQLITE_OK
    if action == sqlite3.SQLITE_FUNCTION and (second or "").lower() != "load_extension":
        return sqlite3.SQLITE_OK
    if action == sqlite3.SQLITE_PRAGMA:
        name = (first or "").lower()
        if name in {"user_version", "integrity_check", "quick_check", "foreign_key_check"} and second is None:
            return sqlite3.SQLITE_OK
        if name in {"table_info", "table_xinfo", "index_info", "index_list", "foreign_key_list"}:
            return sqlite3.SQLITE_OK
    return sqlite3.SQLITE_DENY


def read_query(database, query, max_rows=10000, timeout=5.0):
    if max_rows < 1 or timeout <= 0:
        raise ValueError("row limit and timeout must be positive")
    path = Path(database).resolve(strict=True)
    if not path.is_file():
        raise ValueError("database must be an existing file")
    connection = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True, timeout=timeout)
    try:
        connection.execute("PRAGMA query_only=ON")
        connection.set_authorizer(authorize)
        deadline = time.monotonic() + timeout
        connection.set_progress_handler(lambda: int(time.monotonic() >= deadline), 1000)
        cursor = connection.execute(query)
        if cursor.description is None:
            raise ValueError("query must return rows")
        rows = cursor.fetchmany(max_rows + 1)
        if len(rows) > max_rows:
            raise ValueError("query exceeded the row limit")
        return {"columns": [item[0] for item in cursor.description],
                "rows": [[{"blob_hex": value.hex()} if isinstance(value, bytes) else value
                          for value in row] for row in rows]}
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", type=Path)
    parser.add_argument("query")
    parser.add_argument("--max-rows", type=int, default=10000)
    parser.add_argument("--timeout", type=float, default=5.0)
    args = parser.parse_args()
    try:
        result = read_query(args.database, args.query, args.max_rows, args.timeout)
        print(json.dumps(result, ensure_ascii=True, allow_nan=False))
        return 0
    except (OSError, ValueError, sqlite3.Error) as error:
        print(f"dbread: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
