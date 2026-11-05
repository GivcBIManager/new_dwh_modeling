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
from dataclasses import dataclass
from pathlib import Path

from frame import LOGO
from layout import (DIRECTION, aliases, field_expr, filter_json, lit, report_filters_json, source_expr, stable_id,
                    top_n_json)
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
PAGE_WIDTH = 1920
SYNC_PREFIX = "bsc "


@dataclass(frozen=True)
class ReportSpec:
    """What differs between reports built by this generator: the project / report name (folder and file names, the
    `displayName`), the perspective of the live connection, the custom theme, the logo, and whether the report carries
    the HNH custom visual (False: no `CustomVisuals/` folder and no .pbiviz is looked for). `images`: more images
    registered beside the logo (RegisteredResources, by file name), for image visuals such as card icons.
    `cross_filter`: a selection in a chart filters the other visuals instead of highlighting them (report setting
    `defaultFilterActionIsDataFilter`, Desktop's "Change default visual interaction from cross highlighting to cross
    filtering")."""
    name: str
    perspective: str
    theme: Path
    logo: Path
    custom_visual: bool
    images: tuple[Path, ...] = ()
    cross_filter: bool = False


BSC_REPORT = ReportSpec(REPORT_NAME, PERSPECTIVE, THEME, LOGO, True)

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
    "stackedColumnChart": "columnChart", "waterfallChart": "waterfallChart", "columnChart": "clusteredColumnChart",
    "donutChart": "donutChart", "comboChart": "lineClusteredColumnComboChart",
    "slicerTile": "slicer",  # a slicer drawn as buttons (Desktop's Tile style)
    "slicerDateRange": "slicer", "textbox": "textbox", "buttonNavigate": "actionButton",
    "buttonDrill": "actionButton", "hnhVisual": None,
    "panel": "textbox",  # frame.panel: a text box without text, filled by its container background
    "image": "image",  # frame.image: the logo, a RegisteredResources image
}
# Container formatting objects (visualContainerObjects in visualConfiguration 2.8.0). `general` stays in `objects`
# (Visual.props uses it for a text box's paragraphs), except on the HNH visual (write_visual).
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


def _platform(kind: str, report: ReportSpec = BSC_REPORT) -> dict:
    return {"$schema": SCHEMAS["platform"], "metadata": {"type": kind, "displayName": report.name},
            "config": {"version": "2.0", "logicalId": _guid(kind)}}


def _value(v):
    return {"expr": lit(v)}


# ---- live connection -----------------------------------------------------------------------------------------------

def connection_string(server: str, database: str, perspective: str = PERSPECTIVE) -> str:
    """As Desktop for Report Server writes it in `Connections` (test isual.pbix), with the server name given."""
    return f'Data Source={server};Initial Catalog={database};Cube="{perspective}"'


