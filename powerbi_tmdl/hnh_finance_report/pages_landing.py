"""The Finance report's Home, How to use and Definitions pages (user request 2026-11-19), on fin_frame and fin_blocks.

    home_page()          the landing page: headline tiles, a card per statement with its Monthly and Hospitals buttons,
                         and the way to the guide and the definitions
    guide_page()         How to use: finding the way, picking the period, reading the tables, colours and placeholders,
                         where the figures come from
    definitions_page()   Definitions: the statement figures and every KPI's formula, read from the model's measures
    KPI_DEFINITIONS      KPI code -> formula text (a test keeps it in step with dim_finance_kpi.sql)

Home is the report's only visible page; the others are hidden and reached by the tabs and buttons. Labels and texts
here are this repo's (not title-cased). Colours are the canvas's (fin_frame).
"""
from __future__ import annotations

import re

import fin_frame
from fin_blocks import text, tile
from fin_frame import (DEFINITIONS, GUIDE, HOME, INK, MUTED, PAGE_NAMES, PERIOD_BAND, _colour, _lit, _num, button_props,
                       no_container, tight)
from model import Page, Visual, meas

import hr_frame  # noqa: E402  (on the path through fin_blocks)

X0, W0, GAP = 30, 1860, 24
TOP = 186
END = 1056

# ---- home -----------------------------------------------------------------------------------------------------------

TILE_H = 112
CARD_Y = TOP + TILE_H + GAP  # 322
CARD_H = 360
LOWER_Y = CARD_Y + CARD_H + GAP  # 776
CARD_W = (W0 - 3 * GAP) / 4

HEADLINES = [("Net revenue", "FR Net Revenue", "Net Revenue"), ("EBITDA", "FR EBITDA", "EBITDA"),
             ("Net profit", "FR Net Profit", "Net Profit"), ("Total assets", "FR Total Assets", "Total Assets")]

STATEMENT_CARDS = {
    "tb": ("Trial balance",
           "Every account's opening, debits, credits and closing for the period, its net movement by month, and the "
           "closing against last year and budget.",
           ["Period debits and credits, out of balance", "Cutover difference at a hospital's move to Fusion",
            "Select an account to chart its month-end balance"]),
    "is": ("Income statement",
           "The Fusion profitability report's lines, from revenue to net profit: actual by month, then the period's "
           "actual, budget, variance, last year, growth and share of net revenue.",
           ["Net revenue, EBITDA, EBITDA margin, net profit", "Budget achievement and growth by hospital",
            "Select a line to chart it by month"]),
    "bs": ("Balance sheet",
           "The statement of financial position: assets, liabilities and equity at each month end, then the "
           "closing position against last year and budget.",
           ["Total assets, net working capital", "Current ratio, receivable days",
            "Difference: what stops the sheet balancing"]),
    "kpi": ("KPIs & ratios",
            "27 financial ratios in six groups, each against its target: growth and budget, profitability, liquidity, "
            "working capital, leverage and cost structure.",
            ["Six headline KPI cards with a 12-month trend", "On target, watch and off target counts",
             "Each hospital side by side on the Hospitals view"]),
}


def _paragraphs(runs: list[tuple[str, str, str, str]]) -> dict:
    """A text box's paragraphs: (text, size, colour, weight) each, padding 0."""
    paras = [{"textRuns": [{"value": t, "textStyle": {"fontFamily": "Segoe UI", "fontSize": s, "color": c,
                                                      "fontWeight": w}}]} for t, s, c, w in runs]
    return {"general": [{"properties": {"paragraphs": paras}}], **no_container(), **tight()}


def nav(page: str, label: str, x: float, y: float, w: float, h: float, primary: bool = True) -> Visual:
    """A page-navigation button: navy filled (primary) or outlined in navy."""
    link = {"type": _lit("PageNavigation"), "navigationSection": _lit(page)}
    if primary:
        props = button_props(link, label, "primary")
        for entry in props["fill"]:
            if entry.get("selector") == {"id": "default"}:
                entry["properties"]["fillColor"] = _colour(INK)
    else:
        props = button_props(link, label, "outline", colour=INK)
    return Visual("buttonNavigate", x, y, w, h, props={**props, **no_container()})


