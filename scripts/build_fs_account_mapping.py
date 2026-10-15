"""Build static_mappings/fs_account_mapping.csv (default.map_fs_account) from finance's TB mapping workbook.

The workbook ("Mapping - TB 2026 Oracle", one sheet, one row per branch and natural account with its FS position)
is the supplied mapping, with the label fixes in LABEL_FIXES and CATEGORY_ELEMENT. Per account the position most
hospitals use is the default row (BRANCH_CODE blank, all branches); a branch that maps the account differently gets
its own row with its Fusion branch code. Head Office maps staff, utilities and maintenance to G&A where the hospitals
map them to Direct Cost, so those accounts get a 101 row.

Accounts not in the workbook:
- a row supplied earlier (previous file, MAPPED_IN other than 'inferred') is kept;
- every other Fusion account is inferred again from its 6-digit parent group: when at least two supplied accounts in
  the group exist and all share one FS position, the account takes it. Depreciation, accumulated depreciation and
  PP&E cost accounts whose group has per-asset lines take the line of the same asset class (see asset_line).

Reads only local files. Export the two inputs read-only through the HNH_Gold DSN (scripts/HnhCh.psm1):
  previous:  select * from default.map_fs_account
  accounts:  select natural_account, any(natural_account_name) as name from gold.dim_gl_account
             where code_combination_id is not null group by natural_account

Usage:  python scripts/build_fs_account_mapping.py --workbook "<TB mapping>.xlsx" --previous prev.csv --accounts accounts.csv
            [--out static_mappings/fs_account_mapping.csv] [--review static_mappings/review/fs_account_mapping_changes.csv]
"""
import argparse
import csv
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parent.parent
LEVELS = ["FS_TYPE", "FS_ELEMENT", "FS_CATEGORY", "FS_CAPTION", "FS_LINE"]
COLUMNS = ["ORACLE_CODE", "BRANCH_CODE", *LEVELS, "MAPPED_IN"]

# Workbook branch name -> Fusion branch code (COA segment 1, gold.dim_branch.fusion_branch_code).
BRANCH_CODES = {"Head Office": 101, "Alrabwah": 102, "Ghirnata": 103, "Abha": 104, "Jazan": 105, "Unaizah": 106,
                "Khamis": 107, "Madinah": 108, "Muhayil": 109}
HEAD_OFFICE = 101
# MAPPED_IN of a workbook row: this prefix and the branches that list the account with that position. Rows kept from
# the first mapping (abha_fs_mapping_oracle.xlsx) keep its values: abha, ghirnata, abha,ghirnata.
SOURCE = "tb2026:"

# Label corrections agreed with finance on 2026-10-14, applied after trimming and collapsing spaces.
LABEL_FIXES = {
    "FS_CATEGORY": {"Other income": "Other income, net"},
    "FS_CAPTION": {"Govnernment grant": "Government grant", "Other income": "Other income, net",
                   "General and administrative expenses": "Other indirect Expenses"},
    "FS_LINE": {"Medical Equipments Maintenance": "Medical Equipment Maintenance"},
}

# Element that goes with a category wherever the workbook disagrees (Jazan had Rental Income under Revenue).
CATEGORY_ELEMENT = {"Other income, net": "Other income"}

# PP&E families by natural account prefix, and the line template of each family's labels ({} is the asset class).
# The last two digits name the asset class in every family: 12201108, 12202108 and 55101108 are Medical Furniture.
ASSET_FAMILIES = {"122011": "cost", "122031": "cost", "122021": "accm", "551011": "dep"}
ASSET_TEMPLATES = {"cost": "{} Cost", "accm": "{} Accm Dep", "dep": "Depreciation Expense - {}"}


def label(level, value):
    text = re.sub(r"\s+", " ", str(value or "").replace("\xa0", " ")).strip().replace("Deprecition", "Depreciation")
    if level == "FS_TYPE":
        text = text.upper()
    return LABEL_FIXES.get(level, {}).get(text, text)


def position(values):
    """The five FS levels, cleaned, with the element made consistent with the category."""
    pos = [label(lvl, v) for lvl, v in zip(LEVELS, values)]
    pos[1] = CATEGORY_ELEMENT.get(pos[2], pos[1])
    return tuple(pos)


