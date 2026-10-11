import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

FACT = t.Table("ssas_fact_charge_line", "Charge Lines", "fact", "One charge line.", "delivery_date_key")
DIM = t.Table("ssas_dim_branch", "Branch", "dim", "Branches.")
DATE = t.Table("ssas_dim_date", "Date", "date", "Days.")

CFG = SimpleNamespace(
    DIM_KEYS={"branch_key": ("Branch", "branch_key"), "staff_key": ("Staff", "staff_key")},
    ROLE_KEYS={("Charge Lines", "episode_payer_key"): ("Payer", "payer_key", False),
               ("Charge Lines", "billed_payer_key"): ("Payer", "payer_key", True)},
    NO_RELATIONSHIP={("Charge Lines", "order_key")},
    ACTIVE_DATE={"Charge Lines": "delivery_date_key"},
    ACTIVE_TIME={"Charge Lines": "delivery_time_key"},
)


def test_friendly_names_and_acronyms():
    assert t.friendly("los_days") == "LOS Days"
    assert t.friendly("staff_name_ar") == "Staff Name AR"
    assert t.friendly("can_see_pii") == "Can See PII"
    assert t.friendly("is_icu_readmission_48h") == "Is ICU Readmission 48h"


def test_quoting():
    assert t.q("Branch") == "Branch"
    assert t.q("Charge Lines") == "'Charge Lines'"
    assert t.q("Patient's") == "'Patient''s'"


def test_types():
    assert t.unwrap("LowCardinality(Nullable(String))") == ("String", True)
    assert t.tmdl_type("Nullable(Int64)") == "int64"
    assert t.tmdl_type("Decimal(18, 4)") == "decimal"
    assert t.tmdl_type("Float64") == "double"
    assert t.tmdl_type("DateTime('Asia/Riyadh')") == "dateTime"
    with pytest.raises(ValueError):
        t.tmdl_type("Array(String)")


def test_fact_amount_is_hidden_without_attribute_hierarchy():
    lines = t.column_lines(FACT, t.Column("revenue_amount", "Decimal(18, 4)"), {}, {})
    assert lines[0] == "\tcolumn 'Revenue Amount'"
    assert "\t\tdataType: decimal" in lines
    assert "\t\tisHidden" in lines
    assert "\t\tisAvailableInMdx: false" in lines
    assert "\t\tformatString: #,0.00" in lines
    assert lines[-1] == "\t\tsourceColumn: revenue_amount"


def test_fact_text_stays_visible():
    lines = t.column_lines(FACT, t.Column("charge_status", "String"), {}, {})
    assert "\t\tisHidden" not in lines


def test_key_encoding_hints():
    surrogate = t.column_lines(FACT, t.Column("staff_key", "Int64"), {}, {})
    date_key = t.column_lines(FACT, t.Column("delivery_date_key", "Int64"), {}, {})
    assert "\t\tencodingHint: hash" in surrogate
    assert "\t\tencodingHint: value" in date_key


def test_dimension_key_keeps_attribute_hierarchy():
    lines = t.column_lines(DIM, t.Column("branch_key", "Int64"), {}, {})
    assert "\t\tisHidden" in lines
    assert "\t\tisAvailableInMdx: false" not in lines


def test_date_key_column_override_and_sort():
    overrides = {("ssas_dim_date", "date_day"): "Date"}
    day = t.column_lines(DATE, t.Column("date_day", "Date"), overrides, {})
    assert day[0] == "\tcolumn Date" and "\t\tisKey" in day and "\t\tformatString: yyyy-mm-dd" in day
    month = t.column_lines(DATE, t.Column("month_name", "String"), overrides, {("ssas_dim_date", "month_name"): "month"})
    assert "\t\tsortByColumn: Month" in month


def test_partitions():
    assert t.partition_lines(FACT) == [
        "\tpartition 'Charge Lines template' = m",
        "\t\tsource =",
        "\t\t\t\tlet",
        '\t\t\t\t    Source = Odbc.Query("dsn=HNH_Gold", "select * from gold.ssas_fact_charge_line where 1 = 0")',
        "\t\t\t\tin",
        "\t\t\t\t    Source",
    ]
    assert t.partition_lines(DIM)[3] == '\t\t\t\t    Source = Odbc.Query("dsn=HNH_Gold", "select * from gold.ssas_dim_branch")'


