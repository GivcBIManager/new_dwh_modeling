"""The Finance report's pages, in order (`PAGES`), and its report-level filters (`REPORT_FILTERS`); build.py writes
them. Home (pages_landing.py, the page the report opens on), then a monthly and a hospitals view of each statement: the
trial balance, income statement and balance sheet pages from pages_statements.py, the two KPI pages from pages_kpi.py;
then How to use and Definitions (pages_landing.py). Every page but Home is hidden: the tabs and buttons are the way
around (user request 2026-11-19)."""
from __future__ import annotations

import fin_frame
import pages_landing
import pages_kpi
import pages_statements
from model import Filter, Page

_STATEMENT_PAGES = {p.name: p for p in [*pages_statements.PAGES, *pages_kpi.PAGES]}

_STATEMENTS: list[Page] = [
    _STATEMENT_PAGES.get(name) or Page(name, fin_frame.DISPLAY[name], fin_frame.page_frame(statement, view),
                                       filters=[fin_frame.hospitals()])
    for statement, (monthly, hospitals) in fin_frame.PAGE_NAMES.items()
    for name, view in ((monthly, "monthly"), (hospitals, "hospitals"))
]
for _p in _STATEMENTS:
    _p.hidden = True

PAGES: list[Page] = [pages_landing.home_page(), *_STATEMENTS, pages_landing.guide_page(), pages_landing.definitions_page()]
REPORT_FILTERS: list[Filter] = []
