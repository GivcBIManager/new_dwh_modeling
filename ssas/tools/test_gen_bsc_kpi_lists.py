"""The scorecard KPI lists in _Measures.tmdl are the generator's output (ssas/tools/gen_bsc_kpi_lists.py)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gen_bsc_kpi_lists as g  # noqa: E402

TEXT = g.MEASURES_FILE.read_text(encoding="utf-8")

SAMPLE = """\tmeasure 'X' =
\t\t\tVAR Measured =
\t\t\t\tCALCULATETABLE (
\t\t\t\t\tROW (
\t\t\t\t\t\t"@OLD", [BSC Old]
\t\t\t\t\t),
\t\t\t\t\tPast
\t\t\t\t)
\t\t\tVAR Budgeted =
\t\t\t\tCALCULATETABLE (
\t\t\t\t\tROW (
\t\t\t\t\t\t"@OLD", [BSC Target Old]
\t\t\t\t\t),
\t\t\t\t\tPast
\t\t\t\t)
\t\t\tRETURN
\t\t\t\tSWITCH (
\t\t\t\t\tCode,
\t\t\t\t\t"OLD", MAXX ( Measured, [@OLD] ),
\t\t\t\t\tBLANK ()
\t\t\t\t) + SWITCH (
\t\t\t\t\tCode,
\t\t\t\t\t"OLD", MAXX ( Budgeted, [@OLD] ),
\t\t\t\t\tBLANK ()
\t\t\t\t)
"""


def test_committed_measures_are_current():
    assert g.render(TEXT) == TEXT, "run python ssas/tools/gen_bsc_kpi_lists.py"


def test_render_rewrites_every_list_from_the_kpi_lists():
    out = g.render(SAMPLE, kpis=[("A", "BSC A"), ("B", "BSC B")], budgets=[("A", "BSC Target A")])
    assert '\t\t\t\t\t\t"@A", [BSC A],\n\t\t\t\t\t\t"@B", [BSC B]\n\t\t\t\t\t),' in out
    assert '\t\t\t\t\t\t"@A", [BSC Target A]\n\t\t\t\t\t),' in out
    assert '\t\t\t\t\t"A", MAXX ( Measured, [@A] ),\n\t\t\t\t\t"B", MAXX ( Measured, [@B] ),\n\t\t\t\t\tBLANK ()' in out
    assert '\t\t\t\t\t"A", MAXX ( Budgeted, [@A] ),\n\t\t\t\t\tBLANK ()' in out
    assert "OLD" not in out


def test_every_list_holding_measure_is_rewritten():
    blocks = g.list_blocks(TEXT)
    names = {name for name, _ in blocks}
    assert names == {"BSC Actual", "BSC Target", "BSC Variance %", "BSC Score", "BSC State", "BSC Visual Payload",
                     "BSC Visual Payload Scores"}


TWIN_SAMPLE = """\tmeasure 'Y' =
\t\t\tVAR Measured =
\t\t\t\tCALCULATETABLE (
\t\t\t\t\tROW (
\t\t\t\t\t\t"@OLD", [_Unguarded BSC Old]
\t\t\t\t\t),
\t\t\t\t\tPast
\t\t\t\t)
\t\t\tVAR MeasuredMonths =
\t\t\t\tCALCULATETABLE (
\t\t\t\t\tADDCOLUMNS (
\t\t\t\t\t\tVALUES ( 'Date'[Year Month] ),
\t\t\t\t\t\t"@OLD", [_Unguarded BSC Old]
\t\t\t\t\t),
\t\t\t\t\tPast
\t\t\t\t)
\t\t\tVAR Budgeted =
\t\t\t\tCALCULATETABLE (
\t\t\t\t\tROW (
\t\t\t\t\t\t"@OLD", [_Unguarded BSC Target Old]
\t\t\t\t\t),
\t\t\t\t\tPast
\t\t\t\t)
\t\t\tRETURN 1
"""


def test_render_keeps_unguarded_twins_and_rewrites_the_monthly_list():
    out = g.render(TWIN_SAMPLE, kpis=[("A", "BSC A"), ("B", "BSC B")], budgets=[("A", "BSC Target A")])
    assert out.count('\t\t\t\t\t\t"@A", [_Unguarded BSC A],\n\t\t\t\t\t\t"@B", [_Unguarded BSC B]\n\t\t\t\t\t),') == 2
    assert "\t\t\t\t\tADDCOLUMNS (\n\t\t\t\t\t\tVALUES ( 'Date'[Year Month] ),\n\t\t\t\t\t\t\"@A\", [_Unguarded BSC A]," in out
    assert '\t\t\t\t\t\t"@A", [_Unguarded BSC Target A]\n\t\t\t\t\t),' in out
    assert "OLD" not in out
    assert [kind for _, kind in g.list_blocks(TWIN_SAMPLE)] == ["ROW kpi", "ADDCOLUMNS kpi", "ROW budget"]


# BSC Numerator / BSC Denominator (report plan, Task 2): their bodies are written from bsc_kpi_parts.PARTS.
PARTS_SAMPLE = """\tmeasure 'BSC Numerator' =
\t\t\tVAR __Value = ( -- measure body
\t\t\t\tBLANK ()
\t\t\t) -- end of measure body
\t\t\tVAR __Wrong = [_Guard x]
\t\t\tRETURN IF ( __Wrong = "", __Value, "x" & __Wrong )
\t\tdisplayFolder: Balanced Scorecard\\Scoring

