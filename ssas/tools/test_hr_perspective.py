"""The HR Dashboard perspective holds what the HR report binds: the Workforce facts, the HR tables and the dimensions
of their visuals, and the measures of the HR Dashboard, Workforce and Balanced Scorecard domains."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

MODEL = Path(__file__).resolve().parents[1] / "HNH_Analytics"
PERSPECTIVE = (MODEL / "perspectives" / "HR Dashboard.tmdl").read_text(encoding="utf-8")
MEASURES_TEXT = (MODEL / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8")
RELATIONSHIPS = (MODEL / "relationships.tmdl").read_text(encoding="utf-8")
PAGE_TABLES = ["HR KPI", "HR Targets", "HR Data Issues", "HR Data Issue Records", "Headcount", "Worker Movements",
               "Payroll", "Absences", "Leave Balances", "Requisitions", "Branch", "Date", "HR Department", "Job",
               "Grade", "Employee", "Employee Details", "Staff", "Time Calculation"]
DOMAINS = {"HR Dashboard", "Workforce", "Balanced Scorecard"}


def test_perspective_holds_the_tables_of_the_pages():
    tables = set(t.re.findall(r"^\tperspectiveTable (.+)$", PERSPECTIVE, t.re.M))
    unquoted = {name.strip("'") for name in tables}
    assert [name for name in PAGE_TABLES if name not in unquoted] == []


def test_perspective_holds_the_measures_of_its_domains():
    shown = set(t.re.findall(r"^\t\tperspectiveMeasure (.+)$", PERSPECTIVE, t.re.M))
    shown = {name.strip("'") for name in shown}
    wanted = {name for name, folder in t.measure_folders(MEASURES_TEXT) if folder.split("\\")[0] in DOMAINS}
    assert sorted(wanted - shown) == []


def test_hr_records_have_no_date_relationship():
    blocks = t.re.split(r"(?m)^relationship ", RELATIONSHIPS)
    bad = [b.splitlines()[0] for b in blocks
           if "fromColumn: 'HR Data Issue Records'." in b and "toColumn: Date." in b]
    assert bad == []
