"""Generates the PressGaneyDashboard PBIP (live connection to SSAS) in PBIR format.

Usage (from this folder):
    python tools/build_report.py [--database HNH_Analytics_Test] [--server hnhanalyticssrv\reportserverdb]

Every measure lives in the SSAS model (ssas/HNH_Analytics/tables/_Measures.tmdl, domain Patient Experience); the report
holds no report-level measures. A measure may be referenced as soon as it is in the repository's Patient Experience
perspective (tools/model_measures.py), before the model is deployed.

Inputs:   tools/model_fields.json, the repository's Patient Experience perspective, tools/HayatHealthcare.theme.json,
          tools/assets/*.png, tools/assets/CY24SU10.json, custom-visual/hayatNpsScorecard/dist/*.pbiviz
Output:   PressGaneyDashboard.pbip, PressGaneyDashboard.Report/, PressGaneyDashboard.SemanticModel/

Object names are derived from stable hashes, so re-running the script produces the same file names.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import shutil
import sys
import uuid
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from model_measures import perspective_measure_names  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
PROJECT = "PressGaneyDashboard"
REPORT_DIR = ROOT / f"{PROJECT}.Report"
MODEL_DIR = ROOT / f"{PROJECT}.SemanticModel"

SERVER = r"hnhanalyticssrv\reportserverdb"
DATABASE = "HNH_Analytics_Test"  # --database HNH_Analytics after the production deploy
PERSPECTIVE = "Patient Experience"
MEASURES_TABLE = "_Measures"

SCHEMA = "https://developer.microsoft.com/json-schemas/fabric"
S_PBIP = f"{SCHEMA}/pbip/pbipProperties/1.0.0/schema.json"
S_PLATFORM = f"{SCHEMA}/gitIntegration/platformProperties/2.0.0/schema.json"
S_PBIR = f"{SCHEMA}/item/report/definitionProperties/2.0.0/schema.json"
S_PBISM = f"{SCHEMA}/item/semanticModel/definitionProperties/1.0.0/schema.json"
S_MODELREF = f"{SCHEMA}/item/semanticModel/modelReference/2.0.0/schema.json"
S_REPORT = f"{SCHEMA}/item/report/definition/report/3.0.0/schema.json"
S_VERSION = f"{SCHEMA}/item/report/definition/versionMetadata/1.0.0/schema.json"
S_PAGES = f"{SCHEMA}/item/report/definition/pagesMetadata/1.0.0/schema.json"
S_PAGE = f"{SCHEMA}/item/report/definition/page/2.0.0/schema.json"
S_VISUAL = f"{SCHEMA}/item/report/definition/visualContainer/2.2.0/schema.json"
VERSION_AT_IMPORT = {"visual": "2.2.0", "report": "3.0.0", "page": "2.0.0"}

W, H = 1280, 720
BRAND = {
    "dark": "#0A1E32", "blue": "#0A2D6E", "mid": "#235F96", "light": "#32A5E6",
    "turq": "#23D2C3", "dturq": "#05A591", "lila": "#A0BEFF", "orange": "#EF8D00",
    "red": "#DC280A", "yellow": "#FFB900", "grey": "#5B6B7D",
}


# ----------------------------------------------------------------------------- ids & io

def hex_id(*parts: str, n: int = 20) -> str:
    return hashlib.sha1("|".join(parts).encode()).hexdigest()[:n]


def stable_uuid(*parts: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "hayat-pressganey|" + "|".join(parts)))


def write_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


# ----------------------------------------------------------------------------- model fields

FIELDS = json.loads((TOOLS / "model_fields.json").read_text(encoding="utf-8-sig"))["tables"]
# Every measure sits in _Measures: those the live export saw plus those the repository's perspective lists (not yet
# deployed). Guard and twin measures (_Guard, _Unguarded) are the model's own.
MEASURES: set[str] = {m for spec in FIELDS.values() for m in spec["measures"]} | perspective_measure_names()
MEASURE_TABLE: dict[str, str] = {m: MEASURES_TABLE for m in MEASURES}


def check_column(table: str, column: str) -> None:
    if column not in FIELDS.get(table, {}).get("columns", []):
        raise KeyError(f"Column {table}[{column}] is not visible in perspective '{PERSPECTIVE}'")


def qref(measure: str) -> str:
    """queryRef of a model measure, as formatting selectors and column widths name it."""
    if measure not in MEASURES:
        raise KeyError(f"Measure [{measure}] is not in perspective '{PERSPECTIVE}' (model_fields.json or the TMDL)")
    return f"{MEASURES_TABLE}.{measure}"


# ----------------------------------------------------------------------------- expression helpers

def lit(value) -> dict:
    """Literal in PBIR encoding: strings quoted, numbers suffixed with D, booleans lowercase."""
    if isinstance(value, bool):
        v = "true" if value else "false"
    elif isinstance(value, (int, float)):
        v = f"{value}D"
    else:
        v = "'" + str(value).replace("'", "''") + "'"
    return {"expr": {"Literal": {"Value": v}}}


def color(hex_color: str) -> dict:
    return {"solid": {"color": lit(hex_color)}}


def col(table: str, column: str) -> dict:
    check_column(table, column)
    return {"Column": {"Expression": {"SourceRef": {"Entity": table}}, "Property": column}}


def meas(name: str) -> dict:
    if name not in MEASURES:
        raise KeyError(f"Measure [{name}] is not in perspective '{PERSPECTIVE}' (model_fields.json or the TMDL)")
    return {"Measure": {"Expression": {"SourceRef": {"Entity": MEASURES_TABLE}}, "Property": name}}


class Q:
    """Builds visual.query.queryState with unique queryRef/nativeQueryRef per visual."""

    def __init__(self):
        self.state: dict[str, dict] = {}
        self.sort: list = []

    def add(self, role: str, field: dict, display: str | None = None, active: bool | None = None) -> "Q":
        kind = "Column" if "Column" in field else "Measure"
        table = field[kind]["Expression"]["SourceRef"]["Entity"]
        prop = field[kind]["Property"]
        proj = {"field": field, "queryRef": f"{table}.{prop}", "nativeQueryRef": prop}
        if display:
            proj["displayName"] = display
        if active is not None:
            proj["active"] = active
        self.state.setdefault(role, {"projections": []})["projections"].append(proj)
        return self

    def c(self, role: str, table: str, column: str, display: str | None = None,
          active: bool | None = None) -> "Q":
        return self.add(role, col(table, column), display, active)

    def m(self, role: str, name: str, display: str | None = None) -> "Q":
        return self.add(role, meas(name), display)

    def sort_by(self, field: dict, direction: str = "Descending") -> "Q":
        self.sort.append({"field": field, "direction": direction})
        return self

    def build(self) -> dict:
        q = {"queryState": self.state}
        if self.sort:
            q["sortDefinition"] = {"sort": self.sort, "isDefaultSort": False}
        return q


def props(**kwargs) -> dict:
    return {k: v for k, v in kwargs.items()}


def obj(properties: dict, selector: dict | None = None) -> list:
    entry = {"properties": properties}
    if selector:
        entry["selector"] = selector
    return [entry]


def title_vco(text: str, subtitle: str | None = None) -> dict:
    vco = {"title": obj({"show": lit(True), "text": lit(text)})}
    if subtitle:
        vco["subTitle"] = obj({"show": lit(True), "text": lit(subtitle),
                               "fontColor": color(BRAND["grey"])})
    return vco


def no_chrome_vco() -> dict:
    zero = {"top": lit(0), "bottom": lit(0), "left": lit(0), "right": lit(0)}
    return {
        "background": obj({"show": lit(False)}),
        "border": obj({"show": lit(False)}),
        "title": obj({"show": lit(False)}),
        "padding": obj(zero),
    }


ALL_VALUES = {"data": [{"dataViewWildcard": {"matchingOption": 1}}]}


# ----------------------------------------------------------------------------- page builder

class Page:
    def __init__(self, key: str, display: str, subtitle: str, title: str | None = None, height: int = H):
        self.key = key
        self.height = height  # pages taller than the standard canvas fit to width and scroll as a page
        self.name = hex_id("page", key)
        self.display = display          # page tab name
        self.title = title or display   # header title
        self.subtitle = subtitle
        self.visuals: list[dict] = []
        self.filters: list[dict] = []
        self.binding: dict | None = None
        self.interactions: list[dict] = []  # page.json visualInteractions
        self.period_slicer: str | None = None  # name of the Period tile slicer (filter_row)
        self.hidden = False
        self.z = 0

    def add(self, key: str, x, y, w, h, visual: dict, *, tab: bool = True) -> dict:
        assert x >= 0 and y >= 0 and x + w <= W and y + h <= self.height, f"{self.key}/{key} out of canvas"
        if "__kpi_row__" in visual:
            return self.add_kpi_row(key, x, y, w, h, *visual["__kpi_row__"])
        self.z += 1000
        container = {
            "$schema": S_VISUAL,
            "name": hex_id(self.key, key),
            "position": {"x": x, "y": y, "z": self.z, "height": h, "width": w,
                         "tabOrder": self.z if tab else 0},
            "visual": visual,
        }
        self.visuals.append(container)
        return container

    def add_kpi_row(self, key: str, x, y, w, h, measures: list, title: str | None) -> dict:
        """One classic card per figure, side by side, under an optional row title: a plain value with its label,
        no card chrome. Returns the last tile."""
        top = y
        if title:
            self.add(f"{key}-title", x, y, w, KPI_TITLE_H, textbox(title, "11px", BRAND["mid"], bold=True), tab=False)
            top += KPI_TITLE_H
        n = len(measures)
        tile_w = (w - KPI_GAP * (n - 1)) / n
        last = None
        for i, m in enumerate(measures):
            name, label = (m, None) if isinstance(m, str) else m
            left = round(x + i * (tile_w + KPI_GAP))
            width = round(x + (i + 1) * tile_w + i * KPI_GAP) - left
            last = self.add(f"{key}-{i}", left, top, width, y + h - top, kpi_tile(name, label))
        return last

    def filter_in(self, table: str, column: str, values: list, *, exclude: bool = False,
                  locked: bool = False) -> None:
        """Page filter on a list of values: strings are text, ints are whole numbers (PBIR literal 0L).
        locked=True keeps report readers from changing it."""
        alias = table[0].lower()
        condition = {"In": {
            "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": alias}}, "Property": column}}],
            "Values": [[{"Literal": {"Value": f"{v}L" if isinstance(v, int) else "'" + v + "'"}}] for v in values],
        }}
        if exclude:
            condition = {"Not": {"Expression": condition}}
        f = {
            "name": "Filter" + hex_id(self.key, "filter", table, column, n=24),
            "field": col(table, column),
            "type": "Categorical",
            "filter": {
                "Version": 2,
                "From": [{"Name": alias, "Entity": table, "Type": 0}],
                "Where": [{"Condition": condition}],
            },
            "howCreated": "User",
        }
        if locked:
            f["isLockedInViewMode"] = True
        self.filters.append(f)

    def filter_not_in(self, table: str, column: str, values: list[str]) -> None:
        self.filter_in(table, column, values, exclude=True)

    def drillthrough(self, table: str, column: str) -> None:
        """Makes this page a drillthrough target for `table[column]` (right-click > Drill through)."""
        name = "Filter" + hex_id(self.key, "drillthrough", table, column, n=24)
        self.filters.append({"name": name, "field": col(table, column), "type": "Categorical",
                             "howCreated": "Drillthrough"})
        self.binding = {"name": "Drill" + hex_id(self.key, "binding", n=16), "type": "Drillthrough",
                        "parameters": [{"name": "Param_" + name, "boundFilter": name, "fieldExpr": col(table, column)}]}

    def ignore_period(self, container: dict) -> None:
        """The Period tiles do not filter this visual (Edit interactions > None): a monthly trend keeps every month."""
        assert self.period_slicer, f"{self.key}: no Period slicer on the page"
        self.interactions.append({"source": self.period_slicer, "target": container["name"], "type": "NoFilter"})

    def to_json(self) -> dict:
        page = {
            "$schema": S_PAGE,
            "name": self.name,
            "displayName": self.display,
            "displayOption": "FitToPage" if self.height <= H else "FitToWidth",
            "height": self.height,
            "width": W,
        }
        if self.filters:
            page["filterConfig"] = {"filters": self.filters}
        if self.interactions:
            page["visualInteractions"] = self.interactions
        if self.binding:
            page["pageBinding"] = self.binding
        if self.hidden:
            page["visibility"] = "HiddenInViewMode"
        return page


# ----------------------------------------------------------------------------- visual factories

LOGO_ITEM = "HayatLogoWhite20261025.png"


def header(page: Page) -> None:
    page.add("hdr-band", 0, 0, W, 64, {
        "visualType": "shape",
        "objects": {
            "shape": obj({"tileShape": lit("rectangle")}),
            "fill": obj({"fillColor": color(BRAND["dark"]), "transparency": lit(0)}, {"id": "default"}),
            "outline": obj({"show": lit(False)}, {"id": "default"}),
        },
        "visualContainerObjects": no_chrome_vco(),
    }, tab=False)
    page.add("hdr-accent", 0, 64, W, 4, {
        "visualType": "shape",
        "objects": {
            "shape": obj({"tileShape": lit("rectangle")}),
            "fill": obj({"fillColor": color(BRAND["light"]), "transparency": lit(0)}, {"id": "default"}),
            "outline": obj({"show": lit(False)}, {"id": "default"}),
        },
        "visualContainerObjects": no_chrome_vco(),
    }, tab=False)
    page.add("hdr-logo", 16, 12, 212, 40, {
        "visualType": "image",
        "objects": {
            "general": obj({"imageUrl": {"expr": {"ResourcePackageItem": {
                "PackageName": "RegisteredResources", "PackageType": 1, "ItemName": LOGO_ITEM}}}}),
            "imageScaling": obj({"imageScalingType": lit("Fit")}),
        },
        "visualContainerObjects": no_chrome_vco(),
    }, tab=False)
    page.add("hdr-divider", 244, 14, 2, 36, {
        "visualType": "shape",
        "objects": {
            "shape": obj({"tileShape": lit("rectangle")}),
            "fill": obj({"fillColor": color(BRAND["mid"]), "transparency": lit(0)}, {"id": "default"}),
            "outline": obj({"show": lit(False)}, {"id": "default"}),
        },
        "visualContainerObjects": no_chrome_vco(),
    }, tab=False)
    page.add("hdr-title", 260, 8, 700, 30, textbox(page.title, "22px", "#FFFFFF", bold=True), tab=False)
    page.add("hdr-subtitle", 260, 36, 700, 22, textbox(page.subtitle, "12px", "#A0BEFF"), tab=False)


def textbox(text: str, size: str, fg: str, *, bold: bool = False, align: str = "left") -> dict:
    style = {"fontFamily": "Zain, Segoe UI", "fontSize": size, "color": fg}
    if bold:
        style["fontWeight"] = "bold"
    return {
        "visualType": "textbox",
        "objects": {"general": obj({"paragraphs": [
            {"textRuns": [{"value": text, "textStyle": style}], "horizontalTextAlignment": align}
        ]})},
        "visualContainerObjects": no_chrome_vco(),
    }


def period_selection(items: list[str]) -> dict:
    """Filter body selecting `items` of the Time Calculation column."""
    return {"Version": 2, "From": [{"Name": "t", "Entity": PERIOD[0], "Type": 0}],
            "Where": [{"Condition": {"In": {
                "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": "t"}}, "Property": PERIOD[1]}}],
                "Values": [[{"Literal": {"Value": "'" + i + "'"}}] for i in items]}}}]}


def slicer(table: str, column: str, label: str) -> dict:
    """Dropdown slicer; the date column gets a Between (date range) slicer with start / end date pickers and no
    saved range; the Period column gets horizontal tiles (MTD | YTD) with MTD saved."""
    if (table, column) == DATE_RANGE[:2]:
        objects = {
            "data": obj({"mode": lit("Between")}),
            "header": obj({"show": lit(True), "text": lit(label)}),
            "slider": obj({"show": lit(False)}),  # the two date boxes are the picker; no room for a slider
        }
    elif (table, column) == PERIOD[:2]:
        # The model's Time Calculation group: MTD / YTD run each measure month or year to date (up to today) on top of
        # the date range. Saved as the relative item, so no rebuild is needed
        # to open on the current month (the old date-range default was stamped with fixed dates at build time).
        objects = {
            "data": obj({"mode": lit("Basic")}),
            "general": obj({"orientation": lit(1), "filter": {"filter": period_selection([PERIOD_DEFAULT])}}),  # 1 = horizontal tiles
            "header": obj({"show": lit(True), "text": lit(label)}),
            "selection": obj({"singleSelect": lit(True), "selectAllCheckboxEnabled": lit(False)}),
            "items": obj({"textSize": lit(10)}),
        }
    else:
        objects = {
            "data": obj({"mode": lit("Dropdown")}),
            "header": obj({"show": lit(True), "text": lit(label)}),
            "selection": obj({"selectAllCheckboxEnabled": lit(True), "singleSelect": lit(False)}),
        }
    return {
        "visualType": "slicer",
        # Same field => same sync group, so a selection carries to every page that has this slicer.
        "syncGroup": {"groupName": f"sync {table} {column}", "fieldChanges": True, "filterChanges": True},
        "query": Q().c("Values", table, column).build(),
        "objects": objects,
        "visualContainerObjects": {
            "title": obj({"show": lit(False)}),
            "padding": obj({"top": lit(4), "bottom": lit(8), "left": lit(10), "right": lit(10)}),
        },
    }


KPI_TITLE_H = 22  # row title strip above the tiles
KPI_GAP = 8       # between tiles


def card(measures: list, title: str | None = None) -> dict:
    """A KPI row: each item is a measure name or a (measure, short label) pair. Page.add lays it out as one classic
    card tile per figure (add_kpi_row), the reliable card on Report Server."""
    return {"__kpi_row__": (measures, title)}


def kpi_tile(measure: str, label: str | None) -> dict:
    """Classic card: the value in 22 px over its label; the white panel is its only chrome."""
    return {
        "visualType": "card",
        "query": Q().m("Values", measure, label).build(),
        "objects": {
            "labels": obj({"fontSize": lit(22), "color": color(BRAND["dark"]), "fontFamily": lit("Zain, Segoe UI")}),
            "categoryLabels": obj({"show": lit(True), "fontSize": lit(10), "color": color(BRAND["grey"])}),
            "wordWrap": obj({"show": lit(True)}),
        },
        "visualContainerObjects": {
            "title": obj({"show": lit(False)}),
            "padding": obj({"top": lit(6), "bottom": lit(6), "left": lit(8), "right": lit(8)}),
        },
    }


NO_AXIS_CHARTS = {"clusteredColumnChart", "clusteredBarChart", "lineChart", "lineStackedColumnComboChart"}


def chart(vtype: str, q: Q, title: str, *, subtitle: str | None = None, objects: dict | None = None) -> dict:
    """Column, bar, line and combo charts hide the primary value axis and show every data label instead; a page can
    still override either object."""
    objects = dict(objects or {})
    if vtype in NO_AXIS_CHARTS:
        objects.setdefault("valueAxis", obj({"show": lit(False)}))
        objects.setdefault("labels", obj({"show": lit(True), "labelDensity": lit(100)}))
    v = {"visualType": vtype, "query": q.build(), "visualContainerObjects": title_vco(title, subtitle)}
    if objects:
        v["objects"] = objects
    return v


def nps_point_colors(color_measure: str = "NPS Color") -> dict:
    """Bars coloured by a colour-returning measure (NPS band, or sign of the gap to network)."""
    return {"dataPoint": obj({"fill": {"solid": {"color": {"expr": meas(color_measure)}}}}, ALL_VALUES)}


def data_labels() -> list:
    return obj({"show": lit(True), "labelDensity": lit(100)})  # every label, none dropped for space


def column_widths(widths: dict[str, int]) -> list:
    """Pinned table column widths; needs columnHeaders autoSizeColumnWidth=false + columnAdjustment=fixedWidth."""
    return [{"properties": {"value": lit(w)}, "selector": {"metadata": ref}} for ref, w in widths.items()]


RELIABILITY_ICONS = [(4, 3, "SignalBarFullColored"), (4, 7, "SignalBarMediumColored"), (1, 7, "SignalBarLowColored")]


def reliability_icon() -> dict:
    """Signal bars from [NPS Margin of Error]: full = High (±3 or better), medium = Moderate (±7), low = Low."""
    cases = [{"Condition": {"Comparison": {"ComparisonKind": kind, "Left": meas("NPS Margin of Error"),
                                           "Right": {"Literal": {"Value": f"{limit}D"}}}},
              "Value": {"Literal": {"Value": f"'{icon}'"}}} for kind, limit, icon in RELIABILITY_ICONS]
    return {"kind": "Icon", "layout": lit("After"), "verticalAlignment": lit("Middle"),
            "value": {"expr": {"Conditional": {"Cases": cases}}}}


def nps_font_color(query_ref: str) -> list:
    """NPS cells: colour by NPS band and a reliability icon (see reliability_icon)."""
    return obj({"fontColor": {"solid": {"color": {"expr": meas("NPS Color")}}}, "icon": reliability_icon()},
               {"data": [{"dataViewWildcard": {"matchingOption": 1}}], "metadata": query_ref})


def matrix(q: Q, title: str, *, subtitle: str | None = None, nps_ref: str | None = None,
           expand_buttons: bool = True) -> dict:
    objects = {
        "rowHeaders": obj({"showExpandCollapseButtons": lit(expand_buttons), "wordWrap": lit(True)}),
        "columnHeaders": obj({"wordWrap": lit(True)}),
    }
    if nps_ref:
        objects["values"] = nps_font_color(nps_ref)
    return chart("pivotTable", q, title, subtitle=subtitle, objects=objects)


SCORECARD_GUID = None  # set from the packaged visual


def scorecard(q: Q, title: str | None, *, mode: str, max_cols: int, score_label: str,
              benchmark_label: str = "vs network") -> dict:
    vco = title_vco(title) if title else {"title": obj({"show": lit(False)})}
    vco["background"] = obj({"show": lit(False)})
    vco["border"] = obj({"show": lit(False)})
    vco["padding"] = obj({"top": lit(0), "bottom": lit(0), "left": lit(0), "right": lit(0)})
    return {
        "visualType": SCORECARD_GUID,
        "query": q.build(),
        "objects": {
            "cardStyle": obj({"mode": lit(mode), "maxColumns": lit(max_cols), "showLogo": lit(True),
                              "cornerRadius": lit(14)}),
            "scoreBands": obj({"goodThreshold": lit(70), "warningThreshold": lit(50), "colorByBand": lit(True)}),
            "labels": obj({"scoreLabel": lit(score_label), "benchmarkLabel": lit(benchmark_label),
                           "showSplit": lit(True)}),
        },
        "visualContainerObjects": vco,
    }


# ----------------------------------------------------------------------------- pages

PERIOD = ("Time Calculation", "Time Calculation", "Period")
PERIOD_ITEMS = ["MTD", "YTD"]  # of the model's Time Calculation group
PERIOD_DEFAULT = "MTD"
DATE_RANGE = ("Date", "Date", "Date range")
BRANCH = ("Branch", "Branch Name", "Branch")
SETTING = ("Survey Service", "Care Setting", "Care setting")
SERVICE = ("Survey Service", "Service Name", "Survey service")
DOMAIN = ("Survey Question", "Domain En", "Question group")
SPECIALTY = ("Staff", "Specialty", "Specialty")
# Trends use the month-start date: a continuous date axis labels months without truncation ("Oct 2025").
TREND_AXIS = ("Date", "Start Of Month", "Month")
KPI_H = 116  # card height that fits title + label + 20pt value without clipping

# The story: a landing page, then numbered chapters that each answer one question.
HOME = ("home", "Home", "Opens on month to date (Period: MTD); switch to YTD or set a date range on any page")
CHAPTERS = [
    ("survey-quality", "1 · Participation", "Participation",
     "Who did we reach, by which channel, who answers, and can we trust the sample?"),
    ("satisfaction-nps", "2 · Satisfaction & NPS", "Satisfaction",
     "How do patients rate us overall, and is it moving month to month?"),
    ("question-groups", "3 · What Drives the Score", "Drivers",
     "Which parts of the journey pull NPS down, and why?"),
    ("branch-benchmark", "4 · Branch Benchmark", "Branches",
     "Which branches lead and lag the network, and on which question groups?"),
    ("specialty-doctor", "5 · Specialties & Doctors", "Doctors",
     "Where to recognise and where to coach: specialty and doctor NPS across branches"),
    ("patient-profile", "6 · Patient Profile", "Profile",
     "Does the experience differ by who the patient is and how they came to us?"),
]


def page_id(key: str) -> str:
    return hex_id("page", key)


def button(label: str, target_key: str | None, *, fill: str, fg: str = "#FFFFFF", size: int = 11,
           align: str = "center", tooltip: str | None = None) -> dict:
    """Navigation button. target_key=None makes it a Back button (returns from a drillthrough)."""
    if target_key:
        link = {"show": lit(True), "type": lit("PageNavigation"), "navigationSection": lit(page_id(target_key))}
    else:
        link = {"show": lit(True), "type": lit("Back")}
    if tooltip:
        link["tooltip"] = lit(tooltip)
    return {
        "visualType": "actionButton",
        "objects": {
            "text": [{"properties": {"show": lit(True)}},
                     {"properties": {"text": lit(label), "fontSize": lit(size), "fontColor": color(fg),
                                     "horizontalAlignment": lit(align), "bold": lit(True)},
                      "selector": {"id": "default"}}],
            "icon": [{"properties": {"show": lit(False)}},
                     {"properties": {"placement": lit("left")}, "selector": {"id": "default"}}],
            "fill": [{"properties": {"show": lit(True)}},
                     {"properties": {"fillColor": color(fill), "transparency": lit(0)}, "selector": {"id": "default"}}],
            "outline": [{"properties": {"show": lit(False)}}],
            "shape": [{"properties": {"tileShape": lit("rectangleRounded"), "roundEdge": {"expr": {"Literal": {"Value": "8L"}}}}},
                      {"properties": {"tileShape": lit("rectangleRounded")}, "selector": {"id": "default"}}],
        },
        "visualContainerObjects": {
            "background": obj({"show": lit(False)}),
            "border": obj({"show": lit(False)}),
            "title": obj({"show": lit(False)}),
            "visualLink": obj(link),
        },
        "drillFilterOtherVisuals": True,
    }


GUIDES = [("guide-metrics", "Guide 1 · Metrics", "How every measure is calculated: participation, scoring, NPS and satisfaction"),
          ("guide-rules", "Guide 2 · Rules & Use", "Benchmarks, sample-size rules, top / bottom lists and how to use the report")]


def nav_buttons(page: Page, *, back: bool = False) -> None:
    """Header buttons, laid out right to left: chapters get Guide / Home / Next so the story reads in order;
    drillthrough twins get Guide / Back / Home; guide pages get Back / Home (and Next between the two guides)."""
    keys = [HOME[0]] + [c[0] for c in CHAPTERS]
    guide_keys = [g[0] for g in GUIDES]
    items: list[tuple[str, str, str | None, str]] = []  # (visual key, label, target page key or None=Back, fill)
    if page.key in keys:
        i = keys.index(page.key)
        if i + 1 < len(keys):
            nxt = CHAPTERS[i]
            label, target = (f"Start: {nxt[1]}  ›" if i == 0 else f"Next: {nxt[2]}  ›"), nxt[0]
        else:
            label, target = "Back to start  ›", HOME[0]
        items.append(("nav-guide", "? Guide", guide_keys[0], BRAND["mid"]))
        if back:
            items.append(("nav-back", "‹ Back", None, BRAND["mid"]))
        if i > 0:
            items.append(("nav-home", "‹ Home", HOME[0], BRAND["mid"]))
        items.append(("nav-next", label, target, BRAND["light"]))
    elif page.key in guide_keys:
        items += [("nav-back", "‹ Back", None, BRAND["mid"]), ("nav-home", "‹ Home", HOME[0], BRAND["mid"])]
        if page.key == guide_keys[0]:
            items.append(("nav-next", "Next: Rules & Use  ›", guide_keys[1], BRAND["light"]))
        else:
            items.append(("nav-next", "‹ Guide 1 · Metrics", guide_keys[0], BRAND["light"]))
    else:  # hidden drillthrough twin
        items += [("nav-guide", "? Guide", guide_keys[0], BRAND["mid"]), ("nav-back", "‹ Back", None, BRAND["light"]),
                  ("nav-home", "‹ Home", HOME[0], BRAND["mid"])]
    x = W - 16
    for key, label, target, fill in reversed(items):
        width = max(92, 30 + int(8.2 * len(label)))
        x -= width
        page.add(key, x, 10, width, 44, button(label, target, fill=fill))
        x -= 8


def story_banner(measure: str) -> dict:
    """Key-takeaway sentence (a text measure). Uses the classic card because it word-wraps long text;
    the new cardVisual truncates to a single line."""
    # The sentence is each page's one bold element: larger type on the brand's pale blue, the only tinted panel on
    # the page, with the accent-blue edge that the header band also carries. The card shows two lines, so the story
    # measures keep their sentences short (about 150 characters at 11 px).
    return {
        "visualType": "card",
        "query": Q().m("Values", measure, "Key takeaway").build(),
        "objects": {
            "labels": obj({"fontSize": lit(11), "color": color(BRAND["dark"]), "fontFamily": lit("Zain, Segoe UI")}),
            "categoryLabels": obj({"show": lit(False)}),
            "wordWrap": obj({"show": lit(True)}),
        },
        "visualContainerObjects": {
            "title": obj({"show": lit(False)}),
            "background": obj({"show": lit(True), "color": color("#EAF5FC")}),
            "border": obj({"show": lit(True), "color": color(BRAND["light"]), "radius": lit(8)}),
            "padding": obj({"top": lit(2), "bottom": lit(2), "left": lit(12), "right": lit(12)}),
        },
    }


def filter_row(page: Page, slicers: list[tuple[str, str, str]], story_measure: str) -> None:
    """Period tiles, then the slicers (the date range is wider, for its two date boxes), the page's key takeaway on
    the right."""
    x = 16
    for i, (table, column, label) in enumerate([PERIOD] + slicers):
        w = {PERIOD: 190, DATE_RANGE: 240}.get((table, column, label), 150)  # two tiles; two date boxes
        container = page.add(f"slicer-{i}", x, 76, w, 62, slicer(table, column, label))
        if (table, column, label) == PERIOD:
            page.period_slicer = container["name"]
            # only the two period buttons
            container["filterConfig"] = {"filters": [{
                "name": "Filter" + hex_id(page.key, "period-items", n=24),
                "field": col(PERIOD[0], PERIOD[1]),
                "type": "Categorical",
                "filter": period_selection(PERIOD_ITEMS),
                "howCreated": "User",
            }]}
        if (table, column, label) == DATE_RANGE:
            # Only dates with scored answers, so the picker opens on the survey period, not the whole calendar. A Survey
            # Answers measure: page 3 filters Survey Question, which would turn [Invitations] into its guard message.
            container["filterConfig"] = {"filters": [{
                "name": "Filter" + hex_id(page.key, "date-range-has-surveys", n=24),
                "field": meas("NPS Answers"),
                "type": "Advanced",
                "filter": {
                    "Version": 2,
                    "From": [{"Name": "m", "Entity": MEASURE_TABLE["NPS Answers"], "Type": 0}],
                    "Where": [{"Condition": {"Not": {"Expression": {"Comparison": {
                        "ComparisonKind": 0,
                        "Left": {"Measure": {"Expression": {"SourceRef": {"Source": "m"}}, "Property": "NPS Answers"}},
                        "Right": {"Literal": {"Value": "null"}}}}}}}],
                },
                "howCreated": "User",
            }]}
        x += w + 12
    page.add("story", x, 76, W - 16 - x, 62, story_banner(story_measure))


def chapter(key: str, *, back: bool = False, height: int = H) -> Page:
    _, display, _, question = next(c for c in CHAPTERS if c[0] == key)
    p = Page(key, display, question, height=height)
    header(p)
    nav_buttons(p, back=back)
    return p


def table_objects(nps_ref: str, widths: dict[str, int], *, wrap: bool) -> dict:
    return {
        "values": nps_font_color(nps_ref) + obj({"wordWrap": lit(wrap)}),
        "columnHeaders": obj({"wordWrap": lit(True), "autoSizeColumnWidth": lit(False),
                              "columnAdjustment": lit("fixedWidth")}),
        "columnWidth": column_widths(widths),
        "total": obj({"totals": lit(False)}),
    }


def page_home() -> Page:
    p = Page(HOME[0], HOME[1], HOME[2], title="Patient Experience at a Glance")
    header(p)
    nav_buttons(p)
    filter_row(p, [DATE_RANGE, BRANCH, SETTING], "Report Title Context")
    p.add("hero", 16, 144, 300, 300, scorecard(
        Q().m("nps", "NPS (5-point)").m("promoters", "% Promoters").m("passives", "% Passives")
           .m("detractors", "% Detractors").m("volume", "NPS Answers").m("margin", "NPS Margin of Error"),
        None, mode="light", max_cols=1, score_label="NPS (5-point)"))
    p.add("kpis", 332, 144, 932, KPI_H, card(
        [("Overall Satisfaction (0-100)", "Satisfaction /100"), ("NPS Margin of Error", "NPS margin (±)"), "Reliability",
         ("Response Rate %", "Response rate"), ("Surveys Responded", "Responded"), ("Patients Responded", "Patients")],
        "Headline"))
    takeaways = [("Participation", "Insight Participation"), ("Satisfaction", "Insight NPS"),
                 ("Branches", "Insight Branches"), ("What drives the score", "Insight Drivers")]
    for i, (title, measure) in enumerate(takeaways):
        x = 332 + (i % 2) * 474
        y = 268 + (i // 2) * 92
        v = story_banner(measure)
        v["objects"]["labels"] = obj({"fontSize": lit(11), "color": color(BRAND["dark"]), "fontFamily": lit("Zain, Segoe UI")})
        v["visualContainerObjects"]["title"] = obj({"show": lit(True), "text": lit(title),
                                                    "fontColor": color(BRAND["mid"]), "fontSize": lit(11)})
        p.add(f"takeaway-{i}", x, y, 458, 84, v)
    p.add("explore-label", 16, 454, 600, 24, textbox("Explore the story", "16px", BRAND["dark"], bold=True))
    tile_w, tile_h = 405, 108
    for i, (key, display, _, question) in enumerate(CHAPTERS):
        x = 16 + (i % 3) * (tile_w + 16)
        y = 484 + (i // 3) * (tile_h + 8)
        p.add(f"tile-bg-{i}", x, y, tile_w, tile_h, {
            "visualType": "shape",
            "objects": {
                "shape": obj({"tileShape": lit("rectangleRounded")}),
                "fill": obj({"fillColor": color("#FFFFFF"), "transparency": lit(0)}, {"id": "default"}),
                "outline": obj({"show": lit(False)}, {"id": "default"}),
            },
            "visualContainerObjects": no_chrome_vco(),
        }, tab=False)
        p.add(f"tile-btn-{i}", x + 10, y + 8, tile_w - 20, 44,
              button(f"{display}   ›", key, fill="#EAF5FC", fg=BRAND["dark"], align="left", size=12,
                     tooltip=f"Open {display}"))  # pale, so the header's accent-blue Start button stays the one call to action
        p.add(f"tile-q-{i}", x + 14, y + 58, tile_w - 28, 46, textbox(question, "12px", "#3C4D60"), tab=False)
    return p


def section_label(page: Page, key: str, y: int, text: str) -> None:
    """A section heading of the tall Participation page: the title, with a short accent rule above it that marks
    where a new section of the five-part sequence starts (the header band carries the same rule)."""
    page.add(f"{key}-rule", 16, y - 6, 40, 3, {
        "visualType": "shape",
        "objects": {
            "shape": obj({"tileShape": lit("rectangle")}),
            "fill": obj({"fillColor": color(BRAND["light"]), "transparency": lit(0)}, {"id": "default"}),
            "outline": obj({"show": lit(False)}, {"id": "default"}),
        },
        "visualContainerObjects": no_chrome_vco(),
    }, tab=False)
    page.add(key, 16, y, W - 32, 26, textbox(text, "16px", BRAND["dark"], bold=True), tab=False)


SMS_COLOR, AGENT_COLOR = BRAND["light"], BRAND["dturq"]


def channel_chart(table: str, column: str, label: str, title: str) -> dict:
    """Response rate for SMS vs call-centre agent surveys, side by side for each value of a column."""
    return chart(
        "clusteredColumnChart",
        Q().c("Category", table, column, label).m("Y", "Response Rate % (SMS)", "SMS")
           .m("Y", "Response Rate % (Agent Call)", "Agent call")
           .m("Tooltips", "Invitations (SMS)").m("Tooltips", "Invitations (Agent Call)")
           .sort_by(meas("Response Rate % (SMS)")),
        title,
        objects={"dataPoint": obj({"fill": color(SMS_COLOR)}, {"metadata": qref("Response Rate % (SMS)")})
                 + obj({"fill": color(AGENT_COLOR)}, {"metadata": qref("Response Rate % (Agent Call)")}),
                 "labels": data_labels()})


def page_survey_quality() -> Page:
    """Chapter 1 on a taller page (scrolls as a page; no visual scrolls), in five numbered sections:
    1 at a glance, 2 reach by channel (SMS vs agent call) with trend and data quality, 3 who answers (response
    rate by channel and patient profile), 4 is the sample like our visits (index, mismatch, weighted NPS), and
    5 is each group big enough (sample size vs visits by care type and branch)."""
    p = chapter("survey-quality", height=2460)
    filter_row(p, [DATE_RANGE, BRANCH, SETTING], "Story Participation")

    section_label(p, "sec-1", 148, "1 · At a glance: how many answered, and can we trust the results?")
    p.add("glance", 16, 178, 1248, KPI_H, card(
        [("Invitations", "Invited"), ("Surveys Responded", "Responded"), ("Patients Responded", "Patients"),
         ("Response Rate %", "Response rate"), ("Completion Rate %", "Completed"),
         ("NPS Margin of Error", "NPS margin (±)"), ("Reliability", "Reliability"), ("Sample Mix", "Sample mix")],
        "Participation and reliability (95% confidence)"))

    section_label(p, "sec-2", 308, "2 · How did we reach patients? SMS vs call-centre agent, month by month")
    p.add("kpi-sms", 16, 338, 616, KPI_H,
          card([("Invitations (SMS)", "Invited"), ("Responded (SMS)", "Responded"),
                ("Response Rate % (SMS)", "Response %"), ("Completion Rate % (SMS)", "Completed %")], "SMS surveys"))
    p.add("kpi-agent", 648, 338, 616, KPI_H,
          card([("Invitations (Agent Call)", "Invited"), ("Responded (Agent Call)", "Responded"),
                ("Response Rate % (Agent Call)", "Response %"), ("Agent Call Share of Responses %", "Share of all responses")],
               "Call-centre agent surveys (no SMS sent)"))
    p.ignore_period(p.add("trend", 16, 462, 1248, 230, chart(
        "lineStackedColumnComboChart",
        Q().c("Category", *TREND_AXIS).m("Y", "Invitations (SMS)", "SMS invitations")
           .m("Y", "Invitations (Agent Call)", "Agent-call invitations")
           .m("Y2", "Response Rate % (SMS)", "SMS response %").m("Y2", "Response Rate % (Agent Call)", "Agent response %"),
        "Monthly invitations (columns) and response rate (lines) by channel",
        subtitle="Every month of the date range, whatever the Period; the latest months are still arriving",
        objects={"dataPoint": obj({"fill": color(SMS_COLOR)}, {"metadata": qref("Invitations (SMS)")})
                 + obj({"fill": color(AGENT_COLOR)}, {"metadata": qref("Invitations (Agent Call)")})
                 + obj({"fill": color(BRAND["blue"])}, {"metadata": qref("Response Rate % (SMS)")})
                 + obj({"fill": color(BRAND["orange"])}, {"metadata": qref("Response Rate % (Agent Call)")})})))
    p.add("quality", 16, 700, 1248, KPI_H, card(
        [("Partial Rate %", "Partial responses"), ("Encounter Link %", "Linked to a visit"),
         ("Repeat Invitation Rate %", "Repeat invitations"), ("Unknown Gender %", "Unknown gender"),
         ("Median Days Visit to Answer", "Median days to answer"), ("SMS Reach %", "Sent by SMS")],
        "Data quality"))

    section_label(p, "sec-3", 830, "3 · Who answers? Response rate by channel and patient profile")
    for i, (table, column, label, title) in enumerate([
            ("Survey Service", "Care Setting", "Care setting", "By care setting"),
            ("Patient", "Gender", "Gender", "By gender"),
            ("Patient", "Is Saudi", "Saudi national", "By nationality (Saudi national)")]):
        p.add(f"ch-{i}", 16 + i * 421, 860, 405, 230, channel_chart(table, column, label, title))
    p.add("ch-branch", 16, 1098, 616, 240, channel_chart("Branch", "Branch Name", "Branch", "By branch"))
    p.add("ch-payer", 648, 1098, 616, 240, channel_chart("Payer", "Category", "Payer category", "By payer category"))

    section_label(p, "sec-4", 1352,
                  "4 · Does the sample look like our visits? Share of responses vs share of visits (ER · OP · IP)")
    verdict = story_banner("Story Representativeness")
    verdict["objects"]["labels"] = obj({"fontSize": lit(11), "color": color(BRAND["dark"]), "fontFamily": lit("Zain, Segoe UI")})
    verdict["visualContainerObjects"]["title"] = obj({"show": lit(True), "text": lit("Verdict"),
                                                      "fontColor": color(BRAND["mid"]), "fontSize": lit(11)})
    p.add("verdict", 16, 1382, 400, KPI_H, verdict)
    p.add("kpi-weighted", 432, 1382, 832, KPI_H, card(
        [("Actual Visits", "Actual visits"), ("Response Coverage %", "Responses per visit"),
         ("NPS (Visit-Matched)", "NPS as surveyed"), ("Weighted NPS", "Weighted NPS"),
         ("NPS Weighting Effect", "Weighting effect")],
        "Does the mix change the score? (NPS weighted by actual visits)"))
    p.add("kpi-mismatch", 16, 1506, 1248, KPI_H, card(
        [("Mismatch (Care Type)", "Care type"), ("Mismatch (Branch)", "Branch"), ("Mismatch (Payer)", "Payer"),
         ("Mismatch (Nationality)", "Nationality"), ("Mismatch (Gender)", "Gender")],
        "Mix mismatch vs visits: 0% = same mix, up to 5% representative, up to 10% acceptable"))
    for i, (table, column, label, title) in enumerate([
            ("Care Type", "Care Type Name", "Care type", "By care type"),
            ("Patient", "Gender", "Gender", "By gender"),
            ("Patient", "Is Saudi", "Saudi national", "By nationality (Saudi national)")]):
        p.add(f"mix-{i}", 16 + i * 421, 1630, 405, 190, representation_table(table, column, label, title))
    p.add("mix-branch", 16, 1828, 616, 300, representation_table("Branch", "Branch Name", "Branch", "By branch",
                                                                 counts=True))
    p.add("mix-payer", 648, 1828, 616, 300, representation_table("Payer", "Category", "Payer", "By payer category",
                                                                 counts=True))

    section_label(p, "sec-5", 2142, "5 · Is each group big enough? Sample size vs actual visits by care type and branch")
    p.add("sample", 16, 2172, 816, 276, matrix(
        Q().c("Rows", "Care Type", "Care Type Name", "Care type").c("Rows", "Branch", "Branch Name")
           .m("Values", "Actual Visits", "Actual visits").m("Values", "Invitations (Visit-Matched)", "Invited")
           .m("Values", "Survey Coverage %", "Invited per visit").m("Values", "Respondents (Visit-Matched)", "Responded")
           .m("Values", "Response Rate % (Visit-Matched)", "Response %").m("Values", "Required Sample (±5%)", "Needed ±5%")
           .m("Values", "Sample Gap", "Gap").m("Values", "Margin of Error (±)", "Margin ±"),
        "Sample size by care type", subtitle="Expand (+) for branches"))
    p.add("sample-note", 848, 2172, 416, 276, guide_text([("How surveys match visits", [
        ("Care type", "each survey linked to a visit carries that visit's care type: Emergency → ER visits, "
                      "Outpatient → OP visits, Inpatient → admissions. Day case and unknown are left out."),
        ("", "Only months with 1,000+ invitations and surveys linked to a visit count. Needed ±5%: 385 "
             "responses, less for small groups. Gap: responses still needed."),
        ("Non-response", "each care setting uses one channel, so channels can't show whether non-responders "
                         "feel differently; the lower the response rate, the higher that risk."),
    ])]), tab=False)
    return p


def representation_table(table: str, column: str, label: str, title: str, *, counts: bool = False) -> dict:
    """Share of responses vs share of actual visits per group, with the index and status coloured
    green (fair share 0.80–1.25), orange (0.5–2) or red."""
    q = Q().c("Values", table, column, label)
    widths = {f"{table}.{column}": 120 if counts else 96}
    if counts:
        q.m("Values", "Respondents (Visit-Matched)", "Responses").m("Values", "Actual Visits", "Visits")
        widths |= {qref("Respondents (Visit-Matched)"): 84, qref("Actual Visits"): 82}
    q.m("Values", "Response Share %", "% responses").m("Values", "Visit Share %", "% visits") \
     .m("Values", "Representation Index", "Index").m("Values", "Representation Status", "Status") \
     .sort_by(meas("Visit Share %"))
    # by care type the shares are raw; every other profile is first re-weighted to the care-type mix
    subtitle = ("Care type of the linked visit (ER, OP, IP)"
                if table == "Care Type" else "% responses adjusted for the care-type mix")
    widths |= {qref("Response Share %"): 80 if counts else 78,
               qref("Visit Share %"): 72 if counts else 64,
               qref("Representation Index"): 56 if counts else 52,
               qref("Representation Status"): 74 if counts else 76}
    flag = {"fontColor": {"solid": {"color": {"expr": meas("Representation Color")}}}}
    values = obj({"wordWrap": lit(False)})
    for ref in (qref("Representation Index"), qref("Representation Status")):
        values += obj(flag, {"data": [{"dataViewWildcard": {"matchingOption": 1}}], "metadata": ref})
    return chart("tableEx", q, title, subtitle=subtitle, objects={
        "values": values,
        "columnHeaders": obj({"wordWrap": lit(True), "autoSizeColumnWidth": lit(False),
                              "columnAdjustment": lit("fixedWidth")}),
        "columnWidth": column_widths(widths),
        "total": obj({"totals": lit(False)}),
        "grid": obj({"rowPadding": lit(2)}),
    })


def page_satisfaction() -> Page:
    p = chapter("satisfaction-nps")
    filter_row(p, [DATE_RANGE, BRANCH, SETTING], "Story Satisfaction")
    p.add("hero", 16, 144, 300, 296, scorecard(
        Q().m("nps", "NPS (5-point)").m("promoters", "% Promoters").m("passives", "% Passives")
           .m("detractors", "% Detractors").m("volume", "NPS Answers").m("margin", "NPS Margin of Error"),
        None, mode="light", max_cols=1, score_label="NPS (5-point)"))
    p.add("kpis", 332, 144, 932, 100, card(
        [("Overall Satisfaction (0-100)", "Satisfaction /100"), ("Avg NPS by Question", "Avg NPS by question"),
         ("Top Box %", "Top box"), ("Hospital NPS (5-point)", "Hospital NPS"), ("Physician NPS (5-point)", "Physician NPS"),
         ("NPS Margin of Error", "NPS margin (±)"), "Reliability"], "Satisfaction headline"))
    p.ignore_period(p.add("trend", 332, 252, 932, 188, chart(
        "lineChart",
        Q().c("Category", *TREND_AXIS).m("Y", "NPS (5-point)").m("Y", "Overall Satisfaction (0-100)")
           .m("Y", "Avg NPS by Question").m("Tooltips", "Respondents").m("Tooltips", "NPS Margin of Error", "NPS margin (±)")
           .m("Tooltips", "Reliability"),
        "Monthly NPS, average NPS by question and overall satisfaction (0-100)",
        subtitle="Every month of the date range, whatever the Period",
        objects={"dataPoint": obj({"fill": color(BRAND["light"])}, {"metadata": qref("NPS (5-point)")})
                 + obj({"fill": color(BRAND["dturq"])}, {"metadata": qref("Overall Satisfaction (0-100)")})
                 + obj({"fill": color(BRAND["blue"])}, {"metadata": qref("Avg NPS by Question")})})))
    # One full-width row of care-setting scorecards; each card carries its own promoter / detractor split.
    p.add("by-setting", 16, 452, 1248, 256, scorecard(
        Q().c("category", "Survey Service", "Care Setting").m("nps", "NPS (5-point)").m("promoters", "% Promoters")
           .m("passives", "% Passives").m("detractors", "% Detractors").m("benchmark", "Network NPS")
           .m("volume", "NPS Answers").m("margin", "NPS Margin of Error"),
        "NPS by care setting  (vs network when a branch is selected)", mode="light", max_cols=6,
        score_label="NPS (5-point)"))
    return p


DRILL_TWINS = {
    "doctor": ("question-groups-doctor", "3 · Drivers by Doctor", "Doctor", ("Staff", "Staff Name")),
    "specialty": ("question-groups-specialty", "3 · Drivers by Specialty", "Specialty", ("Staff", "Specialty")),
}


def page_question_groups(drill: str | None = None) -> Page:
    """Chapter 3, or (drill="doctor"/"specialty") one of its hidden twins used as drillthrough targets.
    Keeping the drillthrough on twins leaves chapter 3 unfiltered, and one field per target works whether
    Power BI requires all or any of a page's drillthrough fields in the source visual."""
    if drill:
        key, display, label, (table, column) = DRILL_TWINS[drill]
        p = Page(key, display, "Drillthrough from 5 · Specialties & Doctors",
                 title=f"3 · What Drives the Score: {label}")
        p.hidden = True
        header(p)
        nav_buttons(p)
        p.drillthrough(table, column)
    else:
        p = chapter("question-groups")
    filter_row(p, [DATE_RANGE, BRANCH, SETTING], "Story Drivers")
    p.filter_in("Survey Question", "Is Scored", ["Yes"])
    for key, y, measure, direction, title in [
        ("drags", 144, "Group NPS (Bottom 8)", "Ascending", "Biggest drags: 8 lowest question groups"),
        ("strengths", 432, "Group NPS (Top 8)", "Descending", "Strengths: 8 highest question groups"),
    ]:
        p.add(key, 16, y, 500, 276, chart(
            "clusteredBarChart",
            Q().c("Category", "Survey Question", "Domain En", "Question group", active=True)
               .c("Category", "Survey Question", "Question En", "Question", active=False)
               .m("Y", measure, "NPS").m("Tooltips", "NPS Answers").m("Tooltips", "% Promoters")
               .m("Tooltips", "% Detractors").m("Tooltips", "NPS Margin of Error", "NPS margin (±)")
               .m("Tooltips", "Reliability").sort_by(meas(measure), direction),
            title, subtitle="30+ answers (10+ specialty, 5+ doctor). Right-click a bar > Drill down for questions",
            objects={**nps_point_colors(), "labels": data_labels(), "valueAxis": obj({"show": lit(False)}),
                     "categoryAxis": obj({"maxMarginFactor": lit(40)})}))  # room for "Moving Through your visit"
    p.add("weak-questions", 532, 144, 732, 564, chart(
        "tableEx",
        Q().c("Values", "Survey Question", "Domain En", "Question group")
           .c("Values", "Survey Question", "Question En", "Question")
           .m("Values", "Q NPS (Bottom 8)", "NPS").m("Values", "Q % Promoters (Bottom 8)", "Promoters")
           .m("Values", "Q % Detractors (Bottom 8)", "Detractors").m("Values", "Q Answers (Bottom 8)", "Answers")
           .sort_by(meas("Q NPS (Bottom 8)"), "Ascending"),
        "The 8 lowest-scoring questions",
        subtitle="30+ answers (10+ specialty, 2+ doctor). Click a question group on the left to focus on it",
        objects=table_objects(qref("Q NPS (Bottom 8)"), {
            "Survey Question.Domain En": 128, "Survey Question.Question En": 258,
            qref("Q NPS (Bottom 8)"): 84, qref("Q % Promoters (Bottom 8)"): 76,
            qref("Q % Detractors (Bottom 8)"): 78, qref("Q Answers (Bottom 8)"): 66}, wrap=True)))
    return p


