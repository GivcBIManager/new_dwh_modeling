"""Pure TMDL rendering for the HNH_Analytics model (SSAS spec 4.3, 5, 7; planning decisions P4, P5, P7, P11).

generate.py does the I/O. Nothing here talks to ClickHouse, so the rules are unit-tested in test_hnh_tmdl.py.
"""
import re
from dataclasses import dataclass
from typing import Optional

ACRONYMS = {
    "abc", "alos", "ap", "ar", "cchi", "ctas", "dama", "er", "fs", "fte", "gl", "grn", "hhc", "hr", "icu", "id",
    "ios", "ip", "je", "los", "ltc", "moh", "mrn", "nphies", "nps", "op", "pg", "pii", "po", "sar", "scfhs", "sms",
    "tpa", "uom", "vat",
}
DATA_SOURCE = "HNH_Gold"
DSN = "HNH_Gold"
GOLD = "gold"

DATABASE_TMDL = (
    "database HNH_Analytics\n"
    "\tcompatibilityLevel: 1700\n"
    "\tcompatibilityMode: analysisServices\n"
)
# Structured ODBC source read through Power Query (decision P24): MSDASQL loads the ClickHouse driver's Decimal with
# scale 0 and its String as ANSI text. The DSN holds the password, so the credential is Anonymous.
DATA_SOURCES_TMDL = (
    f"dataSource {DATA_SOURCE}\n"
    "\tconnectionDetails =\n"
    "\t\t\t{\n"
    '\t\t\t  "address": {\n'
    '\t\t\t    "options": {\n'
    f'\t\t\t      "dsn": "{DSN}"\n'
    "\t\t\t    }\n"
    "\t\t\t  }\n"
    "\t\t\t}\n"
    "\t\tprotocol: odbc\n"
    "\tcredential =\n"
    "\t\t\t{\n"
    '\t\t\t  "kind": "ODBC",\n'
    f'\t\t\t  "path": "dsn={DSN}"\n'
    "\t\t\t}\n"
    "\t\tauthenticationKind: Anonymous\n"
    "\t\tprivacySetting: Organizational\n"
)


def odbc_expression(sql: str) -> str:
    """Power Query partition expression that runs sql through the DSN (ssas/scripts/HnhSsas.psm1 builds the same)."""
    return f'let\n    Source = Odbc.Query("dsn={DSN}", "{sql.replace(chr(34), chr(34) * 2)}")\nin\n    Source'


@dataclass(frozen=True)
class Table:
    view: str
    name: str
    kind: str  # date | dim | role_copy | security | fact
    description: str
    partition_column: Optional[str] = None


@dataclass(frozen=True)
class Column:
    name: str
    ch_type: str


@dataclass(frozen=True)
class Relationship:
    from_table: str
    from_column: str
    to_table: str
    to_column: str
    active: bool = True
    one_to_one_both: bool = False


def friendly(name: str) -> str:
    """'los_days' -> 'LOS Days', 'staff_name_ar' -> 'Staff Name AR'."""
    words = [w for w in name.split("_") if w]
    return " ".join(w.upper() if w in ACRONYMS else w[:1].upper() + w[1:] for w in words)


def q(name: str) -> str:
    """TMDL object name, single-quoted unless it is a plain identifier."""
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
        return name
    return "'" + name.replace("'", "''") + "'"


def unwrap(ch_type: str) -> tuple[str, bool]:
    """Strip LowCardinality(...) and Nullable(...) wrappers; return (base type, nullable)."""
    base, nullable, changed = ch_type, False, True
    while changed:
        changed = False
        for wrapper in ("LowCardinality(", "Nullable("):
            if base.startswith(wrapper):
                base, changed = base[len(wrapper):-1], True
                nullable = nullable or wrapper == "Nullable("
    return base, nullable


def tmdl_type(ch_type: str) -> str:
    base, _ = unwrap(ch_type)
    if base.startswith(("Int", "UInt")):
        return "int64"
    if base.startswith("Decimal"):
        return "decimal"
    if base.startswith("Float"):
        return "double"
    if base.startswith(("DateTime", "Date")):
        return "dateTime"
    if base == "String":
        return "string"
    raise ValueError(f"unsupported ClickHouse type {ch_type}")


def display_name(table: Table, column: str, overrides: dict) -> str:
    return overrides.get((table.view, column)) or friendly(column)


def _format_string(dtype: str, base: str, hidden: bool) -> Optional[str]:
    if dtype in ("decimal", "double"):
        return "#,0.00"
    if dtype == "dateTime":
        return "yyyy-mm-dd" if base == "Date" else "yyyy-mm-dd hh:nn"
    if dtype == "int64" and not hidden:
        return "0"
    return None