def statement_card(statement: str, x: float) -> list[Visual]:
    """A statement's card: title, what it shows, three points, and the buttons to its Monthly and Hospitals pages."""
    title, about, points = STATEMENT_CARDS[statement]
    monthly, hospitals = PAGE_NAMES[statement]
    ix, iw = x + 22, CARD_W - 44
    out = [hr_frame.white_panel(x, CARD_Y, CARD_W, CARD_H),
           Visual("panel", x, CARD_Y, CARD_W, 6, props={"background": [{"properties": {
               "show": _lit(True), "color": _colour(PERIOD_BAND), "transparency": _num(0)}}],
               "border": [{"properties": {"show": _lit(False)}}], "visualHeader": [{"properties": {"show": _lit(False)}}]}),
           text(ix, CARD_Y + 24, iw, 32, title, 16, INK, "bold"),
           Visual("textbox", ix, CARD_Y + 66, iw, 110, props=_paragraphs([(about, "11pt", INK, "normal")])),
           Visual("textbox", ix, CARD_Y + 170, iw, 100,
                  props=_paragraphs([("• " + p, "10.5pt", MUTED, "normal") for p in points]))]
    bw = (iw - 12) / 2
    out += [nav(monthly, "Monthly", ix, CARD_Y + CARD_H - 74, bw, 48),
            nav(hospitals, "Hospitals", ix + bw + 12, CARD_Y + CARD_H - 74, bw, 48, primary=False)]
    return out


def home_page() -> Page:
    """The landing page: the period's headline figures (net revenue, EBITDA, net profit, total assets, each against
    budget and last year), a card per statement with its two views, and the guide and definitions."""
    visuals = fin_frame.home_frame()
    tw = (W0 - 3 * GAP) / 4
    for i, (label, value, name) in enumerate(HEADLINES):
        t = f"FR Tile {name}"
        visuals += tile(label, meas(value), meas(f"{t} vs Budget"), meas(f"{t} vs Budget Colour"), meas(f"{t} vs LY"),
                        meas(f"{t} vs LY Colour"), (X0 + i * (tw + GAP), TOP, tw, TILE_H))
    for i, statement in enumerate(STATEMENT_CARDS):
        visuals += statement_card(statement, X0 + i * (CARD_W + GAP))
    lower_h = END - LOWER_Y
    half = (W0 - GAP) / 2
    visuals += [hr_frame.white_panel(X0, LOWER_Y, half, lower_h),
                text(X0 + 22, LOWER_Y + 20, half - 44, 30, "New to the report?", 15, INK, "bold"),
                Visual("textbox", X0 + 22, LOWER_Y + 58, half - 44, 110, props=_paragraphs([
                    ("How to use explains the tabs, the picks at the top, the tables and the colours. Definitions "
                     "gives every figure's and every KPI's formula.", "11pt", INK, "normal")])),
                nav(GUIDE, "How to use", X0 + 22, END - 74, 200, 48),
                nav(DEFINITIONS, "Definitions", X0 + 234, END - 74, 200, 48, primary=False),
                hr_frame.white_panel(X0 + half + GAP, LOWER_Y, half, lower_h),
                text(X0 + half + GAP + 22, LOWER_Y + 20, half - 44, 30, "About the figures", 15, INK, "bold"),
                Visual("textbox", X0 + half + GAP + 22, LOWER_Y + 58, half - 44, lower_h - 76, props=_paragraphs([
                    ("• The eight hospitals; Head Office is not included.", "10.5pt", INK, "normal"),
                    ("• General ledger from 2022: Oasis up to each hospital's move to Fusion, Fusion after it. "
                     "Refreshed every night.", "10.5pt", INK, "normal"),
                    ("• Actuals stop at today, so the current month is partial; a month not yet closed can look low.",
                     "10.5pt", INK, "normal"),
                    ("• Budgets and targets are entered by the BI manager; where none is entered yet the report says "
                     "so (No budget yet, No target yet).", "10.5pt", INK, "normal")]))]
    return Page(HOME, fin_frame.DISPLAY[HOME], visuals, filters=[fin_frame.hospitals()])