def page_branch_benchmark() -> Page:
    p = chapter("branch-benchmark")
    filter_row(p, [DATE_RANGE, SETTING, DOMAIN], "Story Branches")
    p.add("branch-cards", 16, 144, 1248, 310, scorecard(
        Q().c("category", "Branch", "Branch Name").m("nps", "NPS (5-point)").m("promoters", "% Promoters")
           .m("passives", "% Passives").m("detractors", "% Detractors").m("benchmark", "Network NPS")
           .m("volume", "NPS Answers").m("margin", "NPS Margin of Error"),
        None, mode="light", max_cols=4, score_label="NPS (5-point)"))
    p.add("heatmap", 16, 466, 840, 242, matrix(
        Q().c("Rows", "Survey Question", "Domain En", "Question group").c("Columns", "Branch", "Branch Name")
           .m("Values", "Weak Group NPS (Bottom 5)", "NPS").sort_by(meas("Weak Group NPS (Bottom 5)"), "Ascending"),
        "The 5 weakest question groups, by branch", nps_ref=qref("Weak Group NPS (Bottom 5)"),
        expand_buttons=False))
    p.visuals[-1]["visual"]["objects"]["grid"] = obj({"rowPadding": lit(2)})
    p.add("vs-network", 872, 466, 392, 242, chart(
        "clusteredColumnChart",
        Q().c("Category", "Branch", "Branch Name").m("Y", "NPS vs Network", "NPS vs network")
           .m("Tooltips", "NPS (5-point)").m("Tooltips", "NPS Margin of Error", "NPS margin (±)").m("Tooltips", "Reliability")
           .sort_by(meas("NPS vs Network")),
        "NPS gap to network (points)",
        objects={**nps_point_colors("Gap Color"), "labels": data_labels()}))
    return p


