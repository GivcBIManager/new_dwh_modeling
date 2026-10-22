"""Guard every measure against slicers that cannot filter it (SSAS spec P41).

A measure reads one or more facts (directly or through the measures it references). A table filters a fact when an
active relationship path carries its filter there (one side to many side, both ways for bothDirections). A filtered
table that cannot filter every fact of the measure would make the measure repeat one number on every row, so the measure
returns the text '"<measure>" can't be analysed by "<table>"' instead. Date, the calculation group and the security table
are always allowed; the annotation hnh_guard_allow = <table>[, <table>] allows more (a measure that maps a slicer itself).

Each measure keeps its own expression inside a generated wrapper:

    VAR __Value = ( -- measure body
        <the measure's expression>
    ) -- end of measure body
    VAR __Wrong = [_Guard <facts>]
    RETURN IF ( __Wrong = "", __Value, <'"<measure>" can't be analysed by ' as a DAX string> & __Wrong )

and one hidden measure '_Guard <facts>' per fact combination lists the wrong tables that are filtered. Running the tool
again rewrites the wrappers and the guard measures from the current relationships (idempotent).

A measure whose own guard already covers the facts of the measures it calls can call their expressions without the inner
guards: a reference to [_Unguarded <measure>] makes the tool write the hidden twin '_Unguarded <measure>' with that
measure's expression (no wrapper). The twin's facts count as the measure's, so the caller's guard covers them. Twins
that nothing references are dropped (bsc visual plan, Task 10: the scorecard payload).

Usage: python ssas/tools/measure_guards.py [--check]
"""
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

MODEL_DIR = Path(__file__).resolve().parents[1] / "HNH_Analytics"
GUARD_PREFIX = "_Guard "
GUARD_FOLDER = "Diagnostics\\Guards"
TWIN_PREFIX = "_Unguarded "
TWIN_FOLDER = "Diagnostics\\Unguarded"
ALWAYS_ALLOWED_KINDS = {"date", "calculation_group", "security"}
BODY_START = "\t\t\tVAR __Value = ( -- measure body"
BODY_END = "\t\t\t) -- end of measure body"


def _table_of(column_ref: str) -> str:
    """Table name of a TMDL column reference such as 'Absence Days'.'Branch Key' or Date.'Date Key'."""
    if column_ref.startswith("'"):
        return t._object_name(column_ref)
    return column_ref.split(".", 1)[0]


def parse_relationships(text: str) -> list:
    """(from table, to table, active, both directions) of every relationship in relationships.tmdl."""
    rels = []
    for block in re.split(r"(?m)^relationship ", text)[1:]:
        from_ref = re.search(r"^\tfromColumn: (.+)$", block, re.M).group(1).strip()
        to_ref = re.search(r"^\ttoColumn: (.+)$", block, re.M).group(1).strip()
        active = "\tisActive: false" not in block
        both = "\tcrossFilteringBehavior: bothDirections" in block
        rels.append((_table_of(from_ref), _table_of(to_ref), active, both))
    return rels


def filtering_tables(rels: list, fact: str) -> set:
    """Tables whose filters reach `fact` through active relationships (the fact itself included)."""
    edges = []
    for from_table, to_table, active, both in rels:
        if not active:
            continue
        edges.append((to_table, from_table))
        if both:
            edges.append((from_table, to_table))
    found, changed = {fact}, True
    while changed:
        changed = False
        for source, target in edges:
            if target in found and source not in found:
                found.add(source)
                changed = True
    return found


def _chunks(text: str) -> tuple:
    """(prelude, [measure chunk], trailer) of a table file; each chunk is its /// lines, the measure and what follows
    until the next top-level object. Joining the parts gives the text back unchanged."""
    lines = text.split("\n")
    starts = [i for i, line in enumerate(lines) if line.startswith("\tmeasure ")]
    if not starts:
        return text, [], ""
    begins = []
    for i in starts:
        j = i
        while j > 0 and lines[j - 1].startswith("\t///"):
            j -= 1
        begins.append(j)
    end = len(lines)
    for i in range(starts[-1] + 1, len(lines)):
        if re.match(r"^\t(column|partition|annotation|hierarchy) ", lines[i]):
            end = i
            while end > 0 and lines[end - 1].startswith("\t///"):
                end -= 1
            break
    bounds = begins + [end]
    chunks = ["\n".join(lines[bounds[k]:bounds[k + 1]]) + "\n" for k in range(len(begins))]
    prelude = "\n".join(lines[:begins[0]]) + ("\n" if begins[0] else "")
    trailer = "\n".join(lines[end:])
    return prelude, chunks, trailer


