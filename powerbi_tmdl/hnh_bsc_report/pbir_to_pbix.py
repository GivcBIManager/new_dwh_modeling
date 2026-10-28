"""Writes a legacy Report Server .pbix from any PBIP (PBIR) report with a live connection to SSAS.

    python powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py <report.pbip> --out <file.pbix> [--base-theme <json>]

Why: Power BI Report Server on HNHANALYTICSSRV (May 2026, 1.26.9637) reads a report from the package part
`Report/Layout` (the legacy layout: one UTF-16 LE JSON document) and answers 400 to a package that holds the PBIR
folder `Report/definition` instead (its parser PbixParserV1.GetReportDocumentFromPowerBIPackage finds no document;
RSPowerBI log, 2026-10-26). Power BI Desktop 2.158 and Desktop for Report Server (May 2026) both save a PBIR
project as a PBIR package, and neither converts back, so a generated PBIP cannot reach the server without this.

What it writes (shapes from `powerbi_tmdl/test isual.pbix`, written by Desktop for Report Server, the handover's
legacy pbix and `LAYOUT_FORMAT.md`):

- `Report/Layout`: every page as a `sections[]` entry (filters as the legacy list: `expression` for `field`,
  `howCreated` 1 = User, 5 = Drillthrough; hidden state, drillthrough binding and visual interactions in the page
  `config`), every visual as a `visualContainers[]` entry (`projections` role -> queryRef, a `prototypeQuery` with
  From aliases, Select named by queryRef and OrderBy from the sort, `columnProperties` for display names,
  `objects`, `vcObjects` = visualContainerObjects, `syncGroup`, the visual's filters), and the report `config`
  (theme collection, settings) as a JSON string;
- resource packages: the PBIP's RegisteredResources (images type 100, a custom theme 201, package type 1), every
  packaged custom visual (package type 0, item type 5) and one base theme as SharedResources (type 2, item 202):
  `--base-theme` (default `theme/CY26SU05.json` next to this file, the theme Desktop for Report Server writes);
- `Connections` from the PBIP's modelReference.json, in the form Desktop for Report Server writes
  (`Data Source=...;Initial Catalog=...;Cube="..."`), plus `Version` 1.28, `Settings`, `Metadata`, `DiagramLayout`
  and `[Content_Types].xml` as Desktop for Report Server writes them.

Checks before uploading: `pbix.check_upload_rules(<file>)` must return [] and Desktop for Report Server must open
the file (it reads the legacy package; do not save from there). Not covered: bookmarks, field parameters, report
measures (reportExtensions.json), visual calculations, hierarchy fields, mobile layouts; the tool stops on the first
of these it meets. Read only apart from the output file.
"""
from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_BASE_THEME = HERE / "theme" / "CY26SU05.json"
THEME_VERSION = {"visual": "2.9.0", "report": "3.3.0", "page": "2.3.1"}  # what Desktop for Report Server writes
DISPLAY_OPTION = {"FitToPage": 1, "FitToWidth": 2, "ActualSize": 3}
HOW_CREATED = {"User": 1, "Drillthrough": 5}
INTERACTION = {"Default": 0, "DataFilter": 1, "HighlightFilter": 2, "NoFilter": 3}
SORT = {"Ascending": 1, "Descending": 2}
RESOURCE_ITEM = {"Image": 100, "CustomTheme": 201}
VERSION_PART = "1.28".encode("utf-16-le")
SETTINGS_PART = ('{"Version":4,"ReportSettings":{},"QueriesSettings":{"TypeDetectionEnabled":true,'
                 '"RelationshipImportEnabled":true,"Version":"2.154.778.0"}}').encode("utf-8")
METADATA_PART = '{"Version":5,"AutoCreatedRelationships":[],"CreatedFrom":"OnPrem","CreatedFromRelease":"2026.05"}'.encode("utf-8")
DIAGRAM_PART = ('{"version":"1.1.0","diagrams":[{"ordinal":0,"scrollPosition":{"x":0,"y":0},"nodes":[],"name":"All tables",'
                '"zoomValue":100,"pinKeyFieldsToTop":false,"showExtraHeaderInfo":false,"hideKeyFieldsWhenCollapsed":false,'
                '"tablesLocked":false}],"selectedDiagram":"All tables","defaultDiagram":"All tables"}').encode("utf-8")
