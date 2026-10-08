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
            t.Relationship("Patient Details", "patient_key", "Patient", "patient_key", one_to_one_both=True)]
    text = t.render_relationships(rels, lambda table, col: t.friendly(col))
    assert "relationship charge_lines_episode_payer_key\n\tisActive: false\n" in text
    assert "\tfromColumn: 'Charge Lines'.'Episode Payer Key'\n\ttoColumn: Payer.'Payer Key'" in text
    assert "\tcrossFilteringBehavior: bothDirections\n\tsecurityFilteringBehavior: oneDirection\n\tfromCardinality: one" in text


def test_perspective_closure_follows_snowflake_but_not_one_to_one():
    rels = [t.Relationship("GL Balances", "gl_account_key", "GL Account", "gl_account_key"),
            t.Relationship("GL Account", "fs_line_key", "FS Line", "fs_line_key"),
            t.Relationship("Patient Details", "patient_key", "Patient", "patient_key", one_to_one_both=True)]
    assert t.perspective_tables(["GL Balances"], rels, []) == ["FS Line", "GL Account", "GL Balances"]
    assert t.perspective_tables([], rels, ["Patient Details"]) == ["Patient Details"]
    text = t.render_perspective("Finance", ["GL Balances"])
    assert text == "perspective Finance\n\n\tperspectiveTable 'GL Balances'\n\t\tincludeAll\n"


def test_render_model():
    text = t.render_model(["Branch", "Charge Lines"], ["HNH Readers"], ["Finance"])
    assert text.startswith("model Model\n\tculture: en-US\n\tdiscourageImplicitMeasures\n")
    assert "ref table 'Charge Lines'\n" in text and "ref role 'HNH Readers'\n" in text
    assert text.endswith("ref perspective Finance\n")
    assert "compatibilityMode: analysisServices" in t.DATABASE_TMDL
