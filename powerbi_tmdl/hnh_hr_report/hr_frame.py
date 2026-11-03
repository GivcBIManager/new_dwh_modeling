"""The HR report's frame and building blocks, on the BSC generator's modules (powerbi_tmdl/hnh_bsc_report: frame,
model, pbir; spec docs/superpowers/specs/2026-11-02-hr-dashboard-design.md, "Pages" and "Branding and build").

    HR_FRAME, HR_REPORT      the frame (title, tabs, help buttons) and the report (name, perspective, theme, logo)
    page_frame(tab, bar)     the BSC frame with the HR title and tabs; `bar`: the visuals in the filter bar
    filters()                Branch and Month dropdowns, synced across pages
    branches()               the report's branches: the eight hospitals and Head Office (a page filter)
    sub_tabs(current)        the six detail pages as a second row of tabs in the filter bar
    kpi_tile(code, x, y, w, h)  a KPI's actual, target and status on a white panel
    seed_kpis(), home_tile_codes()  the KPI list as scripts/hr_config/hr_config_seed.sql inserts it

The geometry, colours, buttons and the theme are the BSC's; nothing is copied. Labels here are this repo's (not
title-cased).
"""
from __future__ import annotations

import importlib.util
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BSC_DIR = HERE.parent / "hnh_bsc_report"
REPO = HERE.parents[1]
if str(BSC_DIR) not in sys.path:
    sys.path.append(str(BSC_DIR))  # after this folder: both have a pages.py

import frame  # noqa: E402
from frame import (FILTER_BAR, LOGO, NAVY, WHITE, Rect, _colour, _lit, _num, button_props, no_container,  # noqa: E402
                   tab_width)
from layout import aliases, lit, source_expr  # noqa: E402
from model import MEASURE_TABLE, Field, Filter, Visual, col, meas  # noqa: E402
from pbir import THEME, ReportSpec  # noqa: E402
from pbir import _text as pbir_text  # noqa: E402

SEED = REPO / "scripts" / "hr_config" / "hr_config_seed.sql"


def _bsc_pages():
    """The BSC report's pages.py (its slicer, panel and button helpers), loaded as `bsc_pages`: the name `pages` is
    this report's."""
    name = "bsc_pages"
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, BSC_DIR / "pages.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
    return sys.modules[name]


bsc = _bsc_pages()
MUTED = bsc.MUTED

# ---- frame and report ---------------------------------------------------------------------------------------------

TABS: list[tuple[str, str]] = [("home", "Home"), ("story", "Story"), ("scorecard", "Scorecard"),
                               ("headcount", "Details"), ("data_quality", "Data quality"), ("guide", "Guide")]
HELP: list[tuple[str, str, Rect]] = [("guide", "How to use", frame.HELP_BUTTONS[0][2]),
                                     ("guide_definitions", "Definitions", frame.HELP_BUTTONS[1][2])]
HR_FRAME = frame.FrameSpec("Workforce", "Hayat Healthcare", TABS, HELP, logo=LOGO.name)
HR_REPORT = ReportSpec("HNH Workforce", "HR Dashboard", THEME, LOGO, custom_visual=False)

# The detail pages under the Details tab: (page name, display name, sub-tab label).
DETAIL_PAGES: list[tuple[str, str, str]] = [
    ("headcount", "Headcount & mix", "Headcount"),
    ("movements", "Movements & turnover", "Movements"),
    ("payroll", "Payroll & overtime", "Payroll"),
    ("absence", "Absence & leave", "Absence"),
    ("recruitment", "Recruitment", "Recruitment"),
    ("productivity", "Productivity", "Productivity"),
]


def page_frame(tab: str | None, bar: list[Visual]) -> list[Visual]:
    """The BSC frame with the HR title, tabs and help buttons. `tab`: the page's own tab (one of TABS' names; a detail
    page passes "headcount", the Details tab), or None. `bar`: the filter-bar visuals (filters(), sub_tabs())."""
    return frame.frame(tab, bar, spec=HR_FRAME)


# ---- filter bar ---------------------------------------------------------------------------------------------------

