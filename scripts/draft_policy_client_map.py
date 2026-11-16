"""Draft client-company rules for default.map_policy_client: the 200 client names with the most 2026 revenue.

A policy with no company rule gets the client name from its description (int_policy_client: the text after the first
" - " or "-", without the trailing number; dim_policy title-cases it). This renders int_policy_client with no rules, so
every policy shows that fallback name (title-cased as dim_policy shows it), joins it to the 2026 charge lines on
branch + policy code (recognised revenue, the hnh_is_recognised_revenue rule) and writes the 200 names with the most
revenue, with an example description. The BI manager turns them into rules (name_pattern + client_company,
docs/policy_client_config.md). Read-only (DSN HNH_Gold).

Usage:  python scripts/draft_policy_client_map.py --out %TEMP%\\draft.csv [--year 2026] [--top 200]
"""
import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hnh_dsn import select  # noqa: E402
from render_model_sql import render, render_macro, strip_settings  # noqa: E402

NO_RULES = ("select '' as rule_id, toUInt8(0) as branch_id, cast(null as Nullable(Int64)) as purchaser_code, "
            "cast(null as Nullable(Int64)) as policy_code, '' as name_pattern, '' as client_company, "
            "cast(null as Nullable(UInt8)) as is_referral where 0")
COLUMNS = ["client_name", "revenue", "policies", "branches", "example_policy"]


def build_sql(year: int, top: int) -> str:
    policies, _ = strip_settings(render("int_policy_client", replace={"stg_ref__policy_client": NO_RULES}))
    charges, _ = strip_settings(render("stg_oasis__charges"))
    recognised = render_macro("hnh_is_recognised_revenue('c.cancel_flag', 'c.package_deal_flag')")
    client = render_macro("hnh_title('p.client_company')")  # as dim_policy shows it
    return f"""
with pol as (
{policies}
),
ch as (
    select c.branch_id as branch_id, assumeNotNull(c.policy_code) as policy_code, sum(c.price_paid_purchaser) as revenue
    from (
{charges}
    ) as c
    where c.delivered_at >= toDateTime('{year}-01-01 00:00:00', 'Asia/Riyadh')
      and c.delivered_at < toDateTime('{year + 1}-01-01 00:00:00', 'Asia/Riyadh')
      and c.policy_code is not null and {recognised} = 1
    group by c.branch_id, c.policy_code
)
select {client} as client_name, toString(round(sum(ch.revenue), 0)) as revenue,
       toString(count()) as policies, toString(uniqExact(p.branch_id)) as branches,
       argMax(p.policy_name, ch.revenue) as example_policy
from ch
inner join pol as p on p.branch_id = ch.branch_id and p.policy_code = ch.policy_code
group by client_name
order by sum(ch.revenue) desc
limit {top}
settings join_use_nulls = 1
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--year", type=int, default=2026)
    ap.add_argument("--top", type=int, default=200)
    args = ap.parse_args()
    rows = select(build_sql(args.year, args.top))
    with args.out.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} client names -> {args.out}")


if __name__ == "__main__":
    main()
