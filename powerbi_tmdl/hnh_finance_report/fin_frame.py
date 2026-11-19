"""The Finance report's frame and filter bar, on the BSC generator's modules (powerbi_tmdl/hnh_bsc_report: frame, model,
pbir; the look is the design canvas's, plan Task 13).

    FIN_FRAME, FIN_REPORT   the frame (title, seven tabs) and the report (name, perspective, theme, logo)
    PAGE_NAMES              statement -> (monthly page, hospitals page); display names in DISPLAY
    page_frame(st, view)    the BSC frame with the statement's tab current and the filter bar
    filter_bar(st, view)    view buttons, Hospital slicer (monthly) or the hospitals note, Year, Month, period text
    home_frame(), text_frame(name)   the frame of the Home page (filter bar without view buttons) and of the How to
                            use and Definitions pages (no filter bar)

Every page but Home is hidden: the tabs and the Monthly / Hospitals buttons are the navigation (user request
2026-11-19). The slicers are drop-downs and sync across pages (one sync group per field, pbir).
    hospitals()             the page filter Branch[Branch Key] in 1..8, locked in view mode on every page

Labels here are this repo's (not title-cased). Colours are the canvas's (global constraints of the plan).
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BSC_DIR = HERE.parent / "hnh_bsc_report"
if str(BSC_DIR) not in sys.path:
    sys.path.append(str(BSC_DIR))  # after this folder: both have a pages.py

import frame  # noqa: E402
from frame import LOGO, Rect, _colour, _lit, _num, button_props, no_container  # noqa: E402
from layout import aliases, lit, source_expr  # noqa: E402
from model import Field, Filter, Interaction, Visual, col, meas  # noqa: E402
from pbir import THEME, ReportSpec  # noqa: E402
from pbir import _text as pbir_text  # noqa: E402


def _bsc_pages():
    """The BSC report's pages.py (its slicer looks), loaded as `bsc_pages`: the name `pages` is this report's."""
    name = "bsc_pages"
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, BSC_DIR / "pages.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
    return sys.modules[name]


bsc = _bsc_pages()

# ---- colours (canvas) ---------------------------------------------------------------------------------------------

INK, PERIOD_BAND, MONTH_BAND, LIGHT_BAND = "#0A1E32", "#0A2D6E", "#32A5E6", "#BFE0F6"
TOTAL_BAND, NET_BAND, SELECTED = "#EFF4F9", "#DFE8F1", "#CDE8FA"
FAVOURABLE, UNFAVOURABLE, MUTED = "#04705F", "#C2230A", "#4D5B6B"
CHIP_ON, CHIP_WATCH, CHIP_OFF = ("#D9F3EE", "#04564A"), ("#FFDF8A", "#5C3F00"), ("#F5A99B", "#6E1505")
BAR_ON, BAR_WATCH, BAR_OFF = "#05A591", "#EF8D00", "#DC280A"
SERIES_ACTUAL, SERIES_BUDGET, SERIES_LAST_YEAR = "#0A2D6E", "#32A5E6", "#A0BEFF"
PLACEHOLDER_GREY = "#9AA7B5"

# ---- frame and report ---------------------------------------------------------------------------------------------

HOME, GUIDE, DEFINITIONS = "home", "guide", "definitions"
TABS: list[tuple[str, str]] = [(HOME, "Home"), ("tb_monthly", "Trial Balance"), ("is_monthly", "Income Statement"),
                               ("bs_monthly", "Balance Sheet"), ("kpi_monthly", "KPIs & Ratios"),
                               (GUIDE, "How to use"), (DEFINITIONS, "Definitions")]
FIN_FRAME = frame.FrameSpec("Finance Report", "Hayat Healthcare", TABS, [], logo=LOGO.name)
FIN_REPORT = ReportSpec("HNH Finance", "Finance Report", THEME, LOGO, custom_visual=False, cross_filter=True)

PAGE_NAMES: dict[str, tuple[str, str]] = {"tb": ("tb_monthly", "tb_hospitals"), "is": ("is_monthly", "is_hospitals"),
                                          "bs": ("bs_monthly", "bs_hospitals"), "kpi": ("kpi_monthly", "kpi_hospitals")}
STATEMENT_NAMES = {"tb": "Trial Balance", "is": "Income Statement", "bs": "Balance Sheet", "kpi": "KPIs & Ratios"}
DISPLAY: dict[str, str] = {}
for _st, (_m, _h) in PAGE_NAMES.items():
    DISPLAY[_m] = STATEMENT_NAMES[_st]
    DISPLAY[_h] = f"{STATEMENT_NAMES[_st]} · Hospitals"
DISPLAY.update({HOME: "Home", GUIDE: "How to use", DEFINITIONS: "Definitions"})
VIEWS = (("monthly", "Monthly"), ("hospitals", "Hospitals"))

BRANCH_NAME = col("Branch", "Branch Name")
BRANCH_KEY = col("Branch", "Branch Key")
HOSPITAL_KEYS = [1, 2, 3, 4, 5, 6, 7, 8]
YEAR_PICK = col("Date", "Year Pick")
YEAR = col("Date", "Year")
MONTH_SHORT = col("Date", "Month Short")
PERIOD_TEXT = meas("FR Period Text")
CURRENT_YEAR = "Current year"
YEAR_OFFSET = col("Date", "Year Offset")
# 'Date'[Year] 2022..2040: the years with data (the GL starts in 2022) up to a fixed horizon, no yearly rebuild until 2040
YEARS_OFFERED = Filter(YEAR, "in", list(range(2022, 2041)))
# 'Date'[Year Offset] 0 (the current year) and up (past years): the slicer never offers a future year (the Date table
# runs two years ahead, screenshot 2026-11-19), whatever the year
PAST_YEARS = Filter(YEAR_OFFSET, "in", list(range(0, 19)))

# Filter bar rects (the frame's bar is y 84..162; controls 96..150)
VIEW_W, VIEW_GAP, BAR_Y, BAR_H = 110, 6, 96, 54
# drop-down slicers (user request 2026-11-19): header over the box
HOSPITAL_RECT: Rect = (275, 92, 330, 62)
YEAR_RECT: Rect = (620, 92, 220, 62)
MONTH_RECT: Rect = (855, 92, 300, 62)
HOME_NOTE_RECT: Rect = (30, 100, 230, 46)
PERIOD_RECT: Rect = (1640, 94, 250, 34)
UNIT_RECT: Rect = (1640, 128, 250, 24)
PERIOD_PT = 13


def hospitals() -> Filter:
    """The report's branches: the eight hospitals (Branch Key 1..8), a page filter on every page, locked."""
    return Filter(BRANCH_KEY, "in", list(HOSPITAL_KEYS))


