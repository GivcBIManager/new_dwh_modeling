"""The HR report's pages, in order (`PAGES`), and its report-level filters (`REPORT_FILTERS`); build.py writes them.

Home (pages_home.py) for now; Story, Scorecard and KPI detail, the six detail pages, Data quality and the two Guide
pages follow (plan docs/superpowers/plans/2026-11-02-hr-dashboard.md, tasks 12 to 15).
"""
from __future__ import annotations

import hr_frame  # noqa: F401  (puts the BSC generator's modules on the path)
from model import Filter, Page, col
from pages_home import home_page

PAGES: list[Page] = [home_page()]

# Locked report filter, as the BSC's: this year and last year only ('Date'[Year Offset] 0 and 1, recomputed at each
# refresh), so the Month dropdown lists 24 months rather than the whole Date table. HR data starts in 2026.
REPORT_FILTERS: list[Filter] = [Filter(col("Date", "Year Offset"), "in", [0, 1])]
