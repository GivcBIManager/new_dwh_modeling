import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_model_sql as r  # noqa: E402


@pytest.fixture
def project(tmp_path, monkeypatch):
    models = tmp_path / "models" / "hnh"
    for folder in ("staging/x", "marts/finance", "marts/bsc"):
        (models / folder).mkdir(parents=True)
    (models / "staging" / "x" / "stg_a.sql").write_text(
        "select 1 as a from {{ source('reference', 'map_a') }}\n-- trailing comment\n", encoding="utf-8")
    (models / "marts" / "finance" / "fact_b.sql").write_text(
        "{{ config(order_by='(a, b)') }}\n"
        "select a from {{ ref('stg_a') }} as s left join {{ hnh_oasis_gl_source('fact_oasis_gl_line') }} as g on 1\n"
        "where d >= '{{ var('hnh_history_start_date') }}' and e = '{{ var('hnh_bsc_as_of') }}'\n"
        "{{ hnh_settings() }}\n", encoding="utf-8")
    (models / "marts" / "bsc" / "bsc_vw_x.sql").write_text(
        "{{ config(alias='vw_x') }}\nselect * from {{ ref('fact_b') }}\nsettings join_use_nulls = 0\n", encoding="utf-8")
    project_file = tmp_path / "dbt_project.yml"
    project_file.write_text('vars:\n  hnh_history_start_date: "2022-01-01"   # first year\n  hnh_bsc_as_of: ""\n',
                            encoding="utf-8")
    monkeypatch.setattr(r, "MODELS", models)
    monkeypatch.setattr(r, "PROJECT", project_file)
    return models


def test_relation_uses_folder_schema_and_alias(project):
    assert r.relation("stg_a") == "stg.stg_a"
    assert r.relation("fact_b") == "gold.fact_b"
    assert r.relation("bsc_vw_x") == "bsc.vw_x"


def test_refs_resolve_to_built_relations(project):
    assert r.render("bsc_vw_x") == "select * from gold.fact_b\nsettings join_use_nulls = 0"


def test_vars_sources_and_settings(project):
    sql = r.render("fact_b")
    assert "from stg.stg_a as s left join gold.fact_oasis_gl_line as g on 1" in sql
    assert "d >= '2022-01-01' and e = ''" in sql
    assert "config" not in sql
    assert sql.endswith("settings join_use_nulls = 1")


def test_inline_renders_a_subquery_without_its_settings(project):
    sql = r.render("bsc_vw_x", inline={"fact_b"})
    assert sql.startswith("select * from (\nselect a from stg.stg_a")
    assert "join_use_nulls = 1" not in sql
    assert sql.endswith("\n)\nsettings join_use_nulls = 0")


def test_comment_before_closing_paren_does_not_swallow_it(project):
    assert "-- trailing comment\n) as s" in r.render("fact_b", inline={"stg_a"})


def test_replace_puts_given_sql_in_place_of_a_model(project):
    assert "from (\nselect 2 as a\n) as s" in r.render("fact_b", replace={"stg_a": "select 2 as a\n"})


def test_wrap_moves_trailing_settings_outside(project):
    sql = r.wrap(r.render("bsc_vw_x"), "DESCRIBE ({model})")
    assert sql == "DESCRIBE (\nselect * from gold.fact_b\n)\nsettings join_use_nulls = 0"


def test_unsupported_jinja_stops(project):
    (project / "marts" / "bsc" / "bsc_vw_y.sql").write_text("select {{ other_macro() }}", encoding="utf-8")
    with pytest.raises(SystemExit, match="unsupported"):
        r.render("bsc_vw_y")


def test_jinja_statements_stop(project):
    (project / "marts" / "bsc" / "bsc_vw_z.sql").write_text("{% if x %}select 1{% endif %}", encoding="utf-8")
    with pytest.raises(SystemExit, match="not supported"):
        r.render("bsc_vw_z")


def test_fusion_source_renders_the_fusion_table(project):
    (project / "staging" / "x" / "stg_f.sql").write_text(
        "select 1 from {{ hnh_fusion_source('fact_recruiting_requisition') }} final", encoding="utf-8")
    assert r.render("stg_f") == "select 1 from fusion.fact_recruiting_requisition final"