def test_odbc_expression_escapes_m_quotes():
    assert t.odbc_expression('select "a"') == 'let\n    Source = Odbc.Query("dsn=HNH_Gold", "select ""a""")\nin\n    Source'


def test_data_source_is_structured_odbc():
    lines = t.DATA_SOURCES_TMDL.splitlines()
    assert lines[0] == "dataSource HNH_Gold"
    assert '\t\t\t      "dsn": "HNH_Gold"' in lines and "\t\tprotocol: odbc" in lines
    assert "\t\tauthenticationKind: Anonymous" in lines and "MSDASQL" not in t.DATA_SOURCES_TMDL


def test_kept_blocks_keep_measures_and_hierarchies_verbatim():
    text = (
        "/// One charge line.\n"
        "table 'Charge Lines'\n"
        "\n"
        "\t/// Recognised revenue.\n"
        "\tmeasure Revenue =\n"
        "\t\t\tSUM ( 'Charge Lines'[Revenue Amount] )\n"
        "\t\tformatString: #,0\n"
        "\n"
        "\t\tformatStringDefinition = \"#,0\"\n"
        "\n"
        "\t/// a column description that must not be kept\n"
        "\tcolumn 'Revenue Amount'\n"
        "\t\tdataType: decimal\n"
        "\n"
        "\thierarchy Calendar\n"
        "\n"
        "\t\tlevel Year\n"
        "\t\t\tcolumn: Year\n"
    )
    blocks = t.kept_blocks(text)
    assert blocks[0].startswith("\t/// Recognised revenue.\n\tmeasure Revenue =")
    assert blocks[0].endswith('formatStringDefinition = "#,0"')
    assert "column 'Revenue Amount'" not in blocks[0]
    assert blocks[1].startswith("\thierarchy Calendar") and blocks[1].endswith("\t\t\tcolumn: Year")
    assert len(blocks) == 2


def test_kept_blocks_keep_whitespace_only_lines_inside_a_block():
    blocks = t.kept_blocks("table T\n\tmeasure A = 1\n\t\n\t\tformatString: 0\n")
    assert len(blocks) == 1
    assert blocks[0].endswith("\t\tformatString: 0")


def test_render_table_puts_kept_blocks_first_and_annotations_last():
    text = t.render_table(FACT, [t.Column("delivery_date_key", "Int64")], {}, {}, ["\tmeasure X = 1"])
    lines = text.splitlines()
    assert lines[0] == "/// One charge line." and lines[1] == "table 'Charge Lines'"
    assert lines.index("\tmeasure X = 1") < lines.index("\tcolumn 'Delivery Date Key'")
    assert lines[-1] == "\tannotation hnh_partition_column = delivery_date_key"
    with pytest.raises(ValueError):
        t.render_table(FACT, [t.Column("branch_key", "Int64")], {}, {}, [])


def test_derive_relationships():
    cols = [t.Column(n, "Int64") for n in
            ["branch_key", "delivery_date_key", "posted_date_key", "delivery_time_key", "billed_payer_key",
             "episode_payer_key", "order_key", "units"]]
    rels = {(r.from_column, r.to_table, r.active) for r in t.derive_relationships(FACT, cols, CFG)}
    assert rels == {
        ("branch_key", "Branch", True), ("delivery_date_key", "Date", True), ("posted_date_key", "Date", False),
        ("delivery_time_key", "Time", True), ("billed_payer_key", "Payer", True), ("episode_payer_key", "Payer", False),
    }
    with pytest.raises(ValueError):
        t.derive_relationships(FACT, [t.Column("mystery_key", "Int64")], CFG)
    assert t.derive_relationships(DIM, [t.Column("branch_key", "Int64")], CFG) == []


def test_check_relationships():
    ok = [t.Relationship("Charge Lines", "delivery_date_key", "Date", "date_key")]
    t.check_relationships(ok, [FACT])
    twice = ok + [t.Relationship("Charge Lines", "posted_date_key", "Date", "date_key")]
    with pytest.raises(ValueError):
        t.check_relationships(twice, [FACT])
    no_active = [t.Relationship("Charge Lines", "posted_date_key", "Date", "date_key", active=False)]
    with pytest.raises(ValueError):
        t.check_relationships(no_active, [FACT])