\tmeasure 'BSC Denominator' =
\t\t\tBLANK ()
\t\tformatString: #,0.00
\t\tdisplayFolder: Balanced Scorecard\\Scoring
"""
PARTS = {"A": ("[N A]", "[D A]", "ratio"), "B": ("SUMX (\n\tVALUES ( T[c] ),\n\t[N B]\n)", "", "value"),
         "G": ("[N G]", "[D G]", "growth")}


def test_committed_numerator_and_denominator_are_current():
    assert g.render(TEXT) == TEXT
    assert {name for name, _ in g.parts_blocks(TEXT)} == {"BSC Numerator", "BSC Denominator"}


def test_render_writes_numerator_and_denominator_from_the_parts():
    out = g.render(PARTS_SAMPLE, kpis=[], budgets=[], parts=PARTS)
    num, den = out.split("\tmeasure 'BSC Denominator' =")
    # wrapped body one tab deeper than an unwrapped one; the guard lines stay
    assert '\t\t\t\t\t\t\t\t"A", [N A],\n' in num and '\t\t\t\t\t\t\t\t"G", [N G],\n' in num
    assert '\t\t\t\t\t\t\t\t"B",\n\t\t\t\t\t\t\t\t\tSUMX (\n\t\t\t\t\t\t\t\t\t\tVALUES ( T[c] ),\n' in num
    assert "VAR __Wrong = [_Guard x]" in num and "\t\t\t\t\t)\n\t\t\t) -- end of measure body" in num
    assert "SUM ( 'BSC Manual Values'[Numerator] )" in num
    assert '\t\t\t\t\t\t\t"A", [D A],\n' in den and '"G", [D G],' in den and '"B"' not in den
    assert "SUM ( 'BSC Manual Values'[Denominator] )" in den and "[Census]" in den
    for body in (num, den):
        assert "ISBLANK ( Code ) || KpiState = \"parked\", BLANK ()" in body
        assert "REMOVEFILTERS ( 'BSC KPI' )" in body and "KEEPFILTERS ( Branch[Is Hospital] = \"Yes\" )" in body
        assert "KEEPFILTERS ( 'Date'[Date] <= TODAY () )" in body
    assert g.render(out, kpis=[], budgets=[], parts=PARTS) == out
    assert [codes for _, codes in g.parts_blocks(out)] == [["A", "B", "G"], ["A", "G"]]


def test_numerator_and_denominator_format():
    """Up to two decimals, none shown for whole numbers (#,0.##): a count numerator reads 1,234, a ratio's 12.5."""
    out = g.render(PARTS_SAMPLE, kpis=[], budgets=[], parts=PARTS)
    num, den = out.split("\tmeasure 'BSC Denominator' =")
    for body in (num, den):
        assert body.count("\t\tformatString: #,0.##\n") == 1 and "#,0.00" not in body
        assert "\t\tformatString: #,0.##\n\t\tdisplayFolder: Balanced Scorecard\\Scoring" in body
    for name in ("BSC Numerator", "BSC Denominator"):
        block = TEXT.split(f"\tmeasure '{name}' =\n", 1)[1].split("\n\tmeasure ", 1)[0]
        assert "\t\tformatString: #,0.##\n" in block, name
