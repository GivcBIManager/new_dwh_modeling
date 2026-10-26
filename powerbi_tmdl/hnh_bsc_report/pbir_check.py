"""Offline checks of a written PBIP against Power BI Desktop on this machine, without opening Desktop.

- `extract_schemas(dir)`: copy the PBIR report-definition JSON schemas Desktop embeds (tools/extract_schemas.ps1).
- `validate_report(report_dir, schema_dir)`: check every JSON file under `<name>.Report/definition` against its
  `$schema`, with a small JSON Schema (draft-07) validator covering the keywords those schemas use. A file may name a
  newer minor version than Desktop embeds (the handover's visualContainer 2.12.0; Desktop 2.158 has 2.13.0): the
  embedded schema of the same major version is used.
- `desktop_open(pbip)`: open the project with Desktop's own project reader (tools/open_pbip.ps1).

All read only: no server, SSAS or Desktop state changes.
"""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESKTOP_BIN = Path(r"C:\Program Files\Microsoft Power BI Desktop\bin")
_URL = re.compile(r"/definition/([A-Za-z]+)/(\d+)\.(\d+)\.(\d+)/schema\.json$")


def desktop_installed() -> bool:
    return (DESKTOP_BIN / "Microsoft.PowerBI.ClientResources.dll").is_file() and \
        (DESKTOP_BIN / "Microsoft.PowerBI.Packaging.dll").is_file()


def _ps(script: str, *args: str, timeout: int = 300) -> str:
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(HERE / "tools" / script),
                        *args], capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError(f"{script} failed ({r.returncode}): {r.stderr.strip() or r.stdout.strip()}")
    return r.stdout


def extract_schemas(dest, bin_dir: Path | None = None) -> Path:
    """`bin_dir`: another Desktop's bin folder (Desktop for Report Server); the default is DESKTOP_BIN."""
    dest = Path(dest)
    _ps("extract_schemas.ps1", "-Out", str(dest), "-Bin", str(bin_dir or DESKTOP_BIN))
    return dest


def desktop_open(pbip, bin_dir: Path | None = None) -> str:
    return _ps("open_pbip.ps1", "-Pbip", str(Path(pbip).resolve()), "-Bin", str(bin_dir or DESKTOP_BIN)).strip()


# ---- JSON Schema (draft-07 subset) -----------------------------------------------------------------------------------

class _Store:
    """Schemas by $id; a URL with a version Desktop does not embed resolves to the newest embedded one with the same
    name and major version."""

    def __init__(self, schema_dir: Path):
        self.by_id: dict[str, dict] = {}
        self.by_name: dict[tuple[str, int], list[tuple[tuple[int, int, int], str]]] = {}
        for f in sorted(Path(schema_dir).rglob("*.schema.json")):
            s = json.loads(f.read_text(encoding="utf-8-sig"))
            sid = s.get("$id", "")
            self.by_id[sid] = s
            m = _URL.search(sid)
            if m:
                ver = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
                if ver[0] < 9999:
                    self.by_name.setdefault((m.group(1), ver[0]), []).append((ver, sid))
        if not self.by_id:
            raise FileNotFoundError(f"no *.schema.json under {schema_dir}")

    def resolve(self, url: str) -> tuple[dict, str]:
        if url in self.by_id:
            return self.by_id[url], url
        m = _URL.search(url)
        if m:
            versions = sorted(self.by_name.get((m.group(1), int(m.group(2))), []))
            if versions:
                sid = versions[-1][1]
                return self.by_id[sid], sid
        raise KeyError(f"schema not available offline: {url}")


_TYPES = {"object": dict, "array": list, "string": str, "boolean": bool, "null": type(None)}


def _is_type(value, t: str) -> bool:
    if t == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if t == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    return isinstance(value, _TYPES[t])