BRANCH_NAME = col("Branch", "Branch Name")
BRANCH_KEY = col("Branch", "Branch Key")
# User decision 2026-11-03 (supersedes final review I1): Head Office is on every page and in every KPI. The report's
# branches are the eight hospitals and Head Office (100). The Branch dimension's Group member (0) is a synthetic
# all-hospitals row with no HR data: kept out of the slicer, and of the pages, where a text measure such as
# [HR KPI Status Text] ("– No data") would give it a column. The hospital keys are those of 'Branch'[Is Hospital]
# (dbt hnh_dim_branch); a new hospital is added here too.
HEAD_OFFICE = 100
BRANCH_KEYS = [1, 2, 3, 4, 5, 6, 7, 8, HEAD_OFFICE]
# "Last closed month" for the previous calendar month (relabelled by the nightly build), else as Year Month Name
# ("2026-Sep"); sorted by 'Date'[Year Month] (ruling R21)
MONTH_PICK = col("Date", "Month Pick")
LAST_CLOSED_MONTH = "Last closed month"
BRANCH_SLICER: Rect = (30, 90, 330, 66)  # the BSC's slicer rects: the bar (84..162) less 6 px top and bottom
MONTH_SLICER: Rect = (375, 90, 270, 66)
SUB_TAB_X, SUB_TAB_GAP = 669, 6  # right of the Month slicer (ends 645); the row ends before How to use (1590)
SUB_TAB_Y, SUB_TAB_H = 96, 54  # as the help buttons


def branches() -> Filter:
    """The report's branches: the eight hospitals and Head Office, not the Group member (BRANCH_KEYS)."""
    return Filter(BRANCH_KEY, "in", list(BRANCH_KEYS))


# The branches filter as page.json names its field (pbir.filter_entry)
_BRANCH_KEY_FIELD = {"Column": {"Expression": {"SourceRef": {"Entity": BRANCH_KEY.table}}, "Property": BRANCH_KEY.name}}


def lock_branch_filters(files: dict[str, bytes]) -> dict[str, bytes]:
    """The project's files (pbir.project_files) with the branches page filter of every page locked in view mode
    (`isLockedInViewMode`, as the BSC's report-level filter), so a reader cannot clear it and bring in the Group
    member (minor 3e of the Head Office review). The generator writes page filters unlocked and is shared with the
    BSC report, so the HR build locks them here; pbir_to_pbix carries the flag into the legacy layout."""
    out = dict(files)
    for path, data in files.items():
        if not (path.endswith("/page.json") and "/definition/pages/" in path):
            continue
        page = json.loads(data.decode("utf-8"))
        changed = False
        for f in page.get("filterConfig", {}).get("filters", []):
            if f.get("field") == _BRANCH_KEY_FIELD and not f.get("isLockedInViewMode"):
                f["isLockedInViewMode"] = True
                changed = True
        if changed:
            out[path] = pbir_text(page)
    return out


def lock_branch_filters_on_disk(project_dir: Path, report_name: str) -> int:
    """lock_branch_filters on a written project (pbir.write_pbip's folder); returns the number of pages changed."""
    pages = Path(project_dir) / f"{report_name}.Report" / "definition" / "pages"
    files = {p.relative_to(project_dir).as_posix(): p.read_bytes() for p in pages.glob("*/page.json")}
    changed = {k: v for k, v in lock_branch_filters(files).items() if v != files[k]}
    for rel, data in changed.items():
        (Path(project_dir) / rel).write_bytes(data)
    return len(changed)


def search_box() -> dict:
    """A dropdown slicer's search box (Desktop's slicer "Search": `general.selfFilterEnabled`), for a long list."""
    return {"general": [{"properties": {"selfFilterEnabled": _lit(True)}}]}


def saved_selection(column: Field, value: str) -> dict:
    """A slicer's saved selection, `general.filter`: `column IN (value)`, the semantic-query shape Desktop writes for
    a selected slicer item (From alias as layout.aliases names it)."""
    alias = aliases([column.table])[column.table]
    cond = {"In": {"Expressions": [source_expr(column, alias)], "Values": [[lit(value)]]}}
    return {"general": [{"properties": {"filter": {"filter": {
        "Version": 2, "From": [{"Name": alias, "Entity": column.table, "Type": 0}],
        "Where": [{"Condition": cond}]}}}}]}


