"""unknown_fields: every field a page uses must be in the Balanced Scorecard perspective."""
from fields import perspective_fields, unknown_fields
from model import Filter, Page, Visual, col, meas


def page_with(*fields, **kw):
    return Page("p", "P", [Visual("table", 0, 0, 1, 1, roles={"Values": list(fields)}, title=None, **kw)])


def test_known_fields_pass_on_the_real_perspective():
    pages = [page_with(col("Branch", "Branch Name"), col("BSC KPI", "Pillar"), meas("BSC Actual"),
                       col("Time Calculation", "Time Calculation"), col("Date", "Year Month"))]
    assert unknown_fields(pages) == []


def test_unknown_fields_are_reported():
    pages = [page_with(col("Branch", "No Such Column"), meas("No Such Measure"),
                       col("AP Invoice Lines", "Invoice Number"),  # a table outside the perspective
                       meas("Branch Name", table="Branch"))]       # a column named as a measure
    assert unknown_fields(pages) == ["'AP Invoice Lines'[Invoice Number]", "'Branch'[Branch Name] (measure)",
                                     "'Branch'[No Such Column]", "[No Such Measure]"]


def test_every_place_a_field_can_sit_is_checked():
    bad = col("Branch", "Bad")
    pages = [
        Page("a", "A", [], filters=[Filter(col("Branch", "Bad1"), "eq", ["x"])]),
        Page("b", "B", [], drill_fields=[col("Branch", "Bad2")]),
        page_with(meas("BSC Actual"), filters=[Filter(col("Branch", "Bad3"), "eq", ["x"])]),
        page_with(col("Branch", "Branch Name"), top_n=(meas("Bad4"), 5), sort=meas("Bad5")),
        page_with(bad),
        Page("c", "C", [Visual("buttonDrill", 0, 0, 1, 1, title=None, props={"visualLink": [{"properties": {
            "drillthroughSection": {"expr": {"Measure": {"Expression": {"SourceRef": {"Entity": "_Measures"}},
                                                         "Property": "Bad6"}}}}}]})]),
    ]
    assert unknown_fields(pages) == ["'Branch'[Bad1]", "'Branch'[Bad2]", "'Branch'[Bad3]", "'Branch'[Bad]",
                                     "[Bad4]", "[Bad5]", "[Bad6]"]


def test_perspective_column_and_measure_lists(tmp_path):
    (tmp_path / "perspectives").mkdir()
    (tmp_path / "tables").mkdir()
    (tmp_path / "perspectives" / "Balanced Scorecard.tmdl").write_text(
        "perspective 'Balanced Scorecard'\n\n\tperspectiveTable 'T One'\n\t\tperspectiveColumn 'Col A'\n\n"
        "\tperspectiveTable Two\n\t\tincludeAll\n\n\tperspectiveTable _Measures\n\t\tperspectiveMeasure 'M 1'\n",
        encoding="utf-8")
    (tmp_path / "tables" / "T One.tmdl").write_text(
        "table 'T One'\n\n\tcolumn 'Col A'\n\t\tdataType: string\n\n\tcolumn 'Col B'\n\t\tdataType: string\n",
        encoding="utf-8")
    (tmp_path / "tables" / "Two.tmdl").write_text(
        "table Two\n\n\tcolumn X\n\t\tdataType: string\n\n\tmeasure 'Two M' = 1\n", encoding="utf-8")
    (tmp_path / "tables" / "_Measures.tmdl").write_text(
        "table _Measures\n\n\tmeasure 'M 1' = 1\n\n\tmeasure 'M 2' = 2\n", encoding="utf-8")
    cols, measures = perspective_fields(tmp_path)
    assert cols == {("T One", "Col A"), ("Two", "X")}
    assert measures == {("_Measures", "M 1"), ("Two", "Two M")}
    pages = [page_with(col("T One", "Col A"), col("T One", "Col B"), col("Two", "X"), meas("M 1"), meas("M 2"),
                       meas("Two M", table="Two"))]
    assert unknown_fields(pages, tmp_path) == ["'T One'[Col B]", "[M 2]"]
