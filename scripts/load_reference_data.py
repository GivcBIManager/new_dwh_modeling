"""One-off load of reference data into ClickHouse.

Creates the dbt target databases (stg, int, gold) and loads the exported
mapping files from static_mappings/ into tables in `default`.

- Never drops or overwrites: a table that already has rows is skipped.
- The Password column of the BI users export is never read into ClickHouse.
- Connection comes from scripts/ch_env.py (HNH_CH_* variables or the clickhouse MCP entry).

Usage:  python scripts/load_reference_data.py [--only table_name ...]
"""
import argparse
import csv
import sys
from datetime import datetime
from pathlib import Path

import clickhouse_connect

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "static_mappings"
DB = "default"
NULLS = {"", "\\N", "NULL"}


def s(v):
    return v.strip()


def s_null(v):
    return None if v in NULLS else v.strip()


def i(v):
    return int(float(v))


def i_null(v):
    return None if v in NULLS else int(float(v))


def f(v):
    return 0.0 if v in NULLS else float(v)


def dt(v):
    return datetime.strptime(v[:19], "%Y-%m-%d %H:%M:%S")


def dt_null(v):
    return None if v in NULLS else dt(v)


def b(v):
    return 1 if v.strip().lower() in ("1", "1.0", "true", "y") else 0


# table -> (csv file, [(csv column, ClickHouse type, converter)], ORDER BY)
SMALL_TABLES = {
    "map_bed_classification": (
        "bed_mapping.csv",
        [("BRANCH_ID", "UInt8", i), ("CLASSIFICATION", "LowCardinality(String)", s), ("BED", "String", s)],
        "(BRANCH_ID, BED)",
    ),
    "map_ward_tower": (
        "m_wards.csv",
        [("BRANCH_ID", "UInt8", i), ("ID", "Int64", i), ("DESCRIPTION", "String", s), ("Tower", "LowCardinality(String)", s)],
        "(BRANCH_ID, ID)",
    ),
    "map_clinic_duration": (
        "clinic_duration_mapping.csv",
        [("SPECIALTY", "String", s), ("CLINIC_DURATION", "Float64", f), ("SLOTS_PER_HOUR", "Float64", f)],
        "SPECIALTY",
    ),
    "map_clinic_count": (
        "clinics_mapping.csv",
        [("BRANCH_ID", "UInt8", i), ("CLINICS_COUNT", "UInt16", i)],
        "BRANCH_ID",
    ),
    "map_home_care_entity": (
        "home_care_entities.csv",
        [("BRANCH_ID", "UInt8", i), ("WORK_ENTITY", "Int64", i), ("DESCRIPTION", "String", s)],
        "(BRANCH_ID, WORK_ENTITY)",
    ),
    "map_termination_reason": (
        "termination_reason_mapping.csv",
        [
            ("BRANCH_ID", "UInt8", i),
            ("TERMINATION_REASON", "String", s),
            ("TERMINATION_REASON_CODE", "Int64", i),
            ("UNIFIED_REASON", "LowCardinality(String)", s),
        ],
        "(BRANCH_ID, TERMINATION_REASON_CODE)",
    ),
    "map_claim_status": (
        "claim_status_mapping.csv",
        [("DetailedStatus", "String", s), ("SubmitionStatus", "String", s), ("ValidationStatus", "String", s)],
        "DetailedStatus",
    ),
    "map_nphies_reason": (
        "nphies_reason_mapping.csv",
        [("CODE", "String", s), ("REASON", "String", s), ("CATEGORY", "LowCardinality(String)", s)],
        "CODE",
    ),
    "map_order_fulfilment_packages": (
        "order_fulfilment_packages.csv",
        [("DESCRIPTION", "String", s)],
        "DESCRIPTION",
    ),
    # Financial-statement line per Oracle natural account (COA segment 2). Supplied as
    # abha_fs_mapping_oracle.xlsx, one sheet per branch (abha, ghirnata) merged into one list:
    # the sheets agree on every shared account and all ledgers share chart 2001, so it applies
    # group-wide. MAPPED_IN names the sheets that list the account.
    "map_fs_account": (
        "fs_account_mapping.csv",
        [("ORACLE_CODE", "UInt32", i), ("FS_TYPE", "LowCardinality(String)", s), ("FS_ELEMENT", "LowCardinality(String)", s),
         ("FS_CATEGORY", "LowCardinality(String)", s), ("FS_CAPTION", "String", s), ("FS_LINE", "String", s),
         ("MAPPED_IN", "LowCardinality(String)", s)],
        "ORACLE_CODE",
    ),
    # The old warehouse's Oasis chart mapping (default.fs_mapping, behind vw_account_tree): FS position
    # per branch and Oasis sub-account (MAIN_ACC||SUB_ACC). Oasis and Oracle numbers are different
    # spaces, so this is the legacy side of statement reconciliation, not a lookup for Oracle accounts.
    "map_oasis_fs_account": (
        "fs_mapping.csv",
        [("BRANCH_ID", "UInt8", i), ("CODE", "String", s), ("TYPE", "LowCardinality(String)", s),
         ("FS_ELEMENT", "LowCardinality(String)", s), ("FS_CATEGORY", "LowCardinality(String)", s),
         ("FS_CAPTION", "String", s), ("FS_LINE", "String", s)],
        "(BRANCH_ID, CODE)",
    ),
    "map_unified_department_v2": (
        "master_unified_department.csv",
        [("DEPARTMENT", "String", s), ("UNIFIED_DEPARTMENT", "String", s), ("NOT_ADMITTING", "UInt8", i), ("High_Value", "UInt8", i)],
        "DEPARTMENT",
    ),
    "income_statement_budget": (
        "income_statement_budget.csv",
        [("id", "UInt32", i), ("branch_id", "UInt8", i), ("fiscal_year", "UInt16", i), ("scenario", "LowCardinality(String)", s),
         ("line_item_code", "LowCardinality(String)", s), ("assumption_percentage", "Float64", f)]
        + [(f"month_{m}", "Float64", f) for m in range(1, 13)]
        + [("fy_total", "Float64", f), ("published_at", "Nullable(DateTime)", dt_null), ("published_by", "String", s),
           ("created_at", "Nullable(DateTime)", dt_null), ("updated_at", "Nullable(DateTime)", dt_null), ("is_latest", "UInt8", b)],
        "(branch_id, fiscal_year, scenario, line_item_code, id)",
    ),
    # Password is deliberately absent from this column list.
    "bi_users": (
        "_BI_USERS_.csv",
        [("UserName", "String", s), ("BRANCH_ID", "Nullable(UInt8)", i_null), ("IsAdmin", "UInt8", b),
         ("ModefiedDate", "Nullable(DateTime)", dt_null), ("Unified_Speciality", "Nullable(String)", s_null)],
        "UserName",
    ),
}

