"""Write the report as a Power BI project (PBIP, report in the PBIR folder format) from the page model; no template.

    write_pbip(PAGES, out_dir, database, server) -> out_dir / "HNH Balanced Scorecard.pbip"

Shapes follow Desktop-written files on this server (LAYOUT_FORMAT.md, "PBIR"): the handover project
`Hayat_BSC_Full_RS.Report` (schemas, report/page/visual JSON, filters, slicers, buttons), `test isual.pbix` (the live
connection Desktop for Report Server writes), the legacy pbix's `Report/CustomVisuals` (a private visual), and Power BI
Desktop 2.158's own packaging library and embedded report schemas (`pbir_check.py`). The filter, top N and literal
shapes are the legacy writer's (`layout.py`), with the PBIR key names. Points no real file confirmed are each written by
one function here: `live_connection`, `custom_visual`, `date_range_slicer`, `drill_binding`.
"""
from __future__ import annotations

import json
import re
import shutil
import uuid
import zipfile
from pathlib import Path

from frame import LOGO
from layout import DIRECTION, aliases, field_expr, filter_json, lit, source_expr, stable_id, top_n_json
from model import Field, Filter, Page, Visual, interaction_indexes

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
REPORT_NAME = "HNH Balanced Scorecard"
PERSPECTIVE = "Balanced Scorecard"
SERVER = "HNHANALYTICSSRV\\REPORTSERVERDB"
THEME = HERE / "theme" / "hnh_bsc_theme.json"
BASE_THEME = HERE / "theme" / "CY26SU05.json"  # Desktop's base theme, as Desktop for Report Server writes it
BASE_THEME_NAME = "CY26SU05"
THEME_VERSION = {"visual": "2.9.0", "report": "3.3.0", "page": "2.3.1"}  # handover report.json reportVersionAtImport
VISUAL_DIST = REPO / "powerbi_tmdl" / "hnh_bsc_visual" / "dist"
PAGE_WIDTH, PAGE_HEIGHT = 1920, 1080
SYNC_PREFIX = "bsc "

_FABRIC = "https://developer.microsoft.com/json-schemas/fabric/"
SCHEMAS = {  # every URL as the handover project has it, except modelReference (Desktop 2.158's packaging library)
    "pbip": _FABRIC + "pbip/pbipProperties/1.0.0/schema.json",
    "pbir": _FABRIC + "item/report/definitionProperties/2.0.0/schema.json",
    "platform": _FABRIC + "gitIntegration/platformProperties/2.0.0/schema.json",
    "pbism": _FABRIC + "item/semanticModel/definitionProperties/1.0.0/schema.json",
    "modelReference": _FABRIC + "item/semanticModel/modelReference/2.0.0/schema.json",
    "version": _FABRIC + "item/report/definition/versionMetadata/1.0.0/schema.json",
    "report": _FABRIC + "item/report/definition/report/3.3.0/schema.json",
    "pages": _FABRIC + "item/report/definition/pagesMetadata/1.1.0/schema.json",
    "page": _FABRIC + "item/report/definition/page/2.1.0/schema.json",
    "visual": _FABRIC + "item/report/definition/visualContainer/2.12.0/schema.json",
}

# Visual kinds (Visual.sample) -> PBIR visualType; "hnhVisual" is the packaged visual's guid.
VISUAL_TYPES = {
    "card": "card", "multiRowCard": "multiRowCard", "table": "tableEx", "matrix": "pivotTable",
    "barChart": "clusteredBarChart", "lineChart": "lineChart", "slicerDropdown": "slicer",
    "slicerDateRange": "slicer", "textbox": "textbox", "buttonNavigate": "actionButton",
    "buttonDrill": "actionButton", "hnhVisual": None,
    "panel": "textbox",  # frame.panel: a text box without text, filled by its container background
    "image": "image",  # frame.image: the logo, a RegisteredResources image
}
# Container formatting objects (visualContainerObjects in visualConfiguration 2.8.0). `general` stays in `objects`:
# Visual.props uses it for a text box's paragraphs.
CONTAINER_OBJECTS = {"title", "subTitle", "divider", "spacing", "background", "padding", "lockAspect", "border",
                     "dropShadow", "visualLink", "visualTooltip", "stylePreset", "visualHeader",
                     "visualHeaderTooltip"}