def _split_measure(chunk: str) -> tuple:
    """(description lines, name, expression lines, remaining lines) of a measure chunk; a one-line expression becomes
    a three-tab expression line."""
    lines = chunk.rstrip("\n").split("\n")
    i = 0
    while lines[i].startswith("\t///"):
        i += 1
    declaration = lines[i][len("\tmeasure "):]
    name = t._object_name(declaration)
    rest = t._declaration_rest(declaration, name).strip().lstrip("=").strip()
    body = (["\t\t\t" + rest] if rest else [])
    j = i + 1
    while j < len(lines) and lines[j].startswith("\t\t\t"):
        body.append(lines[j])
        j += 1
    return lines[:i], name, body, lines[j:]


def _unwrap(body: list) -> list:
    if body and body[0] == BODY_START and BODY_END in body:
        return [line[1:] for line in body[1:body.index(BODY_END)]]
    return body


def _join(description: list, name: str, body: list, rest: list) -> str:
    return "\n".join(description + [f"\tmeasure {t.q(name)} ="] + body + rest) + "\n"


def strip_guards(text: str) -> str:
    """The table file without guard measures, unguarded twins and wrappers (the measures' own expressions)."""
    prelude, chunks, trailer = _chunks(text)
    out = []
    for chunk in chunks:
        description, name, body, rest = _split_measure(chunk)
        if name.startswith(GUARD_PREFIX) or name.startswith(TWIN_PREFIX):
            continue
        if body and body[0] == BODY_START:
            out.append(_join(description, name, _unwrap(body), rest))
        else:
            out.append(chunk)
    return prelude + "".join(out) + trailer


def _table_mentions(dax: str, tables: list) -> set:
    """Tables named without a column (COUNTROWS ( Encounters ), VALUES ( 'Stock Monthly'[...] ) aside)."""
    text = t._DAX_COMMENT.sub("", t._DAX_STRING.sub('""', dax))
    text = re.sub(r"\[[^\]]*\]", " ", text)
    found = set()
    for table in tables:
        quoted = "'" + table.replace("'", "''") + "'"
        if quoted in text or (re.fullmatch(r"[A-Za-z_]\w*", table)
                              and re.search(r"(?<![\w'])" + re.escape(table) + r"(?![\w'])", text)):
            found.add(table)
    return found


def _twin_source(name: str) -> str:
    """The measure an unguarded twin copies ('_Unguarded X' -> 'X'); other names unchanged."""
    return name[len(TWIN_PREFIX):] if name.startswith(TWIN_PREFIX) else name


def measure_facts(text: str, kinds: dict) -> dict:
    """{measure: set of fact tables it reads, directly or through the measures it references}."""
    measures = {m.name: m for m in t.measures(strip_guards(text))}
    fact_tables = [name for name, kind in kinds.items() if kind == "fact"]
    direct, refs = {}, {}
    for name, m in measures.items():
        dax = m.expression + "\n" + m.format_expression
        columns, names = t.dax_references(dax)
        direct[name] = {table for table, _ in columns if kinds.get(table) == "fact"} | _table_mentions(dax, fact_tables)
        refs[name] = {_twin_source(n) for n in names} & set(measures) - {name}
    memo = {}

    def facts(name, seen=()):
        if name not in memo:
            found = set(direct[name])
            for ref in refs[name]:
                if ref not in seen:
                    found |= facts(ref, seen + (name,))
            memo[name] = found
        return memo[name]

    return {name: facts(name) for name in measures}


def unrelated_tables(facts: set, rels: list, kinds: dict, allow: set) -> list:
    """Tables that cannot filter every fact in `facts`, other than the always-allowed ones and `allow`."""
    if not facts:
        return []
    allowed = set.intersection(*(filtering_tables(rels, fact) for fact in facts))
    candidates = {name for name, kind in kinds.items() if kind not in ALWAYS_ALLOWED_KINDS}
    return sorted(candidates - allowed - allow)


MAX_NAME = 100  # keep object names short; a long fact list is named by count and a hash (bsc ssas plan, Task 7)


def guard_name(facts: set, allow: set) -> str:
    name = GUARD_PREFIX + " + ".join(sorted(facts))
    name += (" | " + ", ".join(sorted(allow)) if allow else "")
    if len(name) <= MAX_NAME:
        return name
    digest = hashlib.sha1(name.encode("utf-8")).hexdigest()[:8]
    return f"{GUARD_PREFIX}{len(facts)} facts #{digest}"


