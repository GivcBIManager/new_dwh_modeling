"""The HR report's pages, in order (`PAGES`), and its report-level filters (`REPORT_FILTERS`); build.py writes them.

Home (pages_home.py), Story (pages_story.py), Scorecard and KPI detail (pages_scorecard.py), the six detail pages and
the Employee list (pages_detail.py); Data quality, How to use and Definitions (pages_dq_guide.py). The Employee list,
a hidden drill-through, is last.
"""
from __future__ import annotations

import hr_frame  # noqa: F401  (puts the BSC generator's modules on the path)
from model import Filter, Page, col
from pages_detail import detail_pages, employee_list_page
from pages_dq_guide import data_quality_page, guide_pages
from pages_home import home_page
from pages_scorecard import kpi_detail_page, scorecard_page
from pages_story import story_page

PAGES: list[Page] = ([home_page(), story_page(), scorecard_page(), kpi_detail_page()] + detail_pages()
                     + [data_quality_page()] + guide_pages() + [employee_list_page()])

# Locked report filter, as the BSC's: this year and last year only ('Date'[Year Offset] 0 and 1, recomputed at each
# refresh), so the Month dropdown lists 24 months rather than the whole Date table. HR data starts in 2026.
REPORT_FILTERS: list[Filter] = [Filter(col("Date", "Year Offset"), "in", [0, 1])]