def column_lines(table: Table, col: Column, overrides: dict, sort_by: dict) -> list[str]:
    dtype = tmdl_type(col.ch_type)
    base, _ = unwrap(col.ch_type)
    is_key = col.name.endswith("_key")
    numeric = dtype in ("int64", "decimal", "double")
    hidden = table.kind == "security" or is_key or (table.kind == "fact" and numeric)
    lines = [f"\tcolumn {q(display_name(table, col.name, overrides))}", f"\t\tdataType: {dtype}"]
    if hidden:
        lines.append("\t\tisHidden")
        if table.kind in ("fact", "security"):
            lines.append("\t\tisAvailableInMdx: false")
    if is_key and dtype == "int64":
        lines.append("\t\tencodingHint: " + ("value" if col.name.endswith(("date_key", "time_key")) else "hash"))
    if table.kind == "date" and col.name == "date_day":
        lines.append("\t\tisKey")
    fmt = _format_string(dtype, base, hidden)
    if fmt:
        lines.append(f"\t\tformatString: {fmt}")
    lines.append("\t\tsummarizeBy: none")
    sort = sort_by.get((table.view, col.name))
    if sort:
        lines.append(f"\t\tsortByColumn: {q(display_name(table, sort, overrides))}")
    lines.append(f"\t\tsourceColumn: {col.name}")
    return lines


def partition_lines(table: Table) -> list[str]:
    if table.partition_column:
        name, where = f"{table.name} template", " where 1 = 0"
    else:
        name, where = table.name, ""
    expression = odbc_expression(f"select * from {GOLD}.{table.view}{where}")
    return [f"\tpartition {q(name)} = m", "\t\tsource ="] + ["\t\t\t\t" + line for line in expression.split("\n")]


def kept_blocks(text: str) -> list[str]:
    """Measure and hierarchy blocks (with their /// descriptions) of an existing table file, verbatim."""
    blocks, current, doc = [], None, []
    for line in text.splitlines():
        blank = line.strip() == ""
        top = not blank and line.startswith("\t") and not line.startswith("\t\t")
        outer = not blank and not line.startswith("\t")
        if top or outer:
            if current is not None:
                blocks.append("\n".join(current).rstrip())
                current = None
            body = line[1:] if top else ""
            if top and body.startswith("///"):
                doc.append(line)
                continue
            if top and body.startswith(("measure ", "hierarchy ")):
                current = doc + [line]
            doc = []
        elif current is not None:
            current.append(line)
    if current is not None:
        blocks.append("\n".join(current).rstrip())
    return blocks


def render_table(table: Table, columns: list[Column], overrides: dict, sort_by: dict, kept: list[str]) -> str:
    if table.partition_column and table.partition_column not in [c.name for c in columns]:
        raise ValueError(f"{table.name}: partition column {table.partition_column} is not in {table.view}")
    out = [f"/// {table.description}", f"table {q(table.name)}"]
    if table.kind == "security":
        out.append("\tisHidden")
    if table.kind == "date":
        out.append("\tdataCategory: Time")
    for block in kept:
        out += ["", block]
    for col in columns:
        out += [""] + column_lines(table, col, overrides, sort_by)
    out += [""] + partition_lines(table)
    out += ["", f"\tannotation hnh_kind = {table.kind}", f"\tannotation hnh_view = {table.view}"]
    if table.partition_column:
        out.append(f"\tannotation hnh_partition_column = {table.partition_column}")
    return "\n".join(out) + "\n"


def derive_relationships(table: Table, columns: list[Column], cfg) -> list[Relationship]:
    rels = []
    for col in columns:
        key = (table.name, col.name)
        if key in cfg.ROLE_KEYS:
            to_table, to_column, active = cfg.ROLE_KEYS[key]
        elif table.kind != "fact" or not col.name.endswith("_key") or key in cfg.NO_RELATIONSHIP:
            continue
        elif col.name.endswith("date_key"):
            to_table, to_column, active = "Date", "date_key", cfg.ACTIVE_DATE.get(table.name) == col.name
        elif col.name.endswith("time_key"):
            to_table, to_column, active = "Time", "time_key", cfg.ACTIVE_TIME.get(table.name) == col.name
        elif col.name in cfg.DIM_KEYS:
            (to_table, to_column), active = cfg.DIM_KEYS[col.name], True
        else:
            raise ValueError(
                f"{table.name}.{col.name}: no relationship rule (add it to DIM_KEYS, ROLE_KEYS or NO_RELATIONSHIP)"
            )
        rels.append(Relationship(table.name, col.name, to_table, to_column, active))
    return rels