_BRANCH_KEY_FIELD = {"Column": {"Expression": {"SourceRef": {"Entity": BRANCH_KEY.table}}, "Property": BRANCH_KEY.name}}


def lock_branch_filters(files: dict[str, bytes]) -> dict[str, bytes]:
    """The project's files with the branches page filter of every page locked in view mode (`isLockedInViewMode`):
    the generator writes page filters unlocked and is shared with the BSC report."""
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
    """lock_branch_filters on a written project; returns the number of pages changed."""
    pages = Path(project_dir) / f"{report_name}.Report" / "definition" / "pages"
    files = {p.relative_to(project_dir).as_posix(): p.read_bytes() for p in pages.glob("*/page.json")}
    changed = {k: v for k, v in lock_branch_filters(files).items() if v != files[k]}
    for rel, data in changed.items():
        (Path(project_dir) / rel).write_bytes(data)
    return len(changed)


def saved_selection(column: Field, value: str) -> dict:
    """A slicer's saved selection, `general.filter`: `column IN (value)` (the shape Desktop writes)."""
    alias = aliases([column.table])[column.table]
    cond = {"In": {"Expressions": [source_expr(column, alias)], "Values": [[lit(value)]]}}
    return {"general": [{"properties": {"filter": {"filter": {
        "Version": 2, "From": [{"Name": alias, "Entity": column.table, "Type": 0}],
        "Where": [{"Condition": cond}]}}}}]}


