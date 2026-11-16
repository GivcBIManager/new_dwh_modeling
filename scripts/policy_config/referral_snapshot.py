"""Referral episodes per branch and start month: the gate after the switch to default.map_policy_client.

stg_ref__referral_policy reads the referral rules of default.map_policy_client (docs/policy_client_config.md), and
gold.fact_episode.is_referral_policy feeds the BSC referral KPIs. Read-only (DSN HNH_Gold).

--against-map (the gate, run after the dbt build that switches to map_policy_client): in the same build, for every
branch and start month of gold.fact_episode, the episodes flagged is_referral_policy = 1 must equal the episodes whose
(branch, policy code) is in default.map_referral_policies. Prints the rows that differ and exits 1 if any. Valid while
the referral rules of map_policy_client are still the seed copy of map_referral_policies.

--save / --compare (sanity check only): counts saved before a build compared with counts after it. The two builds read
different Oasis data, so episodes can move; the current (open) month is skipped and a difference is a lead to look at,
not a failure of the switch.

  python scripts/policy_config/referral_snapshot.py --against-map
  python scripts/policy_config/referral_snapshot.py --save %TEMP%\\ref_before.csv
  python scripts/policy_config/referral_snapshot.py --compare %TEMP%\\ref_before.csv
"""
import argparse
import csv
import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from hnh_dsn import select  # noqa: E402

SQL = """
select toString(branch_key) as branch_key, toString(intDiv(start_date_key, 100)) as start_month,
       toString(count()) as referral_episodes
from gold.fact_episode
where is_referral_policy = 1
group by branch_key, start_month
order by branch_key, start_month
"""
COLUMNS = ["branch_key", "start_month", "referral_episodes"]

AGAINST_MAP_SQL = """
select toString(branch_key) as branch_key, toString(intDiv(start_date_key, 100)) as start_month,
       toString(countIf(is_referral_policy = 1)) as flagged,
       toString(countIf(policy_code is not null and (branch_key, assumeNotNull(policy_code)) in (
           select toUInt8(BRANCH_ID), toInt64(POLICY_CODE) from default.map_referral_policies))) as in_map
from gold.fact_episode
group by branch_key, start_month
order by branch_key, start_month
"""


def current() -> dict:
    return {(r["branch_key"], r["start_month"]): r["referral_episodes"] for r in select(SQL)}


def read(path: Path) -> dict:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return {(r["branch_key"], r["start_month"]): r["referral_episodes"] for r in csv.DictReader(f)}


def open_month(today: datetime.date | None = None) -> str:
    """The current month as yyyymm, the start_month text of fact_episode."""
    today = today or datetime.date.today()
    return f"{today.year}{today.month:02d}"


def differences(before: dict, after: dict, skip_from: str | None = None) -> list[tuple]:
    """(branch, month, before, after) for every key whose count differs; a missing side is ''.
    Months at or after skip_from (yyyymm, the open month) are left out."""
    keys = before.keys() | after.keys()
    if skip_from:
        keys = {k for k in keys if int(k[1]) < int(skip_from)}
    return [(b, m, before.get((b, m), ""), after.get((b, m), ""))
            for b, m in sorted(keys, key=lambda k: (int(k[0]), int(k[1])))
            if before.get((b, m)) != after.get((b, m))]


def map_mismatches(rows: list[dict]) -> list[tuple]:
    """(branch, month, flagged, in_map) for every branch-month whose two counts differ."""
    return [(r["branch_key"], r["start_month"], r["flagged"], r["in_map"])
            for r in rows if int(r["flagged"]) != int(r["in_map"])]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--against-map", action="store_true",
                      help="gate: is_referral_policy against default.map_referral_policies in the same build")
    mode.add_argument("--save", type=Path, help="write today's counts to this CSV (sanity check)")
    mode.add_argument("--compare", type=Path, help="compare today's counts with this CSV, open month skipped (sanity check)")
    args = ap.parse_args()
    if args.against_map:
        rows = select(AGAINST_MAP_SQL)
        bad = map_mismatches(rows)
        flagged = sum(int(r["flagged"]) for r in rows)
        if not bad:
            print(f"same: {len(rows)} branch-months, {flagged} referral episodes, all in map_referral_policies")
            return 0
        print("branch_key,start_month,flagged,in_map")
        for row in bad:
            print(",".join(row))
        print(f"{len(bad)} branch-months differ")
        return 1
    now = current()
    if args.save:
        with args.save.open("w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(COLUMNS)
            for (b, m), n in sorted(now.items(), key=lambda kv: (int(kv[0][0]), int(kv[0][1]))):
                w.writerow([b, m, n])
        print(f"{len(now)} branch-months, {sum(int(n) for n in now.values())} referral episodes -> {args.save}")
        return 0
    month = open_month()
    diff = differences(read(args.compare), now, skip_from=month)
    if not diff:
        print(f"sanity check, same before {month}: {len(now)} branch-months, "
              f"{sum(int(n) for n in now.values())} referral episodes")
        return 0
    print(f"sanity check (months before {month}; the builds read different Oasis data, so look before stopping)")
    print("branch_key,start_month,before,after")
    for row in diff:
        print(",".join(row))
    print(f"{len(diff)} branch-months differ")
    return 1


if __name__ == "__main__":
    sys.exit(main())