def single_selection() -> dict:
    """Slicer selection: one item at a time, no "Select all"."""
    return {"selection": [{"properties": {"singleSelect": _lit(True), "selectAllCheckboxEnabled": _lit(False)}}]}


def filters() -> list[Visual]:
    """Branch (the eight hospitals and Head Office, multi-select with Select all) and Month dropdowns. pbir.py gives
    each slicer the sync group of its field, so a selection carries to every page. Month (ruling R21) is
    single-select on 'Date'[Month Pick], saved on "Last closed month": the model gives that label to the previous
    month each day, so the report opens on the last closed month without a rebuild, the month HR Story Home
    describes. Head Office shows only to users whose access grants it (the HNH Readers role)."""
    return [
        Visual("slicerDropdown", *BRANCH_SLICER, roles={"Values": [BRANCH_NAME]}, filters=[branches()],
               props={**bsc.select_all_selection(), **bsc.dropdown_look()}, labels={BRANCH_NAME: "Branch"}),
        Visual("slicerDropdown", *MONTH_SLICER, roles={"Values": [MONTH_PICK]},
               props={**single_selection(), **bsc.dropdown_look(), **saved_selection(MONTH_PICK, LAST_CLOSED_MONTH)},
               labels={MONTH_PICK: "Month"}),
    ]


def _navigate(page_name: str) -> dict:
    return {"type": _lit("PageNavigation"), "navigationSection": _lit(page_name)}


def sub_tabs(current: str) -> list[Visual]:
    """The six detail pages as a row of buttons in the filter bar, right of the slicers: the current page's filled
    in brand blue ("primary"), the others outlined ("outline"). `current` must be a detail page."""
    names = [name for name, _display, _label in DETAIL_PAGES]
    if current not in names:
        raise ValueError(f"sub_tabs: {current!r} is not a detail page ({', '.join(names)})")
    out, x = [], SUB_TAB_X
    for name, _display, label in DETAIL_PAGES:
        w = tab_width(label)
        kind = "primary" if name == current else "outline"
        out.append(Visual("buttonNavigate", x, SUB_TAB_Y, w, SUB_TAB_H,
                          props={**button_props(_navigate(name), label, kind), **no_container()}))
        x += w + SUB_TAB_GAP
    if x - SUB_TAB_GAP > HELP[0][2][0] or SUB_TAB_Y + SUB_TAB_H > FILTER_BAR[1] + FILTER_BAR[3]:
        raise ValueError("sub_tabs: the row does not fit the filter bar")
    return out


# ---- the KPI list (seed) ------------------------------------------------------------------------------------------

def _skip(sql: str, i: int) -> int:
    """Past white space and `--` comments."""
    while i < len(sql):
        if sql[i].isspace():
            i += 1
        elif sql.startswith("--", i):
            j = sql.find("\n", i)
            i = len(sql) if j < 0 else j + 1
        else:
            break
    return i


_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", "b": "\b", "f": "\f", "v": "\v"}


def _string(sql: str, i: int) -> tuple[str, int]:
    """A quoted string starting after its opening quote, with ClickHouse's escapes: `''` is one quote; `\\n`, `\\t`,
    `\\r`, `\\0`, `\\b`, `\\f` and `\\v` are those characters; any other `\\x` is x (`\\'`, `\\\\`)."""
    out = []
    while True:
        c = sql[i]
        if c == "\\":
            out.append(_ESCAPES.get(sql[i + 1], sql[i + 1]))
            i += 2
        elif c == "'" and sql[i + 1:i + 2] == "'":
            out.append("'")
            i += 2
        elif c == "'":
            return "".join(out), i + 1
        else:
            out.append(c)
            i += 1