def single_selection() -> dict:
    return {"selection": [{"properties": {"singleSelect": _lit(True), "selectAllCheckboxEnabled": _lit(False)}}]}


def multi_selection() -> dict:
    return {"selection": [{"properties": {"singleSelect": _lit(False), "selectAllCheckboxEnabled": _lit(False)}}]}


def tile_look() -> dict:
    return {"header": [{"properties": {"show": _lit(True), "textSize": _num(9), "fontColor": _colour(MUTED)}}],
            "items": [{"properties": {"textSize": _num(11), "fontColor": _colour(INK)}}]}


def tight() -> dict:
    """Padding 0 on every side: a text box or small card keeps its whole rect for the text (with the default
    padding a 10 pt line in a 22 px box overflowed and showed a scroll bar, screenshot 2026-11-19)."""
    zero = _num(0)
    return {"padding": [{"properties": {"top": zero, "bottom": zero, "left": zero, "right": zero}}]}


def _text_props(text: str, size: str, colour: str, weight: str = "normal", align: str | None = None) -> dict:
    style = {"fontFamily": "Segoe UI", "fontSize": size, "fontWeight": weight, "color": colour}
    para: dict = {"textRuns": [{"value": text, "textStyle": style}]}
    if align:
        para["horizontalTextAlignment"] = align
    return {"general": [{"properties": {"paragraphs": [para]}}], **no_container(), **tight()}


def _navigate(page_name: str) -> dict:
    return {"type": _lit("PageNavigation"), "navigationSection": _lit(page_name)}


def nav_button(page_name: str, label: str, x: float, w: float, current: bool) -> Visual:
    """A view button: a page-navigation button, navy-filled with white text when it is the current view, else outlined
    in navy."""
    if not current:
        props = button_props(_navigate(page_name), label, "outline", colour=INK)
    else:
        props = button_props(_navigate(page_name), label, "primary")
        for e in props["fill"]:
            if e.get("selector") == {"id": "default"}:
                e["properties"]["fillColor"] = _colour(INK)
    return Visual("buttonNavigate", x, BAR_Y, w, BAR_H, props={**props, **no_container()})


def dropdown_look() -> dict:
    """The drop-down slicers' look (the BSC report's: small grey header, #CBD3DC border, radius 6), items in ink."""
    return {**bsc.dropdown_look(), "items": [{"properties": {"textSize": _num(11), "fontColor": _colour(INK)}}]}


def hospital_slicer(rect: Rect = HOSPITAL_RECT) -> Visual:
    """The Hospital drop-down: multi-select with Select all, the eight hospitals."""
    return Visual("slicerDropdown", *rect, roles={"Values": [BRANCH_NAME]}, filters=[hospitals()],
                  props={**bsc.select_all_selection(), **dropdown_look()}, labels={BRANCH_NAME: "Hospital"})


def date_slicers() -> list[Visual]:
    """The Year drop-down (single select, saved on "Current year", the years from 2022 up to the current one, newest
    first) and the Month drop-down (multi-select with Select all, nothing saved: every month of the year to date)."""
    return [Visual("slicerDropdown", *YEAR_RECT, roles={"Values": [YEAR_PICK]}, filters=[YEARS_OFFERED, PAST_YEARS],
                   sort=YEAR_PICK, sort_dir="desc",
                   props={**single_selection(), **dropdown_look(), **saved_selection(YEAR_PICK, CURRENT_YEAR)},
                   labels={YEAR_PICK: "Year"}),
            Visual("slicerDropdown", *MONTH_RECT, roles={"Values": [MONTH_SHORT]},
                   props={**bsc.select_all_selection(), **dropdown_look()}, labels={MONTH_SHORT: "Month"})]


