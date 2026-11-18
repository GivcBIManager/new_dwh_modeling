"""The Finance report's pages, in order (`PAGES`), and its report-level filters (`REPORT_FILTERS`); build.py writes
them. Eight pages, a monthly and a hospitals view of each statement; for now empty apart from the frame."""
from __future__ import annotations

import fin_frame
from model import Filter, Page

PAGES: list[Page] = [
    Page(name, fin_frame.DISPLAY[name], fin_frame.page_frame(statement, view), filters=[fin_frame.hospitals()])
    for statement, (monthly, hospitals) in fin_frame.PAGE_NAMES.items()
    for name, view in ((monthly, "monthly"), (hospitals, "hospitals"))
]
REPORT_FILTERS: list[Filter] = []
