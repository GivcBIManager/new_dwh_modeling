"""The Balanced Scorecard perspective holds what the report's detail pages bind (bsc report plan, Tasks 3 and 6):
the measures of the six family domains and every table those pages use."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

MODEL = Path(__file__).resolve().parents[1] / "HNH_Analytics"
PERSPECTIVE = (MODEL / "perspectives" / "Balanced Scorecard.tmdl").read_text(encoding="utf-8")
MEASURES_TEXT = (MODEL / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8")
# Task 6's pages: FS Line, GL Account, Headcount, Worker Movements, Order Lines, Survey Responses, the dimensions of
# their charts and tables, and Staff, the doctor of Charge Lines.
PAGE_TABLES = ["FS Line", "GL Account", "Headcount", "Worker Movements", "Order Lines", "Survey Responses",
               "Discharge Outcome", "NPHIES Reason", "Claim Status", "Product Category", "HR Department", "Job",
               "Employee", "Survey Question", "Department", "Payer", "Bed", "Staff", "Branch", "Date", "Charge Lines"]
DOMAINS = {"Revenue Cycle", "Claims & Pre-auth", "Finance", "Patient Flow", "Workforce", "Patient Experience",
           "Balanced Scorecard"}


def test_perspective_holds_the_tables_of_the_detail_pages():
    tables = set(t.re.findall(r"^\tperspectiveTable (.+)$", PERSPECTIVE, t.re.M))
    unquoted = {name.strip("'") for name in tables}
    assert [name for name in PAGE_TABLES if name not in unquoted] == []


def test_perspective_holds_the_measures_of_the_six_domains():
    shown = set(t.re.findall(r"^\t\tperspectiveMeasure (.+)$", PERSPECTIVE, t.re.M))
    shown = {name.strip("'") for name in shown}
    wanted = {name for name, folder in t.measure_folders(MEASURES_TEXT) if folder.split("\\")[0] in DOMAINS}
    assert sorted(wanted - shown) == []
