"""Referral episodes per branch and start month, before and after a change of the referral policies.

stg_ref__referral_policy reads the referral rules of default.map_policy_client (docs/policy_client_config.md), and
gold.fact_episode.is_referral_policy feeds the BSC referral KPIs. Save the counts before the dbt build that switches
or edits the rules, compare after it: --compare exits 1 and prints the rows that differ. Read-only (DSN HNH_Gold).

  python scripts/policy_config/referral_snapshot.py --save %TEMP%\\ref_before.csv
  python scripts/policy_config/referral_snapshot.py --compare %TEMP%\\ref_before.csv
"""
import argparse
import csv
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


def current() -> dict:
    return {(r["branch_key"], r["start_month"]): r["referral_episodes"] for r in select(SQL)}


def read(path: Path) -> dict:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return {(r["branch_key"], r["start_month"]): r["referral_episodes"] for r in csv.DictReader(f)}


def differences(before: dict, after: dict) -> list[tuple]:
    """(branch, month, before, after) for every key whose count differs; a missing side is ''."""
    return [(b, m, before.get((b, m), ""), after.get((b, m), ""))
            for b, m in sorted(before.keys() | after.keys(), key=lambda k: (int(k[0]), int(k[1])))
            if before.get((b, m)) != after.get((b, m))]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--save", type=Path, help="write today's counts to this CSV")
    mode.add_argument("--compare", type=Path, help="compare today's counts with this CSV")
    args = ap.parse_args()
    now = current()
    if args.save:
        with args.save.open("w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(COLUMNS)
            for (b, m), n in sorted(now.items(), key=lambda kv: (int(kv[0][0]), int(kv[0][1]))):
                w.writerow([b, m, n])
        print(f"{len(now)} branch-months, {sum(int(n) for n in now.values())} referral episodes -> {args.save}")
        return 0
    diff = differences(read(args.compare), now)
    if not diff:
        print(f"same: {len(now)} branch-months, {sum(int(n) for n in now.values())} referral episodes")
        return 0
    print("branch_key,start_month,before,after")
    for row in diff:
        print(",".join(row))
    print(f"{len(diff)} branch-months differ")
    return 1


if __name__ == "__main__":
    sys.exit(main())
