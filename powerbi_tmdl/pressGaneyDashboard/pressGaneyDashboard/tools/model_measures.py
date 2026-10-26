"""The model's Patient Experience measures, read from the repository's TMDL (ssas/HNH_Analytics).

- `perspective_measure_names()`: every measure the `Patient Experience` perspective lists (the live connection exposes
  these), so the report can be built before the model is deployed.
- `define_block()`: a DAX `DEFINE` block with the query-scoped copy of every Patient Experience measure, without the
  guard wrappers, so tools/smoke_test_visuals.ps1 can run the visuals' queries against a database that does not hold
  the measures yet (or holds an older version).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
SSAS = REPO / "ssas"
PERSPECTIVE = SSAS / "HNH_Analytics" / "perspectives" / "Patient Experience.tmdl"
MEASURES = SSAS / "HNH_Analytics" / "tables" / "_Measures.tmdl"
DOMAIN = "Patient Experience"

sys.path.insert(0, str(SSAS / "tools"))
import hnh_tmdl as t  # noqa: E402
import measure_guards  # noqa: E402


def perspective_measure_names() -> set[str]:
    names = set()
    for line in PERSPECTIVE.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\t\tperspectiveMeasure (.+)$", line)
        if m:
            names.add(t._object_name(m.group(1).strip()))
    return names


def domain_measures() -> list:
    """The Patient Experience measures (hnh_tmdl.Measure, expression without the guard wrapper)."""
    text = measure_guards.strip_guards(MEASURES.read_text(encoding="utf-8"))
    return [m for m in t.measures(text) if m.folder.split("\\")[0] == DOMAIN]


def define_block() -> str:
    """Every Patient Experience measure, plus an _Unguarded twin of every measure the domain references that way
    (the same expression without a guard, as measure_guards.py writes it)."""
    measures = {m.name: m for m in t.measures(measure_guards.strip_guards(MEASURES.read_text(encoding="utf-8")))}
    lines, twins, pending = [], set(), []
    for m in domain_measures():
        lines.append(f"MEASURE _Measures[{m.name}] =\n{m.expression}")
        for n in t.dax_references(m.expression)[1]:
            if n.startswith(measure_guards.TWIN_PREFIX) and n not in twins:
                twins.add(n)
                pending.append(n)
    while pending:
        twin = pending.pop()
        source = measures[twin[len(measure_guards.TWIN_PREFIX):]]
        lines.append(f"MEASURE _Measures[{twin}] =\n{source.expression}")
        for n in t.dax_references(source.expression)[1]:
            if n.startswith(measure_guards.TWIN_PREFIX) and n not in twins:
                twins.add(n)
                pending.append(n)
    return "DEFINE\n" + "\n".join(lines) + "\n"


if __name__ == "__main__":
    names = perspective_measure_names()
    print(f"{len(names)} measures in the Patient Experience perspective, {len(domain_measures())} in the domain")
