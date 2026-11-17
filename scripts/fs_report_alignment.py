"""Moves of (account, branch) keys in default.map_fs_account to their position in the Fusion "HNH profitability Report".

The generator (build_fs_account_mapping.py) applies OVERRIDES on top of finance's TB mapping; this file is the tracked
home of those moves because *.csv is not tracked. Rows it writes carry MAPPED_IN = pl-report.

Usage:  python scripts/fs_report_alignment.py --mapping in.csv --out out.csv
            (aligns an exported default.map_fs_account; blank or \\N BRANCH_CODE is the all-branches row)
"""
import argparse
import csv
import sys
from pathlib import Path

MAPPED_IN = "pl-report"
GA = "General and administrative expenses"
DC = "Direct Cost"
OTHER_IND = "Other indirect Expenses"

# (account, branch code or None, FS_CATEGORY, FS_CAPTION, FS_LINE, reason)
OVERRIDES = [
    (41310101, None, "Revenue - Discounts", "Revenue - Settlement Discount", "Early Payment Discount", "decision 2 (2026-11-16)"),
    (54101403, None, DC, "Kitchen Expenses", "Hospitality", "decision 2 (2026-11-16)"),
    (54101507, 101, GA, "Professional Fee and subscription", "Branding", "decision 2 (2026-11-16)"),
    (51201202, None, DC, "Cost of Goods Sold", "Cost of Medicines", "Fusion report line"),
    (51201108, None, DC, "Cost of Goods Sold", "Miscellaneous Inventory", "Fusion report line (Consumables)"),
    (52101106, None, DC, "Employee Costs", "Employee Costs", "Fusion report line"),
    (52101112, None, DC, "Employee Costs", "Employee Costs", "Fusion report line"),
    (52101112, 101, GA, "Employee Cost", "Employee Cost", "Head Office salaries stay G&A"),
    (52101116, None, DC, "Employee Costs", "Employee Costs", "Fusion report line"),
    (52105103, None, GA, OTHER_IND, OTHER_IND, "Fusion report line"),
    (52105103, 101, GA, OTHER_IND, OTHER_IND, "Fusion report line (then dropped as equal to default)"),
    (53101109, None, DC, "Travelling Expenses", "Travelling , Fuel and Transportation", "Fusion report line"),
    (53101304, None, GA, OTHER_IND, OTHER_IND, "Fusion report line"),
    (43102302, None, "Other income, net", "Other income, net", "Rounding Difference", "unmapped: by account name"),
    (43102501, None, "Other income, net", "Other income, net", "Cash Discounts Earned", "unmapped: by account name"),
    (43102602, None, "Other income, net", "Other income, net", "Rental Income", "unmapped: by account name"),
    (43102603, None, "Other income, net", "Other income, net", "Miscellaneous Income", "unmapped: by account name"),
    (51201105, None, DC, "Cost of Goods Sold", "Medical Gases", "unmapped: by account name"),
    (53101103, None, DC, "Utilities Expenses", "Utilities Expenses", "unmapped: by account name"),
    (53101103, 101, GA, "Utilities Expenses", "Utilities Expenses", "unmapped, Head Office like 53101101"),
    (53101104, None, GA, OTHER_IND, "Medical Waste", "unmapped: by account name"),
    (53101105, None, GA, OTHER_IND, "Non-Medical Waste", "unmapped: by account name"),
    (53101108, None, DC, "Rental Cost", "Parking Expenses", "unmapped: by account name"),
    (53101206, None, DC, "Maintenance Expense", "General Maintenance", "unmapped: by account name"),
    (53101206, 101, GA, "Maintenance Expense", "General Maintenance", "unmapped, Head Office like 53101205"),
    (54101604, None, GA, "Expected credit loss", "ECL Provision - Insurance", "unmapped: by account name"),
    (54101606, None, DC, "Cost of Goods Sold", "Inventory Provision", "unmapped: by account name"),
    (57101201, None, "Finance Cost", "Finance Cost", "Interest Expense", "unmapped: by account name"),
    (57101301, None, "Finance Cost", "Finance Cost", "Interest Expense", "unmapped: by account name (Interest expense 1), user 2026-11-17"),
    (54101404, None, DC, "Kitchen Expenses", "Hospitality", "unmapped: like sibling 54101403 (Social activities), user 2026-11-17"),
]


def apply_overrides(rows, overrides=OVERRIDES):
    """rows: (account, branch code or None, 5-level position, mapped_in). Returns the rows with the overrides applied."""
    keys = [(o[0], o[1]) for o in overrides]
    for key in sorted({k for k in keys if keys.count(k) > 1}):
        raise SystemExit(f"overrides: {key[0]} listed twice for branch {key[1]}")
    override_keys = set(keys)
    # FS_TYPE and FS_ELEMENT of a category, and the captions it has, from rows the overrides do not touch.
    type_element, captions = {}, set()
    for acc, br, pos, _ in rows:
        if (acc, br) not in override_keys:
            type_element.setdefault(pos[2], (pos[0], pos[1]))
            captions.add((pos[2], pos[3]))
    out = {(acc, br): (acc, br, pos, m) for acc, br, pos, m in rows}
    for acc, br, cat, caption, line, reason in overrides:
        if not all(str(v).strip() for v in (cat, caption, line, reason)):
            raise SystemExit(f"overrides: {acc} has a blank level or reason")
        if (cat, caption) not in captions:
            raise SystemExit(f"overrides: {acc} targets {cat} / {caption}, which no other row has")
        if br is not None and (acc, None) not in out:
            raise SystemExit(f"overrides: {acc} has a branch {br} override but no default row")
        out[(acc, br)] = (acc, br, (*type_element[cat], cat, caption, line), MAPPED_IN)
    # A branch row that says what the default says adds nothing.
    return [r for r in out.values() if r[1] is None or out[(r[0], None)][2] != r[2]]


def main(argv=None, overrides=OVERRIDES):
    from build_fs_account_mapping import COLUMNS, LEVELS  # the generator imports this module

    ap = argparse.ArgumentParser()
    ap.add_argument("--mapping", required=True, help="default.map_fs_account as CSV")
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)

    with open(args.mapping, encoding="utf-8-sig", newline="") as fh:
        read = list(csv.DictReader(fh))
    rows = []
    for r in read:
        branch = (r["BRANCH_CODE"] or "").strip()
        rows.append((int(r["ORACLE_CODE"]), None if branch in ("", "\\N") else int(branch),
                     tuple(r[lvl] for lvl in LEVELS), r["MAPPED_IN"]))
    rows = sorted(apply_overrides(rows, overrides), key=lambda r: (r[0], r[1] or 0))
    with open(args.out, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(COLUMNS)
        for acc, br, pos, mapped_in in rows:
            w.writerow([acc, "" if br is None else br, *pos, mapped_in])
    print(f"{args.out}: {len(rows)} rows, {sum(r[3] == MAPPED_IN for r in rows)} {MAPPED_IN}")


if __name__ == "__main__":
    sys.exit(main())