def _token(sql: str, i: int) -> tuple[object, int]:
    """A bare value up to the next `,` or `)` outside brackets: an int, a float, or the text (`now64(3)`)."""
    depth, j = 0, i
    while depth or sql[j] not in ",)":
        depth += {"(": 1, ")": -1}.get(sql[j], 0)
        j += 1
    raw = sql[i:j].strip()
    if re.fullmatch(r"-?\d+", raw):
        return int(raw), j
    if re.fullmatch(r"-?\d+\.\d*", raw):
        return float(raw), j
    return raw, j


def _rows(sql: str, table: str) -> list[dict]:
    m = re.search(r"INSERT\s+INTO\s+" + re.escape(table) + r"\s*\(([^)]*)\)\s*VALUES", sql, re.IGNORECASE)
    if not m:
        raise ValueError(f"no INSERT INTO {table} in the seed")
    columns = [c.strip() for c in m.group(1).split(",")]
    rows, i = [], m.end()
    while True:
        i = _skip(sql, i)
        if i >= len(sql) or sql[i] == ";":
            return rows
        if sql[i] == ",":
            i += 1
            continue
        if sql[i] != "(":
            raise ValueError(f"seed: unexpected {sql[i:i + 20]!r} in the {table} values")
        values, i = [], i + 1
        while True:
            i = _skip(sql, i)
            if sql[i] == ")":
                i += 1
                break
            if sql[i] == ",":
                i += 1
                continue
            if sql[i] == "'":
                value, i = _string(sql, i + 1)
            else:
                value, i = _token(sql, i)
            values.append(value)
        if len(values) != len(columns):
            raise ValueError(f"seed: a {table} row has {len(values)} values for {len(columns)} columns")
        rows.append(dict(zip(columns, values)))


def seed_kpis(path: Path = SEED) -> list[dict]:
    """The rows `default.map_hr_kpi` is seeded with, in file order, as {column: value}."""
    return _rows(Path(path).read_text(encoding="utf-8-sig"), "default.map_hr_kpi")


def _current(path: Path = SEED) -> dict[str, dict]:
    """The seed's current row per KPI code: the last one wins, deleted rows drop out."""
    out: dict[str, dict] = {}
    for r in seed_kpis(path):
        out[r["kpi_code"]] = r
    return {code: r for code, r in out.items() if not r.get("is_deleted", 0)}


def home_tile_codes(path: Path = SEED) -> list[str]:
    """Home's tiles: the active `kpi` rows with is_home_tile 1, in display_order."""
    rows = [r for r in _current(path).values()
            if r["is_home_tile"] == 1 and r["status"] == "active" and r.get("kind", "kpi") == "kpi"]
    return [r["kpi_code"] for r in sorted(rows, key=lambda r: (r["display_order"], r["kpi_code"]))]


def kpi_label(code: str, path: Path = SEED) -> str:
    """The KPI's short label in the seed (a repo label, as the HR KPI table shows it)."""
    row = _current(path).get(code)
    if row is None:
        raise ValueError(f"KPI {code!r} is not in {Path(path).name}")
    return row["short_label"]


# ---- KPI tile -----------------------------------------------------------------------------------------------------

KPI_CODE = col("HR KPI", "KPI Code")
HR_ACTUAL_TEXT, HR_TARGET_TEXT = meas("HR KPI Actual Text"), meas("HR KPI Target Text")
HR_WATCH_TEXT, HR_VARIANCE_TEXT = meas("HR KPI Watch Text"), meas("HR KPI Variance Text")
HR_STATUS_TEXT, HR_STATUS_COLOUR = meas("HR KPI Status Text"), meas("HR KPI Status Colour")
TILE_PAD = 16


def measure_colour(measure: str) -> dict:
    """A colour property whose value is a measure's text ("#0E9F8E"): conditional formatting by field value, the
    expression Desktop writes for it (as the Press Ganey report's table font colours, `[NPS Color]`)."""
    return {"solid": {"color": {"expr": {"Measure": {"Expression": {"SourceRef": {"Entity": MEASURE_TABLE}},
                                                     "Property": measure}}}}}


