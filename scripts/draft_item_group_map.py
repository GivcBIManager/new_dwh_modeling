"""Draft static_mappings/item_group_mapping.csv: Fusion "HNH Catalog" category codes to item groups (spec 4.2).

Keyword rules on the category code, first match wins; codes that match no rule are written as 'Other' for the BI
manager to review (open item O-P5-4).

Usage:  python scripts/draft_item_group_map.py [--out PATH]
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "item_group_mapping.csv"
MASTER_ORG = 300000005019401

RULES = [
    (r"IMPLANT|STENT", "Implant"),
    (r"^LAB_|^XXLAB_", "Laboratory"),
    (r"^IT_|EQUIPMENT|PP&E|FURNITURE|COMPUTERS|LAPTOPS|SERVERS?\b|SERVER_RACKS|PRINTERS|SCANNERS|ROUTERS|SWITCHES|"
     r"FIREWALLS|^MONITORS$|SOFTWARE|SYSTEMS$|INFRASTRUCTURE|ASSETS|AMBULANCES|CABINET|CHAIRS|DESKS|TABLES?$|LOCKERS|"
     r"STORAGE|SIGNBOARDS|COUNTERS|RECEIVERS|^TABLETS$", "Asset"),
    (r"_ORAL$|_PARENTERAL$|_TOPICAL$|_OPHTHALMIC$|_OTIC$|_NASAL$|_RECTAL$|_VAGINAL$|_INHALATION$|_INFUSION$|"
     r"NOT_ATC_DEVICE|^DRUG_FORMULARY|^PHARMACEUTICAL$|^FORMULA_|^VITAMINS|^TPN_", "Medication"),
    (r"CLEANING|HOUSEKEEPING|STATIONERY|STAIONARY|PRINTING|PAPER|FORMS|CATERING|LINENS|UNIFORMS|MAINTENACE|WASTE|"
     r"^GENERAL_CONSUMABLES$", "General"),
    (r"^OTHER$", "Other"),
    (r".", "Medical consumable"),
]


def group_of(code):
    up = code.upper()
    return next(group for pattern, group in RULES if re.search(pattern, up))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    rows = client().query(
        "select distinct trimBoth(category_code) from fusion.dim_item_category final "
        f"where organization_id = {MASTER_ORG} and category_set_name = 'HNH Catalog' and ifNull(category_code, '') != '' "
        "order by 1"
    ).result_rows
    out = [(code, group_of(code)) for (code,) in rows]
    with open(args.out, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["CATEGORY_CODE", "ITEM_GROUP"])
        w.writerows(out)
    counts = {}
    for _, g in out:
        counts[g] = counts.get(g, 0) + 1
    print(f"{len(out)} category codes -> {args.out}: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


if __name__ == "__main__":
    main()
