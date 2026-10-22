"""Synthetic pbix fixture: same part layout as a Report Server live-connection file, no business data."""
import json
import sys
import zipfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

SAMPLE_KEYS = [
    "card", "multiRowCard", "table", "matrix", "barChart", "lineChart",
    "slicerDropdown", "slicerRelativeDate", "textbox", "buttonNavigate",
    "buttonDrill", "hnhVisual",
]
HNH_VISUAL_TYPE = "hnh_bsc_visual_PBI_CV_00000000000000000000000000000000"


def lit(v):
    return {"expr": {"Literal": {"Value": v}}}


def _field(entity, prop, kind="Column"):
    return {kind: {"Expression": {"SourceRef": {"Source": "t0"}}, "Property": prop},
            "Name": f"{entity}.{prop}", "NativeReferenceName": prop}


def _query(entity, props, kind="Column"):
    return {"Version": 2, "From": [{"Name": "t0", "Entity": entity, "Type": 0}],
            "Select": [_field(entity, p, kind) for p in props]}


def _proj(entity, props):
    return [{"queryRef": f"{entity}.{p}"} for p in props]


def container(key, i):
    vtype = {
        "card": "card", "multiRowCard": "multiRowCard", "table": "tableEx",
        "matrix": "pivotTable", "barChart": "clusteredBarChart", "lineChart": "lineChart",
        "slicerDropdown": "slicer", "slicerRelativeDate": "slicer", "textbox": "textbox",
        "buttonNavigate": "actionButton", "buttonDrill": "actionButton",
        "hnhVisual": HNH_VISUAL_TYPE,
    }[key]
    sv = {"visualType": vtype, "drillFilterOtherVisuals": True}
    vco = {}
    if key in ("card", "multiRowCard"):
        sv["projections"] = {"Values": _proj("BSC KPI", ["Score"])}
        sv["prototypeQuery"] = _query("BSC KPI", ["Score"], "Measure")
    elif key in ("table", "matrix", "barChart", "lineChart"):
        role = {"table": "Values", "matrix": "Rows", "barChart": "Category", "lineChart": "Category"}[key]
        sv["projections"] = {role: _proj("BSC KPI", ["KPI Code"])}
        sv["prototypeQuery"] = _query("BSC KPI", ["KPI Code"])
        if key == "barChart":
            # Leftovers Desktop writes for the sample's own fields (shapes from Desktop-written files); the generator
            # must drop every one of them when it rebinds the visual.
            sv["projections"] = {"Category": [{"queryRef": "BSC KPI.KPI Code", "active": True, "showAll": True}],
                                 "Y": _proj("BSC KPI", ["Score"])}
            sv["prototypeQuery"]["Select"].append(_field("BSC KPI", "Score", "Measure"))
            sv["prototypeQuery"]["OrderBy"] = [{"Direction": 1, "Expression": {"Column": {
                "Expression": {"SourceRef": {"Source": "t0"}}, "Property": "KPI Code"}}}]
            sv["hasDefaultSort"] = True
            sv["showAllRoles"] = ["Category"]
            sv["columnProperties"] = {"BSC KPI.KPI Code": {"displayName": "Code"}}
            sv["objects"] = {"dataPoint": [{"properties": {"fill": {"solid": {"color": lit("'#13ACE3'")}}},
                                            "selector": {"metadata": "BSC KPI.Score"}},
                                           {"properties": {"showAllDataPoints": lit("true")}}]}
    elif key == "slicerDropdown":
        sv["projections"] = {"Values": [dict(q, active=True) for q in _proj("BSC KPI", ["KPI Code"])]}
        sv["prototypeQuery"] = _query("BSC KPI", ["KPI Code"])
        sv["objects"] = {"data": [{"properties": {"mode": lit("'Dropdown'")}}],
                         "general": [{"properties": {"filter": {"filter": {
                             "Version": 2, "From": [{"Name": "b", "Entity": "BSC KPI", "Type": 0}],
                             "Where": [{"Condition": {"In": {"Expressions": [{"Column": {
                                 "Expression": {"SourceRef": {"Source": "b"}}, "Property": "KPI Code"}}],
                                 "Values": [[lit("'FIN_01'")["expr"]]]}}}]}}}}]}
    elif key == "slicerRelativeDate":
        sv["projections"] = {"Values": [dict(q, active=True) for q in _proj("Date", ["Date"])]}
        sv["prototypeQuery"] = _query("Date", ["Date"])
        sv["objects"] = {"data": [{"properties": {"mode": lit("'Relative'")}}],
                         "general": [{"properties": {"filter": {"filter": {
                             "Version": 2, "From": [{"Name": "d", "Entity": "Date", "Type": 0}],
                             "Where": [{"Condition": {"Between": {"Expression": {"Column": {
                                 "Expression": {"SourceRef": {"Source": "d"}}, "Property": "Date"}}}}}]}}}}]}
    elif key == "hnhVisual":
        sv["projections"] = {"dataset": _proj("BSC KPI", ["KPI Code"])}
        sv["prototypeQuery"] = _query("BSC KPI", ["KPI Code"])
    elif key == "buttonNavigate":
        # Desktop writes the button action under vcObjects (handover pbix), not objects.
        vco["visualLink"] = [{"properties": {"show": lit("true"), "type": lit("'PageNavigation'"),
                                             "navigationSection": lit("'ReportSection2'")}}]
    elif key == "buttonDrill":
        vco["visualLink"] = [{"properties": {"show": lit("true"), "type": lit("'Drillthrough'"),
                                             "drillthroughSection": {"expr": {"Measure": {
                                                 "Expression": {"SourceRef": {"Entity": "_Measures"}},
                                                 "Property": "BSC Detail Page"}}}}}]
    elif key == "textbox":
        sv["objects"] = {"general": [{"properties": {"paragraphs": [{"textRuns": [{"value": "مرحبا 😀"}]}]}}]}
    vco["title"] = [{"properties": {"show": lit("true"), "text": lit(f"'sample:{key}'")}}]
    sv["vcObjects"] = vco
    name = f"{i:020x}"
    cfg = {"name": name,
           "layouts": [{"id": 0, "position": {"x": 10 + 100 * i, "y": 10, "z": i * 1000,
                                              "width": 90, "height": 60, "tabOrder": i * 1000}}],
           "singleVisual": sv}
    vc = {"x": 10 + 100 * i, "y": 10, "z": i * 1000, "width": 90, "height": 60,
          "config": json.dumps(cfg, separators=(",", ":")), "filters": "[]", "tabOrder": i * 1000}
    if "prototypeQuery" in sv:
        # Desktop's cached query and data transforms (container level, JSON strings) name the sample's fields.
        vc["query"] = json.dumps({"Commands": [{"SemanticQueryDataShapeCommand": {"Query": sv["prototypeQuery"]}}]})
        vc["dataTransforms"] = json.dumps({"selects": [{"queryName": q["Name"]}
                                                       for q in sv["prototypeQuery"]["Select"]]})
    return vc