def page_specialty_doctor() -> Page:
    p = chapter("specialty-doctor")
    filter_row(p, [DATE_RANGE, BRANCH, SPECIALTY], "Story Doctors")
    # Answers with no attributed doctor are loaded as Staff "Unknown"; they would top every doctor list.
    p.filter_not_in("Staff", "Staff Name", ["Unknown"])
    p.add("spec-branch", 16, 144, 716, 564, matrix(
        Q().c("Rows", "Staff", "Specialty").c("Rows", "Staff", "Staff Name", "Doctor")
           .c("Columns", "Branch", "Branch Name").m("Values", "Specialty NPS (Top 15 by Volume)", "NPS"),
        "The 15 most-surveyed specialties, by branch",
        subtitle="Expand (+) for doctors. Right-click a doctor or specialty > Drill through for what drives it",
        nps_ref=qref("Specialty NPS (Top 15 by Volume)")))
    for key, y, side, direction, title in [
        ("top-doctors", 144, "Top", "Descending", "Recognise: 8 highest-scoring doctors (30+ answers)"),
        ("bottom-doctors", 432, "Bottom", "Ascending", "Coach: 8 lowest-scoring doctors (30+ answers)"),
    ]:
        p.add(key, 748, y, 516, 276, chart(
            "tableEx",
            Q().c("Values", "Staff", "Staff Name", "Doctor")
               .m("Values", f"{side} Doctor NPS", "NPS").m("Values", f"{side} Doctor Specialty NPS", "Specialty")
               .m("Values", f"{side} Doctor Physician NPS", "Physician").m("Values", f"{side} Doctor Answers", "Answers")
               .sort_by(meas(f"{side} Doctor NPS"), direction),
            title,
            objects={**table_objects(qref(f"{side} Doctor NPS"), {
                "Staff.Staff Name": 190, qref(f"{side} Doctor NPS"): 78,  # NPS + reliability icon
                qref(f"{side} Doctor Specialty NPS"): 76, qref(f"{side} Doctor Physician NPS"): 76,
                qref(f"{side} Doctor Answers"): 58}, wrap=False), "grid": obj({"rowPadding": lit(2)})}))
    return p


