"""Write the HR report (HNH Workforce) as a Power BI project, with the BSC generator's modules, then check it against
Power BI Desktop (pbir_check.py: Desktop's report schemas and its project reader):

    python powerbi_tmdl/hnh_hr_report/build.py [--database HNH_Analytics_Test]

Same arguments as powerbi_tmdl/hnh_bsc_report/build.py. Only --format pbip is built: the server's legacy package is
written from the project by powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py (powerbi_tmdl/README.md); the BSC's
template route (--format pbix, --template) is for the BSC only. --pbiviz is accepted and unused (no custom visual).
"""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
BSC_DIR = HERE.parent / "hnh_bsc_report"
sys.path.insert(0, str(BSC_DIR))
sys.path.insert(0, str(HERE))  # first: this folder's pages.py, not the BSC's

SERVER = "HNHANALYTICSSRV\\REPORTSERVERDB"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--format", choices=("pbip", "pbix"), default="pbip",
                    help="pbip: the Power BI project (default); pbix: not built here (use pbir_to_pbix.py)")
    ap.add_argument("--template", type=Path, help="pbix only: not used by the HR report")
    ap.add_argument("--database", default="HNH_Analytics_Test",
                    help="HNH_Analytics_Test while testing (default), HNH_Analytics for release")
    ap.add_argument("--server", default=SERVER, help=f"SSAS server for the live connection (default {SERVER})")
    ap.add_argument("--out", type=Path, help=f"the folder for the project (default {HERE})")
    ap.add_argument("--pbiviz", type=Path, help="not used: the HR report has no custom visual")
    args = ap.parse_args(argv)
    if args.format == "pbix":
        print("the HR report is built as a project only; write the legacy package with "
              "powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py \"powerbi_tmdl/hnh_hr_report/HNH Workforce.pbip\" "
              "--out <file.pbix>")
        return 1
    try:
        import pages as pages_module
        pages, report_filters = pages_module.PAGES, pages_module.REPORT_FILTERS
    except (ImportError, AttributeError, ValueError) as e:
        print(f"cannot load the page list (pages.py): {e}")
        return 1
    from fields import unknown_fields
    from hr_frame import HR_REPORT
    unknown = unknown_fields(pages, report_filters=report_filters, perspective=HR_REPORT.perspective)
    if unknown:
        print(f"fields not in the {HR_REPORT.perspective} perspective: " + ", ".join(unknown))
        return 1

    import pbir_check
    from pbir import write_pbip
    out = args.out or HERE
    try:
        pbip = write_pbip(pages, out, args.database, args.server, report_filters=report_filters, report=HR_REPORT)
    except (ValueError, OSError) as e:
        print(f"build failed: {e}")
        return 1
    print(f"wrote {pbip} ({len(pages)} pages, server {args.server}, database {args.database})")
    if not pbir_check.desktop_installed():
        print("Power BI Desktop not installed here: schema and project-reader checks skipped")
        return 0
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
