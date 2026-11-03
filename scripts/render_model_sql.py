"""Render an hnh dbt model to plain ClickHouse SQL, for read-only checks through an ODBC DSN.

dbt is not installed on HNHANALYTICSSRV. This handles only the Jinja the bsc and hr models use: config(), ref(), source(),
var(), hnh_settings(), hnh_oasis_gl_source(), hnh_fusion_source(), hnh_oasis_source() (as the oasis source),
hnh_code() and hnh_title() on a column name, hnh_surrogate_key([...]) on column names, and any macro of hnh_dwh/macros
whose body has no Jinja statement (its parameters substituted by the quoted arguments); anything else stops with an
error.

  python scripts/render_model_sql.py bsc_vw_financial --inline fact_gl_fs_monthly,stg_bsc__oasis_gl_line \
      --replace stg_ref__gl_cutover=scripts/fixtures/gl_cutover_stub.sql --wrap "DESCRIBE ({model})" --out m.sql

--inline renders a model that is not built yet as a subquery; --replace puts the given SQL in place of a model;
--wrap places the model inside a query (a trailing settings clause moves to the end of the wrapping query).
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "hnh_dwh" / "models" / "hnh"
PROJECT = ROOT / "hnh_dwh" / "dbt_project.yml"
MACROS = ROOT / "hnh_dwh" / "macros"
SOURCE_SCHEMAS = {"reference": "default", "gold_oasis_gl": "gold", "oasis": "oasis", "fusion": "fusion",
                  "press_ganey": "press_ganey", "hnh_log": "gold"}
LAYER_SCHEMAS = {"staging": "stg", "intermediate": "int", "marts": "gold"}


def model_path(name):
    hits = list(MODELS.rglob(f"{name}.sql"))
    if len(hits) != 1:
        raise SystemExit(f"model {name}: {len(hits)} files found")
    return hits[0]


def relation(name):
    path = model_path(name)
    parts = path.relative_to(MODELS).parts
    schema = "bsc" if parts[:2] == ("marts", "bsc") else LAYER_SCHEMAS[parts[0]]
    alias = re.search(r"alias\s*=\s*'([^']+)'", path.read_text(encoding="utf-8"))
    return f"{schema}.{alias.group(1) if alias else name}"


def project_vars():
    found = {}
    for line in PROJECT.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s+(hnh_\w+):\s*(\"[^\"]*\"|'[^']*'|[^#\s]+)", line)
        if m:
            found[m.group(1)] = m.group(2).strip("\"'")
    return found


def plain_macros():
    """{name: (parameters, body)} of the macros in MACROS whose body holds no Jinja statement ({% ... %})."""
    found = {}
    for path in sorted(MACROS.rglob("*.sql")):
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(r"\{%-?\s*macro\s+(\w+)\(([^)]*)\)\s*-?%\}(.*?)\{%-?\s*endmacro\s*-?%\}", text, re.S):
            params = [p.split("=")[0].strip() for p in m.group(2).split(",") if p.strip()]
            body = m.group(3).strip()
            if "{%" not in body:
                found[m.group(1)] = (params, body)
    return found


ARGUMENT = r"""\s*('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")\s*"""  # a quoted Jinja string


def render_macro(expr):
    """A call of a plain macro with quoted arguments, rendered; None when `expr` is not one."""
    m = re.fullmatch(r"(\w+)\((.*)\)", expr, re.S)
    if not m:
        return None
    macros = plain_macros()
    if m.group(1) not in macros:
        return None
    params, body = macros[m.group(1)]
    args = re.findall(ARGUMENT + r"(?:,|$)", m.group(2))
    if re.sub(r"(?:" + ARGUMENT + r"(?:,|$))", "", m.group(2)).strip() or len(args) != len(params):
        return None
    values = dict(zip(params, (a[1:-1] for a in args)))
    return re.sub(r"\{\{\s*(\w+)\s*\}\}", lambda x: values[x.group(1)], body)


def surrogate_key(columns):
    """hnh_surrogate_key(columns) (macros/hnh/hnh_core.sql), on one line."""
    nulls = " or ".join(f"isNull({c})" for c in columns)
    parts = ", ".join(f"toString(assumeNotNull({c})), '|'" for c in columns)
    return f"if({nulls}, toInt64(-1), toInt64(bitShiftRight(cityHash64(concat({parts})), 1)))"


def render(name, inline=frozenset(), replace=None, depth=0):
    replace = replace or {}
    sql = model_path(name).read_text(encoding="utf-8")
    if "{%" in sql:
        raise SystemExit(f"{name}: Jinja statements are not supported")
    variables = project_vars()

    def sub(match):
        expr = match.group(1).strip()
        if expr.startswith("config("):
            return ""
        if expr == "hnh_settings()":
            return "" if depth else "settings join_use_nulls = 1"
        m = re.fullmatch(r"ref\('(\w+)'\)", expr)
        if m:
            ref = m.group(1)
            if ref in replace:
                return f"(\n{replace[ref].strip()}\n)"
            if ref in inline:
                return f"(\n{strip_settings(render(ref, inline, replace, depth + 1))[0]}\n)"
            return relation(ref)
        m = re.fullmatch(r"source\('(\w+)',\s*'(\w+)'\)", expr)
        if m:
            return f"{SOURCE_SCHEMAS[m.group(1)]}.{m.group(2)}"
        m = re.fullmatch(r"hnh_oasis_gl_source\('(\w+)'\)", expr)
        if m:
            return f"gold.{m.group(1)}"
        m = re.fullmatch(r"hnh_fusion_source\('(\w+)'\)", expr)
        if m:
            return f"fusion.{m.group(1)}"
        m = re.fullmatch(r"hnh_oasis_source\('(\w+)'\)", expr)
        if m:
            return f"oasis.{m.group(1)}"
        m = re.fullmatch(r"hnh_code\('([\w.]+)'\)", expr)
        if m:
            return f"nullIf(upper(trimBoth(ifNull(toString({m.group(1)}), ''))), '')"
        m = re.fullmatch(r"hnh_title\('([\w.]+)'\)", expr)
        if m:
            c = m.group(1)
            return f"if(match({c}, '[a-z]') and match({c}, '[A-Z]'), {c}, initcap({c}))"
        m = re.fullmatch(r"var\('(\w+)'\)", expr)
        if m:
            return variables[m.group(1)]
        m = re.fullmatch(r"hnh_surrogate_key\(\[([^\]]*)\]\)", expr)
        if m:
            return surrogate_key([c.strip().strip("'\"") for c in m.group(1).split(",")])
        macro = render_macro(expr)
        if macro is not None:
            return macro
        raise SystemExit(f"{name}: unsupported Jinja {{{{ {expr} }}}}")

    return re.sub(r"\{\{(.*?)\}\}", sub, sql, flags=re.S).strip()


def strip_settings(sql):
    """Split a trailing `settings ...` line off a rendered model: (sql without it, the settings text or '')."""
    m = re.search(r"\n\s*(settings\s+[^\n]+?)\s*$", sql, flags=re.I)
    if not m:
        return sql, ""
    return sql[: m.start()].rstrip(), m.group(1)


def wrap(sql, template):
    body, settings = strip_settings(sql)
    wrapped = template.replace("{model}", f"\n{body}\n")
    return f"{wrapped}\n{settings}" if settings else wrapped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model")
    ap.add_argument("--inline", default="", help="comma-separated models to render as subqueries")
    ap.add_argument("--replace", action="append", default=[], help="model=path.sql: SQL to use in place of a model")
    ap.add_argument("--wrap", default="", help="query containing {model}")
    ap.add_argument("--out", default="", help="write UTF-8 to this file instead of stdout")
    args = ap.parse_args()
    inline = {m for m in args.inline.split(",") if m}
    replace = {}
    for item in args.replace:
        model, path = item.split("=", 1)
        replace[model] = Path(path).read_text(encoding="utf-8")
    sql = render(args.model, inline, replace)
    if args.wrap:
        sql = wrap(sql, args.wrap)
    if args.out:
        Path(args.out).write_text(sql + "\n", encoding="utf-8")
    else:
        sys.stdout.write(sql + "\n")


if __name__ == "__main__":
    main()
