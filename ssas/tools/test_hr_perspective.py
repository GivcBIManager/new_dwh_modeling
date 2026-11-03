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


def test_date_month_pick_sorts_by_year_month():
    """Ruling R21: the HR report's Month slicer defaults to 'Last closed month' through 'Date'[Month Pick]."""
    date = (MODEL / "tables" / "Date.tmdl").read_text(encoding="utf-8")
    block = t.re.search(r"(?ms)^\tcolumn 'Month Pick'\n(.*?)(?=^\t\S|\Z)", date)
    assert block, "'Date'[Month Pick] missing"
    assert "\t\tdataType: string\n" in block.group(1)
    assert "\t\tsortByColumn: 'Year Month'\n" in block.group(1)
    assert "\t\tsourceColumn: month_pick\n" in block.group(1)


def test_date_contract_ends_with_month_pick():
    contracts = (MODEL.parents[1] / "hnh_dwh" / "models" / "hnh" / "marts" / "ssas" / "_ssas__models.yml")
    columns = t.contract_columns(contracts.read_text(encoding="utf-8"))["ssas_dim_date"]
    assert (columns[-1].name, columns[-1].ch_type) == ("month_pick", "String")