def check_relationships(rels: list[Relationship], tables: list[Table]) -> None:
    active = {}
    for r in rels:
        if r.active:
            pair = (r.from_table, r.to_table)
            if pair in active:
                raise ValueError(f"two active relationships {pair[0]} -> {pair[1]}: {active[pair]} and {r.from_column}")
            active[pair] = r.from_column
    for table in tables:
        has_date = any(r.from_table == table.name and r.to_table == "Date" for r in rels)
        if table.kind == "fact" and has_date and (table.name, "Date") not in active:
            raise ValueError(f"{table.name}: no active date relationship (set ACTIVE_DATE)")


def relationship_name(rel: Relationship) -> str:
    return re.sub(r"[^a-z0-9]+", "_", f"{rel.from_table} {rel.from_column}".lower()).strip("_")


def render_relationships(rels: list[Relationship], col_display) -> str:
    out = []
    for r in sorted(rels, key=relationship_name):
        out.append(f"relationship {relationship_name(r)}")
        if not r.active:
            out.append("\tisActive: false")
        if r.one_to_one_both:
            out += ["\tcrossFilteringBehavior: bothDirections", "\tsecurityFilteringBehavior: oneDirection",
                    "\tfromCardinality: one"]
        out.append(f"\tfromColumn: {q(r.from_table)}.{q(col_display(r.from_table, r.from_column))}")
        out.append(f"\ttoColumn: {q(r.to_table)}.{q(col_display(r.to_table, r.to_column))}")
        out.append("")
    return "\n".join(out)


def perspective_tables(facts: list[str], rels: list[Relationship], extra: list[str]) -> list[str]:
    tables = set(facts) | set(extra)
    changed = True
    while changed:
        changed = False
        for r in rels:
            if r.from_table in tables and r.to_table not in tables and not r.one_to_one_both:
                tables.add(r.to_table)
                changed = True
    return sorted(tables)


MEASURE_TABLE = "_Measures"
DIAGNOSTICS = "Diagnostics"


def _object_name(text: str) -> str:
    """Name at the start of a TMDL declaration remainder: 'quoted ''name''' or a bare word."""
    if text.startswith("'"):
        i, out = 1, []
        while i < len(text):
            if text[i] == "'":
                if text[i + 1:i + 2] == "'":
                    out.append("'")
                    i += 2
                    continue
                break
            out.append(text[i])
            i += 1
        return "".join(out)
    return re.split(r"[\s=]", text, maxsplit=1)[0]


def measure_folders(text: str) -> list[tuple[str, str]]:
    """(measure, display folder) of every measure in a table file, in file order (decision P26)."""
    found, current = [], None
    for line in text.splitlines():
        if line.startswith("\tmeasure "):
            current = _object_name(line[len("\tmeasure "):])
            found.append([current, ""])
        elif line.startswith("\t") and not line.startswith("\t\t") and line.strip():
            current = None
        elif current is not None and line.startswith("\t\tdisplayFolder: "):
            found[-1][1] = line[len("\t\tdisplayFolder: "):].strip()
    return [(name, folder) for name, folder in found]


def perspective_measures(perspective: str, folders: list[tuple[str, str]], domains: dict) -> list[str]:
    """Measures of the measure table shown in a perspective: those whose top display folder is one of the perspective's
    domains (default: its own name; None = every measure), plus Diagnostics."""
    wanted = domains.get(perspective, [perspective])
    names = [name for name, folder in folders
             if wanted is None or folder.split("\\")[0] in set(wanted) | {DIAGNOSTICS}]
    return sorted(names)


def render_perspective(name: str, tables: list[str], measures: Optional[list[str]] = None) -> str:
    out = [f"perspective {q(name)}"]
    for table in tables:
        out += ["", f"\tperspectiveTable {q(table)}", "\t\tincludeAll"]
    if measures:
        out += ["", f"\tperspectiveTable {q(MEASURE_TABLE)}"] + [f"\t\tperspectiveMeasure {q(m)}" for m in measures]
    return "\n".join(out) + "\n"


def render_model(table_names: list[str], role_names: list[str], perspective_names: list[str]) -> str:
    out = ["model Model", "\tculture: en-US", "\tdiscourageImplicitMeasures", ""]
    out += [f"ref table {q(n)}" for n in table_names]
    if role_names:
        out += [""] + [f"ref role {q(n)}" for n in role_names]
    if perspective_names:
        out += [""] + [f"ref perspective {q(n)}" for n in perspective_names]
    return "\n".join(out) + "\n"