def read_workbook(path):
    ws = load_workbook(path, read_only=True, data_only=True).active
    header = [str(c or "").strip() for c in next(ws.iter_rows(min_row=2, max_row=2, values_only=True))]
    col = {name: header.index(name) for name in ["Branch Name", "FS Type", "FS Element", "FS Category", "FS Caption",
                                                 "FS Line", "Natural Account"]}
    rows = []
    for r in ws.iter_rows(min_row=3, values_only=True):
        if r[col["Natural Account"]] is None or r[col["Branch Name"]] in (None, "Grand Total"):
            continue
        branch = str(r[col["Branch Name"]]).strip()
        if branch not in BRANCH_CODES:
            raise SystemExit(f"workbook: unknown branch {branch!r}")
        pos = position(r[col[name]] for name in ["FS Type", "FS Element", "FS Category", "FS Caption", "FS Line"])
        if not all(pos):
            raise SystemExit(f"workbook: blank FS level for {branch} {r[col['Natural Account']]}")
        rows.append((int(r[col["Natural Account"]]), branch, pos))
    return rows


def pick_default(account, by_branch, names):
    """Position for all branches: the one most hospitals use; Head Office only when no hospital lists the account.
    A tie goes to the position whose line is the Fusion account name, then to the lowest branch code."""
    hospitals = {b: p for b, p in by_branch.items() if BRANCH_CODES[b] != HEAD_OFFICE} or by_branch
    counts = Counter(hospitals.values())
    top = max(counts.values())
    tied = [p for p, n in counts.items() if n == top]
    name = names.get(account, "").strip().lower()
    return min(tied, key=lambda p: (p[4].lower() != name, min(BRANCH_CODES[b] for b, q in hospitals.items() if q == p)))


def asset_class(line, family):
    prefix, suffix = ASSET_TEMPLATES[family].split("{}")
    if line.startswith(prefix) and line.endswith(suffix) and len(line) > len(prefix) + len(suffix):
        return line[len(prefix):len(line) - len(suffix)]
    return None


def asset_line(acc, family, classes, names):
    """Line of a PP&E account in its family's words. In order: a mapped account of the same family and class;
    the class another family uses for these digits, translated through a class both families have mapped
    (Laundry is "Catering & Laundry Cost", and Catering's depreciation line is "Depreciation Expense - Catering");
    that other family's class as is; the asset class in the Fusion account name."""
    digits = str(acc)[-2:]

    def one(fam, d):
        found = classes[fam].get(d, set())
        return next(iter(found)) if len(found) == 1 else None

    if one(family, digits):
        return ASSET_TEMPLATES[family].format(one(family, digits))
    others = [f for f in ASSET_TEMPLATES if f != family and one(f, digits)]
    for other in others:
        cls = one(other, digits)
        translated = {one(family, d) for d, found in classes[other].items() if found == {cls} and one(family, d)}
        if len(translated) == 1:
            return ASSET_TEMPLATES[family].format(translated.pop())
    if others:
        return ASSET_TEMPLATES[family].format(one(others[0], digits))
    name = re.sub(r"(?i)\s*clearing.*$|'s\b", "", names.get(acc, "").rsplit("-", 1)[-1]).strip()
    return ASSET_TEMPLATES[family].format(name) if name else None