def period_visuals() -> list[Visual]:
    """The period text and the unit, at the bar's right."""
    return [Visual("card", *PERIOD_RECT, roles={"Values": [PERIOD_TEXT]}, props=period_look()),
            Visual("textbox", *UNIT_RECT, props=_text_props("SAR '000", "10pt", MUTED, align="right"))]


def filter_bar(statement: str, view: str) -> list[Visual]:
    """The filter bar's visuals. `view`: "monthly" or "hospitals". View buttons to the twin pages; on a monthly page the
    Hospital drop-down, on a hospitals page a note; the Year and Month drop-downs (date_slicers), the period text
    and the unit."""
    if view not in dict(VIEWS):
        raise ValueError(f"view must be 'monthly' or 'hospitals', got {view!r}")
    out, x = [], 30.0
    for (name, label), page in zip(VIEWS, PAGE_NAMES[statement]):
        out.append(nav_button(page, label, x, VIEW_W, name == view))
        x += VIEW_W + VIEW_GAP
    if view == "monthly":
        out.append(hospital_slicer())
    else:
        out.append(Visual("textbox", HOSPITAL_RECT[0], HOSPITAL_RECT[1] + 8, HOSPITAL_RECT[2], 40,
                          props=_text_props("All eight hospitals, side by side with the total", "11pt", INK, "bold")))
    out += date_slicers()
    return out + period_visuals()


def period_look() -> dict:
    """The period text card: PERIOD_PT semibold ink, right-aligned, no category label (Desktop's default 27 pt card
    was cut to "Jan to Nov 2...", screenshot 2026-11-19)."""
    labels = {"fontSize": _num(PERIOD_PT), "fontFamily": _lit("Segoe UI Semibold"), "color": _colour(INK),
              "horizontalAlignment": _lit("right")}
    return {"labels": [{"properties": labels}], "categoryLabels": [{"properties": {"show": _lit(False)}}],
            **no_container(), **tight()}


def page_frame(statement: str, view: str) -> list[Visual]:
    """The BSC frame with the Finance title and tabs, the statement's tab current, and filter_bar(statement, view)."""
    return frame.frame(PAGE_NAMES[statement][0], filter_bar(statement, view), spec=FIN_FRAME)


def home_frame() -> list[Visual]:
    """The Home page's frame: its tab current; the filter bar with a note where the view buttons sit, the Hospital,
    Year and Month drop-downs (synced with every page's) and the period text."""
    note = Visual("textbox", *HOME_NOTE_RECT,
                  props=_text_props("Your picks follow you to every page", "10pt", MUTED, align="left"))
    return frame.frame(HOME, [note, hospital_slicer(), *date_slicers(), *period_visuals()], spec=FIN_FRAME)


def text_frame(name: str) -> list[Visual]:
    """The frame of a text page (How to use, Definitions): its tab current, no filter bar."""
    if name not in (GUIDE, DEFINITIONS):
        raise ValueError(f"text pages: {GUIDE}, {DEFINITIONS}; got {name!r}")
    return frame.frame(name, [], filter_bar=False, spec=FIN_FRAME)


def frame_targets(visuals: list[Visual]) -> list[Visual]:
    """The frame visuals a click in the content must not filter: the period text card and the slicers (a selected
    matrix row or chart bar would otherwise filter [FR Period Text], and cross-filter the slicers' items)."""
    return [v for v in visuals if v.sample.startswith("slicer") or
            (v.sample == "card" and v.roles.get("Values") == [PERIOD_TEXT])]


def isolate_from_frame(sources: list[Visual], page_visuals: list[Visual]) -> list[Interaction]:
    """Interaction NoFilter from each content visual in `sources` (matrix, charts, sparklines) to the page's period
    text card and slicers (Task 15 review, every page)."""
    return [Interaction(s, t, "NoFilter") for s in sources for t in frame_targets(page_visuals)]
