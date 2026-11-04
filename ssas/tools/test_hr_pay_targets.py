"""A pay KPI's target and watch value are pay levels (its placeholder is the KPI's own Jan-Sep level), so every measure
that reads a target or watch value hides it from a viewer without pay access (HR dashboard final review C1).

The measure checks in ssas/tests/measures/hr_dashboard.json run as an administrator, who has pay access; this test
checks the no-pay path in the measure text, and test.ps1 -Stage Security runs it as the no-pay test users."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MEASURES = {m.name: m for m in t.measures(
    (ROOT / "ssas" / "HNH_Analytics" / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8"))}

# What a target-derived measure reads: the target and watch columns, or a measure that returns them.
TARGET_SOURCES = re.compile(r"'HR Targets'\[(Target|Watch) Value\]|\[HR KPI (Fixed )?(Target|Watch)\]|\[HR KPI Variance\]")
NO_PAY = re.compile(r"(MAX|SELECTEDVALUE) \( 'HR KPI'\[Needs Pay\] \) = 1 && \[HR Can See Pay\] = 0"
                    r"|NeedsPay = 1 && \[HR Can See Pay\] = 0")
NUMBERS = ["HR KPI Fixed Target", "HR KPI Fixed Watch", "HR KPI Target", "HR KPI Watch", "HR KPI Variance"]
TEXTS = ["HR KPI Target Text", "HR KPI Watch Text", "HR KPI Variance Text", "HR KPI Actual Text", "HR KPI Pay Notice"]


def _body(name: str) -> str:
    return t._DAX_COMMENT.sub("", MEASURES[name].expression)


def _reads(name: str) -> str:
    """The measure's DAX less its REMOVEFILTERS ( ... ) lists (which name the HR Targets columns without reading them)."""
    return re.sub(r"REMOVEFILTERS \([^()]*\)", "", _body(name))


def test_every_target_reader_checks_pay():
    readers = sorted(name for name in MEASURES if not name.startswith("_") and TARGET_SOURCES.search(_reads(name)))
    assert set(NUMBERS[1:] + TEXTS[:3] + ["HR KPI Status"]) <= set(readers)
    assert [name for name in readers if not NO_PAY.search(_body(name))] == []


def test_numbers_are_blank_without_pay():
    for name in NUMBERS:
        body = _body(name)
        assert NO_PAY.search(body), name
        # the no-pay branch returns blank: "<check>, BLANK ()" in a SWITCH, or IF ( NOT NoPay, ... ) with no else
        assert re.search(r"\[HR Can See Pay\] = 0, BLANK \(\)", body) or re.search(r"IF \(\s*NOT NoPay", body), name


def test_texts_say_requires_pay_access():
    for name in TEXTS:
        body = _body(name)
        assert NO_PAY.search(body) or "SELECTEDVALUE ( 'HR KPI'[Needs Pay] ) = 1 && [HR Can See Pay] = 0" in body, name
        assert re.search(r'\[HR Can See Pay\] = 0,?\s*"Requires pay access"', body), name


def test_pay_check_comes_before_not_set():
    """The text measures test pay access before a blank target, so a no-pay viewer never reads Not set or –."""
    for name in ["HR KPI Target Text", "HR KPI Watch Text", "HR KPI Variance Text"]:
        body = _body(name)
        pay = body.index('"Requires pay access"')
        blank = min(i for i in (body.find('"Not set"'), body.find('"–"')) if i >= 0)
        assert pay < blank, name


def test_readers_role_hides_pay_target_rows():
    """User decision 2026-11-04: the hidden target and watch columns are readable through Excel or DAX, so the
    HNH Readers role also filters the HR Targets rows of a pay KPI to readers with Can See Pay."""
    role = (ROOT / "ssas" / "HNH_Analytics" / "roles" / "HNH Readers.tmdl").read_text(encoding="utf-8")
    block = re.search(r"tablePermission 'HR Targets' =(.*?)(?=\n\ttablePermission |\Z)", role, re.S)
    assert block, "HNH Readers has no row filter on 'HR Targets'"
    expression = " ".join(block.group(1).split())
    assert "RELATED ( 'HR KPI'[Needs Pay] ) = 0 ||" in expression
    assert "'User Access'[Login Name] = USERPRINCIPALNAME ()" in expression
    assert "'User Access'[Can See Pay] = 1" in expression