def infer(accounts, mapped, names):
    """FS position for Fusion accounts without a row, from supplied siblings (see module docstring)."""
    groups = defaultdict(list)
    for acc, pos in mapped.items():
        groups[str(acc)[:6]].append(pos)
    classes = {f: defaultdict(set) for f in ASSET_TEMPLATES}  # family -> last two digits -> asset classes
    for acc, pos in mapped.items():
        family = ASSET_FAMILIES.get(str(acc)[:6])
        cls = family and asset_class(pos[4], family)
        if cls:
            classes[family][str(acc)[-2:]].add(cls)
    out = {}
    for acc in accounts:
        if acc in mapped:
            continue
        sibs = groups.get(str(acc)[:6], [])
        if len(sibs) >= 2 and len(set(sibs)) == 1:
            out[acc] = sibs[0]
            continue
        family = ASSET_FAMILIES.get(str(acc)[:6])
        if family and len(sibs) >= 2 and len({p[:4] for p in sibs}) == 1:
            line = asset_line(acc, family, classes, names)
            if line:
                out[acc] = sibs[0][:4] + (line,)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workbook", required=True)
    ap.add_argument("--previous", required=True, help="current default.map_fs_account as CSV")
    ap.add_argument("--accounts", required=True, help="Fusion natural accounts as CSV (natural_account, name)")
    ap.add_argument("--out", default=str(ROOT / "static_mappings" / "fs_account_mapping.csv"))
    ap.add_argument("--review", default=str(ROOT / "static_mappings" / "review" / "fs_account_mapping_changes.csv"))
    args = ap.parse_args()

    with open(args.accounts, encoding="utf-8-sig", newline="") as fh:
        names = {int(float(r["natural_account"])): r["name"] or "" for r in csv.DictReader(fh)}
    with open(args.previous, encoding="utf-8-sig", newline="") as fh:
        previous = list(csv.DictReader(fh))

    wb = defaultdict(dict)
    for acc, branch, pos in read_workbook(args.workbook):
        if branch in wb[acc]:
            raise SystemExit(f"workbook: {branch} lists {acc} twice")
        wb[acc][branch] = pos

    rows = []  # (account, branch code or None, position, mapped_in)
    for acc in sorted(wb):
        default = pick_default(acc, wb[acc], names)
        users = sorted((b for b, p in wb[acc].items() if p == default), key=BRANCH_CODES.get)
        rows.append((acc, None, default, SOURCE + ",".join(b.lower() for b in users)))
        for b in sorted(wb[acc], key=BRANCH_CODES.get):
            if wb[acc][b] != default:
                rows.append((acc, BRANCH_CODES[b], wb[acc][b], SOURCE + b.lower()))

    prev_default = {}
    for r in previous:
        if str(r.get("BRANCH_CODE") or "") not in ("", "0", "\\N"):
            continue
        prev_default[int(float(r["ORACLE_CODE"]))] = (position(r[lvl] for lvl in LEVELS), r["MAPPED_IN"])
    for acc, (pos, mapped_in) in sorted(prev_default.items()):
        if acc not in wb and mapped_in != "inferred":
            rows.append((acc, None, pos, mapped_in))

    supplied = {acc: pos for acc, br, pos, _ in rows if br is None}
    for acc, pos in sorted(infer(sorted(names), supplied, names).items()):
        rows.append((acc, None, pos, "inferred"))
    rows.sort(key=lambda r: (r[0], r[1] or 0))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(COLUMNS)
        for acc, br, pos, mapped_in in rows:
            w.writerow([acc, "" if br is None else br, *pos, mapped_in])

    # Review: every account whose default position, branch rows or source changed against the previous file.
    new_default = {acc: (pos, m) for acc, br, pos, m in rows if br is None}
    branch_rows = defaultdict(list)
    for acc, br, pos, _ in rows:
        if br is not None:
            branch_rows[acc].append(f"{br}: {' | '.join(pos[2:])}")
    review = Path(args.review)
    review.parent.mkdir(parents=True, exist_ok=True)
    counts = Counter()
    with open(review, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["CHANGE", "ORACLE_CODE", "ACCOUNT_NAME", "OLD_MAPPED_IN", "NEW_MAPPED_IN", "CHANGED_LEVELS",
                    *[f"OLD_{lvl}" for lvl in LEVELS], *[f"NEW_{lvl}" for lvl in LEVELS], "BRANCH_ROWS"])
        for acc in sorted(set(prev_default) | set(new_default)):
            old_pos, old_m = prev_default.get(acc, (("",) * 5, ""))
            new_pos, new_m = new_default.get(acc, (("",) * 5, ""))
            change = ("new" if acc not in prev_default else "removed" if acc not in new_default
                      else "changed" if old_pos != new_pos else "branch rows" if branch_rows.get(acc) else "")
            if not change:
                continue
            counts[change] += 1
            diff = [lvl for lvl, a, b in zip(LEVELS, old_pos, new_pos) if a != b]
            w.writerow([change, acc, names.get(acc, ""), old_m, new_m, ",".join(diff), *old_pos, *new_pos,
                        "; ".join(branch_rows.get(acc, []))])

    by_source = Counter("inferred" if m == "inferred" else "branch" if br is not None else "supplied"
                        for _, br, _, m in rows)
    print(f"{out}: {len(rows)} rows ({by_source['supplied']} supplied, {by_source['inferred']} inferred, "
          f"{by_source['branch']} branch rows) for {len(new_default)} accounts")
    print(f"{review}: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


if __name__ == "__main__":
    sys.exit(main())
