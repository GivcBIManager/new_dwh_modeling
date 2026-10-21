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