HOW_CREATED = {1: "User", 5: "Drillthrough"}  # legacy numeric howCreated -> PBIR name (same enum order)


# ---- files ---------------------------------------------------------------------------------------------------------

def _text(obj) -> bytes:
    """2-space indented JSON with CRLF line ends and no byte-order mark, as Desktop writes the handover project."""
    return (json.dumps(obj, indent=2, ensure_ascii=False) + "\n").replace("\n", "\r\n").encode("utf-8")


def _guid(*parts) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "hnh-bsc-report/" + "/".join(parts)))


def _platform(kind: str) -> dict:
    return {"$schema": SCHEMAS["platform"], "metadata": {"type": kind, "displayName": REPORT_NAME},
            "config": {"version": "2.0", "logicalId": _guid(kind)}}


def _value(v):
    return {"expr": lit(v)}


# ---- live connection -----------------------------------------------------------------------------------------------

def connection_string(server: str, database: str, perspective: str = PERSPECTIVE) -> str:
    """As Desktop for Report Server writes it in `Connections` (test isual.pbix), with the server name given."""
    return f'Data Source={server};Initial Catalog={database};Cube="{perspective}"'


def live_connection(server: str, database: str, perspective: str = PERSPECTIVE) -> dict[str, dict]:
    """{relative path: JSON} for the dataset reference: definition.pbir points `byPath` at a semantic model folder that
    holds only definition.pbism and modelReference.json (the live connection). Power BI Desktop 2.158's packaging
    library says `byConnection` must point at a Fabric model and "connections to other Analysis Services semantic
    models must use a byPath reference to a semantic model definition containing a modelReference.json file"; its
    project reader reads `<model>.SemanticModel/modelReference.json` when the folder has no model. Shapes checked with
    Desktop's own schema validator and reader (pbir_check.desktop_open); not yet opened in Desktop."""
    model = f"{REPORT_NAME}.SemanticModel"
    return {
        f"{REPORT_NAME}.Report/definition.pbir": {
            "$schema": SCHEMAS["pbir"], "version": "4.0",
            "datasetReference": {"byPath": {"path": f"../{model}"}}},
        f"{model}/.platform": _platform("SemanticModel"),
        f"{model}/definition.pbism": {"$schema": SCHEMAS["pbism"], "version": "4.2", "settings": {}},
        f"{model}/modelReference.json": {
            "$schema": SCHEMAS["modelReference"],
            "connectionString": connection_string(server, database, perspective),
            "connectionType": "analysisServicesDatabaseLive"},
    }


# ---- the HNH visual ------------------------------------------------------------------------------------------------

def _pbiviz_version(path: Path) -> tuple[int, ...] | None:
    """The version `pbiviz package` writes into the file name (`hnhBscVisual<guid>.1.2.0.0.pbiviz`), or None."""
    m = re.search(r"\.(\d+(?:\.\d+)*)\.pbiviz$", path.name)
    return tuple(int(x) for x in m.group(1).split(".")) if m else None


def find_pbiviz(dist: Path = VISUAL_DIST) -> Path:
    """The packaged HNH visual in `dist`: the only one, or the highest version (compared as numbers, 1.10 > 1.9).
    Several packages without a version in the name, or two of the same version, need --pbiviz."""
    found = sorted(Path(dist).glob("hnhBscVisual*.pbiviz"))
    if not found:
        raise FileNotFoundError(f"no packaged HNH visual (*.pbiviz) in {dist}: run `npm run package` in "
                                "powerbi_tmdl/hnh_bsc_visual, or pass the .pbiviz path")
    if len(found) == 1:
        return found[0]
    versions = [_pbiviz_version(f) for f in found]
    if None in versions or versions.count(max(versions)) > 1:
        raise ValueError(f"several HNH visual packages in {dist} ({', '.join(f.name for f in found)}) and no single "
                         "highest version in their names: pass the one to use with --pbiviz")
    return found[versions.index(max(versions))]