CONTENT_TYPES = (
    '<?xml version="1.0" encoding="utf-8"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="json" ContentType="" /><Default Extension="png" ContentType="" />'
    '<Default Extension="jpg" ContentType="" /><Default Extension="jpeg" ContentType="" />'
    '<Default Extension="svg" ContentType="" /><Default Extension="gif" ContentType="" />'
    '<Override PartName="/Version" ContentType="" /><Override PartName="/DiagramLayout" ContentType="" />'
    '<Override PartName="/Report/Layout" ContentType="" />'
    '<Override PartName="/Settings" ContentType="application/json" />'
    '<Override PartName="/Metadata" ContentType="application/json" />'
    '<Override PartName="/Connections" ContentType="" /></Types>').encode("utf-8")


class Unsupported(ValueError):
    """A PBIR construct this tool does not translate."""


def dump(obj) -> str:
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def aliases(tables: list[str]) -> dict[str, str]:
    """From aliases the way Desktop writes them: the table's first letter in lower case ('_' for _Measures), then
    'p1', 'p2' ... for the next tables with the same letter."""
    out: dict[str, str] = {}
    for t in tables:
        if t in out:
            continue
        base = next((c.lower() for c in t if c.isalpha() or c == "_"), "t")
        a, n = base, 1
        while a in out.values() or a == "subquery":
            a, n = f"{base}{n}", n + 1
        out[t] = a
    return out


def field_parts(field: dict, where: str) -> tuple[str, str, str]:
    kind = "Column" if "Column" in field else "Measure" if "Measure" in field else None
    if kind is None:
        raise Unsupported(f"{where}: field kind {list(field)} (only Column and Measure are translated)")
    src = field[kind]["Expression"]["SourceRef"]
    if "Entity" not in src or src.get("Schema"):
        raise Unsupported(f"{where}: field {field[kind]['Property']} is not a model field (report-level measure?)")
    return kind, src["Entity"], field[kind]["Property"]


def source_field(field: dict, al: dict[str, str], where: str) -> dict:
    kind, table, prop = field_parts(field, where)
    return {kind: {"Expression": {"SourceRef": {"Source": al[table]}}, "Property": prop}}


# ---- visuals ------------------------------------------------------------------------------------------------------

def convert_filters(filters: list[dict], where: str) -> list[dict]:
    out = []
    for f in filters:
        if f.get("howCreated") not in HOW_CREATED:
            raise Unsupported(f"{where}: filter howCreated {f.get('howCreated')!r}")
        field_parts(f["field"], where)
        entry = {"name": f["name"], "expression": f["field"], "type": f["type"], "howCreated": HOW_CREATED[f["howCreated"]]}
        if "filter" in f:
            entry["filter"] = f["filter"]
        if f.get("isLockedInViewMode"):
            entry["isLockedInViewMode"] = True
        out.append(entry)
    return out


def convert_visual(v: dict, where: str) -> dict:
    if "visualGroup" in v:
        raise Unsupported(f"{where}: visual groups")
    vis = v["visual"]
    sv: dict = {"visualType": vis["visualType"]}
    query = vis.get("query")
    if query:
        state = query.get("queryState", {})
        projections, selects, column_props, tables = {}, [], {}, []
        for role, spec in state.items():
            items = []
            for proj in spec.get("projections", []):
                kind, table, prop = field_parts(proj["field"], where)
                if table not in tables:
                    tables.append(table)
                item = {"queryRef": proj["queryRef"]}
                if proj.get("active") is not None:
                    item["active"] = proj["active"]
                items.append(item)
                if proj.get("displayName"):
                    column_props[proj["queryRef"]] = {"displayName": proj["displayName"]}
                selects.append((proj["field"], proj["queryRef"], prop))
            projections[role] = items
        al = aliases(tables)
        proto = {"Version": 2, "From": [{"Name": a, "Entity": t, "Type": 0} for t, a in al.items()],
                 "Select": [{**source_field(f, al, where), "Name": ref, "NativeReferenceName": native}
                            for f, ref, native in selects]}
        sort = query.get("sortDefinition", {}).get("sort")
        if sort:
            proto["OrderBy"] = [{"Direction": SORT[s["direction"]], "Expression": source_field(s["field"], al, where)}
                                for s in sort]
        sv["projections"] = projections
        sv["prototypeQuery"] = proto
        if column_props:
            sv["columnProperties"] = column_props
    sv["drillFilterOtherVisuals"] = bool(vis.get("drillFilterOtherVisuals", True))
    for key in ("objects", "visualContainerObjects", "syncGroup"):
        if vis.get(key):
            sv["vcObjects" if key == "visualContainerObjects" else key] = vis[key]
    pos = v["position"]
    position = {"x": pos["x"], "y": pos["y"], "z": pos["z"], "width": pos["width"], "height": pos["height"],
                "tabOrder": pos.get("tabOrder", 0)}
    config = {"name": v["name"], "layouts": [{"id": 0, "position": position}], "singleVisual": sv}
    if v.get("isHidden"):
        config["singleVisual"]["display"] = {"mode": "hidden"}
    container = {**position, "config": dump(config),
                 "filters": dump(convert_filters(v.get("filterConfig", {}).get("filters", []), where))}
    return container


