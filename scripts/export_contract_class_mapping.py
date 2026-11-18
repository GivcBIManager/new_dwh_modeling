"""One-off copy of the old server's contract class mapping (default.patient_contract_mapping) to a CSV.

The old warehouse classified the contracts whose Oasis class description carries no class (VIP, A, B, C) by hand, in
default.patient_contract_mapping (branch + contract number -> class id, classification). This reads it read-only
through the old server's DSN (chDWH) and writes static_mappings/contract_class_mapping.csv, which
scripts/load_reference_data.py loads into default.map_contract_class (docs/superpowers/specs/2026-11-18-policy-class-design.md).

Usage: python scripts/export_contract_class_mapping.py
"""
import csv
from pathlib import Path

from hnh_dsn import select

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "contract_class_mapping.csv"
COLUMNS = ["BRANCH_ID", "CONTRACT_NO", "CLASS_ID", "CLASSIFICATION"]


def main():
    rows = select("select BRANCH_ID, CONTRACT_NO, CLASS_ID, CLASSIFICATION "
                  "from default.patient_contract_mapping order by BRANCH_ID, CONTRACT_NO", dsn="chDWH")
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(COLUMNS)
        w.writerows([r[c] for c in COLUMNS] for r in rows)
    print(f"{OUT}: {len(rows):,} rows")


if __name__ == "__main__":
    main()