def custom_visual(pbiviz: Path) -> tuple[str, dict[str, bytes], dict]:
    """(visual guid, {path under the .Report folder: bytes}, report.json resource package) for the private visual.
    Mirrors how Desktop for Report Server stores an imported .pbiviz in a pbix (`Report/CustomVisuals/<guid>/
    package.json` and `resources/<guid>.pbiviz.json`; a resource package of type 0 = CustomVisual with one item of
    type 5 = CustomVisualMetadata), in the PBIR folder and with PBIR's names for those types. Not confirmed by a
    Desktop-written PBIR file: the handover's visual is an AppSource visual (`publicCustomVisuals`)."""
    pbiviz = Path(pbiviz)
    if not pbiviz.is_file():
        raise FileNotFoundError(f"HNH visual package (.pbiviz) not found: {pbiviz}")
    with zipfile.ZipFile(pbiviz) as z:
        pkg = json.loads(z.read("package.json").decode("utf-8-sig"))
        guid = pkg["visual"]["guid"]
        files = {f"CustomVisuals/{guid}/package.json": json.dumps(pkg, separators=(",", ":"),
                                                                   ensure_ascii=False).encode("utf-8")}
        for res in pkg.get("resources", []):
            files[f"CustomVisuals/{guid}/{res['file']}"] = z.read(res["file"])
    item = f"{guid}.pbiviz.json"
    if f"CustomVisuals/{guid}/resources/{item}" not in files:
        raise ValueError(f"{pbiviz}: no resources/{item} in the package")
    package = {"name": guid, "type": "CustomVisual",
               "items": [{"name": item, "path": item, "type": "CustomVisualMetadata"}]}
    return guid, files, package


# ---- report --------------------------------------------------------------------------------------------------------

def report_json(visual_package: dict) -> dict:
    """report.json: the handover's settings and objects, the base theme, the brand theme as the custom theme (a
    RegisteredResources item of type CustomTheme), the logo (a RegisteredResources item of type Image, as the
    handover registers its header image) and the HNH visual's resource package."""
    return {
        "$schema": SCHEMAS["report"],
        "themeCollection": {
            "baseTheme": {"name": BASE_THEME_NAME, "reportVersionAtImport": THEME_VERSION,
                          "type": "SharedResources"},
            "customTheme": {"name": THEME.name, "reportVersionAtImport": THEME_VERSION,
                            "type": "RegisteredResources"},
        },
        "objects": {"section": [{"properties": {"verticalAlignment": _value("Top")}}]},
        "resourcePackages": [
            {"name": "SharedResources", "type": "SharedResources",
             "items": [{"name": BASE_THEME_NAME, "path": f"BaseThemes/{BASE_THEME_NAME}.json",
                        "type": "BaseTheme"}]},
            {"name": "RegisteredResources", "type": "RegisteredResources",
             "items": [{"name": THEME.name, "path": THEME.name, "type": "CustomTheme"},
                       {"name": LOGO.name, "path": LOGO.name, "type": "Image"}]},
            visual_package,
        ],
        "settings": {
            "useStylableVisualContainerHeader": True, "exportDataMode": "AllowSummarized",
            "defaultDrillFilterOtherVisuals": True, "allowChangeFilterTypes": True, "useEnhancedTooltips": True,
            "useDefaultAggregateDisplayName": True,
        },
    }


# ---- filters -------------------------------------------------------------------------------------------------------

def _pbir_filter(legacy: dict) -> dict:
    """A legacy filter entry (layout.filter_json / top_n_json) with PBIR's keys: `field`, howCreated by name."""
    out = {"name": legacy["name"], "field": legacy["expression"], "type": legacy["type"]}
    if "filter" in legacy:
        out["filter"] = legacy["filter"]
    out["howCreated"] = HOW_CREATED[legacy["howCreated"]]
    return out


def filter_entry(name: str, flt: Filter) -> dict:
    return _pbir_filter(filter_json(name, flt))