def _errors(value, schema, root: dict, store: _Store, path: str) -> list[str]:
    if schema is True or schema == {}:
        return []
    if schema is False:
        return [f"{path}: not allowed"]
    if "$ref" in schema:
        ref = schema["$ref"]
        base, _, frag = ref.partition("#")
        target_root = root if not base else store.resolve(base)[0]
        target = target_root
        for part in [p for p in frag.split("/") if p]:
            target = target[part]
        errs = _errors(value, target, target_root, store, path)
        rest = {k: v for k, v in schema.items() if k not in ("$ref", "description")}
        return errs + (_errors(value, rest, root, store, path) if rest else [])
    out: list[str] = []
    t = schema.get("type")
    if t is not None:
        types = t if isinstance(t, list) else [t]
        if not any(_is_type(value, x) for x in types):
            return [f"{path}: expected {t}, got {type(value).__name__}"]
    if "const" in schema and value != schema["const"]:
        out.append(f"{path}: expected {schema['const']!r}, got {value!r}")
    if "enum" in schema and value not in schema["enum"]:
        out.append(f"{path}: {value!r} not one of {schema['enum']}")
    if isinstance(value, str):
        if "pattern" in schema and not re.search(schema["pattern"], value):
            out.append(f"{path}: {value!r} does not match {schema['pattern']}")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            out.append(f"{path}: longer than {schema['maxLength']}")
        if "minLength" in schema and len(value) < schema["minLength"]:
            out.append(f"{path}: shorter than {schema['minLength']}")
    if isinstance(value, dict):
        props = schema.get("properties", {})
        patterns = schema.get("patternProperties", {})
        for req in schema.get("required", []):
            if req not in value:
                out.append(f"{path}: missing required '{req}'")
        for k, v in value.items():
            matched = False
            if k in props:
                matched = True
                out += _errors(v, props[k], root, store, f"{path}.{k}")
            for pat, sub in patterns.items():
                if re.search(pat, k):
                    matched = True
                    out += _errors(v, sub, root, store, f"{path}.{k}")
            if not matched:
                extra = schema.get("additionalProperties", True)
                if extra is False:
                    out.append(f"{path}: unexpected property '{k}'")
                elif isinstance(extra, dict):
                    out += _errors(v, extra, root, store, f"{path}.{k}")
    if isinstance(value, list) and isinstance(schema.get("items"), dict):
        for i, v in enumerate(value):
            out += _errors(v, schema["items"], root, store, f"{path}[{i}]")
    if "allOf" in schema:
        for sub in schema["allOf"]:
            out += _errors(value, sub, root, store, path)
    if "anyOf" in schema:
        results = [_errors(value, sub, root, store, path) for sub in schema["anyOf"]]
        if all(results):
            best = min(results, key=len)
            out.append(f"{path}: matches none of anyOf ({len(results)} options); closest: {'; '.join(best[:3])}")
    if "oneOf" in schema:
        ok = sum(1 for sub in schema["oneOf"] if not _errors(value, sub, root, store, path))
        if ok != 1:
            out.append(f"{path}: matches {ok} of oneOf, expected 1")
    if "not" in schema and not _errors(value, schema["not"], root, store, path):
        out.append(f"{path}: matches a 'not' schema")
    return out


def validate_report(report_dir, schema_dir) -> list[str]:
    """Problems ("<file>: <path>: <message>") of every JSON file under `report_dir/definition`; [] when all pass."""
    store = _Store(Path(schema_dir))
    report_dir = Path(report_dir)
    problems: list[str] = []
    for f in sorted((report_dir / "definition").rglob("*.json")):
        rel = f.relative_to(report_dir).as_posix()
        try:
            doc = json.loads(f.read_bytes().decode("utf-8"))
        except ValueError as e:
            problems.append(f"{rel}: not UTF-8 JSON without a byte-order mark ({e})")
            continue
        url = doc.get("$schema")
        if not url:
            problems.append(f"{rel}: no $schema")
            continue
        try:
            schema, _ = store.resolve(url)
        except KeyError as e:
            problems.append(f"{rel}: {e}")
            continue
        problems += [f"{rel}: {p}" for p in _errors(doc, schema, schema, store, "$")]
    return problems
