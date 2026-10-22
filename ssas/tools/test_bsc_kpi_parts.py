"""bsc_kpi_parts.PARTS: the numerator and denominator of every KPI actual (report plan, Task 2)."""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bsc_kpi_parts as p  # noqa: E402
import gen_bsc_kpi_lists as g  # noqa: E402

SSAS = Path(__file__).resolve().parents[1]
CHECKS = json.loads((SSAS / "tests" / "measures" / "balanced_scorecard.json").read_text(encoding="utf-8"))


def test_every_kpi_has_parts_or_a_reason():
    codes = [code for code, _ in g.KPIS]
    assert sorted(set(p.PARTS) | set(p.NO_PARTS)) == sorted(set(codes))
    assert set(p.PARTS) & set(p.NO_PARTS) == set()
    assert all(reason for reason in p.NO_PARTS.values())


def test_parts_have_a_kind_and_value_kpis_no_denominator():
    assert {kind for _, _, kind in p.PARTS.values()} <= {"ratio", "growth", "value"}
    assert all(num.strip() for num, _, _ in p.PARTS.values())
    assert [c for c, (_, den, kind) in p.PARTS.items() if (kind == "value") != (den == "")] == []


def test_readme_lists_the_kpis_without_parts():
    readme = (SSAS / "README.md").read_text(encoding="utf-8")
    assert [code for code in p.NO_PARTS if f"`{code}`" not in readme] == []


def test_rebuild_checks_use_the_parts_kinds():
    """The rebuild checks name the growth, value and no-parts KPIs; every other KPI (manual ones too) is a ratio."""
    rebuild = [c for c in CHECKS if c["name"].startswith("BSC Numerator and BSC Denominator rebuild BSC Actual")]
    assert len(rebuild) == 2
    want = {kind: sorted(c for c, (_, _, k) in p.PARTS.items() if k == kind) for kind in ("growth", "value")}
    want["none"] = sorted(p.NO_PARTS)
    for check in rebuild:
        lists = dict(re.findall(r'c IN \{([^}]*)\}, "(\w+)"', check["dax"]))
        assert {kind: sorted(re.findall(r'"([^"]+)"', codes)) for codes, kind in lists.items()} == want