def drill_binding(page: Page) -> tuple[dict, list[dict]]:
    """(pageBinding, drill filters) for a drill-through page. `page.keep_filters` is "keep all filters":
    acceptsFilterContext Default ("flows filter context" in page schema 2.1.0) when on, None when off (only the drill
    fields arrive). One parameter and one filter per drill field, named as the legacy writer names them. Standard
    PBIR (page schema); no Desktop-written drill-through page on this server."""
    fields = page.drill_fields or []
    if any(f.kind != "column" for f in fields):
        raise ValueError(f"page {page.display}: drill-through fields must be columns")
    params, filters = [], []
    for i, f in enumerate(fields):
        name = stable_id(page.name, "drill", i)
        filters.append({"name": name, "field": field_expr(f), "type": "Categorical", "howCreated": "Drillthrough"})
        params.append({"name": "Param_" + name, "boundFilter": name, "fieldExpr": field_expr(f)})
    binding = {"name": stable_id(page.name, "pod"), "type": "Drillthrough", "parameters": params,
               "acceptsFilterContext": "Default" if page.keep_filters else "None"}
    return binding, filters


# ---- visuals -------------------------------------------------------------------------------------------------------

def date_range_slicer(column: Field, date_range: tuple[str, str]) -> dict:
    """Slicer objects for a From - To date slicer: style Between (`data.mode`), and the saved range as the slicer's
    selection filter, `general.filter`: `column >= from AND column <= to` (semanticQuery schema 1.4.0: Comparison with
    ComparisonKind 2 GreaterThanOrEqual and 4 LessThanOrEqual, And; datetime literals `datetime'YYYY-MM-DDThh:mm:ss'`).
    Dates are ISO strings, both inclusive. The names `Between` and the filter body follow what Desktop writes for a
    date range slicer; the extracted schemas do not list slicer property values, so only the filter body is
    schema-checked."""
    al = aliases([column.table])
    left = source_expr(column, al[column.table])

    def bound(kind: int, day: str) -> dict:
        return {"Comparison": {"ComparisonKind": kind, "Left": left,
                               "Right": {"Literal": {"Value": f"datetime'{day}T00:00:00'"}}}}
    cond = {"And": {"Left": bound(2, date_range[0]), "Right": bound(4, date_range[1])}}
    flt = {"Version": 2, "From": [{"Name": al[column.table], "Entity": column.table, "Type": 0}],
           "Where": [{"Condition": cond}]}
    return {
        "data": [{"properties": {"mode": _value("Between")}}],
        "general": [{"properties": {"filter": {"filter": flt}}}],
    }


def committed_year(project_dir) -> int | None:
    """The year the committed project's Date slicers are saved on (the date literal in a slicer's `general.filter`),
    or None when the project has none. `build.py` warns when it differs from today's year."""
    for f in sorted(Path(project_dir).glob(f"{REPORT_NAME}.Report/definition/pages/*/visuals/*/visual.json")):
        m = re.search(r"datetime'(\d{4})-", f.read_text(encoding="utf-8"))
        if m:
            return int(m.group(1))
    return None


def _projection(f: Field, active: bool) -> dict:
    p = {"field": field_expr(f), "queryRef": f.ref, "nativeQueryRef": f.name}
    if active:
        p["active"] = True
    return p


def _active(sample: str, role: str) -> bool:
    """Desktop marks a chart's Category and a slicer's field `active`; every matrix row level is active so all
    levels show expanded (legacy writer)."""
    return (role == "Category" or (sample.startswith("slicer") and role == "Values")
            or (sample == "matrix" and role == "Rows"))


def _merge(target: dict, props: dict) -> None:
    """Merge format objects: an entry with the same selector has its properties updated, others are appended."""
    for obj, entries in props.items():
        current = target.setdefault(obj, [])
        for e in json.loads(json.dumps(entries)):
            match = next((x for x in current if x.get("selector") == e.get("selector")), None)
            if match is None:
                current.append(e)
            else:
                match.setdefault("properties", {}).update(e.get("properties", {}))


