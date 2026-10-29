"""Write the scorecard's KPI lists into ssas/HNH_Analytics/tables/_Measures.tmdl (bsc visual plan, Task 9).

BSC Actual, BSC Target and the measures that inline them (BSC Variance %, BSC Score, BSC State, BSC Visual Payload,
BSC Visual Payload Scores) read every KPI measure in one ROW ( "@<CODE>", [<measure>], ... ) table and pick the KPI in
context with SWITCH ( Code, "<CODE>", MAXX ( <table>, [@<CODE>] ), ..., BLANK () ). This tool rewrites every such ROW
list and SWITCH lookup from KPIS (the KPI measures) and BUDGETS (the budget targets), keeping each block's indentation
and lookup table. BSC Visual Payload also has an ADDCOLUMNS ( VALUES ( 'Date'[Year Month] ), "@<CODE>", ... ) list
for its trend months, and its lists call [_Unguarded <measure>] (the twins measure_guards.py writes); a list keeps that
form. To add a KPI, add its line below and run the tool, then measure_guards.py and sync_perspectives.py.

BSC Numerator and BSC Denominator (report plan, Task 2) are written whole from bsc_kpi_parts.PARTS: one
SWITCH ( Code, "<CODE>", <part>, ..., BLANK () ) evaluated in the filter context BSC Actual gives the KPI measures.

Usage: python ssas/tools/gen_bsc_kpi_lists.py [--check]   (--check: exit 1 when the file is not current)
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from bsc_kpi_parts import PARTS  # noqa: E402

MEASURES_FILE = Path(__file__).resolve().parents[1] / "HNH_Analytics" / "tables" / "_Measures.tmdl"

# (KPI code in 'BSC KPI'[KPI Code], measure that computes its actual), in dispatch order.
KPIS = [
    ("FIN_NET_REVENUE", "BSC Net Revenue"),
    ("FIN_REVENUE_GROWTH", "BSC Net Revenue"),
    ("FIN_EBITDA_MARGIN", "BSC EBITDA Margin"),
    ("FIN_COST_TO_REVENUE", "BSC Cost to Revenue"),
    ("FIN_CONSUMABLES_RATIO", "BSC Consumables Ratio"),
    ("FIN_DAYS_IN_AR", "BSC Days in AR (days)"),
    ("FIN_NET_COLLECTION", "BSC Net Collection Rate"),
    ("FIN_DAYS_INVENTORY", "BSC Days Inventory (days)"),
    ("FIN_REVENUE_PER_BED", "BSC Revenue per Bed"),
    ("FIN_RETURN_ON_ASSETS", "BSC Return on Assets"),
    ("FIN_EBITDA_PER_BED", "BSC EBITDA per Bed"),
    ("FIN_REVENUE_PER_DOCTOR", "BSC Revenue per Doctor"),
    ("FIN_EBITDA_PER_DOCTOR", "BSC EBITDA per Doctor"),
    ("CUS_MULTI_SPECIALTY_SHARE", "BSC Multi-Specialty Revenue Share"),
    ("CUS_PAYER_MIX", "BSC Payer Mix"),
    ("CUS_PATIENT_SATISFACTION", "BSC Patient Satisfaction"),
    ("CUS_PATIENT_RETENTION", "BSC Patient Retention"),
    ("CUS_NEW_PATIENTS", "BSC New Patient Acquisition"),
    ("CUS_PREMS", "BSC PREMs Score"),
    ("CUS_OP_WAIT", "BSC OP Waiting Time (min)"),
    ("CUS_NON_MOH_SHARE", "BSC Non-MoH Revenue Share"),
    ("CUS_PAYER_VOLUME", "BSC Payer Volume"),
    ("CUS_ACQUISITION_COST", "BSC Patient Acquisition Cost"),
    ("CUS_REFERRAL_CONVERSION", "BSC Referral Conversion Rate"),
    ("INT_BED_OCCUPANCY", "BSC Bed Occupancy"),
    ("INT_OP_UTILIZATION", "BSC Clinic Utilization"),
    ("INT_ALOS", "BSC ALOS (days)"),
    ("INT_OP_TO_IP", "BSC OP to IP Conversion"),
    ("INT_PATIENT_VOLUME", "BSC Patient Volume"),
    ("INT_ER_GROWTH", "BSC ER Growth"),
    ("INT_DOCTOR_UTILIZATION", "BSC OP Doctor Utilization"),
    ("INT_ACTIVATED_BEDS", "BSC Activated Beds"),
    ("INT_HIGH_VALUE_REVENUE", "BSC High-Value Revenue Share"),
    ("INT_HIGH_VALUE_CENSUS", "BSC High-Value Census"),
    ("INT_OP_REVENUE_PER_EPISODE", "BSC OP Revenue per Episode"),
    ("INT_ANCILLARY_UTILIZATION", "BSC Ancillary Utilization"),
    ("INT_REVENUE_LEAKAGE", "BSC Revenue Leakage"),
    ("INT_CLAIM_INITIAL_REJECTION", "BSC Claim Initial Rejection"),
    ("INT_CLAIM_FINAL_REJECTION", "BSC Claim Final Rejection"),
    ("INT_ORDER_NOT_DONE", "BSC Order Not Done"),
    ("INT_APPROVAL_TAT", "BSC Approval TAT (min)"),
    ("INT_COST_BUDGET_VARIANCE", "BSC Cost Budget Variance"),
    ("INT_GA_RATIO", "BSC G&A Ratio"),
    ("INT_READMISSION_30D", "BSC Readmission 30d"),
    ("INT_READMISSION_48H_CRITICAL", "BSC Readmission 48h Critical"),
    ("INT_EXTERNAL_REFERRALS", "BSC External Referrals"),
    ("LRN_TURNOVER", "BSC Turnover"),
    ("LRN_REVENUE_PER_FTE", "BSC Revenue per FTE"),
    ("LRN_STAFF_TO_BED", "BSC Staff to Bed"),
    ("LRN_SAUDIZATION", "BSC Saudization"),
    ("LRN_VACANCY_RATE", "BSC Vacancy Rate"),
    ("LRN_TIME_TO_FILL", "BSC Time to Fill (days)"),
    ("LRN_CLINICAL_TO_DOCTOR", "BSC Clinical to Doctor"),
]

# (KPI code, measure that computes its budget target) for the KPIs whose Target Source is "budget".
BUDGETS = [
    ("FIN_NET_REVENUE", "BSC Target Net Revenue"),
    ("FIN_EBITDA_MARGIN", "BSC Target EBITDA Margin"),
    ("FIN_COST_TO_REVENUE", "BSC Target Cost to Revenue"),
    ("FIN_CONSUMABLES_RATIO", "BSC Target Consumables Ratio"),
    ("FIN_DAYS_INVENTORY", "BSC Target Days Inventory (days)"),
    ("FIN_REVENUE_PER_BED", "BSC Target Revenue per Bed"),
    ("FIN_EBITDA_PER_BED", "BSC Target EBITDA per Bed"),
    ("FIN_REVENUE_PER_DOCTOR", "BSC Target Revenue per Doctor"),
    ("FIN_EBITDA_PER_DOCTOR", "BSC Target EBITDA per Doctor"),
    ("CUS_MULTI_SPECIALTY_SHARE", "BSC Target Multi-Specialty Share"),
    ("CUS_PAYER_MIX", "BSC Target Payer Mix"),
    ("CUS_NON_MOH_SHARE", "BSC Target Non-MoH Share"),
    ("CUS_PAYER_VOLUME", "BSC Target Payer Volume"),
    ("CUS_ACQUISITION_COST", "BSC Target Patient Acquisition Cost"),
    ("INT_OP_UTILIZATION", "BSC Target Clinic Utilization"),
    ("INT_OP_TO_IP", "BSC Target OP to IP"),
    ("INT_PATIENT_VOLUME", "BSC Target Patient Volume"),
    ("INT_ER_GROWTH", "BSC Target ER Growth"),
    ("INT_OP_REVENUE_PER_EPISODE", "BSC Target OP Revenue per Episode"),
    ("INT_ANCILLARY_UTILIZATION", "BSC Target Ancillary Utilization"),
    ("INT_GA_RATIO", "BSC Target G&A Ratio"),
    ("LRN_REVENUE_PER_FTE", "BSC Target Revenue per FTE"),
]

# ROW ( or ADDCOLUMNS ( VALUES ( 'Date'[Year Month] ), (BSC Visual Payload's months, Task 10), then "@<CODE>",
# [<measure>] lines one tab deeper, up to the ) at the opening line's indentation. A list of budget targets when every
# measure is a "BSC Target ..." measure. A list that calls unguarded twins ([_Unguarded <measure>], written by
# measure_guards.py) keeps calling them.
ROW_RE = re.compile(r"(?m)^(\t*)(ROW \(\n|ADDCOLUMNS \(\n\1\tVALUES \( 'Date'\[Year Month\] \),\n)"
                    r'((?:\1\t"@[^"]+", \[[^\]]+\],?\n)+)(?=\1\))')
TWIN_PREFIX = "_Unguarded "
# Code, then "<CODE>", MAXX ( <table>, [@<CODE>] ), lines up to BLANK (). Budget targets when <table> says Budget.
SWITCH_RE = re.compile(r'(?m)^(\t*)Code,\n((?:\1"[^"]+", MAXX \( (\w+), \[@[^\]]+\] \),\n)+)(?=\1BLANK \(\))')
MEASURE_RE = re.compile(r"(?m)^\tmeasure (?:'((?:[^']|'')+)'|(\S+))")


def _row_measures(block: str) -> list:
    return re.findall(r'"@[^"]+", \[([^\]]+)\]', block)


def _row_kind(block: str) -> str:
    measures = [m[len(TWIN_PREFIX):] if m.startswith(TWIN_PREFIX) else m for m in _row_measures(block)]
    return "budget" if all(m.startswith("BSC Target ") for m in measures) else "kpi"


def _row_prefix(block: str) -> str:
    return TWIN_PREFIX if all(m.startswith(TWIN_PREFIX) for m in _row_measures(block)) else ""


def _switch_kind(table: str) -> str:
    return "budget" if "Budget" in table else "kpi"


def _measure_at(text: str, pos: int) -> str:
    names = [m.group(1) or m.group(2) for m in MEASURE_RE.finditer(text, 0, pos)]
    return names[-1].replace("''", "'") if names else ""


def list_blocks(text: str) -> list:
    """(measure name, "ROW kpi" | "ROW budget" | "SWITCH kpi" | "SWITCH budget") of every KPI list in the text."""
    found = [(m.start(), m.group(2).split(" ")[0] + " " + _row_kind(m.group(3))) for m in ROW_RE.finditer(text)]
    found += [(m.start(), "SWITCH " + _switch_kind(m.group(3))) for m in SWITCH_RE.finditer(text)]
    return [(_measure_at(text, pos), kind) for pos, kind in sorted(found)]


# The measures written whole from PARTS: (name, which part, the manual KPIs' part). A measure_guards.py wrapper stays.
PARTS_MEASURES = [
    ("BSC Numerator", 0, "CALCULATE ( SUM ( 'BSC Manual Values'[Numerator] ), Past, "
                         "KEEPFILTERS ( Branch[Is Hospital] = \"Yes\" ) )"),
    ("BSC Denominator", 1, "CALCULATE (\n"
                           "\tVAR Num = SUM ( 'BSC Manual Values'[Numerator] )\n"
                           "\tVAR Den = SUM ( 'BSC Manual Values'[Denominator] )\n"
                           "\t-- a denominator of 0 divides by outpatient and ER visits, as in BSC Manual Value\n"
                           "\tRETURN IF ( Den = 0 && NOT ISBLANK ( Num ), "
                           "CALCULATE ( [Census], REMOVEFILTERS ( 'BSC KPI' ) ), Den ),\n"
                           "\tPast,\n"
                           "\tKEEPFILTERS ( Branch[Is Hospital] = \"Yes\" )\n"
                           ")"),
]
PARTS_FORMAT = "#,0.##"  # up to two decimals, none for whole numbers (a count reads 1,234, a ratio's part 12.5)
BODY_START = "\t\t\tVAR __Value = ( -- measure body\n"
BODY_END = "\t\t\t) -- end of measure body\n"


def _entry(tabs: str, label: str, dax: str) -> list:
    """'<label>, <dax>,' on one line, or '<label>,' then the DAX lines one tab deeper."""
    lines = dax.split("\n")
    if len(lines) == 1:
        return [f"{tabs}{label}, {dax},"]
    return [f"{tabs}{label},"] + [f"{tabs}\t{line}" for line in lines[:-1]] + [f"{tabs}\t{lines[-1]},"]


def parts_body(which: int, manual: str, parts: dict, tabs: str) -> str:
    """Body of BSC Numerator (which = 0) or BSC Denominator (which = 1) at indentation `tabs`."""
    word = ("numerator", "denominator")[which]
    lines = [
        "VAR Code = SELECTEDVALUE ( 'BSC KPI'[KPI Code] )",
        "VAR KpiState = SELECTEDVALUE ( 'BSC KPI'[Status] )",
        "VAR Source = SELECTEDVALUE ( 'BSC KPI'[Value Source] )",
        "VAR Past = CALCULATETABLE ( VALUES ( 'Date'[Date] ), KEEPFILTERS ( 'Date'[Date] <= TODAY () ) )",
        f"-- the KPI's {word} (tools/bsc_kpi_parts.py) in the filter context BSC Actual gives the KPI's measure",
        "RETURN",
        "\tSWITCH (",
        "\t\tTRUE (),",
        "\t\tISBLANK ( Code ) || KpiState = \"parked\", BLANK (),",
    ]
    lines += _entry("\t\t", 'Source = "manual"', manual)
    lines += ["\t\tCALCULATE (", "\t\t\tSWITCH (", "\t\t\t\tCode,"]
    for code, part in parts.items():
        if part[which]:
            lines += _entry("\t\t\t\t", f'"{code}"', part[which])
    lines += ["\t\t\t\tBLANK ()", "\t\t\t),", "\t\t\tPast,", "\t\t\tREMOVEFILTERS ( 'BSC KPI' ),",
              "\t\t\tKEEPFILTERS ( Branch[Is Hospital] = \"Yes\" )", "\t\t)", "\t)"]
    return "".join(f"{tabs}{line}\n" for line in lines)


def _body_span(text: str, name: str):
    """(start, end, indentation) of the measure's body: inside its measure_guards.py wrapper, or its three-tab
    expression lines when it has none; None when the measure is missing."""
    declaration = f"\tmeasure '{name}' =\n"
    at = text.find(declaration)
    if at < 0:
        return None
    start = at + len(declaration)
    if text.startswith(BODY_START, start):
        start += len(BODY_START)
        return start, text.index(BODY_END, start), "\t\t\t\t"
    end = start
    while text.startswith("\t\t\t", end):
        end = text.index("\n", end) + 1
    return start, end, "\t\t\t"


def _set_format(text: str, name: str, fmt: str) -> str:
    """The text with the measure's formatString property set to `fmt`: an existing formatString line is replaced,
    else one is written as the first property, after the expression lines."""
    declaration = f"\tmeasure '{name}' =\n"
    at = text.find(declaration)
    if at < 0:
        return text
    pos = at + len(declaration)
    while text.startswith("\t\t\t", pos) or (text.startswith("\n", pos) and text.startswith("\t\t\t", pos + 1)):
        pos = text.index("\n", pos) + 1  # the expression lines (and blank lines between them)
    first = pos
    while text.startswith("\t\t", pos) and not text.startswith("\t\t\t", pos):
        end = text.index("\n", pos) + 1
        if text.startswith("\t\tformatString:", pos):
            return text[:pos] + f"\t\tformatString: {fmt}\n" + text[end:]
        pos = end
    return text[:first] + f"\t\tformatString: {fmt}\n" + text[first:]


def render_parts(text: str, parts: dict = PARTS) -> str:
    """The text with the bodies of BSC Numerator and BSC Denominator written from the parts, formatted
    PARTS_FORMAT."""
    for name, which, manual in PARTS_MEASURES:
        span = _body_span(text, name)
        if span:
            start, end, tabs = span
            text = text[:start] + parts_body(which, manual, parts, tabs) + text[end:]
            text = _set_format(text, name, PARTS_FORMAT)
    return text


def parts_blocks(text: str) -> list:
    """(measure name, KPI codes of its parts lookup) of BSC Numerator and BSC Denominator, when present."""
    found = []
    for name, _, _ in PARTS_MEASURES:
        span = _body_span(text, name)
        if span:
            lookup = re.search(r"SWITCH \(\n(\t*)Code,\n(.*?)\n\1BLANK \(\)", text[span[0]:span[1]], re.S)
            found.append((name, re.findall(rf'(?m)^{lookup.group(1)}"([^"]+)",', lookup.group(2)) if lookup else []))
    return found

def render(text: str, kpis: list = KPIS, budgets: list = BUDGETS, parts: dict = PARTS) -> str:
    """The text with every ROW list and SWITCH lookup rewritten from the KPI lists, and the parts measures from the
    parts."""
    def row(m):
        lines = budgets if _row_kind(m.group(3)) == "budget" else kpis
        prefix = _row_prefix(m.group(3))
        entries = ",\n".join(f'{m.group(1)}\t"@{code}", [{prefix}{measure}]' for code, measure in lines)
        return f"{m.group(1)}{m.group(2)}{entries}\n"

    def switch(m):
        tabs, table = m.group(1), m.group(3)
        lines = budgets if _switch_kind(table) == "budget" else kpis
        return f"{tabs}Code,\n" + "".join(f'{tabs}"{code}", MAXX ( {table}, [@{code}] ),\n' for code, _ in lines)

    return render_parts(SWITCH_RE.sub(switch, ROW_RE.sub(row, text)), parts)


def main() -> int:
    text = MEASURES_FILE.read_text(encoding="utf-8")
    new = render(text)
    if "--check" in sys.argv[1:]:
        if new != text:
            print("KPI lists out of date: run python ssas/tools/gen_bsc_kpi_lists.py")
            return 1
        return 0
    if new != text:
        MEASURES_FILE.write_text(new, encoding="utf-8", newline="\n")
    print(f"{len(list_blocks(new))} KPI lists in {MEASURES_FILE.name}: {len(KPIS)} KPIs, {len(BUDGETS)} budget targets; "
          f"{len(parts_blocks(new))} parts measures: {len(PARTS)} KPIs with parts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