def page_patient_profile() -> Page:
    p = chapter("patient-profile")
    filter_row(p, [DATE_RANGE, BRANCH, SETTING], "Story Profile")
    # Every tile uses the bridged "(Response Attr)" measures: Survey Answers has no relationship to Survey
    # Responses, so a response attribute (who completed the survey, first visit...) is carried to the answers by
    # TREATAS when one is filtered; with none filtered they are the plain measures. Using them on the patient and
    # payer tiles too keeps those tiles working when a click on a respondent-type bar cross-filters the page.
    tiles = [
        ("gender", "Patient", "Gender", "Gender", "By gender"),
        ("saudi", "Patient", "Is Saudi", "Saudi national", "By nationality (Saudi / non-Saudi)"),
        ("payer", "Payer", "Category", "Payer category", "By payer category"),
        ("respondent", "Survey Responses", "Respondent Type", "Who completed the survey", "By who completed the survey"),
        ("first-visit", "Survey Responses", "First Visit", "First visit / admission", "By first visit / admission"),
        ("via-er", "Survey Responses", "Admitted Via ER", "Admitted through the ER", "By admission through the ER"),
    ]
    nps_m, sat_m = "NPS (Response Attr)", "Overall Satisfaction (Response Attr)"
    vol, margin_m, rel_m = "Respondents (Response Attr)", "NPS Margin of Error (Response Attr)", "Reliability (Response Attr)"
    tw, th, gap = 405, 274, 16
    for i, (key, table, column, label, title) in enumerate(tiles):
        x = 16 + (i % 3) * (tw + gap)
        y = 144 + (i // 3) * (th + gap)
        p.add(key, x, y, tw, th, chart(
            "clusteredColumnChart",
            Q().c("Category", table, column, label).m("Y", nps_m, "NPS").m("Y", sat_m, "Satisfaction")
               .m("Tooltips", vol, "Respondents").m("Tooltips", margin_m, "NPS margin (±)").m("Tooltips", rel_m, "Reliability")
               .sort_by(meas(vol)),
            title,
            objects={"dataPoint": obj({"fill": color(BRAND["light"])}, {"metadata": qref(nps_m)})
                     + obj({"fill": color(BRAND["dturq"])}, {"metadata": qref(sat_m)}),
                     "labels": obj({"show": lit(True)})}))
    return p


# ----------------------------------------------------------------------------- user guide

def guide_text(sections: list[tuple[str, list[tuple[str, str]]]]) -> dict:
    """Textbox with section headings and 'Name: explanation' entries (name in bold)."""
    paragraphs = []
    for s_i, (heading, entries) in enumerate(sections):
        if s_i:
            paragraphs.append({"textRuns": [{"value": " ", "textStyle": {"fontSize": "6px"}}]})
        paragraphs.append({"textRuns": [{"value": heading, "textStyle": {
            "fontFamily": "Zain, Segoe UI", "fontSize": "16px", "fontWeight": "bold", "color": BRAND["mid"]}}]})
        for name, text in entries:
            runs = [{"value": text, "textStyle": {"fontFamily": "Zain, Segoe UI", "fontSize": "13px", "color": "#3C4D60"}}]
            if name:
                runs.insert(0, {"value": f"{name}: ", "textStyle": {
                    "fontFamily": "Zain, Segoe UI", "fontSize": "13px", "fontWeight": "bold", "color": BRAND["dark"]}})
            paragraphs.append({"textRuns": runs})
    return {
        "visualType": "textbox",
        "objects": {"general": obj({"paragraphs": paragraphs})},
        "visualContainerObjects": {
            "background": obj({"show": lit(True), "color": color("#FFFFFF")}),
            "border": obj({"show": lit(True), "color": color("#D5DFEA"), "radius": lit(10)}),
            "padding": obj({"top": lit(12), "bottom": lit(12), "left": lit(16), "right": lit(16)}),
            "title": obj({"show": lit(False)}),
        },
    }


def guide_page(key: str, columns: list[list[tuple[str, list[tuple[str, str]]]]]) -> Page:
    _, display, subtitle = next(g for g in GUIDES if g[0] == key)
    p = Page(key, display, subtitle, title=f"User {display}")
    header(p)
    nav_buttons(p)
    col_w, gap, top, bottom = 405, 16, 80, 708
    for i, sections in enumerate(columns):
        x = 16 + i * (col_w + gap)
        p.add(f"text-{i}", x, top, col_w, bottom - top, guide_text(sections), tab=False)
    return p


def page_guide_metrics() -> Page:
    participation = ("Participation (page 1)", [
        ("Invitations", "Survey invitations, counting one primary invitation per patient encounter."),
        ("Invitations (SMS)", "Invitations whose survey SMS was sent. SMS Reach % = Invitations (SMS) ÷ Invitations."),
        ("Surveys Responded", "Invitations where the patient answered at least one question (submitted or partial)."),
        ("Surveys Submitted", "Invitations where the patient completed and submitted the survey."),
        ("Response Rate %", "Surveys Responded ÷ Invitations. Divided by invitations, not SMS sent, because some "
                            "submitted surveys have no SMS date."),
        ("Completion Rate %", "Surveys Submitted ÷ Surveys Responded: how many responders finished the survey."),
        ("Patients Invited / Responded", "Distinct known patients behind the invitations and the responses."),
        ("Encounter Link %", "Invitations matched to a hospital visit ÷ invitations."),
        ("Median Days Visit to Answer", "Median days from the visit to the patient's answer (submitted surveys)."),
        ("Channel", "an invitation with an SMS is an SMS survey; one without an SMS is conducted by a call-centre "
                    "agent. Invited, Responded, Response % and Completed % are shown for each channel."),
        ("Share of all responses", "agent-call responses ÷ all responses."),
        ("Data quality", "partial responses ÷ responders; repeat (non-primary) invitations ÷ all invitations; "
                         "invitations whose patient has no recorded gender ÷ invitations."),
    ])
    scoring = ("How each answer is scored", [
        ("", "Only rating questions are scored; background and routing questions (who completed the survey, "
             "first visit, services used...) are used for the Patient Profile instead."),
        ("1–5 scales (rating, agree)", "4–5 = promoter, 3 = passive, 1–2 = detractor."),
        ("1–4 scale (definitely)", "3–4 = promoter, 1–2 = detractor (no passive)."),
        ("0–10 scale (likelihood)", "8–10 = promoter, 5–7 = passive, 0–4 = detractor."),
        ("NPS Answers", "Number of answers to scored questions; the base of every NPS and satisfaction figure."),
        ("Respondents", "Distinct survey responses with at least one scored answer."),
        ("% Promoters / Passives / Detractors", "Promoter, passive or detractor answers ÷ NPS Answers."),
    ])
    nps = ("NPS", [
        ("NPS (5-point)", "(Promoter answers − Detractor answers) ÷ NPS Answers × 100, across every scored question. "
                          "Ranges from −100 (all detractors) to +100 (all promoters). Scored on the 5-point Press "
                          "Ganey scales, so it is not comparable with 0–10 NPS benchmarks. Under 30 answers it reads "
                          "\"insufficient sample\"."),
        ("Avg NPS by Question", "Average of the NPS of each question, so every question counts equally however "
                                "many answers it has."),
        ("Hospital NPS (5-point)", "NPS of the 'likelihood of recommending this hospital / practice / "
                                   "department' questions only."),
        ("Physician NPS (5-point)", "NPS of the 'likelihood of recommending this physician' question only."),
    ])
    satisfaction = ("Satisfaction", [
        ("Overall Satisfaction (0-100)", "Average answer rescaled to 0–100: 1–5 scales (score − 1) ÷ 4 × 100, 1–4 "
                                         "scale (score − 1) ÷ 3 × 100, 0–10 scale score × 10. Shown out of 100."),
        ("Top Box %", "Answers at the very top of their scale (5 of 5, 4 of 4, 9–10 of 10) ÷ NPS Answers."),
    ])
    colours = ("Colours", [
        ("NPS", "green 70 and above, orange 50 to 69.9, red below 50 (bars, tables and gauges)."),
        ("Gap to network", "green when a branch is at or above the network, red when below."),
        ("Gauges", "the arc runs from −100 to +100; the small marker is the benchmark (the network, when shown); "
                   "n and ± (NPS margin of error) are under each gauge."),
        ("Signal bars", "next to NPS in tables show reliability: 4 bars High (±3 or better), 3 bars Moderate "
                        "(up to ±7), 2 bars Low. Tooltips on NPS charts show the margin and reliability too."),
    ])
    sample = ("Sample vs visits (page 1)", [
        ("Actual visits", "each survey linked to a visit carries that visit's care type: Emergency → ER visits, "
                          "Outpatient → OP visits, Inpatient → admissions. Months with 1,000+ invitations; "
                          "responses linked to a visit."),
        ("Index", "share of responses ÷ share of visits. 1.00 = fair share; under 0.80 Under, over 1.25 Over. "
                  "Except by care type, responses are first re-weighted to each care type's share of visits."),
        ("Mismatch", "½ × Σ |response share − visit share|: the share of responses that would have to move for the "
                     "mix to match the visits. Sample mix: worst mismatch up to 5% Representative, 10% Acceptable."),
        ("Weighted NPS", "NPS of each branch × care type weighted by its visits; weighting effect = weighted − "
                         "as surveyed."),
    ])
    return guide_page("guide-metrics", [[participation], [scoring, nps], [satisfaction, colours, sample]])


def page_guide_rules() -> Page:
    benchmarks = ("Benchmarks", [
        ("Network NPS", "NPS for all branches together. Shown only when a branch is in view (selected "
                        "in a slicer, or a branch row / card), so the comparison is meaningful."),
        ("NPS vs Network", "NPS − Network NPS, in points (the ▲ / ▼ chips and the gap chart)."),
        ("Network Response Rate %", "Response rate for all branches together (tooltip on the branch chart)."),
        ("Specialty NPS", "NPS of the doctor's specialty across every branch and doctor."),
    ])
    samples = ("Minimum sample sizes", [
        ("", "Small samples swing wildly, so rankings only use items with enough answers:"),
        ("Rankings and NPS columns", "30+ scored answers (shown blank otherwise)."),
        ("Physician column", "Physician NPS with 10+ physician-question answers."),
        ("Drivers page (3)", "question groups need 30+ answers, 10+ for a specialty and 5+ for a doctor; single "
                             "questions need 30 / 10 / 2."),
        ("Key takeaways", "branches and care settings need 100+ answers, specialties 200+, and branch response "
                          "rates 500+ invitations."),
    ])
    lists = ("Top and bottom lists", [
        ("", "Long lists are shown as fixed Top / Bottom N views so no visual needs to scroll:"),
        ("Page 3", "8 lowest and 8 highest question groups by NPS, and the 8 lowest-scoring questions. "
                   "Ties are broken alphabetically."),
        ("Page 4", "the 5 question groups with the lowest network NPS, shown by branch."),
        ("Page 5", "the 15 most-surveyed specialties (by scored answers); the 8 highest and 8 lowest doctors by "
                   "NPS (30+ answers), ties broken by answer volume then name."),
        ("", "All lists respect the slicers: a list for one branch ranks within that branch."),
    ])
    reliability = ("Reliability and sample size", [
        ("NPS margin (± pts)", "how far the true NPS could be from the measured one (95% confidence) = "
                               "1.96 × √((P + D − (P − D)²) ÷ respondents) × 100. Each answer scores +1 (promoter), "
                               "0 (passive) or −1 (detractor), so NPS = P − D (P, D = promoter and detractor shares). "
                               "P + D − (P − D)² is the spread of those scores; dividing by respondents and taking √ "
                               "gives the standard error; × 1.96 × 100 gives ± points. Example: P 0.826, D 0.092, "
                               "29,919 respondents → ±0.7. Reliability: High at ±3 or better, Moderate up to ±7, else Low."),
        ("Needed ±5% / Gap / Margin ±", "385 responses give a ±5% margin at 95% confidence; Margin ± = 0.98 ÷ "
                                        "√responses, both reduced for small groups using the actual visits "
                                        "(finite-population correction)."),
    ])
    profile = ("Patient Profile", [
        ("", "Gender, nationality and payer filter NPS directly. Who completed the survey, first visit and "
             "admitted-via-ER are answers stored on the survey response, so their NPS measures match each "
             "response to its answers before calculating."),
    ])
    usage = ("Using the report", [
        ("Story", "Start on Home, then follow chapters 1–6 with the Next button; each page opens with its "
                  "question and an automatic key takeaway that updates with the slicers."),
        ("Period", "MTD (the default) shows this month to date, YTD this year to date, each on top of the date "
                   "range when one is set. The monthly trend charts always show every month of the date range."),
        ("Slicers", "Period, Date range (type or pick the start and end dates), Branch, Care setting, Specialty and "
                    "Question group are synced: a selection carries to every page that has the same slicer. Page 4 "
                    "has no Branch slicer so it always compares all branches."),
        ("Drill down", "on page 3, right-click a question-group bar > Drill down to see its questions."),
        ("Drill through", "on page 5, right-click a doctor or a specialty > Drill through to open its own "
                          "'What Drives the Score' page; use ‹ Back to return."),
        ("Buttons", "a normal click on the Report Server; Ctrl + click while editing in Power BI Desktop."),
        ("Clicking a chart", "filters the other visuals on the page (cross-filter) rather than highlighting them."),
    ])
    data = ("Data", [
        ("Source", "Press Ganey patient surveys in the HNH_Analytics model (Patient Experience perspective), "
                   "live connection: figures are as of the model's last refresh. Every measure is defined in the "
                   "model and documented there (hover a field in Power BI Desktop)."),
        ("Dates", "periods and date ranges use the patient's visit date. The report opens on month to date; survey "
                  "answers arrive over the following weeks, so early-month figures are partial."),
    ])
    return guide_page("guide-rules", [[benchmarks, samples], [lists, reliability, profile], [usage, data]])


# ----------------------------------------------------------------------------- assemble

def build(database: str = DATABASE, server: str = SERVER) -> None:
    global SCORECARD_GUID
    pbiviz = sorted((ROOT / "custom-visual/hayatNpsScorecard/dist").glob("*.pbiviz"))[-1]
    with zipfile.ZipFile(pbiviz) as z:
        package = json.loads(z.read("package.json"))
        SCORECARD_GUID = package["visual"]["guid"]
        resource_name = f"{SCORECARD_GUID}.pbiviz.json"
        resource_bytes = z.read(f"resources/{resource_name}")

    for d in (REPORT_DIR, MODEL_DIR):
        if d.exists():
            shutil.rmtree(d)

    # --- pbip + semantic model reference (live connection to SSAS)
    write_json(ROOT / f"{PROJECT}.pbip", {
        "$schema": S_PBIP, "version": "1.0",
        "artifacts": [{"report": {"path": f"{PROJECT}.Report"}}],
        "settings": {"enableAutoRecovery": True},
    })
    write_json(MODEL_DIR / ".platform", {
        "$schema": S_PLATFORM,
        "metadata": {"type": "SemanticModel", "displayName": PROJECT},
        "config": {"version": "2.0", "logicalId": stable_uuid("model")},
    })
    write_json(MODEL_DIR / "definition.pbism", {"$schema": S_PBISM, "version": "4.0", "settings": {}})
    write_json(MODEL_DIR / "modelReference.json", {
        "$schema": S_MODELREF,
        "connectionString": (f"Provider=MSOLAP;Data Source={server};Initial Catalog={database};"
                             f"Cube={PERSPECTIVE};Integrated Security=SSPI"),
        "isMultiDimentional": False,
        "connectionType": "analysisServicesDatabaseLive",
    })

    # --- report shell
    write_json(REPORT_DIR / ".platform", {
        "$schema": S_PLATFORM,
        "metadata": {"type": "Report", "displayName": PROJECT},
        "config": {"version": "2.0", "logicalId": stable_uuid("report")},
    })
    write_json(REPORT_DIR / "definition.pbir", {
        "$schema": S_PBIR, "version": "4.0",
        "datasetReference": {"byPath": {"path": f"../{PROJECT}.SemanticModel"}},
    })

    # --- static resources
    theme_name = "HayatHealthcare-" + hex_id("theme", (TOOLS / "HayatHealthcare.theme.json").read_text(), n=8) + ".json"
    reg = REPORT_DIR / "StaticResources/RegisteredResources"
    reg.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(TOOLS / "HayatHealthcare.theme.json", reg / theme_name)
    shutil.copyfile(TOOLS / "assets/HayatLogoWhite.png", reg / LOGO_ITEM)
    base = REPORT_DIR / "StaticResources/SharedResources/BaseThemes"
    base.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(TOOLS / "assets/CY24SU10.json", base / "CY24SU10.json")

    # --- private custom visual (unpacked .pbiviz)
    cv = REPORT_DIR / "CustomVisuals" / SCORECARD_GUID
    write_json(cv / "package.json", package)
    (cv / "resources").mkdir(parents=True, exist_ok=True)
    (cv / "resources" / resource_name).write_bytes(resource_bytes)

    # --- definition
    d = REPORT_DIR / "definition"
    write_json(d / "version.json", {"$schema": S_VERSION, "version": "2.0.0"})
    write_json(d / "report.json", {
        "$schema": S_REPORT,
        "themeCollection": {
            "baseTheme": {"name": "CY24SU10", "reportVersionAtImport": VERSION_AT_IMPORT, "type": "SharedResources"},
            "customTheme": {"name": theme_name, "reportVersionAtImport": VERSION_AT_IMPORT,
                            "type": "RegisteredResources"},
        },
        "resourcePackages": [
            {"name": "SharedResources", "type": "SharedResources",
             "items": [{"name": "CY24SU10", "path": "BaseThemes/CY24SU10.json", "type": "BaseTheme"}]},
            {"name": "RegisteredResources", "type": "RegisteredResources",
             "items": [{"name": theme_name, "path": theme_name, "type": "CustomTheme"},
                       {"name": LOGO_ITEM, "path": LOGO_ITEM, "type": "Image"}]},
            {"name": SCORECARD_GUID, "type": "CustomVisual",
             "items": [{"name": resource_name, "path": resource_name, "type": "CustomVisualMetadata"}]},
        ],
        "settings": {
            "useStylableVisualContainerHeader": True,
            "defaultDrillFilterOtherVisuals": True,
            "allowChangeFilterTypes": True,
            "useEnhancedTooltips": True,
            "useDefaultAggregateDisplayName": True,
            "defaultFilterActionIsDataFilter": True,  # cross-filter (not cross-highlight) by default
        },
    })

    pages = [page_home(), page_survey_quality(), page_satisfaction(), page_question_groups(),
             page_branch_benchmark(), page_specialty_doctor(), page_patient_profile(),
             page_guide_metrics(), page_guide_rules(),
             page_question_groups(drill="doctor"), page_question_groups(drill="specialty")]
    write_json(d / "pages/pages.json", {
        "$schema": S_PAGES, "pageOrder": [p.name for p in pages], "activePageName": pages[0].name,
    })
    for p in pages:
        write_json(d / "pages" / p.name / "page.json", p.to_json())
        for v in p.visuals:
            write_json(d / "pages" / p.name / "visuals" / v["name"] / "visual.json", v)

    used = sorted({proj["field"]["Measure"]["Property"] for p in pages for v in p.visuals
                   for state in v["visual"].get("query", {}).get("queryState", {}).values()
                   for proj in state["projections"] if "Measure" in proj["field"]})
    print(f"Built {PROJECT} on {server} / {database}: {len(pages)} pages, {sum(len(p.visuals) for p in pages)} visuals, "
          f"{len(used)} model measures in visuals, custom visual {SCORECARD_GUID}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--database", default=DATABASE, help=f"SSAS database of the live connection (default {DATABASE})")
    ap.add_argument("--server", default=SERVER)
    a = ap.parse_args()
    build(a.database, a.server)
