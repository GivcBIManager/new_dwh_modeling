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
    _infos: dict = field(default_factory=dict, repr=False)


def _decode_json(raw: bytes) -> tuple[dict, str]:
    """Decode a JSON part in UTF-16 LE/BE (BOM or not) or UTF-8. Returns (value, codec for writing)."""
    if raw[:2] == b"\xff\xfe":
        return json.loads(raw[2:].decode("utf-16-le")), "utf-16-le"
    if raw[:2] == b"\xfe\xff":
        return json.loads(raw[2:].decode("utf-16-be")), "utf-16-le"
    if raw[:3] == b"\xef\xbb\xbf":
        return json.loads(raw[3:].decode("utf-8")), "utf-8-sig"
    if len(raw) > 1 and raw[1:2] == b"\x00":
        return json.loads(raw.decode("utf-16-le")), "utf-16-le"
    return json.loads(raw.decode("utf-8")), "utf-8"


def _dump(obj: dict) -> str:
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


def read_pbix(path) -> Pbix:
    with zipfile.ZipFile(path) as z:
        infos = {i.filename: i for i in z.infolist() if not i.is_dir()}
        parts = {n: z.read(n) for n in infos}
    if LAYOUT not in parts:
        raise ValueError(f"{path}: no {LAYOUT} part")
    layout, _ = _decode_json(parts[LAYOUT])
    conn = conn_original = None
    enc = "utf-8"
    if CONNECTIONS in parts:
        conn, enc = _decode_json(parts[CONNECTIONS])
        conn_original = json.loads(json.dumps(conn))
    return Pbix(parts, layout, conn, conn_original, enc, infos)


def write_pbix(pbix: Pbix, path) -> None:
    out = dict(pbix.parts)
    out[LAYOUT] = _dump(pbix.layout).encode("utf-16-le")  # no BOM
    if pbix.connection is not None and pbix.connection != pbix._conn_original:
        out[CONNECTIONS] = _dump(pbix.connection).encode(pbix._conn_encoding)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in out.items():
            old = pbix._infos.get(name)
            if old is None:
                z.writestr(name, data)
                continue
            zi = zipfile.ZipInfo(old.filename, old.date_time)
            zi.compress_type = old.compress_type
            zi.external_attr = old.external_attr
            zi.create_system = old.create_system
            z.writestr(zi, data)


def check_upload_rules(path) -> list[str]:
    """Rules from Notes/05 Report Server.md. Empty list means the file passes."""
    problems: list[str] = []
    try:
        z = zipfile.ZipFile(path)
    except (zipfile.BadZipFile, OSError) as e:
        return [f"not a readable zip file ({e})"]
    with z:
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
        else:
            try:
                json.loads(raw.decode("utf-16-le"))
            except ValueError as e:
                problems.append(f"Report/Layout is not valid JSON ({e})")
    return problems


_CATALOG = re.compile(r"(?i)(\b(?:Initial Catalog|Database|Catalog)\s*=\s*)([^;]*)")


def set_database(pbix: Pbix, name: str) -> None:
    """Point a live connection at another database; Data Source and every other field stay as they are.

    The catalog is rewritten in ConnectionString. Other fields (PbiModelDatabaseName ...) are rewritten
    only when they still equal the old catalog.
    """
    if not pbix.connection:
        raise ValueError("pbix has no Connections part (not a live-connection file)")
    changed = 0
    for c in pbix.connection.get("Connections", []):
        cs = c.get("ConnectionString")
        m = _CATALOG.search(cs) if isinstance(cs, str) else None
        if not m:
            continue
        old = m.group(2).strip()
        c["ConnectionString"] = _CATALOG.sub(lambda mm: mm.group(1) + name, cs)
        changed += 1
        for key in ("PbiModelDatabaseName", "InitialCatalog", "Database", "Catalog"):
            if c.get(key) == old:
                c[key] = name
    if not changed:
        raise ValueError("no catalog / database found in any Connections ConnectionString")


_SERVER = re.compile(r"(?i)(\bData Source\s*=\s*)([^;]*)")


def set_server(pbix: Pbix, name: str) -> None:
    """Point a live connection at another server (Data Source). Desktop for Report Server writes the server as the
    user typed it (`localhost\\reportserverdb` on this machine); a file opened elsewhere needs the real host name.
    Other fields (Server, DataSource) are rewritten only when they still equal the old Data Source."""
    if not pbix.connection:
        raise ValueError("pbix has no Connections part (not a live-connection file)")
    changed = 0
    for c in pbix.connection.get("Connections", []):
        cs = c.get("ConnectionString")
        m = _SERVER.search(cs) if isinstance(cs, str) else None
        if not m:
            continue
        old = m.group(2).strip()
        c["ConnectionString"] = _SERVER.sub(lambda mm: mm.group(1) + name, cs)
        changed += 1
        for key in ("Server", "DataSource", "Data Source"):
            if c.get(key) == old:
                c[key] = name
    if not changed:
        raise ValueError("no Data Source found in any Connections ConnectionString")


def _key_of(config: dict) -> str | None:
    """The sample key: title text, else Alt text (vcObjects.general[0].properties.altText)."""
    vco = config.get("singleVisual", {}).get("vcObjects", {})
    for obj, prop in (("title", "text"), ("general", "altText")):
        try:
            v = vco[obj][0]["properties"][prop]["expr"]["Literal"]["Value"]
        except (KeyError, IndexError, TypeError):
            continue
        if isinstance(v, str) and len(v) >= 2 and v[0] == v[-1] == "'":
            t = v[1:-1].strip()
            if t.startswith("sample:"):
                return t
    return None


def samples(pbix: Pbix) -> dict[str, dict]:
    """Map each `sample:<key>` visual on the Samples page to its visual container."""
    page = next((s for s in pbix.layout.get("sections", []) if s.get("displayName") == SAMPLES_PAGE), None)
    if page is None:
        raise ValueError(f"template has no page named '{SAMPLES_PAGE}'")
    found: dict[str, dict] = {}
    dups: list[str] = []
    for vc in page.get("visualContainers", []):
        t = _key_of(json.loads(vc["config"]))
        if t:
            k = t[len("sample:"):]
            if k in found:
                dups.append(f"sample:{k}")
            found[k] = vc
    if dups:
        raise ValueError("duplicate sample visuals: " + ", ".join(sorted(set(dups))))
    missing = [k for k in SAMPLE_KEYS if k not in found]
    if missing:
        raise ValueError("template is missing sample visuals: " + ", ".join(f"sample:{k}" for k in missing))
    return found
