"""The Finance Report perspective and the tables behind the finance report (finance report plan, Task 7)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

MODEL = Path(__file__).resolve().parents[1] / "HNH_Analytics"
RELATIONSHIPS = (MODEL / "relationships.tmdl").read_text(encoding="utf-8")
MEASURES_TEXT = (MODEL / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8")
REPORT_TABLES = ["GL FS Monthly", "P&L Report", "P&L Line", "Finance Budget", "Finance KPI", "Finance Column",
                 "Finance Target", "Branch", "Date", "Time Calculation"]


def perspective(name):
    text = (MODEL / "perspectives" / f"{name}.tmdl").read_text(encoding="utf-8")
    return {n.strip("'") for n in t.re.findall(r"^\tperspectiveTable (.+)$", text, t.re.M)}, text


def table_text(name):
    return (MODEL / "tables" / f"{name}.tmdl").read_text(encoding="utf-8")


def column_block(table, column):
    pattern = r"(?ms)^\tcolumn " + t.re.escape(t.q(column)) + r"\n(.*?)(?=^\t\S|\Z)"
    block = t.re.search(pattern, table_text(table))
    assert block, f"{table}[{column}] missing"
    return block.group(1)


def test_finance_report_perspective_has_the_report_tables():
    tables, text = perspective("Finance Report")
    assert [n for n in REPORT_TABLES if n not in tables] == []
    shown = {n.strip("'") for n in t.re.findall(r"^\t\tperspectiveMeasure (.+)$", text, t.re.M)}
    wanted = {n for n, folder in t.measure_folders(MEASURES_TEXT) if folder.split("\\")[0] == "Finance"}
    assert sorted(wanted - shown) == []


def test_scorecard_and_hr_perspectives_read_the_pl_report_and_budget():
    for name in ("Balanced Scorecard", "HR Dashboard"):
        tables, _ = perspective(name)
        assert {"P&L Report", "Finance Budget"} <= tables, name


def test_finance_budget_relates_to_branch_date_and_pl_line():
    blocks = t.re.split(r"(?m)^relationship ", RELATIONSHIPS)
    mine = [b for b in blocks if "fromColumn: 'Finance Budget'." in b]
    targets = sorted(t.re.search(r"toColumn: (.+)", b).group(1) for b in mine)
    assert targets == sorted(["Branch.'Branch Key'", "Date.'Date Key'", "'P&L Line'.'PL Line Key'"]), targets
    date = next(b for b in mine if "toColumn: Date." in b)
    assert "isActive: false" not in date


def test_finance_dims_have_no_relationship():
    for name in ("Finance KPI", "Finance Column", "Finance Target"):
        assert f"'{name}'." not in RELATIONSHIPS


def test_column_names_follow_the_plan():
    names = {
        "Finance KPI": ["KPI Code", "KPI Group", "KPI Name"],
        "GL FS Monthly": ["BS Side", "BS Element", "BS Category", "BS Caption", "FS Caption Name", "Account Name"],
        "Date": ["Year Pick"],
        "Finance Column": ["Group Name", "Column Name", "Kind", "Page", "View", "Month Num"],
        "P&L Report": ["Account Name", "FS Caption Name"],
    }
    for table, columns in names.items():
        for column in columns:
            column_block(table, column)


def test_sort_by_columns():
    pairs = [("Date", "Year Pick", "Year"), ("Finance Column", "Column Name", "Column Order"),
             ("Finance Column", "Group Name", "Group Order"), ("Finance KPI", "KPI Name", "Display Order"),
             ("Finance KPI", "KPI Group", "Group Order"), ("GL FS Monthly", "BS Element", "BS Element Order"),
             ("GL FS Monthly", "BS Category", "BS Category Order")]
    for table, column, sort in pairs:
        assert f"\t\tsortByColumn: {t.q(sort)}\n" in column_block(table, column), (table, column)