def card_look(size: float, colour: str | dict | None = None, category: bool = False, box: bool = False,
              decimals: int | None = None) -> dict:
    """Card format objects: the value in Segoe UI `size` pt, `colour` a hex colour or a measure_colour(); the
    category label (the field's name or its label in the visual) in small grey, or hidden. `box`: keep the theme's
    white panel; else no background, border or visual header (the card sits on a panel). `decimals`: the value's
    decimal places (`labelPrecision`) whatever the measure's format; None keeps the format's."""
    labels = {"fontSize": _num(size)}
    if decimals is not None:  # display units None (1): with Auto the card kept the format's decimal
        labels["labelDisplayUnits"] = _num(1)
        labels["labelPrecision"] = {"expr": {"Literal": {"Value": f"{decimals}L"}}}
    if colour is not None:
        labels["color"] = _colour(colour) if isinstance(colour, str) else colour
    out = {"labels": [{"properties": labels}],
           "categoryLabels": [{"properties": {"show": _lit(category), **({"fontSize": _num(9),
                                                                          "color": _colour(MUTED)}
                                                                         if category else {})}}]}
    return out if box else {**out, **no_container()}


def fixed_table(widths: dict[Field, float], font: float, left: tuple[Field, ...] = ()) -> dict:
    """Table format objects for a table that fits its width: each field's column at its fixed width in px
    (`columnWidth` by the field's queryRef, with autosize off and the fixed-width adjustment, as the Press Ganey
    report's tables), text wrapped, values and headers in Segoe UI `font` pt, no total row. `left`: text measures
    to align left (a measure's column is right-aligned by default, even when it returns text)."""
    out = {"columnHeaders": [{"properties": {"wordWrap": _lit(True), "autoSizeColumnWidth": _lit(False),
                                             "columnAdjustment": _lit("fixedWidth"), "fontSize": _num(font)}}],
           "values": [{"properties": {"wordWrap": _lit(True), "fontSize": _num(font)}}],
           "columnWidth": [{"properties": {"value": _num(w)}, "selector": {"metadata": f.ref}}
                           for f, w in widths.items()],
           "total": [{"properties": {"totals": _lit(False)}}]}
    if left:
        out["columnFormatting"] = [{"properties": {"alignment": _lit("Left")}, "selector": {"metadata": f.ref}}
                                   for f in left]
    return out


def small_title(size: float = 11) -> dict:
    """A visual title in small grey (over the tile's figure, the mockup's label)."""
    return {"title": [{"properties": {"fontColor": _colour(MUTED), "fontSize": _num(size)}}]}


def white_panel(x: float, y: float, w: float, h: float) -> Visual:
    """A white panel with the data visuals' 1 px #DCE5EF border and radius 12 (BSC pages.white_panel)."""
    return Visual("panel", x, y, w, h, props={**bsc.white_panel(),
                                              "visualHeader": [{"properties": {"show": _lit(False)}}]})


def kpi_tile(code: str, x: float, y: float, w: float, h: float) -> list[Visual]:
    """A KPI tile: a white panel, then three cards on it, each filtered to the KPI's code (the page's branches filter
    keeps the hospitals and Head Office, the scope of the HR KPI measures): [HR KPI Actual Text] (the formatted actual, "Requires pay access" for a
    pay KPI without pay access, "–" without data; ruling R22) under the KPI's short label, [HR KPI Target Text]
    ("6.0% (placeholder)", "Not set", "Requires pay access") labelled "Target", and [HR KPI Status Text] (shape and
    word, "◆ Watch") in the colour of [HR KPI Status Colour]: colour, shape and word."""
    label = kpi_label(code)
    pad, status_h, target_h = TILE_PAD, 48, 56
    ix, iw = x + pad, w - 2 * pad
    actual_h = h - 2 * pad - target_h - status_h
    if actual_h < 80:
        raise ValueError(f"kpi_tile {code}: {h} px is too low for a tile")
    only = [Filter(KPI_CODE, "eq", [code])]
    actual = Visual("card", ix, y + pad, iw, actual_h, roles={"Values": [HR_ACTUAL_TEXT]}, filters=list(only),
                    title=label, props={**card_look(28, NAVY), **small_title()})
    target = Visual("card", ix, y + pad + actual_h, iw, target_h, roles={"Values": [HR_TARGET_TEXT]},
                    filters=list(only), props=card_look(12, MUTED, category=True),
                    labels={HR_TARGET_TEXT: "Target"})
    status = Visual("card", ix, y + pad + actual_h + target_h, iw, status_h, roles={"Values": [HR_STATUS_TEXT]},
                    filters=list(only), props=card_look(14, measure_colour(HR_STATUS_COLOUR.name)))
    return [white_panel(x, y, w, h), actual, target, status]