BUDGET_DDL = f"""
CREATE TABLE IF NOT EXISTS {DB}.budget_data (
    BranchId UInt8, TableDate Date, Year UInt16, Quarter UInt8,
    Scenario LowCardinality(String), CareType LowCardinality(String), StayType LowCardinality(String),
    Creditor LowCardinality(String), Speciality LowCardinality(String),
    Census Float64, Episodes Float64, CPE Float64, ALOS Float64, Revenue Float64,
    is_last_value UInt8, CreatedAt DateTime, CreatedBy String
) ENGINE = MergeTree
ORDER BY (BranchId, TableDate, Scenario, CareType, StayType, Creditor, Speciality)
"""
BUDGET_COLUMNS = ["BranchId", "TableDate", "Year", "Quarter", "Scenario", "CareType", "StayType", "Creditor", "Speciality",
                  "Census", "Episodes", "CPE", "ALOS", "Revenue", "is_last_value", "CreatedAt", "CreatedBy"]


def connect():
    # HNH_CH_* settings (or the clickhouse MCP entry), never the machine-wide CLICKHOUSE_* variables.
    from ch_env import client
    return client()


def rows_in(client, table):
    return client.command(f"SELECT count() FROM {DB}.{table}")


def load_small(client, table):
    file, cols, order_by = SMALL_TABLES[table]
    ddl_cols = ", ".join(f"`{name}` {typ}" for name, typ, _ in cols)
    client.command(f"CREATE TABLE IF NOT EXISTS {DB}.{table} ({ddl_cols}) ENGINE = MergeTree ORDER BY {order_by}")
    if rows_in(client, table) > 0:
        return "skipped (already has rows)"
    with open(SRC / file, encoding="utf-8-sig", newline="") as fh:
        data = [[conv(row[name]) for name, _, conv in cols] for row in csv.DictReader(fh)]
    client.insert(f"{DB}.{table}", data, column_names=[name for name, _, _ in cols])
    return f"loaded {len(data):,}"


def load_budget(client):
    client.command(BUDGET_DDL)
    if rows_in(client, "budget_data") > 0:
        return "skipped (already has rows)"
    # Stream the file as-is, minus rows without a branch or date (one blank row in the export).
    path = SRC / "budget_data.csv"

    def chunks():
        with open(path, encoding="utf-8-sig", newline="") as fh:
            reader = csv.reader(fh)
            next(reader)
            buf, n = [], 0
            for row in reader:
                if row[0] in NULLS or row[0] == "0" or row[1] in NULLS:
                    continue
                buf.append(row)
                if len(buf) >= 200_000:
                    yield buf
                    buf = []
            if buf:
                yield buf

    total = 0
    for chunk in chunks():
        data = [
            [int(r[0]), datetime.strptime(r[1], "%Y-%m-%d").date(), int(r[2]), int(r[3]), r[4], r[5], r[6], r[7], r[8],
             f(r[9]), f(r[10]), f(r[11]), f(r[12]), f(r[13]), b(r[14]), dt(r[15]), r[16]]
            for r in chunk
        ]
        client.insert(f"{DB}.budget_data", data, column_names=BUDGET_COLUMNS)
        total += len(data)
        print(f"    budget_data: {total:,} rows", flush=True)
    return f"loaded {total:,}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", help="load only these tables")
    args = ap.parse_args()
    client = connect()

    for db in ("stg", "int", "gold"):
        client.command(f"CREATE DATABASE IF NOT EXISTS `{db}`")
    print("databases:", [d for d in client.query("SHOW DATABASES").result_columns[0] if d in ("stg", "int", "gold")])

    targets = args.only or (list(SMALL_TABLES) + ["budget_data"])
    for table in targets:
        result = load_budget(client) if table == "budget_data" else load_small(client, table)
        print(f"  {DB}.{table}: {result} -> {rows_in(client, table):,} rows in table")


if __name__ == "__main__":
    sys.exit(main())