# ---- text pages -------------------------------------------------------------------------------------------------------

TITLE_Y, TITLE_H = 104, 44
BODY_Y = TITLE_Y + TITLE_H + 16
COL_W = (W0 - 2 * GAP) / 3
HEADING_PT, BODY_PT = "13pt", "10.5pt"


def _section(heading: str, bullets: list[str]) -> list[tuple[str, str]]:
    return [("heading", heading)] + [("bullet", b) for b in bullets]


def column_text(sections: list[list[tuple[str, str]]], body_pt: str = BODY_PT) -> dict:
    """A column's text: headings in 13pt Semibold navy, bullets (or "term: text" entries) in 10.5pt, a small gap
    between entries and before each heading; the white panel's look, padding 14. `body_pt`: the entries' size
    (Definitions takes 10pt to fit its longest column)."""
    heading = {"fontFamily": "Segoe UI Semibold", "fontSize": HEADING_PT, "color": INK}
    body = {"fontFamily": "Segoe UI", "fontSize": body_pt, "color": INK}
    bold = {**body, "fontFamily": "Segoe UI Semibold"}
    space = {"fontFamily": "Segoe UI", "fontSize": "5pt", "color": INK}
    out: list[dict] = []
    for sec in sections:
        for style, value in sec:
            if style == "heading" and out:
                out.append({"textRuns": [{"value": " ", "textStyle": dict(space)}]})
            if style == "heading":
                out.append({"textRuns": [{"value": value, "textStyle": dict(heading)}]})
            elif style == "term":
                term, rest = value.split(": ", 1)
                out.append({"textRuns": [{"value": term + ": ", "textStyle": dict(bold)},
                                         {"value": rest, "textStyle": dict(body)}]})
            else:
                out.append({"textRuns": [{"value": "• " + value, "textStyle": dict(body)}]})
            out.append({"textRuns": [{"value": " ", "textStyle": dict(space)}]})
    pad = _num(14)
    return {"general": [{"properties": {"paragraphs": out}}], **hr_frame.bsc.white_panel(),
            "padding": [{"properties": {"top": pad, "bottom": pad, "left": pad, "right": pad}}]}


def _text_page(name: str, title: str, columns: list[list[list[tuple[str, str]]]], body_pt: str = BODY_PT) -> Page:
    visuals = fin_frame.text_frame(name) + [text(X0, TITLE_Y, W0, TITLE_H, title, 20, INK, "bold")]
    visuals += [Visual("textbox", X0 + i * (COL_W + GAP), BODY_Y, COL_W, END - BODY_Y, props=column_text(col, body_pt))
                for i, col in enumerate(columns)]
    return Page(name, fin_frame.DISPLAY[name], visuals, filters=[fin_frame.hospitals()], hidden=True)