def live_connection(server: str, database: str, perspective: str = PERSPECTIVE,
                    report: ReportSpec = BSC_REPORT) -> dict[str, dict]:
    """{relative path: JSON} for the dataset reference: definition.pbir points `byPath` at a semantic model folder that
    holds only definition.pbism and modelReference.json (the live connection). Power BI Desktop 2.158's packaging
    library says `byConnection` must point at a Fabric model and "connections to other Analysis Services semantic
    models must use a byPath reference to a semantic model definition containing a modelReference.json file"; its
    project reader reads `<model>.SemanticModel/modelReference.json` when the folder has no model. Shapes checked with
    Desktop's own schema validator and reader (pbir_check.desktop_open); not yet opened in Desktop."""
    model = f"{report.name}.SemanticModel"
    return {
        f"{report.name}.Report/definition.pbir": {
            "$schema": SCHEMAS["pbir"], "version": "4.0",
            "datasetReference": {"byPath": {"path": f"../{model}"}}},
        f"{model}/.platform": _platform("SemanticModel", report),
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

def report_json(visual_package: dict | None, report_filters: list[Filter] = (),
                report: ReportSpec = BSC_REPORT) -> dict:
    """report.json: the handover's settings and objects, the base theme, the brand theme as the custom theme (a
    RegisteredResources item of type CustomTheme), the logo (a RegisteredResources item of type Image, as the
    handover registers its header image), the HNH visual's resource package and the report-level filters (locked)."""
    out = {
        "$schema": SCHEMAS["report"],
        "themeCollection": {
            "baseTheme": {"name": BASE_THEME_NAME, "reportVersionAtImport": THEME_VERSION,
                          "type": "SharedResources"},
            "customTheme": {"name": report.theme.name, "reportVersionAtImport": THEME_VERSION,
                            "type": "RegisteredResources"},
        },
        "objects": {"section": [{"properties": {"verticalAlignment": _value("Top")}}]},
        "resourcePackages": [
            {"name": "SharedResources", "type": "SharedResources",
             "items": [{"name": BASE_THEME_NAME, "path": f"BaseThemes/{BASE_THEME_NAME}.json",
                        "type": "BaseTheme"}]},
            {"name": "RegisteredResources", "type": "RegisteredResources",
             "items": [{"name": report.theme.name, "path": report.theme.name, "type": "CustomTheme"},
                       {"name": report.logo.name, "path": report.logo.name, "type": "Image"}]
                      + [{"name": i.name, "path": i.name, "type": "Image"} for i in report.images]},
        ] + ([visual_package] if report.custom_visual else []),
        "settings": {
            "useStylableVisualContainerHeader": True, "exportDataMode": "AllowSummarized",
            "defaultDrillFilterOtherVisuals": True, "allowChangeFilterTypes": True, "useEnhancedTooltips": True,
            "useDefaultAggregateDisplayName": True,
            **({"defaultFilterActionIsDataFilter": True} if report.cross_filter else {}),
        },
    }
    if report_filters:
        out["filterConfig"] = {"filters": [_pbir_filter(f) for f in report_filters_json(list(report_filters))]}
    return out


# ---- filters -------------------------------------------------------------------------------------------------------

def _pbir_filter(legacy: dict) -> dict:
    """A legacy filter entry (layout.filter_json / top_n_json) with PBIR's keys: `field`, howCreated by name."""
    out = {"name": legacy["name"], "field": legacy["expression"], "type": legacy["type"]}
    if "filter" in legacy:
        out["filter"] = legacy["filter"]
    out["howCreated"] = HOW_CREATED[legacy["howCreated"]]
    if legacy.get("isLockedInViewMode"):
        out["isLockedInViewMode"] = True
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


def committed_year(project_dir, report: ReportSpec = BSC_REPORT) -> int | None:
    """The year the committed project's Date slicers are saved on (the date literal in a slicer's `general.filter`),
    or None when the project has none. `build.py` warns when it differs from today's year."""
    for f in sorted(Path(project_dir).glob(f"{report.name}.Report/definition/pages/*/visuals/*/visual.json")):
        m = re.search(r"datetime'(\d{4})-", f.read_text(encoding="utf-8"))
        if m:
            return int(m.group(1))
    return None


def _projection(f: Field, active: bool, label: str | None = None) -> dict:
    """`label`: the field's name in this visual (`displayName`, as Desktop writes a field renamed in a visual)."""
    p = {"field": field_expr(f), "queryRef": f.ref, "nativeQueryRef": f.name}
    if label:
        p["displayName"] = label
    if active:
        p["active"] = True
    return p


def _active(sample: str, role: str, position: int = 0, expand: bool = True) -> bool:
    """Desktop marks a chart's Category and a slicer's field `active`; every matrix row level is active so all
    levels show expanded (legacy writer). A chart with several Category fields is a drill-down: only the top level is
    active (all active would show the levels' values joined on one axis); a matrix with `expand` off shows its top
    row level, the others reached by expand or drill down."""
    if role == "Category":
        return position == 0
    if sample == "matrix" and role == "Rows":
        return expand or position == 0
    return sample.startswith("slicer") and role == "Values"


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
            role: {"projections": [_projection(f, _active(visual.sample, role, i, visual.expand), visual.labels.get(f))
                                   for i, f in enumerate(fs)]}
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
        # without a date_range: a From - To slicer with no saved selection (every date until the user picks)
        objects.update(date_range_slicer(fields[0], visual.date_range) if visual.date_range is not None
                       else {"data": [{"properties": {"mode": _value("Between")}}]})
    elif visual.sample == "slicerTile":
        # Desktop's Tile style: Basic mode laid out horizontally (general.orientation 1), each item a button
        objects["data"] = [{"properties": {"mode": _value("Basic")}}]
        objects["general"] = [{"properties": {"orientation": {"expr": {"Literal": {"Value": "1D"}}}}}]
    title = ({"show": _value(True), "text": _value(visual.title)} if visual.title is not None
             else {"show": _value(False)})
    container["title"] = [{"properties": title}]
    # The HNH visual has no `general` object of its own (capabilities: scorecard, colours), so its `general` is the
    # container's (keepLayerOrder)
    container_keys = CONTAINER_OBJECTS | ({"general"} if visual.sample == "hnhVisual" else set())
    _merge(objects, {k: e for k, e in visual.props.items() if k not in container_keys})
    _merge(container, {k: e for k, e in visual.props.items() if k in container_keys})
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
    # A page taller than the 1080 px screen fits its width and scrolls; FitToPage would shrink it to one screen
    fit = "FitToWidth" if page.height > 1080 else "FitToPage"
    out = {"$schema": SCHEMAS["page"], "name": page.name, "displayName": page.display, "displayOption": fit,
           "height": page.height, "width": PAGE_WIDTH}
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

def project_files(pages: list[Page], database: str, server: str = SERVER, perspective: str | None = None,
                  pbiviz: Path | None = None, report_filters: list[Filter] = (),
                  report: ReportSpec = BSC_REPORT) -> dict[str, bytes]:
    """{path relative to the output folder: bytes} of the whole project. `perspective` overrides the report's."""
    _check_unique(pages)
    perspective = perspective or report.perspective
    if report.custom_visual:
        guid, cv_files, cv_package = custom_visual(pbiviz or find_pbiviz())
    else:
        guid, cv_files, cv_package = "", {}, None
    rep = f"{report.name}.Report"
    files: dict[str, bytes] = {
        f"{report.name}.pbip": _text({"$schema": SCHEMAS["pbip"], "version": "1.0",
                                      "artifacts": [{"report": {"path": rep}}],
                                      "settings": {"enableAutoRecovery": True}}),
        ".gitignore": b"**/.pbi/localSettings.json\r\n**/.pbi/cache.abf\r\n",  # what Desktop writes beside a .pbip
        f"{rep}/.platform": _text(_platform("Report", report)),
    }
    files.update({k: _text(v) for k, v in live_connection(server, database, perspective, report).items()})
    files[f"{rep}/definition/version.json"] = _text({"$schema": SCHEMAS["version"], "version": "2.0.0"})
    files[f"{rep}/definition/report.json"] = _text(report_json(cv_package, report_filters, report))
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
    files[f"{rep}/StaticResources/RegisteredResources/{report.theme.name}"] = report.theme.read_bytes()
    files[f"{rep}/StaticResources/RegisteredResources/{report.logo.name}"] = report.logo.read_bytes()
    for i in report.images:
        files[f"{rep}/StaticResources/RegisteredResources/{i.name}"] = i.read_bytes()
    files.update({f"{rep}/{k}": b for k, b in cv_files.items()})
    return files


def write_pbip(pages: list[Page], out_dir, database: str, server: str = SERVER, perspective: str | None = None,
               pbiviz: Path | None = None, report_filters: list[Filter] = (),
               report: ReportSpec = BSC_REPORT) -> Path:
    """Write the project into `out_dir` and return the .pbip path. The report's generated folders (`definition`,
    `StaticResources`, `CustomVisuals`) are replaced, so pages that are gone do not linger; every other file is
    overwritten, except `.gitignore`, which is written only when missing. Desktop's local state (`.pbi` folders,
    git-ignored) is kept."""
    out = Path(out_dir)
    files = project_files(pages, database, server, perspective, pbiviz, report_filters, report)  # everything checked first
    rep = out / f"{report.name}.Report"
    for d in (rep / "definition", rep / "StaticResources", rep / "CustomVisuals"):
        if d.exists():
            shutil.rmtree(d)
    for rel, data in files.items():
        path = out / rel
        if rel == ".gitignore" and path.exists():
            continue  # the folder's own .gitignore (Desktop may extend it) is kept
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return out / f"{report.name}.pbip"
