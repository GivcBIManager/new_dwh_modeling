"""Write the TMDL folder ssas/HNH_Analytics from the gold.ssas_* views and model_config.py (SSAS plan task 9).

Usage: python ssas/tools/generate.py
Keeps measure and hierarchy blocks of existing table files; never touches roles/ or tables/Time Calculation.tmdl.
"""
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(TOOLS))

import hnh_tmdl as t  # noqa: E402
import model_config as cfg  # noqa: E402
from ch_env import client  # noqa: E402

MODEL_DIR = ROOT / "ssas" / "HNH_Analytics"
CALC_GROUP = "Time Calculation"


def read_columns(ch, view):
    rows = ch.query(
        "select name, type from system.columns where database = 'gold' and table = {v:String} order by position",
        parameters={"v": view},
    ).result_rows
    if not rows:
        raise SystemExit(f"gold.{view} not found: build the ssas views first (dbt build --select tag:hnh_ssas)")
    return [t.Column(name, typ) for name, typ in rows]


def check_sort_pairs(ch):
    for (view, column), sort in cfg.SORT_BY.items():
        bad = ch.query(
            f"select count() from (select {column} from gold.{view} group by {column} having uniqExact({sort}) > 1)"
        ).result_rows[0][0]
        if bad:
            raise SystemExit(f"sortByColumn {view}.{column} -> {sort}: {bad} values have more than one sort value")


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def main():
    ch = client()
    by_name = {table.name: table for table in cfg.TABLES}
    columns = {table.name: read_columns(ch, table.view) for table in cfg.TABLES}
    check_sort_pairs(ch)

    rels = list(cfg.EXTRA_RELATIONSHIPS)
    for table in cfg.TABLES:
        rels += t.derive_relationships(table, columns[table.name], cfg)
    t.check_relationships(rels, cfg.TABLES)

    def col_display(table_name, column):
        return t.display_name(by_name[table_name], column, cfg.COLUMN_NAMES)

    tables_dir = MODEL_DIR / "tables"
    for table in cfg.TABLES:
        path = tables_dir / f"{table.name}.tmdl"
        kept = t.kept_blocks(path.read_text(encoding="utf-8")) if path.exists() else []
        write(path, t.render_table(table, columns[table.name], cfg.COLUMN_NAMES, cfg.SORT_BY, kept))
    write(MODEL_DIR / "relationships.tmdl", t.render_relationships(rels, col_display))

    has_calc_group = (tables_dir / f"{CALC_GROUP}.tmdl").exists()
    for name, facts in cfg.PERSPECTIVES.items():
        tables = t.perspective_tables(facts, rels, cfg.PERSPECTIVE_EXTRA.get(name, []))
        write(MODEL_DIR / "perspectives" / f"{name}.tmdl",
              t.render_perspective(name, tables + ([CALC_GROUP] if has_calc_group else [])))

    write(MODEL_DIR / "database.tmdl", t.DATABASE_TMDL)
    write(MODEL_DIR / "dataSources.tmdl", t.DATA_SOURCES_TMDL)
    table_names = sorted(p.stem for p in tables_dir.glob("*.tmdl"))
    role_names = sorted(p.stem for p in (MODEL_DIR / "roles").glob("*.tmdl"))
    write(MODEL_DIR / "model.tmdl", t.render_model(table_names, role_names, list(cfg.PERSPECTIVES)))
    print(f"{len(cfg.TABLES)} tables, {len(rels)} relationships, {len(cfg.PERSPECTIVES)} perspectives -> {MODEL_DIR}")


if __name__ == "__main__":
    main()