def test_render_relationships():
    rels = [t.Relationship("Charge Lines", "episode_payer_key", "Payer", "payer_key", active=False),
            t.Relationship("Patient Details", "patient_key", "Patient", "patient_key", both_directions=True)]
    text = t.render_relationships(rels, lambda table, col: t.friendly(col))
    assert "relationship charge_lines_episode_payer_key\n\tisActive: false\n" in text
    assert "\tfromColumn: 'Charge Lines'.'Episode Payer Key'\n\ttoColumn: Payer.'Payer Key'" in text
    assert ("relationship patient_details_patient_key\n\tcrossFilteringBehavior: bothDirections\n"
            "\tsecurityFilteringBehavior: oneDirection\n\tfromColumn:") in text
    # Decision P27: never one-to-one; SSAS applies a row filter both ways across a one-to-one relationship.
    assert "fromCardinality" not in text


def test_perspective_closure_follows_snowflake_but_not_both_directions():
    rels = [t.Relationship("GL Balances", "gl_account_key", "GL Account", "gl_account_key"),
            t.Relationship("GL Account", "fs_line_key", "FS Line", "fs_line_key"),
            t.Relationship("Patient Details", "patient_key", "Patient", "patient_key", both_directions=True)]
    assert t.perspective_tables(["GL Balances"], rels, []) == ["FS Line", "GL Account", "GL Balances"]
    assert t.perspective_tables([], rels, ["Patient Details"]) == ["Patient Details"]
    text = t.render_perspective("Finance", ["GL Balances"])
    assert text == "perspective Finance\n\n\tperspectiveTable 'GL Balances'\n\t\tincludeAll\n"


MEASURES_TMDL = (
    "table _Measures\n"
    "\n"
    "\t/// Revenue.\n"
    "\tmeasure Revenue = SUM ( 'Charge Lines'[Revenue Amount] )\n"
    "\t\tformatString: #,0\n"
    "\t\tdisplayFolder: Revenue Cycle\\Revenue\n"
    "\n"
    "\tmeasure 'Hospital NPS (5-point)' =\n"
    "\t\t\tVAR x = 1\n"
    "\t\t\tRETURN x\n"
    "\t\tdisplayFolder: Patient Experience\\NPS\n"
    "\t\n"
    "\t\tformatStringDefinition =\n"
    "\t\t\t\t\"0.0\"\n"
    "\n"
    "\tmeasure 'Current User' = USERPRINCIPALNAME ()\n"
    "\t\tdisplayFolder: Diagnostics\n"
    "\n"
    "\tcolumn Measure\n"
    "\t\tdataType: string\n"
)


def test_measure_folders_reads_names_and_folders():
    assert t.measure_folders(MEASURES_TMDL) == [
        ("Revenue", "Revenue Cycle\\Revenue"),
        ("Hospital NPS (5-point)", "Patient Experience\\NPS"),
        ("Current User", "Diagnostics"),
    ]


def test_perspective_measures_by_folder_domain():
    folders = t.measure_folders(MEASURES_TMDL)
    assert t.perspective_measures("Revenue Cycle", folders, {}) == ["Current User", "Revenue"]
    assert t.perspective_measures("Executive", folders, {"Executive": None}) == [
        "Current User", "Hospital NPS (5-point)", "Revenue"]
    assert t.perspective_measures("Patient Details", folders, {"Patient Details": ["Revenue Cycle"]}) == [
        "Current User", "Revenue"]


def test_render_perspective_lists_measures_of_the_measure_table():
    text = t.render_perspective("Finance", ["GL Balances"], ["Current User", "GL Closing Balance"])
    assert text.endswith(
        "\n\tperspectiveTable _Measures\n"
        "\t\tperspectiveMeasure 'Current User'\n"
        "\t\tperspectiveMeasure 'GL Closing Balance'\n"
    )