def _dax_table(name: str) -> str:
    return "'" + name.replace("'", "''") + "'"


def _guard_chunk(name: str, facts: set, allow: set, tables: list) -> str:
    label = ", ".join(sorted(facts)) + (f" (also allowed: {', '.join(sorted(allow))})" if allow else "")
    lines = [f"\t/// Filtered tables that cannot filter {label}, as a quoted list; generated by ssas/tools/measure_guards.py (SSAS spec P41).",
             f"\tmeasure {t.q(name)} =",
             "\t\t\tVAR __Names ="]
    for k, table in enumerate(tables):
        lead = "\t\t\t\t" + ("" if k == 0 else "& ")
        lines.append(f"{lead}IF ( ISFILTERED ( {_dax_table(table)} ), \", \"\"{table.replace(chr(34), chr(34) * 2)}\"\"\" )")
    lines += ["\t\t\tRETURN MID ( __Names, 3, 4000 )",
              "\t\tformatString: General",
              "\t\tisHidden",
              f"\t\tdisplayFolder: {GUARD_FOLDER}",
              ""]
    return "\n".join(lines) + "\n"


def _twin_chunk(source: str, body: list) -> str:
    lines = [f"\t/// The expression of {source} without its guard, for measures whose own guard covers its facts; "
             "generated by ssas/tools/measure_guards.py.",
             f"\tmeasure {t.q(TWIN_PREFIX + source)} ="] + body + [
             "\t\tformatString: General",
             "\t\tisHidden",
             f"\t\tdisplayFolder: {TWIN_FOLDER}",
             ""]
    return "\n".join(lines) + "\n"


def render(text: str, rels: list, kinds: dict) -> str:
    """The table file with every measure that reads a fact wrapped in its guard and the guard measures regenerated."""
    base = strip_guards(text)
    facts = measure_facts(base, kinds)
    allows = {m.name: {a.strip() for a in m.annotations.get("hnh_guard_allow", "").split(",") if a.strip()}
              for m in t.measures(base)}
    wanted = set()
    for m in t.measures(base):
        wanted |= {n[len(TWIN_PREFIX):] for n in t.dax_references(m.expression + "\n" + m.format_expression)[1]
                   if n.startswith(TWIN_PREFIX)}
    prelude, chunks, trailer = _chunks(base)
    out, guards, bodies = [], {}, {}
    for chunk in chunks:
        description, name, body, rest = _split_measure(chunk)
        bodies[name] = body
        tables = unrelated_tables(facts[name], rels, kinds, allows[name])
        if not tables:
            out.append(chunk)
            continue
        gname = guard_name(facts[name], allows[name])
        guards[gname] = (facts[name], allows[name], tables)
        message = name.replace('"', '""')
        wrapped = ([BODY_START] + ["\t" + line for line in body] + [BODY_END,
                   f"\t\t\tVAR __Wrong = [{gname}]",
                   f"\t\t\tRETURN IF ( __Wrong = \"\", __Value, \"\"\"{message}\"\" can't be analysed by \" & __Wrong )"])
        out.append(_join(description, name, wrapped, rest))
    twins = sorted(wanted & set(bodies))
    if (guards or twins) and not out[-1].endswith("\n\n"):
        out[-1] += "\n"
    for gname in sorted(guards):
        out.append(_guard_chunk(gname, *guards[gname]))
    for source in twins:
        out.append(_twin_chunk(source, bodies[source]))
    return prelude + "".join(out) + trailer


def model_inputs(model_dir: Path = MODEL_DIR) -> tuple:
    kinds = {}
    for path in (model_dir / "tables").glob("*.tmdl"):
        text = path.read_text(encoding="utf-8")
        kind = re.search(r"^\tannotation hnh_kind = (\w+)$", text, re.M)
        if kind:
            kinds[t.table_columns(text)[0]] = kind.group(1)
    rels = parse_relationships((model_dir / "relationships.tmdl").read_text(encoding="utf-8"))
    return rels, kinds


def main():
    path = MODEL_DIR / "tables" / f"{t.MEASURE_TABLE}.tmdl"
    text = path.read_text(encoding="utf-8")
    rels, kinds = model_inputs()
    new = render(text, rels, kinds)
    if "--check" in sys.argv[1:]:
        if new != text:
            raise SystemExit("measure guards are out of date: run python ssas/tools/measure_guards.py")
        return
    if new != text:
        path.write_text(new, encoding="utf-8", newline="\n")
        print(f"updated {path.name}")


if __name__ == "__main__":
    main()
