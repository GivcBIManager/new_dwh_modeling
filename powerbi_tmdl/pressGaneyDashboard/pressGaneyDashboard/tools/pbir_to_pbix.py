"""Writes the legacy Report Server .pbix of this report with the shared converter
(powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py: the server reads only the legacy `Report/Layout` package).

    python tools/pbir_to_pbix.py [--out "dist/PGaney Patient Survey.pbix"]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT.parents[1] / "hnh_bsc_report"))
import pbir_to_pbix  # noqa: E402
from pbix import check_upload_rules  # noqa: E402

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=str(ROOT / "dist" / "PGaney Patient Survey.pbix"))
    out = Path(ap.parse_args().out)
    layout = pbir_to_pbix.write(ROOT / "PressGaneyDashboard.pbip", out)
    problems = check_upload_rules(out)
    n_visuals = sum(len(s["visualContainers"]) for s in layout["sections"])
    print(f"wrote {out}: {len(layout['sections'])} pages, {n_visuals} visuals; upload rules: {problems or 'ok'}")
    sys.exit(1 if problems else 0)