# ---- pages --------------------------------------------------------------------------------------------------------

def convert_page(page: dict, visuals: list[dict], ordinal: int) -> dict:
    where = f"page {page['displayName']}"
    config: dict = {}
    if page.get("visibility") == "HiddenInViewMode":
        config["visibility"] = 1
    if page.get("pageBinding"):
        config["pageBinding"] = page["pageBinding"]
    if page.get("visualInteractions"):
        config["visualInteractions"] = [{"source": i["source"], "target": i["target"], "type": INTERACTION[i["type"]]}
                                        for i in page["visualInteractions"]]
    if page.get("objects"):
        config["objects"] = page["objects"]
    containers = [convert_visual(v, f"{where}, visual {v['name']}") for v in sorted(visuals, key=lambda v: v["position"]["z"])]
    return {
        "id": ordinal,
        "name": page["name"],
        "displayName": page["displayName"],
        "filters": dump(convert_filters(page.get("filterConfig", {}).get("filters", []), where)),
        "ordinal": ordinal,
        "config": dump(config),
        "displayOption": DISPLAY_OPTION[page.get("displayOption", "FitToPage")],
        "width": page["width"],
        "height": page["height"],
        "visualContainers": containers,
    }


# ---- report -------------------------------------------------------------------------------------------------------

def report_dir_of(pbip: Path) -> Path:
    artifacts = read(pbip)["artifacts"]
    rel = next(a["report"]["path"] for a in artifacts if "report" in a)
    return (pbip.parent / rel).resolve()


def model_reference_of(report_dir: Path) -> dict:
    pbir = read(report_dir / "definition.pbir")
    by_path = pbir.get("datasetReference", {}).get("byPath")
    if not by_path:
        raise Unsupported("definition.pbir: only a byPath dataset reference (a modelReference.json) is translated")
    return read((report_dir / by_path["path"]).resolve() / "modelReference.json")