def test_render_model():
    text = t.render_model(["Branch", "Charge Lines"], ["HNH Readers"], ["Finance"])
    assert text.startswith("model Model\n\tculture: en-US\n\tdiscourageImplicitMeasures\n")
    assert "ref table 'Charge Lines'\n" in text and "ref role 'HNH Readers'\n" in text
    assert text.endswith("ref perspective Finance\n")
    assert "compatibilityMode: analysisServices" in t.DATABASE_TMDL


SNAPSHOT_TMDL = (
    "\t/// Stock value.\n"
    "\tmeasure 'Stock Value' = 1\n"
    "\t\tformatString: #,0\n"
    "\t\tdisplayFolder: Supply Chain\\Stock\n"
    "\n"
    "\t\tannotation hnh_snapshot = 1\n"
)


def test_measures_reads_descriptions_properties_annotations_and_dax():
    found = t.measures(MEASURES_TMDL + SNAPSHOT_TMDL)
    assert [m.name for m in found] == ["Revenue", "Hospital NPS (5-point)", "Current User", "Stock Value"]
    revenue, nps, user, stock = found
    assert (revenue.description, revenue.folder, revenue.format_string) == ("Revenue.", "Revenue Cycle\\Revenue", "#,0")
    assert revenue.expression == "SUM ( 'Charge Lines'[Revenue Amount] )"
    assert nps.description == ""
    assert nps.expression == "VAR x = 1\nRETURN x"
    assert nps.format_expression == '"0.0"'
    assert user.expression == "USERPRINCIPALNAME ()"
    assert stock.annotations == {"hnh_snapshot": "1"}
    assert revenue.annotations == {}


def test_dax_references_skip_strings_comments_and_addcolumns_names():
    columns, names = t.dax_references(
        "CALCULATE ( [OP Visits], 'Date'[Year] = 2026, Branch[Branch Key] = 1 ) -- [Not A Measure]\n"
        "+ SUMX ( ADDCOLUMNS ( VALUES ( 'Date'[Year Month] ), \"@Fte\", [FTE] ), [@Fte] ) & \"[text]\""
    )
    assert columns == {("Date", "Year"), ("Branch", "Branch Key"), ("Date", "Year Month")}
    assert names == {"OP Visits", "FTE"}


def test_snapshot_lists_read_names_with_parentheses():
    text = (
        "IF ( ISSELECTEDMEASURE ( [Headcount], [GL Closing Balance (incl. Unposted)] ), x )\n"
        "IF ( ISSELECTEDMEASURE ( [Stock Value] ), y )"
    )
    assert t.snapshot_lists(text) == [["Headcount", "GL Closing Balance (incl. Unposted)"], ["Stock Value"]]


def test_table_columns():
    assert t.table_columns(MEASURES_TMDL) == ("_Measures", {"Measure"})


def test_replace_perspective_measures_matches_render_perspective():
    bare = t.render_perspective("Finance", ["GL Balances"])
    one = t.render_perspective("Finance", ["GL Balances"], ["Current User"])
    two = t.render_perspective("Finance", ["GL Balances"], ["Current User", "GL Movement"])
    assert t.replace_perspective_measures(one, ["Current User", "GL Movement"]) == two
    assert t.replace_perspective_measures(bare, ["Current User"]) == one
    assert t.replace_perspective_measures(two, []) == bare


CONTRACTS_YML = (
    "version: 2\n"
    "\n"
    "# Generated by scripts/gen_view_contracts.py from the built views; do not edit by hand.\n"
    "models:\n"
    "  - name: ssas_dim_branch\n"
    "    config:\n"
    "      contract: {enforced: true}\n"
    "    columns:\n"
    "      - name: branch_key\n"
    "        data_type: \"Int64\"\n"
    "      - name: branch_name\n"
    "        data_type: \"Nullable(String)\"\n"
    "  - name: ssas_fact_absence_daily\n"
    "    config:\n"
    "      contract: {enforced: true}\n"
    "    columns:\n"
    "      - name: absence_days\n"
    "        data_type: \"Int64\"\n"
)


def test_contract_columns_reads_views_columns_and_types_in_order():
    assert t.contract_columns(CONTRACTS_YML) == {
        "ssas_dim_branch": [t.Column("branch_key", "Int64"), t.Column("branch_name", "Nullable(String)")],
        "ssas_fact_absence_daily": [t.Column("absence_days", "Int64")],
    }