def page(name, display, ordinal, containers, config="{}"):
    # Desktop writes id, ordinal and displayOption as numbers (handover and live-connection files on the server).
    return {"id": ordinal, "name": name, "displayName": display, "filters": "[]",
            "ordinal": ordinal, "config": config, "displayOption": 1,
            "width": 1280, "height": 720, "visualContainers": containers}


KPI_CODE = {"Column": {"Expression": {"SourceRef": {"Entity": "BSC KPI"}}, "Property": "KPI Code"}}
DRILL_FILTER = "a0000000000000000001"


def drill_parts(where="pods"):
    """The drill-through settings of the `Drill sample` page: a drill filter on the page plus the binding that names
    it. NOT confirmed by a real file (no Desktop-written drill-through page was available): the legacy layout keeps
    the binding in a root `pods` entry (boundSection = page name, parameters as a JSON string); PBIR calls it
    pageBinding. The generator copies whichever the template has; check against the real template."""
    flt = [{"name": DRILL_FILTER, "expression": KPI_CODE, "type": "Categorical", "howCreated": 5}]
    params = [{"name": "Param_" + DRILL_FILTER, "boundFilter": DRILL_FILTER, "fieldExpr": KPI_CODE}]
    if where == "pods":
        pod = {"name": "Pod", "boundSection": "ReportSection2", "config": "{}",
               "parameters": json.dumps(params, separators=(",", ":")), "type": 1}
        return flt, {}, [pod]
    return flt, {"pageBinding": {"name": "Pod", "type": "Drillthrough", "parameters": params}}, []