def convert(pbip: Path, base_theme: Path = DEFAULT_BASE_THEME) -> tuple[list[tuple[str, bytes]], dict]:
    """(package parts in order, legacy layout) of the PBIP."""
    report_dir = report_dir_of(pbip)
    definition = report_dir / "definition"
    if (definition / "reportExtensions.json").exists():
        raise Unsupported("reportExtensions.json: report-level measures are not translated; put them in the model")
    if (definition / "bookmarks").exists():
        raise Unsupported("bookmarks are not translated")
    report = read(definition / "report.json")
    order = read(definition / "pages" / "pages.json")["pageOrder"]
    sections = []
    for i, name in enumerate(order):
        page_dir = definition / "pages" / name
        page = read(page_dir / "page.json")
        visuals = [read(p) for p in sorted(page_dir.glob("visuals/*/visual.json"))]
        sections.append(convert_page(page, visuals, i))

    parts: dict[str, bytes] = {}
    registered, custom_theme, visual_packages = [], None, []
    for pkg in report.get("resourcePackages", []):
        if pkg["type"] == "RegisteredResources":
            for item in pkg["items"]:
                if item["type"] not in RESOURCE_ITEM:
                    raise Unsupported(f"report.json: registered resource type {item['type']}")
                if item["type"] == "CustomTheme":
                    custom_theme = item["name"]
                registered.append({"name": item["name"], "path": item["path"], "type": RESOURCE_ITEM[item["type"]]})
                parts["Report/StaticResources/RegisteredResources/" + item["path"]] = \
                    (report_dir / "StaticResources" / "RegisteredResources" / item["path"]).read_bytes()
        elif pkg["type"] == "CustomVisual":
            guid = pkg["name"]
            visual_packages.append({"resourcePackage": {
                "name": guid, "type": 0,
                "items": [{"name": it["name"], "path": it["path"], "type": 5} for it in pkg["items"]],
                "disabled": False}})
            cv = report_dir / "CustomVisuals" / guid
            parts[f"Report/CustomVisuals/{guid}/package.json"] = (cv / "package.json").read_bytes()
            for it in pkg["items"]:
                parts[f"Report/CustomVisuals/{guid}/resources/{it['path']}"] = (cv / "resources" / it["path"]).read_bytes()
        elif pkg["type"] != "SharedResources":
            raise Unsupported(f"report.json: resource package type {pkg['type']}")
    if report.get("publicCustomVisuals"):
        raise Unsupported("publicCustomVisuals (AppSource visuals) are not translated; package the visual in the report")
    theme_name = base_theme.stem
    parts[f"Report/StaticResources/SharedResources/BaseThemes/{theme_name}.json"] = base_theme.read_bytes()
    resource_packages = [
        {"resourcePackage": {"name": "SharedResources", "type": 2,
                             "items": [{"type": 202, "path": f"BaseThemes/{theme_name}.json", "name": theme_name}],
                             "disabled": False}},
    ]
    if registered:
        resource_packages.append({"resourcePackage": {"name": "RegisteredResources", "type": 1, "items": registered,
                                                      "disabled": False}})
    resource_packages += visual_packages
    theme_collection = {"baseTheme": {"name": theme_name, "type": 2, "version": THEME_VERSION}}
    if custom_theme:
        theme_collection["customTheme"] = {"name": custom_theme, "type": 1, "version": THEME_VERSION}
    settings = dict(report.get("settings", {}))
    config = {
        "version": "5.73",
        "themeCollection": theme_collection,
        "activeSectionIndex": 0,
        "defaultDrillFilterOtherVisuals": bool(settings.pop("defaultDrillFilterOtherVisuals", True)),
        "settings": {"useNewFilterPaneExperience": True, "queryLimitOption": 6, "exportDataMode": 1, **settings},
        "objects": report.get("objects") or
                   {"section": [{"properties": {"verticalAlignment": {"expr": {"Literal": {"Value": "'Top'"}}}}}]},
    }
    layout = {"id": 0, "resourcePackages": resource_packages, "sections": sections, "config": dump(config),
              "layoutOptimization": 0}
    report_filters = report.get("filterConfig", {}).get("filters", [])
    if report_filters:  # the report-level filters, as the legacy layout's own `filters`
        layout["filters"] = dump(convert_filters(report_filters, "report.json"))

    ref = model_reference_of(report_dir)
    if ref.get("connectionType") != "analysisServicesDatabaseLive":
        raise Unsupported(f"modelReference.json: connection type {ref.get('connectionType')}")
    cs = dict(kv.split("=", 1) for kv in ref["connectionString"].split(";") if "=" in kv)
    cube = cs["Cube"].strip('"')
    connection = {"Version": 1, "Connections": [{
        "Name": "EntityDataSource",
        "ConnectionString": f"Data Source={cs['Data Source']};Initial Catalog={cs['Initial Catalog']};Cube=\"{cube}\"",
        "ConnectionType": "analysisServicesDatabaseLive"}]}
    ordered: list[tuple[str, bytes]] = [
        ("Version", VERSION_PART),
        ("[Content_Types].xml", CONTENT_TYPES),
        ("DiagramLayout", DIAGRAM_PART),
        ("Report/Layout", dump(layout).encode("utf-16-le")),  # no BOM
        ("Settings", SETTINGS_PART),
        ("Metadata", METADATA_PART),
        ("Connections", dump(connection).encode("utf-8")),
        *sorted(parts.items()),
    ]
    return ordered, layout


def write(pbip: Path, out: Path, base_theme: Path = DEFAULT_BASE_THEME) -> dict:
    parts, layout = convert(pbip, base_theme)
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in parts:
            z.writestr(name, data)
    return layout


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("pbip", help="the .pbip file of the report")
    ap.add_argument("--out", required=True, help="the .pbix to write (upload this one)")
    ap.add_argument("--base-theme", default=str(DEFAULT_BASE_THEME), help="base theme JSON (default CY26SU05)")
    a = ap.parse_args()
    layout = write(Path(a.pbip), Path(a.out), Path(a.base_theme))
    n_visuals = sum(len(s["visualContainers"]) for s in layout["sections"])
    print(f"wrote {a.out}: {len(layout['sections'])} pages, {n_visuals} visuals; "
          f"check it with pbix.check_upload_rules and open it in Desktop for Report Server before uploading")


if __name__ == "__main__":
    main()