GUIDE_COLUMNS = [
    [_section("Find your way", [
        "The report opens on Home: the period's headline figures and a card for each statement.",
        "The tabs at the top lead to Home, Trial Balance, Income Statement, Balance Sheet, KPIs & Ratios, How to use "
        "and Definitions. Pages are reached only through the tabs and buttons.",
        "Each statement has two views. Monthly: months across, for the hospitals picked. Hospitals: the eight "
        "hospitals side by side, with All hospitals after them under each figure.",
        "Switch views with the Monthly and Hospitals buttons at the top left."]),
     _section("Pick the period", [
        "Hospital: one or more hospitals (Monthly pages and Home). The Hospitals view always shows all eight.",
        "Year: the current year when the report opens; pick an earlier year to look back.",
        "Month: nothing picked means every month of the year up to today; pick one or more months to narrow it.",
        "The period in use shows at the top right. Your picks follow you to every page.",
        "Actuals stop at today: the current month is partial, and a month the ledger has not closed yet can look "
        "low."])],
    [_section("Read the tables", [
        "Click + beside a row to open the next level, − to close it.",
        "Select a row to show it in the two charts above the table; click it again to clear. Without a selection the "
        "charts show a default line (trade receivables, or net revenue on the income statement).",
        "Amounts in the tables are in SAR thousands; the tiles abbreviate (14bn, 451M). Brackets mean a negative "
        "figure, or a credit on the trial balance.",
        "Flows (income statement, debits, credits, movements) add up over the period. Balances (closing, balance "
        "sheet, total assets) are those at the end of the period, per hospital.",
        "Wide tables scroll sideways; the KPI table takes up to a minute to load."]),
     _section("Colours and placeholders", [
        "Green: favourable (above budget or last year on income, below on costs). Red: unfavourable.",
        "KPI status: On target, Watch (short of the target by no more than its watch margin, 5% by default) and "
        "Off target. The coloured counts at the top of the KPI table add them up.",
        "Grey words: Not budgeted (the line has no budget line), No budget yet (a budget the BI manager has not "
        "entered yet), No target yet; a dash: no figure for the period.",
        "Review (red) on the trial balance: debits and credits of the period do not agree."])],
    [_section("Where the figures come from", [
        "The general ledger from 2022: Oasis up to each hospital's move to Fusion, Fusion from that month on. The "
        "Cutover difference column and the balance sheet's Difference show any gap the move left.",
        "The income statement uses the lines of Fusion's profitability report; Oasis accounts are mapped onto the "
        "same lines, so years compare.",
        "Budgets: the yearly budget file, plus any line the BI manager enters. Against budget, All hospitals compares "
        "only the hospitals and months that have a budget (like for like).",
        "KPI targets are set per year by the BI manager, for each hospital or for all.",
        "Head Office is not included. The data is refreshed every night.",
        "Questions, a budget or a target to change: contact the BI manager."])],
]


def guide_page() -> Page:
    return _text_page(GUIDE, "How to use the finance report", GUIDE_COLUMNS)


# ---- definitions --------------------------------------------------------------------------------------------------------

_DIM = fin_frame.HERE.parents[1] / "hnh_dwh" / "models" / "hnh" / "marts" / "finance" / "dim_finance_kpi.sql"
_ROW = re.compile(r"\('(FR_[A-Z_]+)', '([^']*)', (\d+), '([^']*)', '([^']*)', (-?\d+), (\d+), '[^']*'\)")


def read_kpis() -> list[dict]:
    """The KPI list of dim_finance_kpi.sql: code, group, group order, name, unit, direction, display order."""
    rows = [dict(code=c, group=g, group_order=int(go), name=n, unit=u, direction=int(d), order=int(o))
            for c, g, go, n, u, d, o in _ROW.findall(_DIM.read_text(encoding="utf-8"))]
    return sorted(rows, key=lambda r: r["order"])


# formulas as the model computes them ([FR KPI Value]); flows are over the period, balances at its end
KPI_DEFINITIONS = {
    "FR_REV_GROWTH": "net revenue against the same period last year: (this year − last year) ÷ |last year|",
    "FR_REV_VS_BUD": "net revenue as a share of its budget, like for like (only hospitals and months with a budget)",
    "FR_NP_GROWTH": "net profit against the same period last year: (this year − last year) ÷ |last year|",
    "FR_NP_VS_BUD": "net profit as a share of its budget, like for like: 1 + (actual − budget) ÷ |budget|",
    "FR_GP_MARGIN": "gross profit ÷ net revenue",
    "FR_EBITDA_MARGIN": "EBITDA ÷ net revenue",
    "FR_OP_MARGIN": "(EBITDA − depreciation and amortisation) ÷ net revenue",
    "FR_NP_MARGIN": "net profit ÷ net revenue",
    "FR_ROA": "net profit, annualised, ÷ total assets at the end of the period",
    "FR_ROE": "net profit, annualised, ÷ equity (total assets − total liabilities)",
    "FR_CURRENT_RATIO": "current assets ÷ current liabilities",
    "FR_QUICK_RATIO": "(current assets − inventories) ÷ current liabilities",
    "FR_CASH_RATIO": "cash and bank balances ÷ current liabilities",
    "FR_AR_DAYS": "trade receivables (net) ÷ net revenue × days in the period",
    "FR_INV_DAYS": "inventories ÷ (consumables + medicines cost) × days in the period",
    "FR_AP_DAYS": "trade payables ÷ purchases on credit × days in the period; purchases: direct cost and G&A less "
                  "employee costs and doctors' fees, plus selling and marketing",
    "FR_CCC": "receivable days + inventory days − payable days",
    "FR_ASSET_TURNOVER": "net revenue, annualised, ÷ total assets",
    "FR_DEBT_EQUITY": "lease liability ÷ equity (total assets − total liabilities)",
    "FR_NET_DEBT_EBITDA": "(lease liability − cash) ÷ EBITDA, annualised",
    "FR_INTEREST_COVER": "(EBITDA − depreciation and amortisation) ÷ finance cost",
    "FR_EQUITY_RATIO": "equity (total assets − total liabilities) ÷ total assets",
    "FR_COST_TO_REV": "direct cost ÷ net revenue",
    "FR_STAFF_COST_RATIO": "employee costs (direct cost and G&A) ÷ net revenue",
    "FR_MED_MATERIALS_RATIO": "(consumables + medicines cost) ÷ net revenue",
    "FR_REJECTION_RATE": "claim rejections ÷ total revenue before discounts",
    "FR_ECL_RATIO": "expected credit loss charge (G&A) ÷ net revenue",
}