def visual_json(page: Page, visual: Visual, index: int, visual_guid: str) -> dict:
    if visual.sample not in VISUAL_TYPES:
        raise ValueError(f"page {page.display}: unknown visual kind '{visual.sample}' "
                         f"(known: {', '.join(sorted(VISUAL_TYPES))})")
    vtype = VISUAL_TYPES[visual.sample] or visual_guid
    fields: list[Field] = []
    for fs in visual.roles.values():
        fields += [f for f in fs if f not in fields]
    if visual.sort and visual.sort not in fields:
        raise ValueError(f"page {page.display}: sort field {visual.sort} is not one of the {visual.sample}'s fields")
    if visual.sort_dir not in DIRECTION:
        raise ValueError(f"page {page.display}: sort_dir must be 'desc' or 'asc', got {visual.sort_dir!r}")
    if visual.top_n and visual.top_n[0].kind != "measure":
        raise ValueError(f"page {page.display}: top N ranks by a measure, got {visual.top_n[0]}")
    if not fields and (visual.sort or visual.top_n):
        raise ValueError(f"page {page.display}: a {visual.sample} visual without fields cannot sort or take a top N")

    v: dict = {"visualType": vtype}
    if fields:
        query: dict = {"queryState": {
            role: {"projections": [_projection(f, _active(visual.sample, role)) for f in fs]}
            for role, fs in visual.roles.items()}}
        if visual.sort:
            query["sortDefinition"] = {"sort": [{"field": field_expr(visual.sort),
                                                 "direction": "Ascending" if visual.sort_dir == "asc"
                                                 else "Descending"}]}
        v["query"] = query

    objects: dict = {}
    container: dict = {}
    if visual.sample == "slicerDropdown":
        objects["data"] = [{"properties": {"mode": _value("Dropdown")}}]
    elif visual.sample == "slicerDateRange":
        if visual.date_range is None:
            raise ValueError(f"page {page.display}: a slicerDateRange needs a date_range")
        objects.update(date_range_slicer(fields[0], visual.date_range))
    title = ({"show": _value(True), "text": _value(visual.title)} if visual.title is not None
             else {"show": _value(False)})
    container["title"] = [{"properties": title}]
    _merge(objects, {k: e for k, e in visual.props.items() if k not in CONTAINER_OBJECTS})
    _merge(container, {k: e for k, e in visual.props.items() if k in CONTAINER_OBJECTS})
    if objects:
        v["objects"] = objects
    v["visualContainerObjects"] = container
    if visual.sample.startswith("slicer") and fields:
        # one group per field: the same slicer syncs across pages, slicers on different fields never sync
        v["syncGroup"] = {"groupName": SYNC_PREFIX + fields[0].ref, "fieldChanges": True, "filterChanges": True}
    v["drillFilterOtherVisuals"] = True

    filters = [filter_entry(stable_id(page.name, index, "filter", j), f) for j, f in enumerate(visual.filters)]
    if visual.top_n:
        by, n = visual.top_n
        column = next((f for f in fields if f.kind == "column"), None)
        if column is None:
            raise ValueError(f"page {page.display}: top N on a {visual.sample} visual needs a column to rank")
        filters.append(_pbir_filter(top_n_json(stable_id(page.name, index, "topn"), column, by, n)))

    z = index * 1000
    out = {"$schema": SCHEMAS["visual"], "name": stable_id(page.name, "visual", index),
           "position": {"x": visual.x, "y": visual.y, "z": z, "height": visual.h, "width": visual.w, "tabOrder": z},
           "visual": v}
    if filters:
        out["filterConfig"] = {"filters": filters}
    return out


# ---- pages ---------------------------------------------------------------------------------------------------------

def page_json(page: Page) -> dict:
    out = {"$schema": SCHEMAS["page"], "name": page.name, "displayName": page.display, "displayOption": "FitToPage",
           "height": PAGE_HEIGHT, "width": PAGE_WIDTH}
    filters = [filter_entry(stable_id(page.name, "page-filter", j), f) for j, f in enumerate(page.filters)]
    if page.drill_fields:
        binding, drill = drill_binding(page)
        filters = drill + filters
        out["type"] = "Drillthrough"
        out["pageBinding"] = binding
    if filters:
        out["filterConfig"] = {"filters": filters}
    if page.hidden:
        out["visibility"] = "HiddenInViewMode"
    interactions = [{"source": stable_id(page.name, "visual", s), "target": stable_id(page.name, "visual", t),
                     "type": kind} for s, t, kind in interaction_indexes(page)]
    if interactions:
        out["visualInteractions"] = interactions  # page schema 2.1.0 VisualInteraction {source, target, type}
    return out


