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
    if key in ("card", "multiRowCard"):
        sv["projections"] = {"Values": _proj("BSC KPI", ["Score"])}
        sv["prototypeQuery"] = _query("BSC KPI", ["Score"], "Measure")
    elif key in ("table", "matrix", "barChart", "lineChart"):
        role = {"table": "Values", "matrix": "Rows", "barChart": "Category", "lineChart": "Category"}[key]
        sv["projections"] = {role: _proj("BSC KPI", ["KPI Code"])}
        sv["prototypeQuery"] = _query("BSC KPI", ["KPI Code"])
    elif key == "slicerDropdown":
        sv["projections"] = {"Values": [dict(q, active=True) for q in _proj("BSC KPI", ["KPI Code"])]}
        sv["prototypeQuery"] = _query("BSC KPI", ["KPI Code"])
        sv["objects"] = {"data": [{"properties": {"mode": lit("'Dropdown'")}}]}
    elif key == "slicerRelativeDate":
        sv["projections"] = {"Values": [dict(q, active=True) for q in _proj("Date", ["Date"])]}
        sv["prototypeQuery"] = _query("Date", ["Date"])
        sv["objects"] = {"data": [{"properties": {"mode": lit("'Relative'")}}]}
    elif key == "hnhVisual":
        sv["projections"] = {"dataset": _proj("BSC KPI", ["KPI Code"])}
        sv["prototypeQuery"] = _query("BSC KPI", ["KPI Code"])
    elif key == "buttonNavigate":
        sv["objects"] = {"visualLink": [{"properties": {"show": lit("true"), "type": lit("'PageNavigation'"),
                                                        "navigationSection": lit("'ReportSection2'")}}]}
    elif key == "buttonDrill":
        sv["objects"] = {"visualLink": [{"properties": {"show": lit("true"), "type": lit("'Drillthrough'"),
                                                        "drillthroughSection": {"expr": {"Measure": {
                                                            "Expression": {"SourceRef": {"Entity": "BSC KPI"}},
                                                            "Property": "BSC Detail Page"}}}}}]}
    elif key == "textbox":
        sv["objects"] = {"general": [{"properties": {"paragraphs": [{"textRuns": [{"value": "x"}]}]}}]}
    sv["vcObjects"] = {"title": [{"properties": {"show": lit("true"), "text": lit(f"'sample:{key}'")}}]}
    name = f"{i:020x}"
    cfg = {"name": name,
           "layouts": [{"id": 0, "position": {"x": 10 + 100 * i, "y": 10, "z": i * 1000,
                                              "width": 90, "height": 60, "tabOrder": i * 1000}}],
           "singleVisual": sv}
    return {"x": 10 + 100 * i, "y": 10, "z": i * 1000, "width": 90, "height": 60,
            "config": json.dumps(cfg, separators=(",", ":")), "filters": "[]", "tabOrder": i * 1000}


def page(name, display, ordinal, containers, config="{}"):
    return {"id": ordinal, "name": name, "displayName": display, "filters": "[]",
            "ordinal": str(ordinal), "config": config, "displayOption": "1",
            "width": 1280, "height": 720, "visualContainers": containers}


def build_layout(keys=SAMPLE_KEYS):
    drill_cfg = json.dumps({"filterSortOrder": 3}, separators=(",", ":"))
    drill_filters = json.dumps([{"name": "f1", "expression": {"Column": {
        "Expression": {"SourceRef": {"Entity": "BSC KPI"}}, "Property": "KPI Code"}},
        "type": "Categorical", "howCreated": 1}], separators=(",", ":"))
    drill = page("ReportSection2", "Drill sample", 1, [], drill_cfg)
    drill["filters"] = drill_filters
    return {
        "id": 0, "resourcePackages": [],
        "sections": [page("ReportSection1", "Samples", 0, [container(k, i) for i, k in enumerate(keys)]), drill],
        "config": json.dumps({"version": "5.73", "themeCollection": {"baseTheme": {"name": "CY26SU05"}}},
                             separators=(",", ":")),
        "layoutOptimization": 0,
    }


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


def write_zip(path, parts):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for n, b in parts.items():
            z.writestr(n, b)


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
