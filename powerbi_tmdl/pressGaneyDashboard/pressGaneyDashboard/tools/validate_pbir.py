"""Validates the generated PBIP before opening it in Power BI Desktop. Read only.

    python tools/validate_pbir.py [--desktop-rs]

1. JSON-schema validation of every report-definition file against the PBIR schemas Power BI Desktop embeds
   (powerbi_tmdl/hnh_bsc_report/pbir_check.py: the same check Desktop runs), and the project opened with Desktop's
   own project reader. With --desktop-rs the same two checks run against Power BI Desktop for Report Server.
2. Semantic checks: every Column reference exists in the perspective (tools/model_fields.json), every Measure
   reference is a model measure of the perspective (model_fields.json or the repository's TMDL), no report-level
   measures, custom-visual roles exist in the visual's capabilities, registered resources exist on disk, queryRefs
   are unique per visual, and visuals stay on the canvas without overlapping.
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
REPORT = ROOT / "PressGaneyDashboard.Report"
MODEL = ROOT / "PressGaneyDashboard.SemanticModel"
BSC = ROOT.parents[1] / "hnh_bsc_report"
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(BSC))
import pbir_check  # noqa: E402
from model_measures import perspective_measure_names  # noqa: E402

errors: list[str] = []
warnings: list[str] = []


def walk_fields(node, found: list):
    if isinstance(node, dict):
        for kind in ("Column", "Measure"):
            if kind in node and isinstance(node[kind], dict) and "Property" in node[kind]:
                src = node[kind].get("Expression", {}).get("SourceRef", {})
                if "Entity" in src:
                    found.append((kind, src["Entity"], node[kind]["Property"], src.get("Schema")))
        for v in node.values():
            walk_fields(v, found)
    elif isinstance(node, list):
        for v in node:
            walk_fields(v, found)


def desktop_checks(desktop_rs: bool) -> None:
    if desktop_rs:
        pbir_check.DESKTOP_BIN = Path(r"C:\Program Files\Microsoft Power BI Desktop RS\bin")
    label = "Desktop for Report Server" if desktop_rs else "Desktop"
    if not pbir_check.desktop_installed():
        warnings.append(f"{label} not found under {pbir_check.DESKTOP_BIN}: schema and project-reader checks skipped")
        return
    with tempfile.TemporaryDirectory() as tmp:
        schemas = pbir_check.extract_schemas(Path(tmp) / "schemas", bin_dir=pbir_check.DESKTOP_BIN)
        for p in pbir_check.validate_report(REPORT, schemas):
            errors.append(f"{label} schema: {p}")
    try:
        out = pbir_check.desktop_open(ROOT / "PressGaneyDashboard.pbip", bin_dir=pbir_check.DESKTOP_BIN)
    except RuntimeError as e:
        errors.append(f"{label} project reader: {e}")
        return
    for line in out.splitlines():
        if line.startswith("FAIL") or line.startswith("issue:"):
            errors.append(f"{label} project reader: {line}")
    print(f"{label}: schemas checked, project reader: {out.splitlines()[0] if out else '(no output)'}")


def main() -> int:
    desktop_checks("--desktop-rs" in sys.argv)

    fields = json.loads((TOOLS / "model_fields.json").read_text(encoding="utf-8-sig"))["tables"]
    columns = {(t, c) for t, s in fields.items() for c in s["columns"]}
    measures = {m for s in fields.values() for m in s["measures"]} | perspective_measure_names()
    if (REPORT / "definition/reportExtensions.json").exists():
        errors.append("reportExtensions.json exists: every measure belongs in the SSAS model")

    report = json.loads((REPORT / "definition/report.json").read_text(encoding="utf-8"))
    custom_roles: dict[str, set] = {}
    for pkg in report.get("resourcePackages", []):
        for item in pkg["items"]:
            if pkg["type"] == "SharedResources":
                p = REPORT / "StaticResources/SharedResources" / item["path"]
            elif pkg["type"] == "RegisteredResources":
                p = REPORT / "StaticResources/RegisteredResources" / item["path"]
            elif pkg["type"] == "CustomVisual":
                p = REPORT / "CustomVisuals" / pkg["name"] / "resources" / item["path"]
                caps = json.loads(p.read_text(encoding="utf-8"))["capabilities"]
                custom_roles[pkg["name"]] = {r["name"] for r in caps["dataRoles"]}
            else:
                continue
            if not p.exists():
                errors.append(f"report.json: resource {pkg['name']}/{item['path']} missing at {p}")

    page_order = json.loads((REPORT / "definition/pages/pages.json").read_text(encoding="utf-8"))["pageOrder"]
    n_visuals = 0
    for page_name in page_order:
        page_dir = REPORT / "definition/pages" / page_name
        page = json.loads((page_dir / "page.json").read_text(encoding="utf-8"))
        boxes = []
        found: list = []
        walk_fields(page.get("filterConfig", {}), found)
        for vfile in sorted(page_dir.glob("visuals/*/visual.json")):
            n_visuals += 1
            v = json.loads(vfile.read_text(encoding="utf-8"))
            label = f"{page['displayName']}/{v['name']}"
            pos = v["position"]
            if pos["x"] < 0 or pos["y"] < 0 or pos["x"] + pos["width"] > page["width"] or pos["y"] + pos["height"] > page["height"]:
                errors.append(f"{label}: outside the canvas")
            vis = v.get("visual", {})
            vtype = vis.get("visualType")
            if vtype not in ("shape", "image", "textbox"):
                boxes.append((label, pos))
            refs = []
            for role, state in vis.get("query", {}).get("queryState", {}).items():
                if vtype in custom_roles and role not in custom_roles[vtype]:
                    errors.append(f"{label}: role '{role}' not defined by custom visual {vtype}")
                for proj in state["projections"]:
                    refs.append(proj["queryRef"])
            if len(refs) != len(set(refs)):
                errors.append(f"{label}: duplicate queryRef {refs}")
            for link in vis.get("visualContainerObjects", {}).get("visualLink", []):
                target = link["properties"].get("navigationSection", {}).get("expr", {}).get("Literal", {}).get("Value")
                if target and target.strip("'") not in page_order:
                    errors.append(f"{label}: navigation target {target} is not a page")
            walk_fields(vis, found)
            walk_fields(v.get("filterConfig", {}), found)
        for kind, table, prop, schema in found:
            if schema is not None:
                errors.append(f"{page['displayName']}: {kind} {table}[{prop}] uses schema '{schema}' (report-level measure?)")
            elif kind == "Column":
                if (table, prop) not in columns:
                    errors.append(f"{page['displayName']}: unresolvable Column {table}[{prop}]")
            elif table != "_Measures" or prop not in measures:
                errors.append(f"{page['displayName']}: unresolvable Measure {table}[{prop}]")
        for i, (la, a) in enumerate(boxes):
            for lb, b in boxes[i + 1:]:
                if a["x"] < b["x"] + b["width"] and b["x"] < a["x"] + a["width"] and \
                   a["y"] < b["y"] + b["height"] and b["y"] < a["y"] + a["height"]:
                    warnings.append(f"overlap: {la} and {lb}")

    for w in warnings:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print(f"\nChecked {len(page_order)} pages, {n_visuals} visuals: {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
