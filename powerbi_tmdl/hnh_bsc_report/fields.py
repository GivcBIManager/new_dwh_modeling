"""Which fields the `Balanced Scorecard` perspective shows, read from the model's TMDL with ssas/tools/hnh_tmdl.py."""
from __future__ import annotations

import sys
from pathlib import Path

from model import Field, Page, page_fields

REPO = Path(__file__).resolve().parents[2]
MODEL_DIR = REPO / "ssas" / "HNH_Analytics"
PERSPECTIVE = "Balanced Scorecard"

sys.path.insert(0, str(REPO / "ssas" / "tools"))
import hnh_tmdl  # noqa: E402


def _tables(model_dir: Path) -> dict[str, tuple[set, set]]:
    """{table: ({column}, {measure})} of every table file."""
    out = {}
    for f in sorted((model_dir / "tables").glob("*.tmdl")):
        text = f.read_text(encoding="utf-8-sig")
        name, columns = hnh_tmdl.table_columns(text)
        out[name] = (columns, {m.name for m in hnh_tmdl.measures(text)})
    return out


def perspective_fields(model_dir: Path = MODEL_DIR) -> tuple[set, set]:
    """({(table, column)}, {(table, measure)}) shown by the perspective. `includeAll` takes the whole table (the way
    sync_perspectives / render_perspective write it); otherwise the listed perspectiveColumn / perspectiveMeasure."""
    text = (model_dir / "perspectives" / f"{PERSPECTIVE}.tmdl").read_text(encoding="utf-8-sig")
    tables = _tables(model_dir)
    columns, measures = set(), set()
    table = None
    for line in text.splitlines():
        body = line.strip()
        if line.startswith("\tperspectiveTable "):
            table = hnh_tmdl._object_name(body[len("perspectiveTable "):])
        elif table is None or not line.startswith("\t\t"):
            continue
        elif body == "includeAll":
            cols, meas = tables.get(table, (set(), set()))
            columns |= {(table, c) for c in cols}
            measures |= {(table, m) for m in meas}
        elif body.startswith("perspectiveColumn "):
            columns.add((table, hnh_tmdl._object_name(body[len("perspectiveColumn "):])))
        elif body.startswith("perspectiveMeasure "):
            measures.add((table, hnh_tmdl._object_name(body[len("perspectiveMeasure "):])))
    return columns, measures


def prop_fields(obj) -> list[Field]:
    """Fields named inside format objects, e.g. a button's drill-through destination measure."""
    out: list[Field] = []
    if isinstance(obj, dict):
        for kind in ("Column", "Measure"):
            ref = obj.get(kind)
            if isinstance(ref, dict) and "Property" in ref:
                entity = ref.get("Expression", {}).get("SourceRef", {}).get("Entity")
                if entity:
                    out.append(Field(entity, ref["Property"], kind.lower()))
        for v in obj.values():
            out += prop_fields(v)
    elif isinstance(obj, list):
        for v in obj:
            out += prop_fields(v)
    return out


def unknown_fields(pages: list[Page], model_dir: Path = MODEL_DIR) -> list[str]:
    """The fields the pages use that the perspective does not show, as `'Table'[Column]` / `[Measure]`, sorted."""
    columns, measures = perspective_fields(model_dir)
    bad = set()
    for page in pages:
        used = page_fields(page) + [f for v in page.visuals for f in prop_fields(v.props)]
        for f in used:
            known = columns if f.kind == "column" else measures
            if (f.table, f.name) not in known:
                bad.add(str(f))
    return sorted(bad)
