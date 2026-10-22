"""Read and write a legacy Report Server .pbix (a zip) without touching parts other than the layout.

Only `Report/Layout` (UTF-16 LE, no BOM) and, when `set_database` changed it, `Connections` are
re-encoded on write. Every other part is kept byte for byte, in the original order.
"""
from __future__ import annotations

import json
import re
import zipfile
from dataclasses import dataclass, field

LAYOUT = "Report/Layout"
CONNECTIONS = "Connections"
SAMPLES_PAGE = "Samples"
SAMPLE_KEYS = (
    "card", "multiRowCard", "table", "matrix", "barChart", "lineChart",
    "slicerDropdown", "slicerRelativeDate", "textbox", "buttonNavigate",
    "buttonDrill", "hnhVisual",
)


@dataclass
class Pbix:
    parts: dict[str, bytes]
    layout: dict
    connection: dict | None = None
    _conn_original: dict | None = field(default=None, repr=False)
    _conn_encoding: str = field(default="utf-8", repr=False)


def _decode_json(raw: bytes) -> tuple[dict, str]:
    """Decode a JSON part in UTF-16 LE/BE (BOM or not) or UTF-8. Returns (value, codec for writing)."""
    if raw[:2] == b"\xff\xfe":
        return json.loads(raw[2:].decode("utf-16-le")), "utf-16-le"
    if raw[:2] == b"\xfe\xff":
        return json.loads(raw[2:].decode("utf-16-be")), "utf-16-le"
    if raw[:3] == b"\xef\xbb\xbf":
        return json.loads(raw[3:].decode("utf-8")), "utf-8"
    if len(raw) > 1 and raw[1:2] == b"\x00":
        return json.loads(raw.decode("utf-16-le")), "utf-16-le"
    return json.loads(raw.decode("utf-8")), "utf-8"


def _dump(obj: dict) -> str:
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


def read_pbix(path) -> Pbix:
    with zipfile.ZipFile(path) as z:
        parts = {i.filename: z.read(i.filename) for i in z.infolist() if not i.is_dir()}
    if LAYOUT not in parts:
        raise ValueError(f"{path}: no {LAYOUT} part")
    layout, _ = _decode_json(parts[LAYOUT])
    conn = conn_original = None
    enc = "utf-8"
    if CONNECTIONS in parts:
        conn, enc = _decode_json(parts[CONNECTIONS])
        conn_original = json.loads(json.dumps(conn))
    return Pbix(parts, layout, conn, conn_original, enc)


def write_pbix(pbix: Pbix, path) -> None:
    out = dict(pbix.parts)
    out[LAYOUT] = _dump(pbix.layout).encode("utf-16-le")  # no BOM
    if pbix.connection is not None and pbix.connection != pbix._conn_original:
        out[CONNECTIONS] = _dump(pbix.connection).encode(pbix._conn_encoding)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in out.items():
            z.writestr(name, data)


def check_upload_rules(path) -> list[str]:
    """Rules from Notes/05 Report Server.md. Empty list means the file passes."""
    problems: list[str] = []
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        norm = [n.replace("\\", "/") for n in names]
        if LAYOUT not in norm:
            problems.append("no Report/Layout part")
            raw = None
        else:
            raw = z.read(names[norm.index(LAYOUT)])
        if any(n.startswith("Report/definition/") or n == "Report/definition" for n in norm):
            problems.append("has a Report/definition/ entry (the site refuses the file)")
    if raw is not None:
        if raw[:2] in (b"\xff\xfe", b"\xfe\xff") or raw[:3] == b"\xef\xbb\xbf":
            problems.append("Report/Layout starts with a byte-order mark (Desktop reports the file as corrupt)")
        elif raw[:2] != b"\x7b\x00":
            problems.append("Report/Layout is not UTF-16 LE starting with '{'")
    return problems


def set_database(pbix: Pbix, name: str) -> None:
    """Point a live connection at another database; Data Source and every other field stay as they are."""
    if not pbix.connection:
        raise ValueError("pbix has no Connections part (not a live-connection file)")
    pat = re.compile(r"(?i)(\b(?:Initial Catalog|Database|Catalog)\s*=\s*)[^;]*")
    changed = 0
    for c in pbix.connection.get("Connections", []):
        cs = c.get("ConnectionString")
        if isinstance(cs, str) and pat.search(cs):
            c["ConnectionString"] = pat.sub(lambda m: m.group(1) + name, cs)
            changed += 1
        for key in ("PbiModelDatabaseName", "InitialCatalog", "Database", "Catalog"):
            if isinstance(c.get(key), str):
                c[key] = name
                changed += 1
    if not changed:
        raise ValueError("no catalog / database field found in Connections")


def _title(config: dict) -> str | None:
    try:
        v = config["singleVisual"]["vcObjects"]["title"][0]["properties"]["text"]["expr"]["Literal"]["Value"]
    except (KeyError, IndexError, TypeError):
        return None
    return v[1:-1] if isinstance(v, str) and len(v) >= 2 and v[0] == v[-1] == "'" else None


def samples(pbix: Pbix) -> dict[str, dict]:
    """Map each `sample:<key>` visual on the Samples page to its visual container."""
    page = next((s for s in pbix.layout.get("sections", []) if s.get("displayName") == SAMPLES_PAGE), None)
    if page is None:
        raise ValueError(f"template has no page named '{SAMPLES_PAGE}'")
    found: dict[str, dict] = {}
    for vc in page.get("visualContainers", []):
        t = _title(json.loads(vc["config"]))
        if t and t.startswith("sample:"):
            found[t[len("sample:"):]] = vc
    missing = [k for k in SAMPLE_KEYS if k not in found]
    if missing:
        raise ValueError("template is missing sample visuals: " + ", ".join(f"sample:{k}" for k in missing))
    return found