# ---- notices in a chart's title band (ruling R31) ----------------------------------------------------------------
# A notice on a chart or table ([HR Pay Notice], [HR KPI Pay Notice], [HR Vacancy Note]: "" when there is nothing to
# say) sits in the visual's title strip, right-aligned, in a small font: over the plot area it would take the hover
# and the clicks (tooltips, cross-highlighting) even while empty.
CHART_TITLE_PT = 14  # the theme's title text class (Segoe UI Semibold), one line
TITLE_BAND_H = 32  # px from the visual's top: its top padding and the title's row; the plot area starts below
NOTICE_PT = 9
NOTICE_TOP, NOTICE_H, NOTICE_RIGHT = 3, 26, 8  # the notice card in the band; NOTICE_RIGHT: gap to the right edge
# The longest text each notice measure shows (ssas/HNH_Analytics/tables/_Measures.tmdl)
NOTICE_TEXTS = {"HR Pay Notice": "Requires pay access", "HR KPI Pay Notice": "Requires pay access",
                "HR Vacancy Note": "Budgeted FTE not loaded: vacancy rate not available"}
EM_PER_CHAR = 0.52  # Segoe UI, regular and semibold: 0.44-0.48 em a character on these texts (System.Drawing)


def _text_px(text: str, pt: float) -> float:
    return len(text) * EM_PER_CHAR * pt * 4 / 3


def title_text_width(title: str) -> float:
    """A generous estimate of a visual title's width in px, with the visual's left padding."""
    return 12 + _text_px(title, CHART_TITLE_PT)


def notice_text_width(measure: str) -> float:
    """The notice card's width for `measure`'s longest text, with the card's own padding."""
    return 16 + _text_px(NOTICE_TEXTS[measure], NOTICE_PT)


def title_notice(chart: Visual, measure: str) -> Visual:
    """`measure`'s notice in `chart`'s title band, right-aligned; the card has no filter (a card filtered to no row
    prints "(Blank)"). Draw it after the chart. Raises when the title and the notice do not fit on one line."""
    if chart.title is None:
        raise ValueError(f"a notice needs a titled visual: {chart.sample} {chart.roles}")
    w = notice_text_width(measure)
    x = chart.x + chart.w - NOTICE_RIGHT - w
    if x < chart.x + title_text_width(chart.title):
        raise ValueError(f"chart '{chart.title}' ({chart.w:.0f} px) is too narrow for its title and [{measure}]")
    return Visual("card", x, chart.y + NOTICE_TOP, w, NOTICE_H, roles={"Values": [meas(measure)]},
                  props=card_look(NOTICE_PT, NAVY))


def nav_button(x: float, y: float, w: float, h: float, page_name: str, label: str) -> Visual:
    """An outline page-navigation button ("Open data quality ›")."""
    return Visual("buttonNavigate", x, y, w, h,
                  props={**button_props(_navigate(page_name), label, "outline"), **no_container()})


__all__ = ["BRANCH_KEYS", "BSC_DIR", "DETAIL_PAGES", "HEAD_OFFICE", "HELP", "HR_FRAME", "HR_REPORT", "MUTED", "NAVY",
           "NOTICE_PT", "SEED", "TABS", "TITLE_BAND_H", "WHITE", "branches", "card_look", "filters", "fixed_table",
           "home_tile_codes", "kpi_label", "kpi_tile", "lock_branch_filters", "lock_branch_filters_on_disk",
           "measure_colour", "nav_button", "notice_text_width", "page_frame", "search_box", "seed_kpis", "small_title",
           "sub_tabs", "title_notice", "title_text_width", "white_panel"]
