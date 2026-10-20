"""Read the Hayat BSC handover project (powerbi_tmdl/Hayat BSC Deliverable): TMDL DATATABLE partitions and the
configuration blocks inside the D3 board scripts. Standard library only."""
import json
import re
from pathlib import Path


def _tokens(text):
    """Yield the literals of a DATATABLE body: strings (with "" escapes), numbers, TRUE/FALSE, BLANK(), braces."""
    pos = 0
    pattern = re.compile(r'\s*(?:(")((?:[^"]|"")*)"|(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)|(TRUE|FALSE)|(BLANK\(\))|([{},]))')
    while pos < len(text):
        m = pattern.match(text, pos)
        if not m:
            if text[pos:].strip() == "":
                return
            raise ValueError(f"unexpected DATATABLE text near: {text[pos:pos + 60]!r}")
        pos = m.end()
        if m.group(1):
            yield ("str", m.group(2).replace('""', '"'))
        elif m.group(3) is not None:
            n = m.group(3)
            yield ("val", float(n) if any(c in n for c in ".eE") else int(n))
        elif m.group(4):
            yield ("val", m.group(4) == "TRUE")
        elif m.group(5):
            yield ("val", None)
        else:
            yield (m.group(6), m.group(6))


def read_datatable(tmdl_path: Path, table: str) -> list[dict]:
    """Rows of the DATATABLE partition of `table` in a TMDL file, keyed by column name."""
    text = Path(tmdl_path).read_text(encoding="utf-8")
    start = text.index("DATATABLE(", text.index(f"partition {table}" if " " not in table else f"partition '{table}'"))
    body = text[start + len("DATATABLE("):]
    columns = re.findall(r'^\s*"([^"]+)",\s*(?:INTEGER|STRING|BOOLEAN|DOUBLE|CURRENCY|DATETIME),?\s*$', body.split("{", 1)[0], re.M)
    rows_text = body[body.index("{") + 1:]
    rows, current, depth = [], None, 0
    for kind, value in _tokens(rows_text[: _matching_brace(rows_text)]):
        if kind == "{":
            depth += 1
            current = []
        elif kind == "}":
            depth -= 1
            rows.append(dict(zip(columns, current)))
            current = None
        elif kind in ("str", "val") and current is not None:
            current.append(value)
    return rows


def _matching_brace(text):
    """Index of the brace that closes the outer row list (text starts just after its opening brace)."""
    depth, in_str, i = 1, False, 0
    while i < len(text):
        c = text[i]
        if in_str:
            if c == '"':
                if text[i + 1:i + 2] == '"':
                    i += 1
                else:
                    in_str = False
        elif c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unbalanced DATATABLE braces")


def visual_script(visual_json: Path) -> str:
    """The D3JSVisual script of a visual.json (PBIR literal '...' with '' escapes)."""
    v = json.loads(Path(visual_json).read_text(encoding="utf-8"))["visual"]
    literal = v["objects"]["general"][0]["properties"]["js"]["expr"]["Literal"]["Value"]
    return literal[1:-1].replace("''", "'")


def read_script_block(visual_json: Path, name: str) -> object:
    """The JSON value assigned to `name` (`name = {` or `var name = {`) in a board script."""
    script = visual_script(visual_json)
    m = re.search(r"(?:\bvar\s+)?\b" + re.escape(name) + r"\s*=\s*([\[{])", script)
    if not m:
        raise KeyError(f"{name} not found in {visual_json}")
    text = script[m.start(1):]
    try:
        value, _ = json.JSONDecoder().raw_decode(text)
        return value
    except json.JSONDecodeError:
        cleaned = re.sub(r",(\s*[}\]])", r"\1", text)
        value, _ = json.JSONDecoder().raw_decode(cleaned)
        return value
