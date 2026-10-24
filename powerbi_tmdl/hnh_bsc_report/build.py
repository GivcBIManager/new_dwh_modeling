"""Write the Balanced Scorecard report: a Power BI project (default) or the legacy pbix from the template (fallback).

Default, --format pbip: the project in this folder (HNH Balanced Scorecard.pbip, .Report/, .SemanticModel/),
then the checks against Power BI Desktop (pbir_check.py):

    python powerbi_tmdl/hnh_bsc_report/build.py [--database HNH_Analytics_Test]

Fallback, --format pbix: a legacy pbix written from the template (README, appendix "Fallback"):

    python powerbi_tmdl/hnh_bsc_report/build.py --format pbix --database HNH_Analytics_Test \
        --out "powerbi_tmdl/hnh_bsc_report/dist/HNH Balanced Scorecard.pbix"
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from layout import page_section, show_all_on_branch  # noqa: E402
from model import Page  # noqa: E402
from pbix import (SAMPLES_PAGE, check_upload_rules, read_pbix, samples, set_database, set_server,  # noqa: E402
                  write_pbix)

DRILL_SAMPLE_PAGE = "Drill sample"
TEMPLATE = HERE / "template" / "hnh_bsc_template.pbix"
SERVER = "HNHANALYTICSSRV\\REPORTSERVERDB"


def _check_unique(pages: list[Page]) -> None:
    for what, values in (("page name", [p.name for p in pages]), ("page display name", [p.display for p in pages])):
        dups = sorted({v for v in values if values.count(v) > 1})
        if dups:
            raise ValueError(f"duplicate {what}: {', '.join(dups)}")


def _drop_bookmarks(marks: list, sections: set) -> list:
    """Bookmarks (and bookmark groups' children) whose page is still in the report."""
    out = []
    for m in marks:
        if isinstance(m.get("children"), list):
            kids = _drop_bookmarks(m["children"], sections)
            if kids:
                out.append({**m, "children": kids})
        elif (m.get("explorationState") or {}).get("activeSection") in sections:
            out.append(m)
    return out


def build(template: Path, pages: list[Page], database: str, out: Path, server: str = SERVER) -> None:
    """Read the template, write `pages` (in order) in place of its `Samples` and `Drill sample` pages, point the live
    connection at `server` / `database`, write `out` and raise if it breaks the Report Server upload rules."""
    _check_unique(pages)
    p = read_pbix(template)
    smp = samples(p)
    layout = p.layout
    sections = layout.get("sections", [])
    base = next(s for s in sections if s.get("displayName") == SAMPLES_PAGE)
    drill_sample = next((s for s in sections if s.get("displayName") == DRILL_SAMPLE_PAGE), None)

    new_sections, pods = [], []
    for i, page in enumerate(pages):
        section, page_pods = page_section(page, i, smp, layout, drill_sample, base)
        new_sections.append(section)
        pods += page_pods
    layout["sections"] = new_sections
    if pods:
        layout["pods"] = pods
    else:
        layout.pop("pods", None)  # only the template pages' bindings were there
    cfg = json.loads(layout.get("config") or "{}")
    cfg["activeSectionIndex"] = 0
    if "bookmarks" in cfg:  # bookmarks on the template pages would point at pages that are gone
        cfg["bookmarks"] = _drop_bookmarks(cfg["bookmarks"], {s["name"] for s in new_sections})
    layout["config"] = json.dumps(cfg, separators=(",", ":"), ensure_ascii=False)

    names = [json.loads(vc["config"]).get("name") for s in new_sections for vc in s["visualContainers"]]
    dups = sorted({n for n in names if names.count(n) > 1})
    if dups:
        raise ValueError(f"duplicate visual names: {', '.join(dups)}")
    bad = show_all_on_branch(layout)
    if bad:
        raise ValueError("'show items with no data' on a Branch field: " + "; ".join(bad))

    set_server(p, server)
    set_database(p, database)
    write_pbix(p, out)
    problems = check_upload_rules(out)
    if problems:
        raise ValueError(f"{out} breaks the Report Server upload rules: " + "; ".join(problems))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--format", choices=("pbip", "pbix"), default="pbip",
                    help="pbip: the Power BI project (default); pbix: the legacy template route (fallback)")
    ap.add_argument("--template", type=Path, default=TEMPLATE, help="pbix only")
    ap.add_argument("--database", default="HNH_Analytics_Test",
                    help="HNH_Analytics_Test while testing (default), HNH_Analytics for release")
    ap.add_argument("--server", default=SERVER, help=f"SSAS server for the live connection (default {SERVER})")
    ap.add_argument("--out", type=Path,
                    help=f"pbip: the folder for the project (default {HERE}); pbix: the .pbix file (required)")
    ap.add_argument("--pbiviz", type=Path, help="pbip only: the HNH visual package (default: hnh_bsc_visual/dist)")
    args = ap.parse_args(argv)
    try:
        from pages import PAGES
    except ImportError as e:
        print(f"cannot load the page list (pages.py): {e}")
        return 1
    from fields import unknown_fields
    unknown = unknown_fields(PAGES)
    if unknown:
        print("fields not in the Balanced Scorecard perspective: " + ", ".join(unknown))
        return 1
    if args.format == "pbip":
        return _main_pbip(args, PAGES)
    if args.out is None:
        print("--format pbix needs --out <file.pbix>")
        return 1
    args.out.parent.mkdir(parents=True, exist_ok=True)
    try:
        build(args.template, PAGES, args.database, args.out, args.server)
    except (ValueError, OSError) as e:
        print(f"build failed: {e}")
        return 1
    problems = check_upload_rules(args.out)
    print(f"wrote {args.out} ({len(PAGES)} pages, server {args.server}, database {args.database})")
    print("check_upload_rules: " + ("passed" if not problems else "; ".join(problems)))
    return 1 if problems else 0


def _main_pbip(args, pages: list[Page]) -> int:
    from pbir import write_pbip
    import pbir_check
    out = args.out or HERE
    try:
        pbip = write_pbip(pages, out, args.database, args.server, pbiviz=args.pbiviz)
    except (ValueError, OSError) as e:
        print(f"build failed: {e}")
        return 1
    print(f"wrote {pbip} ({len(pages)} pages, server {args.server}, database {args.database})")
    if not pbir_check.desktop_installed():
        print("Power BI Desktop not installed here: schema and project-reader checks skipped")
        return 0
    import tempfile
    try:
        with tempfile.TemporaryDirectory() as tmp:
            problems = pbir_check.validate_report(pbip.with_suffix(".Report"), pbir_check.extract_schemas(tmp))
        opened = pbir_check.desktop_open(pbip)
    except (RuntimeError, OSError) as e:
        print(f"checks against Power BI Desktop failed to run: {e}")
        return 1
    print("report schemas: " + ("passed" if not problems else f"{len(problems)} problems"))
    for p in problems[:20]:
        print("  " + p)
    ok = "FAIL" not in opened and "issue:" not in opened
    print("Desktop project reader: " + ("opened" if ok else "problems"))
    if not ok:
        print(opened)
    return 0 if ok and not problems else 1


if __name__ == "__main__":
    sys.exit(main())