FIGURES = [
    "Net revenue: revenue less contractual and settlement discounts (the profitability report's Net Revenue line).",
    "Gross profit: net revenue less direct cost.",
    "EBITDA: gross profit less G&A, selling and marketing and head office charges, plus other income.",
    "Net profit: EBITDA less depreciation and amortisation, finance cost and zakat.",
    "Total assets: each hospital's assets at the end of the period, added up.",
    "Net working capital: current assets − current liabilities at the end of the period.",
    "Out of balance: the period's debits − credits; 0 when the ledger balances.",
    "Cutover difference: closing − opening − opening journals − debits + credits; 0 within one ledger, the gap a "
    "hospital's move from Oasis to Fusion left.",
    "Difference (balance sheet): assets − liabilities and equity − current year profit (year-to-date total "
    "comprehensive income); unmapped accounts and cutover gaps show here.",
]
COMPARISONS = [
    "Budget: the budget of the period's months up to today.",
    "Variance and vs Bud: actual − budget. Var %: variance ÷ |budget|. Ach %: actual ÷ budget, like for like.",
    "Last year: the same period a year earlier. Growth: (actual − last year) ÷ |last year|; n/m when not "
    "meaningful.",
    "% Rev: the line ÷ net revenue. % Assets: the line ÷ total assets.",
    "Annualised: × 12 ÷ the number of months in the period. Days in the period: up to today.",
]
STATUS = [
    "Attainment: actual ÷ target when higher is better, target ÷ actual when lower is better.",
    "On target: attainment of 1 or more. Watch: below it by no more than the watch margin (5% unless set). Off "
    "target: further below. No target yet: no target entered (counted in no chip).",
    "A ratio whose denominator is zero or negative is left blank.",
]


def kpi_sections(kpis: list[dict], groups: list[str]) -> list[list[tuple[str, str]]]:
    """One section per KPI group in `groups`: each KPI as "name: formula. Higher / Lower is better."."""
    out = []
    for g in groups:
        rows = [r for r in kpis if r["group"] == g]
        out.append([("heading", g)] + [("term", f"{r['name']}: {KPI_DEFINITIONS[r['code']]}. "
                                               f"{'Higher' if r['direction'] > 0 else 'Lower'} is better.")
                                       for r in rows])
    return out


def definitions_page() -> Page:
    """The statement figures and comparisons (first column), the KPIs by group (second and third), the status rule."""
    kpis = read_kpis()
    groups = list(dict.fromkeys(r["group"] for r in sorted(kpis, key=lambda r: (r["group_order"], r["order"]))))
    first = [[("heading", "Statement figures")] + [("term", t) for t in FIGURES],
             [("heading", "Comparisons")] + [("term", t) for t in COMPARISONS]]
    second = kpi_sections(kpis, groups[:3])
    third = kpi_sections(kpis, groups[3:]) + [[("heading", "KPI status")] + [("bullet", t) for t in STATUS]]
    return _text_page(DEFINITIONS, "Definitions: figures and KPIs", [first, second, third], body_pt="10pt")