def _check_unique(pages: list[Page]) -> None:
    for what, values in (("page name", [p.name for p in pages]), ("page display name", [p.display for p in pages])):
        dups = sorted({v for v in values if values.count(v) > 1})
        if dups:
            raise ValueError(f"duplicate {what}: {', '.join(dups)}")


# ---- project -------------------------------------------------------------------------------------------------------

def project_files(pages: list[Page], database: str, server: str = SERVER, perspective: str = PERSPECTIVE,
                  pbiviz: Path | None = None) -> dict[str, bytes]:
    """{path relative to the output folder: bytes} of the whole project."""
    _check_unique(pages)
    guid, cv_files, cv_package = custom_visual(pbiviz or find_pbiviz())
    rep = f"{REPORT_NAME}.Report"
    files: dict[str, bytes] = {
        f"{REPORT_NAME}.pbip": _text({"$schema": SCHEMAS["pbip"], "version": "1.0",
                                      "artifacts": [{"report": {"path": rep}}],
                                      "settings": {"enableAutoRecovery": True}}),
        ".gitignore": b"**/.pbi/localSettings.json\r\n**/.pbi/cache.abf\r\n",  # what Desktop writes beside a .pbip
        f"{rep}/.platform": _text(_platform("Report")),
    }
    files.update({k: _text(v) for k, v in live_connection(server, database, perspective).items()})
    files[f"{rep}/definition/version.json"] = _text({"$schema": SCHEMAS["version"], "version": "2.0.0"})
    files[f"{rep}/definition/report.json"] = _text(report_json(cv_package))
    files[f"{rep}/definition/pages/pages.json"] = _text({"$schema": SCHEMAS["pages"],
                                                         "pageOrder": [p.name for p in pages],
                                                         "activePageName": pages[0].name if pages else ""})
    for page in pages:
        base = f"{rep}/definition/pages/{page.name}"
        files[f"{base}/page.json"] = _text(page_json(page))
        for i, v in enumerate(page.visuals):
            vj = visual_json(page, v, i, guid)
            path = f"{base}/visuals/{vj['name']}/visual.json"
            if path in files:
                raise ValueError(f"page {page.display}: duplicate visual name {vj['name']}")
            files[path] = _text(vj)
    files[f"{rep}/StaticResources/SharedResources/BaseThemes/{BASE_THEME_NAME}.json"] = BASE_THEME.read_bytes()
    files[f"{rep}/StaticResources/RegisteredResources/{THEME.name}"] = THEME.read_bytes()
    files[f"{rep}/StaticResources/RegisteredResources/{LOGO.name}"] = LOGO.read_bytes()
    files.update({f"{rep}/{k}": b for k, b in cv_files.items()})
    return files


def write_pbip(pages: list[Page], out_dir, database: str, server: str = SERVER, perspective: str = PERSPECTIVE,
               pbiviz: Path | None = None) -> Path:
    """Write the project into `out_dir` and return the .pbip path. The report's generated folders (`definition`,
    `StaticResources`, `CustomVisuals`) are replaced, so pages that are gone do not linger; every other file is
    overwritten, except `.gitignore`, which is written only when missing. Desktop's local state (`.pbi` folders,
    git-ignored) is kept."""
    out = Path(out_dir)
    files = project_files(pages, database, server, perspective, pbiviz)  # everything checked before writing
    rep = out / f"{REPORT_NAME}.Report"
    for d in (rep / "definition", rep / "StaticResources", rep / "CustomVisuals"):
        if d.exists():
            shutil.rmtree(d)
    for rel, data in files.items():
        path = out / rel
        if rel == ".gitignore" and path.exists():
            continue  # the folder's own .gitignore (Desktop may extend it) is kept
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return out / f"{REPORT_NAME}.pbip"
