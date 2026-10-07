"""Create or update the read-only ClickHouse user that SSAS reads through (SSAS spec 9.1, decision P8).

The password comes from the HNH_SSAS_READER_PASSWORD environment variable and is never printed or stored.
Statements run as the account resolved by ch_env (the authorised default account). Safe to re-run.

Usage:
  python scripts/create_ssas_reader.py           create or update ssas_reader and its grant
  python scripts/create_ssas_reader.py --check   connect as ssas_reader and check what it can and cannot do
"""
import argparse
import os
import sys

import clickhouse_connect

from ch_env import client, resolve_env

USER = "ssas_reader"


def password():
    value = os.environ.get("HNH_SSAS_READER_PASSWORD", "")
    if len(value) < 16:
        raise SystemExit("Set HNH_SSAS_READER_PASSWORD (at least 16 characters) before running this script")
    return value


def literal(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def create(pw):
    admin = client()
    for sql in (
        f"CREATE USER IF NOT EXISTS {USER} IDENTIFIED WITH sha256_password BY {literal(pw)}",
        f"ALTER USER {USER} IDENTIFIED WITH sha256_password BY {literal(pw)}",
        f"ALTER USER {USER} SETTINGS readonly = 2, max_execution_time = 3600",
        f"GRANT SELECT ON gold.ssas_* TO {USER}",
    ):
        admin.command(sql)
    print(f"{USER}: created or updated; SELECT on gold.ssas_*")


def refused(action):
    try:
        action()
    except Exception:
        return True
    return False


def first_ssas_view():
    rows = client().query(
        "select name from system.tables where database = 'gold' and startsWith(name, 'ssas_') order by name limit 1"
    ).result_rows
    return rows[0][0] if rows else None


def check(pw):
    env = resolve_env()
    reader = clickhouse_connect.get_client(
        host=env["HNH_CH_HOST"], port=int(env["HNH_CH_PORT"]), username=USER, password=pw
    )
    results = {
        "connects as ssas_reader": reader.query("select currentUser()").result_rows[0][0] == USER,
        "cannot read gold.dim_branch": refused(lambda: reader.query("select count() from gold.dim_branch")),
        "cannot create tables": refused(
            lambda: reader.command("create table default.ssas_reader_probe (a UInt8) engine = Memory")
        ),
    }
    view = first_ssas_view()
    if view:
        results[f"reads gold.{view}"] = not refused(lambda: reader.query(f"select count() from gold.{view}"))
    for name, ok in results.items():
        print(("PASS " if ok else "FAIL ") + name)
    return all(results.values())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    pw = password()
    if args.check:
        return 0 if check(pw) else 1
    create(pw)
    return 0


if __name__ == "__main__":
    sys.exit(main())