def build_layout(keys=SAMPLE_KEYS, drill="pods"):
    flt, cfg, pods = drill_parts(drill)
    drill_page = page("ReportSection2", "Drill sample", 1, [], json.dumps(cfg, separators=(",", ":")))
    drill_page["filters"] = json.dumps(flt, separators=(",", ":"))
    lay = {
        "id": 0,
        "resourcePackages": [{"resourcePackage": {"name": "RegisteredResources", "type": 1, "items": [
            {"type": 100, "path": "logo.png", "name": "logo.png"}]}}],
        "sections": [page("ReportSection1", "Samples", 0, [container(k, i) for i, k in enumerate(keys)]),
                     drill_page],
        "config": json.dumps({"version": "5.73", "themeCollection": {"baseTheme": {"name": "CY26SU05"}},
                              "activeSectionIndex": 1}, separators=(",", ":")),
        "layoutOptimization": 0,
    }
    if pods:
        lay["pods"] = pods
    return lay


CONNECTIONS = {
    "Version": 3,
    "Connections": [{
        "Name": "EntityDataSource",
        "ConnectionString": "Data Source=HNHANALYTICSSRV\\REPORTSERVERDB;Initial Catalog=HNH_Analytics_Test;"
                            "Cube=Balanced Scorecard",
        "ConnectionType": "analysisServicesDatabaseLive",
        "PbiServiceModelId": None,
        "PbiModelVirtualServerName": "sobe_wowvirtualserver",
        "PbiModelDatabaseName": "HNH_Analytics_Test",
    }],
}


STORED = {"DataModel"}
DATE_TIME = (2026, 5, 1, 12, 30, 10)


def write_zip(path, parts):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for i, (n, b) in enumerate(parts.items()):
            zi = zipfile.ZipInfo(n, (2026, 5, 1, 12, 30, 10 + i))
            zi.compress_type = zipfile.ZIP_STORED if n in STORED else zipfile.ZIP_DEFLATED
            zi.external_attr = 0o600 << 16
            z.writestr(zi, b)


def good_parts(layout=None, bom=False):
    layout = layout or build_layout()
    lb = json.dumps(layout, separators=(",", ":")).encode("utf-16-le")
    if bom:
        lb = b"\xff\xfe" + lb
    return {
        "Version": "1.28".encode("utf-16-le"),
        "[Content_Types].xml": b'\xef\xbb\xbf<?xml version="1.0" encoding="utf-8"?><Types/>',
        "Connections": json.dumps(CONNECTIONS, separators=(",", ":")).encode("utf-8"),
        "Report/Layout": lb,
        "DataModel": b"fake stored model" * 10,
        "Report/CustomVisuals/hnh/package.json": b'{"x":1}',
        "Settings": b"\x00\x01binary\xff",
    }


@pytest.fixture
def pbix_path(tmp_path):
    p = tmp_path / "template.pbix"
    write_zip(p, good_parts())
    return p


@pytest.fixture
def make_pbix(tmp_path):
    def _make(parts, name="x.pbix"):
        p = tmp_path / name
        write_zip(p, parts)
        return p
    return _make
