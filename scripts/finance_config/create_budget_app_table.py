r"""Create default.income_statement_budget_app: the budget app's income statement budget read live from its Postgres
(172.22.24.7, database postgres, schema budget, table income_statement_budget), as the old warehouse's
budget.income_statement_budget (user request 2026-11-19). The connection is a ClickHouse named collection
`budget_app`, so the password is in no DDL, file of this repo or command line.

The password comes from C:\HNH\secrets\budget_pg.env (Administrators only): KEY=VALUE lines, PG_PASSWORD required;
PG_HOST, PG_PORT, PG_DATABASE, PG_SCHEMA, PG_USER optional (defaults below). It is never printed.

    python scripts\finance_config\create_budget_app_table.py --check   # read-only: what exists, what it would create
    python scripts\finance_config\create_budget_app_table.py           # creates the collection and the table, reads a count

Writes to production ClickHouse (a named collection and a table): run only on the user's go-ahead. Then point the dbt
source `reference.income_statement_budget` at it (`identifier: income_statement_budget_app` in
hnh_dwh/models/hnh/staging/reference/_reference__sources.yml) so the nightly build reads the latest published budget.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ch_env import _read_env_file, client  # noqa: E402

SECRETS = Path(r"C:\HNH\secrets\budget_pg.env")
DEFAULTS = {"PG_HOST": "172.22.24.7", "PG_PORT": "5432", "PG_DATABASE": "postgres", "PG_SCHEMA": "budget",
            "PG_USER": "postgres"}
COLLECTION, TABLE = "budget_app", "default.income_statement_budget_app"
COLUMNS = """    id Int32,
    branch_id Int32,
    fiscal_year Int32,
    scenario String,
    line_item_code String,
    assumption_percentage Nullable(Decimal(10, 4)),
""" + "".join(f"    month_{m} Nullable(Decimal(18, 2)),\n" for m in range(1, 13)) + """    fy_total Nullable(Decimal(18, 2)),
    published_at Nullable(DateTime),
    published_by Nullable(Int32),
    created_at Nullable(DateTime),
    updated_at Nullable(DateTime),
    is_latest Nullable(Bool)"""


def _quote(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="read-only: report, create nothing")
    args = ap.parse_args()
    ch = client()
    has_collection = bool(ch.query(f"select 1 from system.named_collections where name = '{COLLECTION}'").result_rows)
    has_table = bool(ch.query("select 1 from system.tables where database = 'default' and "
                              "name = 'income_statement_budget_app'").result_rows)
    print(f"named collection {COLLECTION}: {'exists' if has_collection else 'missing'}; {TABLE}: "
          f"{'exists' if has_table else 'missing'}; secrets file: {'found' if SECRETS.exists() else 'missing'}")
    if args.check:
        return 0
    if not has_collection:
        if not SECRETS.exists():
            print(f"put PG_PASSWORD=... in {SECRETS} first")
            return 1
        cfg = {**DEFAULTS, **_read_env_file(SECRETS)}
        if not cfg.get("PG_PASSWORD"):
            print(f"{SECRETS} has no PG_PASSWORD")
            return 1
        ch.command(f"CREATE NAMED COLLECTION {COLLECTION} AS host = {_quote(cfg['PG_HOST'])}, "
                   f"port = {int(cfg['PG_PORT'])}, database = {_quote(cfg['PG_DATABASE'])}, "
                   f"schema = {_quote(cfg['PG_SCHEMA'])}, user = {_quote(cfg['PG_USER'])}, "
                   f"password = {_quote(cfg['PG_PASSWORD'])}")
        print(f"named collection {COLLECTION} created")
    if not has_table:
        ch.command(f"CREATE TABLE {TABLE}\n(\n{COLUMNS}\n)\n"
                   f"ENGINE = PostgreSQL({COLLECTION}, table = 'income_statement_budget')")
        print(f"{TABLE} created")
    rows = ch.query(f"select fiscal_year, count(), countIf(is_latest) from {TABLE} group by 1 order by 1").result_rows
    print("rows by fiscal year (year, rows, latest):", rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
