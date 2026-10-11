# SSAS KPI Catalogue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the full KPI catalogue of SSAS spec 8.1 to `HNH_Analytics`. That is 161 measures on top of the 16 starter measures, each checked against ClickHouse. The six KPIs that need a gold change are listed under "Deferred KPIs".

**Architecture:** Every measure is hand-written TMDL in `ssas/HNH_Analytics/tables/_Measures.tmdl` (decision P26), one domain per task. Each domain first gets its DAX-vs-SQL checks in `ssas/tests/measures/<domain>.json`. An offline catalogue test (`ssas/tools/test_measure_catalogue.py`) then fails until the measures exist. It also keeps every measure documented, foldered, formatted, referencing real columns, checked, listed in its perspective and, for snapshots, excluded from period-to-date time items. A new `deploy.ps1 -Stage TestMeasures` puts the metadata on the processed test database and runs the measure checks, so no domain needs a full reprocess.

**Tech Stack:** TMDL / DAX at compatibility level 1700 (SQL Server 2025 Analysis Services 17.0.25.218), Tabular Editor 2.27 (Best Practice Analyzer, CLI deploy), Python 3.12 + pytest (`C:\Program Files\Python312`), Windows PowerShell 5.1 + Pester 3.4, ClickHouse 26.5 through the system DSN `HNH_Gold`.

**Spec:** `docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md` section 8 (catalogue, rules, calculation group) and decisions P12, P13, P19, P20, P26. The KPI sources are: the "KPI definitions" sections of the eight specs in `docs/superpowers/specs/` and "Notes for the SSAS model" in `docs/receiving_project_config.md`.

**Branch:** work on `ssas-kpi-catalogue` (create it from `main` before Task 1); `main` is the deployed model.

## Global Constraints

- Work happens on HNHANALYTICSSRV, the production server (`CLAUDE.md`). **Ask the user before every run of `deploy.ps1`, `process.ps1` or `partitions.ps1`** (without `-DryRun`), and before anything that writes to SSAS or ClickHouse. Offline work needs no confirmation: pytest, Pester, the Best Practice Analyzer, and `SELECT`s through the DSN.
- Every measure lives in table `_Measures`, display folder `<domain>\<topic>`. The domain is one of `Patient Flow`, `Revenue Cycle`, `Claims & Pre-auth`, `Finance`, `Workforce`, `Supply Chain`, `Patient Experience`, `Diagnostics` (P26).
- Every measure has a `///` description, a `displayFolder`, and a `formatString` or `formatStringDefinition` (BPA rules `HNH_DESCRIPTIONS`, `HNH_MEASURE_FORMAT_FOLDER`).
- Formats (spec 8.2.7): SAR `#,0`; percentages `0.0%`; counts `#,0`; durations `#,0.0` with the unit in the measure name. Unit prices and ratios that are not percentages use `#,0.00`.
- Spec 8.2.1: base measures are `SUM`/`COUNTROWS` with column filters inside `CALCULATE` (`KEEPFILTERS` where the filter must intersect the user's selection).
- Spec 8.2.1 / BPA `HNH_NO_ITERATOR_OVER_LARGE_FACT`: no `FILTER(<fact>, …)` and no `SUMX`/`AVERAGEX`/`COUNTX`/`MINX`/`MAXX` over Charge Lines, Order Lines, Stock Movements, Patient Consumption, Claim Lines, Cash Receipts, GL Journal Lines, Pre-auth Lines, Encounters, Episodes, Invoices, Bed Occupancy, Episode Billing, Clinic Capacity, Targets or Payroll. Iterating `VALUES` of a dimension column, or `FILTER(ALL(<one column>), …)`, is allowed.
- Spec 8.2.2: no `DISTINCTCOUNT` on a fact above 20M rows. It is allowed on facts under 10M rows (Encounters 5.8M, Pre-auth Lines 6.9M) and on keys under 1M distinct values.
- Spec 8.2.3: ratios use `DIVIDE` and reuse base measures where one exists.
- Spec 8.2.4 / P20: snapshot measures take the last period **per branch** and add the branches. Every snapshot measure carries `annotation hnh_snapshot = 1`, and its name is in all five `ISSELECTEDMEASURE` lists of `tables/Time Calculation.tmdl` (MTD, QTD, YTD, PY YTD, Rolling 12M).
- Receiving notes are measure rules. Visit KPIs use `Encounter Type IN {"OP","ER"}`. Claim KPIs use `Is Latest Submission = "Yes"` and `Is Cancelled Claim = "No"`, except first-pass. Pre-auth KPIs exclude `Line Source = "Payer advance"`. Finance multiplies by `'FS Line'[Display Sign]` and defaults to `Balance View = "posted"`. Payroll sums `Cost Amount`/`Gross Pay`, never `Amount`. NPS is labelled "(5-point)" and shows "insufficient sample" when n < 30. Absence and leave stop at today (`'Date'[Is Past] = "Yes"`).
- Measure checks: `ssas/tests/measures/<domain>.json`, entries `{name, tolerance, dax, sql[, allow_zero]}`. SAR sums have tolerance 0.01, counts 0, ratios and averages 0.0001 (0.001 for the target ALOS identity). A median in SQL is `quantileExactInclusive(0.5)(toFloat64(x))`, which equals DAX `MEDIAN`.
- TMDL is indented with **tabs**: measure at one tab, properties at two, expression lines at three, format-string-expression lines at four. Insert each domain's block immediately before the line `	column Measure` of `_Measures.tmdl`, separated by one blank line.
- Windows PowerShell 5.1 syntax only (no ternary, `??`, `&&`/`||`). Never echo a password.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A check passes when both sides are blank.** `Get-HnhScalar` turns BLANK into 0, so a measure that is wrong everywhere passes against a SQL query that is also empty. Expected: a check fails when both values are 0, unless it sets `"allow_zero": true` because blank is the intended answer. Pinned in Task 2 (test.ps1 guard). The `allow_zero` checks in Tasks 4, 5 and 6 are the only ones allowed to be blank.
2. **Defaults must give way to the user's choice.** Order-fulfilment measures default to `Is Inpatient = "No"`, and targets to `Scenario = "most_likely"`. A user who selects the other value must get that value, not the default or the sum of both. Pre-auth measures exclude payer advances with `KEEPFILTERS`, so selecting "Payer advance" gives 0 services, not every service. Pinned by the "inpatient", "worst case" and "payer advance slice" checks in Tasks 3, 4 and 5.
3. **A snapshot must not be summed over months.** YTD or Rolling 12M of a balance must equal the month-end value. Expected: every snapshot measure is in the five Time Calculation lists. Pinned by `test_snapshot_lists_match_the_snapshot_measures` (Task 1) and by YTD checks in Tasks 6, 7 and 8.
4. **A multi-branch total of a per-branch snapshot or ratio** (Days of Stock, Leave Balance) must add the branches' numerators and denominators. Averaging branch ratios or using one group-wide last month is wrong (P20). Pinned by all-branch checks in Tasks 7 and 8.
5. **Values that are meaningless at a total must be blank.** An income-statement sum across budget codes, a median of days to payment over more than one payment month, and a last PO price over several items should show blank, not a number. Pinned by the `allow_zero` blank checks in Tasks 5, 6 and 8.

## Deferred KPIs (need a gold or view change; not in this plan)

| KPI | Source | Why it cannot be a measure now | What would make it possible |
|---|---|---|---|
| Orders | order fulfilment §8 | distinct `order_key`; `order_key` dropped from the view (P16), 22.7M values on 58.8M rows (rule 8.2.2) | a gold aggregate at order grain, or an order-level flag table |
| Census (order lines) | order fulfilment §8 | distinct `episode_key` over 58.8M rows (rule 8.2.2); `episode_key` dropped from the view | an `agg_order_episode_category` aggregate |
| Contribution | order fulfilment §8 | episodes with a category ÷ episodes: same distinct count | the same aggregate |
| Paid headcount | Phase 4 §7, receiving notes | `paid_person_key` (10,342 values, allowed by rule 8.2.2) is dropped from `ssas_fact_payroll_monthly` | keep `paid_person_key` in the view (dbt change + contract + generate.py), then `DISTINCTCOUNT` |
| Near-expiry stock | Phase 5 §7 | stock on hand by lot is not in gold (`fact_stock_monthly` has only `has_expired_lot`) | a lot-level stock snapshot in gold |
| ABC class | Phase 5 §7 | an item attribute, not a measure (users slice by it) | an item-by-branch ABC column from `hnh_abc_class` |

Balance last year, change and change % (Phase 3 §8) are not separate measures. They are the Time Calculation items **PY**, **YoY Δ** and **YoY %** applied to the balance measures; YoY % already divides by the absolute prior value and is blank without one.

## File Structure

```
ssas/tools/hnh_tmdl.py                     Task 1  + Measure, measures(), dax_references(), snapshot_lists(),
                                                     table_columns(), replace_perspective_measures()
ssas/tools/test_hnh_tmdl.py                Task 1  unit tests of the new helpers
ssas/tools/sync_perspectives.py            Task 1  rewrites the _Measures block of each perspective, offline
ssas/tools/test_measure_catalogue.py       Task 1  offline checks of the whole catalogue (reads the model files)
ssas/scripts/test.ps1                      Task 2  a check where both values are 0 fails unless allow_zero
ssas/scripts/deploy.ps1                    Task 2  -Stage TestMeasures
ssas/README.md                             Tasks 2, 10
ssas/HNH_Analytics/tables/_Measures.tmdl   Tasks 1, 3-9  the measures
ssas/HNH_Analytics/tables/Time Calculation.tmdl   Tasks 6-8  snapshot lists
ssas/HNH_Analytics/perspectives/*.tmdl     Tasks 3-9  regenerated by sync_perspectives.py
ssas/tests/measures/<domain>.json          Tasks 3-9  checks: patient_flow, revenue_cycle, claims_preauth, finance,
                                                     workforce, supply_chain, patient_experience
docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md   Task 10  decisions P28-P36
```

Tasks 3–9 are cumulative: each one appends to `_Measures.tmdl`, and Tasks 6–8 extend the same snapshot list. Run them in order.

---

### Task 1: Catalogue helpers, perspective sync and the catalogue test

**Files:**
- Modify: `ssas/tools/hnh_tmdl.py` (imports; new helpers after `render_perspective`)
- Modify: `ssas/tools/test_hnh_tmdl.py` (append tests)
- Create: `ssas/tools/sync_perspectives.py`
- Create: `ssas/tools/test_measure_catalogue.py`
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl` (annotate the three starter snapshot measures)

**Interfaces:**
- Produces, in `hnh_tmdl`:
  - `Measure` (dataclass: `name: str`, `description: str`, `folder: str`, `format_string: str`, `format_expression: str`, `expression: str`, `annotations: dict`)
  - `measures(text: str) -> list[Measure]`
  - `dax_references(dax: str) -> tuple[set[tuple[str, str]], set[str]]`, returning `({(table, column)}, {measure})`
  - `snapshot_lists(text: str) -> list[list[str]]`
  - `table_columns(text: str) -> tuple[str, set[str]]`
  - `replace_perspective_measures(text: str, measures: list[str]) -> str`
- Produces: `python ssas/tools/sync_perspectives.py` (no arguments) and `ssas/tools/test_measure_catalogue.py`, which every later task runs.

- [ ] **Step 1: Write the failing unit tests**

Append to `ssas/tools/test_hnh_tmdl.py` (it already defines `MEASURES_TMDL`):

```python
SNAPSHOT_TMDL = (
    "\t/// Stock value.\n"
    "\tmeasure 'Stock Value' = 1\n"
    "\t\tformatString: #,0\n"
    "\t\tdisplayFolder: Supply Chain\\Stock\n"
    "\n"
    "\t\tannotation hnh_snapshot = 1\n"
)


def test_measures_reads_descriptions_properties_annotations_and_dax():
    found = t.measures(MEASURES_TMDL + SNAPSHOT_TMDL)
    assert [m.name for m in found] == ["Revenue", "Hospital NPS (5-point)", "Current User", "Stock Value"]
    revenue, nps, user, stock = found
    assert (revenue.description, revenue.folder, revenue.format_string) == ("Revenue.", "Revenue Cycle\\Revenue", "#,0")
    assert revenue.expression == "SUM ( 'Charge Lines'[Revenue Amount] )"
    assert nps.description == ""
    assert nps.expression == "VAR x = 1\nRETURN x"
    assert nps.format_expression == '"0.0"'
    assert user.expression == "USERPRINCIPALNAME ()"
    assert stock.annotations == {"hnh_snapshot": "1"}
    assert revenue.annotations == {}


def test_dax_references_skip_strings_comments_and_addcolumns_names():
    columns, names = t.dax_references(
        "CALCULATE ( [OP Visits], 'Date'[Year] = 2026, Branch[Branch Key] = 1 ) -- [Not A Measure]\n"
        "+ SUMX ( ADDCOLUMNS ( VALUES ( 'Date'[Year Month] ), \"@Fte\", [FTE] ), [@Fte] ) & \"[text]\""
    )
    assert columns == {("Date", "Year"), ("Branch", "Branch Key"), ("Date", "Year Month")}
    assert names == {"OP Visits", "FTE"}


def test_snapshot_lists_read_names_with_parentheses():
    text = (
        "IF ( ISSELECTEDMEASURE ( [Headcount], [GL Closing Balance (incl. Unposted)] ), x )\n"
        "IF ( ISSELECTEDMEASURE ( [Stock Value] ), y )"
    )
    assert t.snapshot_lists(text) == [["Headcount", "GL Closing Balance (incl. Unposted)"], ["Stock Value"]]


def test_table_columns():
    assert t.table_columns(MEASURES_TMDL) == ("_Measures", {"Measure"})


def test_replace_perspective_measures_matches_render_perspective():
    bare = t.render_perspective("Finance", ["GL Balances"])
    one = t.render_perspective("Finance", ["GL Balances"], ["Current User"])
    two = t.render_perspective("Finance", ["GL Balances"], ["Current User", "GL Movement"])
    assert t.replace_perspective_measures(one, ["Current User", "GL Movement"]) == two
    assert t.replace_perspective_measures(bare, ["Current User"]) == one
    assert t.replace_perspective_measures(two, []) == bare
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m pytest ssas/tools/test_hnh_tmdl.py -q`
Expected: 5 failures with `AttributeError: module 'hnh_tmdl' has no attribute 'measures'` (and the same for the other helpers).

- [ ] **Step 3: Implement the helpers**

In `ssas/tools/hnh_tmdl.py`, change the import `from dataclasses import dataclass` to:

```python
from dataclasses import dataclass, field
```

Append after `render_perspective` (before `render_model`):

```python
@dataclass
class Measure:
    """One measure of a table file, as the measure catalogue test reads it."""
    name: str
    description: str = ""
    folder: str = ""
    format_string: str = ""
    format_expression: str = ""
    expression: str = ""
    annotations: dict = field(default_factory=dict)


def _declaration_rest(text: str, name: str) -> str:
    """What follows the object name in a declaration remainder (the counterpart of _object_name)."""
    size = len(name) + name.count("'") + 2 if text.startswith("'") else len(name)
    return text[size:]


def measures(text: str) -> list[Measure]:
    """Every measure of a table file in file order, with its /// description, display folder, format string or format
    string expression, annotations and DAX expression."""
    found, description, current, target = [], [], None, "expression"
    for line in text.splitlines():
        if line.startswith("\t///"):
            description.append(line[len("\t///"):].strip())
            continue
        if line.startswith("\tmeasure "):
            declaration = line[len("\tmeasure "):]
            name = _object_name(declaration)
            expression = _declaration_rest(declaration, name).strip().lstrip("=").strip()
            current = Measure(name, " ".join(description), expression=expression)
            found.append(current)
            description, target = [], "expression"
            continue
        if line.startswith("\t") and not line.startswith("\t\t") and line.strip():
            current, description = None, []
            continue
        if current is None or not line.strip():
            continue
        if line.startswith("\t\t") and not line.startswith("\t\t\t"):
            body = line.strip()
            if body.startswith("formatStringDefinition"):
                target = "format_expression"
                current.format_expression = body.partition("=")[2].strip()
            elif body.startswith("annotation "):
                key, _, value = body[len("annotation "):].partition("=")
                current.annotations[key.strip()] = value.strip()
            elif body.startswith("formatString:"):
                current.format_string = body.partition(":")[2].strip()
            elif body.startswith("displayFolder:"):
                current.folder = body.partition(":")[2].strip()
            continue
        setattr(current, target, (getattr(current, target) + "\n" + line.strip()).strip())
    return found


_DAX_STRING = re.compile(r'"(?:[^"]|"")*"')
_DAX_COMMENT = re.compile(r"(?:--|//)[^\n]*")
_DAX_COLUMN = re.compile(r"(?:'((?:[^']|'')+)'|(?<![\w'\]])([A-Za-z_][A-Za-z0-9_]*))\[([^\]]+)\]")
_DAX_MEASURE = re.compile(r"\[([^\]]+)\]")


def dax_references(dax: str) -> tuple[set, set]:
    """({(table, column)}, {measure}) referenced by a DAX expression. String literals and comments are ignored, and
    ADDCOLUMNS names (written [@name]) are not measures."""
    text = _DAX_COMMENT.sub("", _DAX_STRING.sub('""', dax))
    columns = {(quoted.replace("''", "'") if quoted else bare, column)
               for quoted, bare, column in _DAX_COLUMN.findall(text)}
    names = {name for name in _DAX_MEASURE.findall(_DAX_COLUMN.sub(" ", text)) if not name.startswith("@")}
    return columns, names


def snapshot_lists(text: str) -> list[list[str]]:
    """The measure names of every ISSELECTEDMEASURE ( [a], [b], ... ) call, in file order (Time Calculation)."""
    calls = re.findall(r"ISSELECTEDMEASURE\s*\(\s*((?:\[[^\]]+\]\s*,?\s*)+)\)", text)
    return [re.findall(r"\[([^\]]+)\]", call) for call in calls]


def table_columns(text: str) -> tuple[str, set]:
    """(table name, {column name}) of a table file."""
    table = _object_name(re.search(r"^table (.+)$", text, re.M).group(1))
    return table, {_object_name(found) for found in re.findall(r"^\tcolumn (.+)$", text, re.M)}


def replace_perspective_measures(text: str, measures: list[str]) -> str:
    """A perspective file with its measure-table block replaced by `measures` (the layout of render_perspective)."""
    head = text.split(f"\n\n\tperspectiveTable {q(MEASURE_TABLE)}\n", 1)[0].rstrip("\n")
    if not measures:
        return head + "\n"
    return head + f"\n\n\tperspectiveTable {q(MEASURE_TABLE)}\n" + "".join(
        f"\t\tperspectiveMeasure {q(m)}\n" for m in measures)
```

- [ ] **Step 4: Run the unit tests to verify they pass**

Run: `python -m pytest ssas/tools/test_hnh_tmdl.py -q`
Expected: all pass (22 existing + 5 new = 27).

- [ ] **Step 5: Write the perspective sync script**

Create `ssas/tools/sync_perspectives.py`:

```python
"""Rewrite the _Measures block of every perspective from tables/_Measures.tmdl, without ClickHouse (KPI catalogue plan).
generate.py writes the same blocks when it regenerates the whole model.

Usage: python ssas/tools/sync_perspectives.py
"""
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import hnh_tmdl as t  # noqa: E402
import model_config as cfg  # noqa: E402

MODEL_DIR = TOOLS.parents[1] / "ssas" / "HNH_Analytics"


def main():
    folders = t.measure_folders((MODEL_DIR / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8"))
    for name in cfg.PERSPECTIVES:
        path = MODEL_DIR / "perspectives" / f"{name}.tmdl"
        text = path.read_text(encoding="utf-8")
        new = t.replace_perspective_measures(text, t.perspective_measures(name, folders, cfg.PERSPECTIVE_MEASURE_DOMAINS))
        if new != text:
            path.write_text(new, encoding="utf-8", newline="\n")
            print(f"updated {path.name}")


if __name__ == "__main__":
    main()
```

Run: `python ssas/tools/sync_perspectives.py`
Expected: no output (the generated perspectives already match the 16 starter measures), and `git status` shows no perspective change.

- [ ] **Step 6: Write the catalogue test**

Create `ssas/tools/test_measure_catalogue.py`:

```python
"""Offline checks of the measure catalogue (KPI catalogue plan). Every measure in tables/_Measures.tmdl is documented,
foldered and formatted, references columns and measures that exist, and is covered by a DAX-vs-ClickHouse check in
ssas/tests/measures/*.json. The Time Calculation snapshot lists and the perspectives must agree with the measure file."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402
import model_config as cfg  # noqa: E402

SSAS = Path(__file__).resolve().parents[1]
MODEL = SSAS / "HNH_Analytics"
DOMAINS = {"Patient Flow", "Revenue Cycle", "Claims & Pre-auth", "Finance", "Workforce", "Supply Chain",
           "Patient Experience", t.DIAGNOSTICS}
MEASURES_TEXT = (MODEL / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8")
MEASURES = t.measures(MEASURES_TEXT)
NAMES = {m.name for m in MEASURES}
COLUMNS = dict(t.table_columns(path.read_text(encoding="utf-8")) for path in (MODEL / "tables").glob("*.tmdl"))
CHECKS = [check for path in sorted((SSAS / "tests" / "measures").glob("*.json"))
          for check in json.loads(path.read_text(encoding="utf-8"))]


def unknown_references(dax):
    columns, names = t.dax_references(dax)
    bad = [f"{table}[{column}]" for table, column in sorted(columns) if column not in COLUMNS.get(table, set())]
    return bad + [f"[{name}]" for name in sorted(names - NAMES)]


def test_every_measure_has_a_description_folder_and_format():
    bad = [m.name for m in MEASURES
           if not m.description or not m.folder or not (m.format_string or m.format_expression)]
    assert bad == []


def test_every_folder_starts_with_a_domain():
    assert [m.name for m in MEASURES if m.folder.split("\\")[0] not in DOMAINS] == []


def test_measure_names_are_unique():
    names = [m.name for m in MEASURES]
    assert sorted({n for n in names if names.count(n) > 1}) == []


def test_measures_reference_existing_columns_and_measures():
    bad = {m.name: unknown_references(m.expression + "\n" + m.format_expression) for m in MEASURES}
    assert {name: refs for name, refs in bad.items() if refs} == {}


def test_checks_reference_existing_columns_and_measures():
    bad = {c["name"]: unknown_references(c["dax"]) for c in CHECKS}
    assert {name: refs for name, refs in bad.items() if refs} == {}


def test_every_measure_has_a_check():
    checked = set().union(*(t.dax_references(c["dax"])[1] for c in CHECKS))
    assert sorted(m.name for m in MEASURES if m.folder != t.DIAGNOSTICS and m.name not in checked) == []


def test_check_names_are_unique():
    names = [c["name"] for c in CHECKS]
    assert sorted({n for n in names if names.count(n) > 1}) == []


def test_snapshot_lists_match_the_snapshot_measures():
    snapshots = sorted(m.name for m in MEASURES if m.annotations.get("hnh_snapshot") == "1")
    lists = t.snapshot_lists((MODEL / "tables" / "Time Calculation.tmdl").read_text(encoding="utf-8"))
    assert len(lists) == 5
    assert [sorted(found) for found in lists] == [snapshots] * 5


def test_perspectives_list_their_domain_measures():
    folders = t.measure_folders(MEASURES_TEXT)
    stale = []
    for name in cfg.PERSPECTIVES:
        text = (MODEL / "perspectives" / f"{name}.tmdl").read_text(encoding="utf-8")
        wanted = t.perspective_measures(name, folders, cfg.PERSPECTIVE_MEASURE_DOMAINS)
        if t.replace_perspective_measures(text, wanted) != text:
            stale.append(name)
    assert stale == [], "run python ssas/tools/sync_perspectives.py"


def test_nps_measures_show_insufficient_sample():
    bad = [m.name for m in MEASURES if "NPS (5-point)" in m.name and "insufficient sample" not in m.format_expression]
    assert bad == []
```

- [ ] **Step 7: Run the catalogue test to verify the snapshot check fails**

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: `test_snapshot_lists_match_the_snapshot_measures` fails: the lists hold `Headcount`, `Stock Value`, `GL Closing Balance`, but no measure carries the annotation yet. Every other test passes.

- [ ] **Step 8: Annotate the three starter snapshot measures**

In `ssas/HNH_Analytics/tables/_Measures.tmdl`, after each of these three `displayFolder` lines add a blank line and the annotation (two tabs before `annotation`):

```
		displayFolder: Finance\Balances

		annotation hnh_snapshot = 1
```

```
		displayFolder: Workforce\Headcount

		annotation hnh_snapshot = 1
```

```
		displayFolder: Supply Chain\Stock

		annotation hnh_snapshot = 1
```

(`Finance\Balances` is `GL Closing Balance`, `Workforce\Headcount` is `Headcount`, `Supply Chain\Stock` is `Stock Value`.)

- [ ] **Step 9: Run all offline checks**

Run: `python -m pytest ssas/tools -q`
Expected: all pass.

Run: `& 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe' ssas\HNH_Analytics -A ssas\bpa_rules.json -V`
Expected: no line containing `type=error`.

- [ ] **Step 10: Commit**

```bash
git add ssas/tools/hnh_tmdl.py ssas/tools/test_hnh_tmdl.py ssas/tools/sync_perspectives.py ssas/tools/test_measure_catalogue.py ssas/HNH_Analytics/tables/_Measures.tmdl
git commit -m "Add the measure catalogue test and the offline perspective sync

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Zero guard and the TestMeasures deploy stage

**Files:**
- Modify: `ssas/scripts/test.ps1:129-141` (Measures stage)
- Modify: `ssas/scripts/deploy.ps1` (parameter `ValidateSet`, new stage block after the `Promote` block)
- Modify: `ssas/README.md` ("Change the model" and "Run" sections)

**Interfaces:**
- Consumes: `Update-HnhUnprocessed`, `Add-HnhRoleMember`, `Connect-HnhServer`, `Get-HnhDatabase`, `Invoke-HnhStep` from `ssas/scripts/HnhSsas.psm1`; `partitions.ps1 -NoRefresh`; `test.ps1 -Stage Measures`.
- Produces: `deploy.ps1 -Stage TestMeasures`, which Tasks 3–9 run. A check entry may now set `"allow_zero": true`.

- [ ] **Step 1: Make a check where both values are 0 fail**

In `ssas/scripts/test.ps1`, replace the body of the `foreach ($check …)` loop in the `Measures` stage:

```powershell
                try {
                    $value = Get-HnhScalar (Dax $check.dax $null)
                    $expected = Get-HnhScalar (Sql $check.sql)
                    Report "measure $($check.name)" ([math]::Abs($value - $expected) -le [double]$check.tolerance) "SSAS $value, ClickHouse $expected"
                } catch {
```

with:

```powershell
                try {
                    $value = Get-HnhScalar (Dax $check.dax $null)
                    $expected = Get-HnhScalar (Sql $check.sql)
                    # Review focus 1 (KPI catalogue plan): blank becomes 0, so two zeros prove nothing unless blank is the answer.
                    $bothZero = ($value -eq 0) -and ($expected -eq 0) -and -not $check.allow_zero
                    $detail = "SSAS $value, ClickHouse $expected"
                    if ($bothZero) { $detail += ' (both zero: pick a filter with data, or set allow_zero)' }
                    Report "measure $($check.name)" ((-not $bothZero) -and ([math]::Abs($value - $expected) -le [double]$check.tolerance)) $detail
                } catch {
```

- [ ] **Step 2: Add the TestMeasures stage**

In `ssas/scripts/deploy.ps1`, change the `ValidateSet` of `$Stage` to:

```powershell
    [ValidateSet('All', 'Validate', 'Test', 'Promote', 'Rollback', 'TestMeasures')][string]$Stage = 'All',
```

Add to the `.EXAMPLE` block of the header comment:

```
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures
```

Insert this block immediately before `if ($Stage -eq 'Rollback') {`:

```powershell
    if ($Stage -eq 'TestMeasures') {
        # Measure work (KPI catalogue plan): metadata to the test database, keeping its partitions and data source, load
        # only what is not processed (everything after a promotion cleared it), then run the measure checks.
        Write-Host '== Validate'
        Invoke-TabularEditor @($modelDir, '-A', $rules, '-V')
        Write-Host '== Measures: HNH_Analytics_Test'
        $srv = Connect-HnhServer $Server
        $exists = ($srv.Databases.FindByName('HNH_Analytics_Test') -ne $null)
        $srv.Disconnect()
        if (-not $exists) { throw 'HNH_Analytics_Test does not exist: run deploy.ps1 -Stage Test first' }
        Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics_Test', '-O', '-R', '-E', '-V')
        $srv = Connect-HnhServer $Server
        [void](Add-HnhRoleMember -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model -Role 'HNH Readers' -Member $group)
        $srv.Disconnect()
        Invoke-Step 'partitions.ps1' @{ Server = $Server; Database = 'HNH_Analytics_Test'; TabularEditorDir = $TabularEditorDir; NoRefresh = $true }
        $srv = Connect-HnhServer $Server
        $loaded = Update-HnhUnprocessed -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model
        $srv.Disconnect()
        Write-Host ("loaded {0} unprocessed partition(s)" -f $loaded.Count)
        Invoke-Step 'test.ps1' @{ Server = $Server; Database = 'HNH_Analytics_Test'; Dsn = $Dsn; TabularEditorDir = $TabularEditorDir; Stage = @('Measures') }
    }
```

- [ ] **Step 3: Document both in the README**

In `ssas/README.md`, "Change the model", replace step 2's last sentence ("New snapshot measures must be added …") with:

```
New snapshot measures carry `annotation hnh_snapshot = 1` and are added to the list in every `ISSELECTEDMEASURE` of `tables/Time Calculation.tmdl`. Every measure needs at least one check in `tests/measures/<domain>.json` (`allow_zero: true` only where blank is the intended answer). After editing measures run `python ssas/tools/sync_perspectives.py`.
```

Add a row to the "Run" table:

```
| Try measure changes on the test database | `deploy.ps1 -Stage TestMeasures` (validate, metadata to `HNH_Analytics_Test` keeping its data, load unprocessed partitions, measure checks). The first run after a promotion loads the whole test database. |
```

- [ ] **Step 4: Run the offline checks**

Run: `powershell -NoProfile -Command "Invoke-Pester -Script ssas\scripts"`
Expected: all Pester tests pass (the changed scripts have no Pester cases; this proves nothing else broke).

Run: `powershell -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ssas\scripts\deploy.ps1), [ref]$null, [ref]$e); $e; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ssas\scripts\test.ps1), [ref]$null, [ref]$e2); $e2"`
Expected: no parse errors printed.

- [ ] **Step 5: Baseline run on the test database. Ask the user first.**

Ask the user: "May I run `deploy.ps1 -Stage TestMeasures`? It deploys the model metadata to `HNH_Analytics_Test` and loads its data, which the last promotion cleared. That takes about an hour and uses SSAS memory on the production server. Then it runs the 18 starter measure checks."

Only after a yes, run: `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`
Expected: `loaded N unprocessed partition(s)` with N > 0, then 18 `PASS measure …` lines, exit code 0. A `FAIL … (both zero …)` on a starter check means its month has no data: report it to the user rather than editing the check.

- [ ] **Step 6: Commit**

```bash
git add ssas/scripts/test.ps1 ssas/scripts/deploy.ps1 ssas/README.md
git commit -m "Fail measure checks that are zero on both sides and add the TestMeasures deploy stage

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Patient Flow measures (gold layer spec section 8, targets 7.7)

**Files:**
- Create: `ssas/tests/measures/patient_flow.json`
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl` (insert before `	column Measure`)
- Modify: `ssas/HNH_Analytics/perspectives/*.tmdl` (by `sync_perspectives.py`)

**Interfaces:**
- Consumes: starter measures `[OP Visits]`, `[Admissions]`; catalogue test and `deploy.ps1 -Stage TestMeasures` (Tasks 1–2).
- Produces: measures `[ER Visits]`, `[Census]`, `[Episodes]`, `[Discharges]` (used by `[Bed Turnover]` and `[Conversion Rate %]` here), plus the rest listed below.

- [ ] **Step 1: Write the checks**

Create `ssas/tests/measures/patient_flow.json`:

```json
[
  {"name": "ER Visits, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([ER Visits], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type = 'ER' and is_cancelled = 'No'"},
  {"name": "Census, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Census], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf((encounter_type = 'OP' and is_arrived = 'Yes' and is_cancelled = 'No') or (encounter_type = 'ER' and is_cancelled = 'No')) from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901"},
  {"name": "Census, all branches, 2025", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Census], 'Date'[Year] = 2025))",
   "sql": "select countIf((encounter_type = 'OP' and is_arrived = 'Yes' and is_cancelled = 'No') or (encounter_type = 'ER' and is_cancelled = 'No')) from gold.ssas_fact_encounter where encounter_date_key >= 20250101 and encounter_date_key < 20260101"},
  {"name": "Unique Patients, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Unique Patients], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select uniqExact(patient_key) from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type in ('OP', 'ER') and is_arrived = 'Yes' and is_cancelled = 'No'"},
  {"name": "New Patients, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([New Patients], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type in ('OP', 'ER') and is_arrived = 'Yes' and visit_type = 'New patient'"},
  {"name": "Returning Patients, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Returning Patients], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select uniqExact(patient_key) from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type in ('OP', 'ER') and is_arrived = 'Yes' and is_cancelled = 'No' and is_returning = 'Yes'"},
  {"name": "Average Wait (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Average Wait (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select avg(wait_minutes) from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type in ('OP', 'ER') and is_arrived = 'Yes' and is_cancelled = 'No'"},
  {"name": "Median Wait (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Median Wait (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(wait_minutes)) from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type in ('OP', 'ER') and is_arrived = 'Yes' and is_cancelled = 'No'"},
  {"name": "Total Wait (min), branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Total Wait (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(wait_minutes) from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type in ('OP', 'ER') and is_arrived = 'Yes' and is_cancelled = 'No'"},
  {"name": "Average ER LOS (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Average ER LOS (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select avg(er_los_minutes) from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type = 'ER' and is_arrived = 'Yes' and is_cancelled = 'No'"},
  {"name": "No-show Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([No-show Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_no_show = 'Yes') / count() from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type in ('OP', 'ER') and is_walk_in = 'No' and is_cancelled = 'No'"},
  {"name": "Cancellation Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Cancellation Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_cancelled = 'Yes') / count() from gold.ssas_fact_encounter where branch_key = 1 and encounter_date_key >= 20260801 and encounter_date_key < 20260901 and encounter_type in ('OP', 'ER') and is_walk_in = 'No'"},
  {"name": "Episodes, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Episodes], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_episode where branch_key = 1 and start_date_key >= 20260801 and start_date_key < 20260901 and has_arrived_non_follow_up_encounter = 'Yes'"},
  {"name": "Discharges, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Discharges], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_admission where branch_key = 1 and is_countable = 'Yes' and physical_discharge_date_key >= 20260801 and physical_discharge_date_key < 20260901"},
  {"name": "ALOS (days), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([ALOS (days)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select avg(los_days) from gold.ssas_fact_admission where branch_key = 1 and is_countable = 'Yes' and physical_discharge_date_key >= 20260801 and physical_discharge_date_key < 20260901"},
  {"name": "Readmission Rate 30d %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Readmission Rate 30d %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_readmission_30d = 'Yes') / count() from gold.ssas_fact_admission where branch_key = 1 and is_countable = 'Yes' and admit_date_key >= 20260801 and admit_date_key < 20260901"},
  {"name": "ICU Readmissions 48h, all branches, 2026", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([ICU Readmissions 48h], 'Date'[Year] = 2026))",
   "sql": "select countIf(is_icu_readmission_48h = 'Yes') from gold.ssas_fact_admission where is_countable = 'Yes' and admit_date_key >= 20260101 and admit_date_key < 20270101"},
  {"name": "Conversion Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Conversion Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select (select count() from gold.ssas_fact_admission as a inner join gold.ssas_dim_admission_source as s on s.admission_source_key = a.admission_source_key where a.branch_key = 1 and a.is_countable = 'Yes' and a.admit_date_key >= 20260801 and a.admit_date_key < 20260901 and s.admission_source in ('OP', 'ER')) / (select count() from gold.ssas_fact_episode as e inner join gold.ssas_dim_care_type as c on c.care_type_key = e.care_type_key inner join gold.ssas_dim_staff as st on st.staff_key = e.consultant_staff_key where e.branch_key = 1 and e.start_date_key >= 20260801 and e.start_date_key < 20260901 and e.has_arrived_non_follow_up_encounter = 'Yes' and c.care_type in ('OP', 'ER') and st.is_non_admitting_specialty = 'No')"},
  {"name": "Bed Turnover, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Bed Turnover], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select (select count() from gold.ssas_fact_admission where branch_key = 1 and is_countable = 'Yes' and physical_discharge_date_key >= 20260801 and physical_discharge_date_key < 20260901) / (select sum(is_available) / uniqExact(date_key) from gold.ssas_fact_bed_occupancy_daily where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and is_inpatient_ward = 'Yes' and is_excluded_ward = 'No')"},
  {"name": "Clinic Utilisation %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Clinic Utilisation %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(slots_attended) / sum(slots_total) from gold.ssas_agg_clinic_capacity_daily where branch_key = 1 and date_key >= 20260801 and date_key < 20260901"},
  {"name": "Theatre Volume, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Theatre Volume], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_surgery where branch_key = 1 and operation_date_key >= 20260801 and operation_date_key < 20260901 and is_cancelled = 'No'"},
  {"name": "Target Census, branch 1, 2026-08 (most likely by default)", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Target Census], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(target_census) from gold.ssas_fact_target_daily where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and scenario = 'most_likely'"},
  {"name": "Target Census, branch 1, 2026-08, worst case selected (review focus 2)", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Target Census], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608, Targets[Scenario] = \"worst_case\"))",
   "sql": "select sum(target_census) from gold.ssas_fact_target_daily where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and scenario = 'worst_case'"},
  {"name": "Target Episodes, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Target Episodes], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(target_episodes) from gold.ssas_fact_target_daily where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and scenario = 'most_likely'"},
  {"name": "Target Revenue, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Target Revenue], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(target_revenue) from gold.ssas_fact_target_daily where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and scenario = 'most_likely'"},
  {"name": "Target Cost per Episode, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Target Cost per Episode], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(target_cost_total) / sum(target_episodes) from gold.ssas_fact_target_daily where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and scenario = 'most_likely'"},
  {"name": "Target ALOS (days) equals the episode-weighted target_alos, branch 1, 2026-08", "tolerance": 0.001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Target ALOS (days)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(target_alos * target_episodes) / sum(target_episodes) from gold.ssas_fact_target_daily where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and scenario = 'most_likely' and stay_type in ('Non-LTC', 'LTC')"}
]
```

- [ ] **Step 2: Run the catalogue test to verify it fails**

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: `test_checks_reference_existing_columns_and_measures` fails, listing `[ER Visits]`, `[Census]`, … (the 25 measures of this task).

- [ ] **Step 3: Add the measures**

Insert before `	column Measure` in `ssas/HNH_Analytics/tables/_Measures.tmdl`:

```
	/// Emergency visits: ER encounters that are not cancelled (gold spec section 8).
	measure 'ER Visits' =
			CALCULATE (
				COUNTROWS ( Encounters ),
				KEEPFILTERS ( Encounters[Encounter Type] = "ER" ),
				Encounters[Is Cancelled] = "No"
			)
		formatString: #,0
		displayFolder: Patient Flow\Visits

	/// Census: OP visits plus ER visits (gold spec section 8).
	measure Census = [OP Visits] + [ER Visits]
		formatString: #,0
		displayFolder: Patient Flow\Visits

	/// Distinct patients with an arrived, not cancelled OP or ER encounter (gold spec section 8; IP rows are admissions).
	measure 'Unique Patients' =
			CALCULATE (
				DISTINCTCOUNT ( Encounters[Patient Key] ),
				KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
				Encounters[Is Arrived] = "Yes",
				Encounters[Is Cancelled] = "No"
			)
		formatString: #,0
		displayFolder: Patient Flow\Patients

	/// Arrived OP and ER encounters with visit type New patient (gold spec section 8).
	measure 'New Patients' =
			CALCULATE (
				COUNTROWS ( Encounters ),
				KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
				KEEPFILTERS ( Encounters[Visit Type] = "New patient" ),
				Encounters[Is Arrived] = "Yes"
			)
		formatString: #,0
		displayFolder: Patient Flow\Patients

	/// Distinct returning patients (is_returning) among arrived, not cancelled OP and ER encounters (gold spec section 8).
	measure 'Returning Patients' =
			CALCULATE (
				DISTINCTCOUNT ( Encounters[Patient Key] ),
				KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
				Encounters[Is Arrived] = "Yes",
				Encounters[Is Cancelled] = "No",
				Encounters[Is Returning] = "Yes"
			)
		formatString: #,0
		displayFolder: Patient Flow\Patients

	/// Average waiting minutes of arrived, not cancelled OP and ER encounters; ER wait is arrival to treatment start (gold spec section 8; receiving notes).
	measure 'Average Wait (min)' =
			CALCULATE (
				AVERAGE ( Encounters[Wait Minutes] ),
				KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
				Encounters[Is Arrived] = "Yes",
				Encounters[Is Cancelled] = "No"
			)
		formatString: #,0.0
		displayFolder: Patient Flow\Waiting

	/// Median waiting minutes of arrived, not cancelled OP and ER encounters (gold spec section 8).
	measure 'Median Wait (min)' =
			CALCULATE (
				MEDIAN ( Encounters[Wait Minutes] ),
				KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
				Encounters[Is Arrived] = "Yes",
				Encounters[Is Cancelled] = "No"
			)
		formatString: #,0.0
		displayFolder: Patient Flow\Waiting

	/// Sum of waiting minutes, the figure the old reports published; use the average or median for comparisons (gold spec section 8 corrections).
	measure 'Total Wait (min)' =
			CALCULATE (
				SUM ( Encounters[Wait Minutes] ),
				KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
				Encounters[Is Arrived] = "Yes",
				Encounters[Is Cancelled] = "No"
			)
		formatString: #,0
		displayFolder: Patient Flow\Waiting

	/// Average ER length of stay in minutes, arrival to completion, of arrived, not cancelled ER encounters (receiving notes).
	measure 'Average ER LOS (min)' =
			CALCULATE (
				AVERAGE ( Encounters[ER LOS Minutes] ),
				KEEPFILTERS ( Encounters[Encounter Type] = "ER" ),
				Encounters[Is Arrived] = "Yes",
				Encounters[Is Cancelled] = "No"
			)
		formatString: #,0.0
		displayFolder: Patient Flow\Waiting

	/// No-shows ÷ booked appointments that are not walk-ins and not cancelled (gold spec section 8).
	measure 'No-show Rate %' =
			VAR Booked =
				CALCULATE (
					COUNTROWS ( Encounters ),
					KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
					Encounters[Is Walk In] = "No",
					Encounters[Is Cancelled] = "No"
				)
			VAR NoShows =
				CALCULATE (
					COUNTROWS ( Encounters ),
					KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
					Encounters[Is Walk In] = "No",
					Encounters[Is Cancelled] = "No",
					Encounters[Is No Show] = "Yes"
				)
			RETURN DIVIDE ( NoShows, Booked )
		formatString: 0.0%
		displayFolder: Patient Flow\Appointments

	/// Cancelled ÷ booked appointments (not walk-ins), cancelled ones included in the denominator (gold spec section 8).
	measure 'Cancellation Rate %' =
			VAR Booked =
				CALCULATE (
					COUNTROWS ( Encounters ),
					KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
					Encounters[Is Walk In] = "No"
				)
			VAR Cancelled =
				CALCULATE (
					COUNTROWS ( Encounters ),
					KEEPFILTERS ( Encounters[Encounter Type] IN { "OP", "ER" } ),
					Encounters[Is Walk In] = "No",
					Encounters[Is Cancelled] = "Yes"
				)
			RETURN DIVIDE ( Cancelled, Booked )
		formatString: 0.0%
		displayFolder: Patient Flow\Appointments

	/// Episodes with an arrived encounter that is not a follow-up, by episode start date (gold spec section 8).
	measure Episodes = CALCULATE ( COUNTROWS ( Episodes ), Episodes[Has Arrived Non Follow Up Encounter] = "Yes" )
		formatString: #,0
		displayFolder: Patient Flow\Episodes

	/// Countable admissions by physical discharge date (gold spec section 8).
	measure Discharges =
			CALCULATE (
				COUNTROWS ( Admissions ),
				Admissions[Is Countable] = "Yes",
				USERELATIONSHIP ( Admissions[Physical Discharge Date Key], 'Date'[Date Key] )
			)
		formatString: #,0
		displayFolder: Patient Flow\Admissions

	/// Average length of stay in days of countable stays discharged in the period; slice by Is LTC for the LTC split (gold spec section 8).
	measure 'ALOS (days)' =
			CALCULATE (
				AVERAGE ( Admissions[LOS Days] ),
				Admissions[Is Countable] = "Yes",
				USERELATIONSHIP ( Admissions[Physical Discharge Date Key], 'Date'[Date Key] )
			)
		formatString: #,0.0
		displayFolder: Patient Flow\Admissions

	/// 30-day readmissions (previous discharge to this admit) ÷ countable admissions, by admit date (gold spec section 8).
	measure 'Readmission Rate 30d %' =
			DIVIDE ( CALCULATE ( [Admissions], Admissions[Is Readmission 30d] = "Yes" ), [Admissions] )
		formatString: 0.0%
		displayFolder: Patient Flow\Admissions

	/// Countable admissions readmitted to a critical bed within 48 hours (gold spec section 8).
	measure 'ICU Readmissions 48h' = CALCULATE ( [Admissions], Admissions[Is ICU Readmission 48h] = "Yes" )
		formatString: #,0
		displayFolder: Patient Flow\Admissions

	/// Countable admissions from OP or ER ÷ OP and ER episodes whose consultant's specialty admits (gold spec section 8; episodes as in the Episodes measure).
	measure 'Conversion Rate %' =
			VAR Converted = CALCULATE ( [Admissions], 'Admission Source'[Admission Source] IN { "OP", "ER" } )
			VAR Eligible =
				CALCULATE (
					[Episodes],
					'Care Type'[Care Type] IN { "OP", "ER" },
					Staff[Is Non Admitting Specialty] = "No"
				)
			RETURN DIVIDE ( Converted, Eligible )
		formatString: 0.0%
		displayFolder: Patient Flow\Admissions

	/// Discharges ÷ average available beds of inpatient, not excluded wards over the days in the period (gold spec section 8).
	measure 'Bed Turnover' =
			VAR BedDays =
				CALCULATE (
					SUM ( 'Bed Occupancy'[Is Available] ),
					'Bed Occupancy'[Is Inpatient Ward] = "Yes",
					'Bed Occupancy'[Is Excluded Ward] = "No"
				)
			VAR Days =
				CALCULATE (
					DISTINCTCOUNT ( 'Bed Occupancy'[Date Key] ),
					'Bed Occupancy'[Is Inpatient Ward] = "Yes",
					'Bed Occupancy'[Is Excluded Ward] = "No"
				)
			RETURN DIVIDE ( [Discharges], DIVIDE ( BedDays, Days ) )
		formatString: #,0.00
		displayFolder: Patient Flow\Occupancy

	/// Attended ÷ scheduled clinic slots (gold spec section 8).
	measure 'Clinic Utilisation %' =
			DIVIDE ( SUM ( 'Clinic Capacity'[Slots Attended] ), SUM ( 'Clinic Capacity'[Slots Total] ) )
		formatString: 0.0%
		displayFolder: Patient Flow\Clinics

	/// Operations that are not cancelled, by operation date (gold spec section 8).
	measure 'Theatre Volume' = CALCULATE ( COUNTROWS ( Surgeries ), Surgeries[Is Cancelled] = "No" )
		formatString: #,0
		displayFolder: Patient Flow\Theatre

	/// Target census of the most likely scenario unless a scenario is selected (gold spec 7.7).
	measure 'Target Census' =
			VAR Scenario =
				FILTER (
					ALL ( Targets[Scenario] ),
					IF ( ISFILTERED ( Targets[Scenario] ), Targets[Scenario] IN VALUES ( Targets[Scenario] ), Targets[Scenario] = "most_likely" )
				)
			RETURN CALCULATE ( SUM ( Targets[Target Census] ), Scenario )
		formatString: #,0
		displayFolder: Patient Flow\Targets

	/// Target episodes of the most likely scenario unless a scenario is selected (gold spec 7.7).
	measure 'Target Episodes' =
			VAR Scenario =
				FILTER (
					ALL ( Targets[Scenario] ),
					IF ( ISFILTERED ( Targets[Scenario] ), Targets[Scenario] IN VALUES ( Targets[Scenario] ), Targets[Scenario] = "most_likely" )
				)
			RETURN CALCULATE ( SUM ( Targets[Target Episodes] ), Scenario )
		formatString: #,0
		displayFolder: Patient Flow\Targets

	/// Target revenue in SAR of the most likely scenario unless a scenario is selected (gold spec 7.7).
	measure 'Target Revenue' =
			VAR Scenario =
				FILTER (
					ALL ( Targets[Scenario] ),
					IF ( ISFILTERED ( Targets[Scenario] ), Targets[Scenario] IN VALUES ( Targets[Scenario] ), Targets[Scenario] = "most_likely" )
				)
			RETURN CALCULATE ( SUM ( Targets[Target Revenue] ), Scenario )
		formatString: #,0
		displayFolder: Patient Flow\Targets

	/// Target cost per episode in SAR = Σ target_cost_total ÷ Σ target_episodes, never a sum of the per-row value (receiving notes).
	measure 'Target Cost per Episode' =
			VAR Scenario =
				FILTER (
					ALL ( Targets[Scenario] ),
					IF ( ISFILTERED ( Targets[Scenario] ), Targets[Scenario] IN VALUES ( Targets[Scenario] ), Targets[Scenario] = "most_likely" )
				)
			RETURN CALCULATE ( DIVIDE ( SUM ( Targets[Target Cost Total] ), SUM ( Targets[Target Episodes] ) ), Scenario )
		formatString: #,0
		displayFolder: Patient Flow\Targets

	/// Target ALOS in days of inpatient stay types = Σ target patient days ÷ Σ target episodes (the episode-weighted target_alos; receiving notes).
	measure 'Target ALOS (days)' =
			VAR Scenario =
				FILTER (
					ALL ( Targets[Scenario] ),
					IF ( ISFILTERED ( Targets[Scenario] ), Targets[Scenario] IN VALUES ( Targets[Scenario] ), Targets[Scenario] = "most_likely" )
				)
			RETURN
				CALCULATE (
					DIVIDE ( SUM ( Targets[Target Patient Days] ), SUM ( Targets[Target Episodes] ) ),
					Scenario,
					KEEPFILTERS ( Targets[Stay Type] IN { "Non-LTC", "LTC" } )
				)
		formatString: #,0.0
		displayFolder: Patient Flow\Targets

```

- [ ] **Step 4: Sync perspectives and run the offline checks**

Run: `python ssas/tools/sync_perspectives.py`
Expected: `updated Executive.tmdl`, `updated Patient Details.tmdl`, `updated Patient Flow.tmdl`.

Run: `python -m pytest ssas/tools -q`
Expected: all pass.

Run: `& 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe' ssas\HNH_Analytics -A ssas\bpa_rules.json -V`
Expected: no `type=error`.

- [ ] **Step 5: Check on the test database. Ask the user first.**

Ask the user: "May I run `deploy.ps1 -Stage TestMeasures` to deploy the Patient Flow measures to `HNH_Analytics_Test` and run the checks? Its data is already loaded, so only the metadata changes."

Only after a yes, run: `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`
Expected: `loaded 0 unprocessed partition(s)`; every `measure …` line PASS (18 starter + 27 new); exit code 0. On a FAIL, find the cause first (superpowers:systematic-debugging). Compare the DAX filter list with the SQL `where` clause and the spec definition, and fix whichever side is wrong. Never widen a tolerance to make a check pass.

- [ ] **Step 6: Commit**

```bash
git add ssas/tests/measures/patient_flow.json ssas/HNH_Analytics/tables/_Measures.tmdl ssas/HNH_Analytics/perspectives
git commit -m "Add the Patient Flow KPI measures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Revenue Cycle and order-fulfilment measures (Phase 2 spec section 9, order fulfilment spec section 8)

**Files:**
- Create: `ssas/tests/measures/revenue_cycle.json`
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl`, `ssas/HNH_Analytics/perspectives/*.tmdl`

**Interfaces:**
- Consumes: starter measures `[Revenue]`, `[Billed Amount]`.
- Produces: `[Post-invoice Discount]`, `[Order Lines]`, `[Lost Lines]` (reused by the ratios here), plus the rest below. Pre-auth KPIs of the Phase 2 spec are in Task 5 (domain Claims & Pre-auth, where the Pre-auth Lines table is).

- [ ] **Step 1: Write the checks**

Create `ssas/tests/measures/revenue_cycle.json`:

```json
[
  {"name": "Gross Charges, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Gross Charges], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(gross_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901 and is_recognised_revenue = 'Yes'"},
  {"name": "Line Discount, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Line Discount], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(line_discount_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901 and is_recognised_revenue = 'Yes'"},
  {"name": "VAT, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([VAT], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(vat_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901 and is_recognised_revenue = 'Yes'"},
  {"name": "Claimable Revenue, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Claimable Revenue], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(claimable_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901"},
  {"name": "Patient Share Revenue, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Patient Share Revenue], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(revenue_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901 and is_patient_share = 'Yes'"},
  {"name": "Cash Revenue, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Cash Revenue], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(revenue_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901 and is_cash_billed = 'Yes'"},
  {"name": "Medication Revenue, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Medication Revenue], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(revenue_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901 and is_medication = 'Yes'"},
  {"name": "Revenue by Episode Payer, TPA payers, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Revenue by Episode Payer], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608, Payer[Is TPA] = \"Yes\"))",
   "sql": "select sum(c.revenue_amount) from gold.ssas_fact_charge_line as c inner join gold.ssas_dim_payer as p on p.payer_key = c.episode_payer_key where c.branch_key = 1 and c.delivery_date_key >= 20260801 and c.delivery_date_key < 20260901 and p.is_tpa = 'Yes'"},
  {"name": "Package Content Value, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Package Content Value], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(package_content_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901"},
  {"name": "Cancelled Charges, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Cancelled Charges], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(net_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901 and charge_status = 'Cancelled'"},
  {"name": "Post-invoice Discount, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Post-invoice Discount], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(adjustment_amount) from gold.ssas_fact_revenue_adjustment where branch_key = 1 and adjustment_date_key >= 20260801 and adjustment_date_key < 20260901"},
  {"name": "Net Revenue After Adjustments, all branches, 2025", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Net Revenue After Adjustments], 'Date'[Year] = 2025))",
   "sql": "select (select sum(revenue_amount) from gold.ssas_fact_charge_line where delivery_date_key >= 20250101 and delivery_date_key < 20260101) + (select sum(adjustment_amount) from gold.ssas_fact_revenue_adjustment where adjustment_date_key >= 20250101 and adjustment_date_key < 20260101)"},
  {"name": "Verified Billed Amount, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Verified Billed Amount], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(net_amount) from gold.ssas_fact_invoice where branch_key = 1 and invoice_date_key >= 20260801 and invoice_date_key < 20260901 and is_verified = 'Yes'"},
  {"name": "Unbilled Amount, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Unbilled Amount], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(unbilled_amount) from gold.ssas_agg_episode_billing where branch_key = 1 and last_delivery_date_key >= 20260801 and last_delivery_date_key < 20260901"},
  {"name": "Patient Refunds, branch 1, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Patient Refunds], Branch[Branch Key] = 1, 'Date'[Year] = 2026))",
   "sql": "select sum(receipt_amount) from gold.ssas_fact_cash_receipt where branch_key = 1 and receipt_date_key >= 20260101 and receipt_date_key < 20270101 and receipt_kind = 'Refund'"},
  {"name": "Order Lines, branch 1, 2026-08 (outpatient by default)", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Order Lines], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'No' and is_in_leak_scope = 'Yes'"},
  {"name": "Order Lines, branch 1, 2026-08, inpatient selected (review focus 2)", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Order Lines], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608, 'Order Lines'[Is Inpatient] = \"Yes\"))",
   "sql": "select count() from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'Yes' and is_in_leak_scope = 'Yes'"},
  {"name": "Lost Lines, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Lost Lines], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'No' and is_in_leak_scope = 'Yes' and is_lost = 'Yes'"},
  {"name": "Leak Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Leak Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_lost = 'Yes') / count() from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'No' and is_in_leak_scope = 'Yes'"},
  {"name": "Lost Value, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Lost Value], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(ordered_value) from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'No' and is_in_leak_scope = 'Yes' and is_lost = 'Yes' and is_unit_outlier = 'No'"},
  {"name": "Unit Fulfilment Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Unit Fulfilment Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select avg(unit_fulfilment_ratio) from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'No' and is_in_leak_scope = 'Yes'"},
  {"name": "Partially Delivered Lines, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Partially Delivered Lines], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'No' and is_in_leak_scope = 'Yes' and is_partially_delivered = 'Yes' and is_unit_outlier = 'No'"},
  {"name": "Share of Total Lost %, EMERGENCY ROOM, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Share of Total Lost %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608, Staff[Unified Specialty] = \"EMERGENCY ROOM\"))",
   "sql": "select countIf(s.unified_specialty = 'EMERGENCY ROOM') / count() from gold.ssas_fact_order_line as o inner join gold.ssas_dim_staff as s on s.staff_key = o.ordering_staff_key where o.branch_key = 1 and o.order_date_key >= 20260801 and o.order_date_key < 20260901 and o.is_inpatient = 'No' and o.is_in_leak_scope = 'Yes' and o.is_lost = 'Yes'"},
  {"name": "Order to Delivery Median (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Order to Delivery Median (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(order_to_delivery_minutes)) from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'No' and line_status = 'Delivered' and order_category not in ('Consultation', 'Package')"},
  {"name": "Order Cancellation Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Order Cancellation Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(line_status = 'Cancelled') / count() from gold.ssas_fact_order_line where branch_key = 1 and order_date_key >= 20260801 and order_date_key < 20260901 and is_inpatient = 'No'"}
]
```

- [ ] **Step 2: Run the catalogue test to verify it fails**

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: `test_checks_reference_existing_columns_and_measures` fails, listing the 24 new measure names.

- [ ] **Step 3: Add the measures**

Insert before `	column Measure`:

```
	/// Gross charges in SAR of recognised revenue lines (Phase 2 spec section 9).
	measure 'Gross Charges' = CALCULATE ( SUM ( 'Charge Lines'[Gross Amount] ), 'Charge Lines'[Is Recognised Revenue] = "Yes" )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Line discount in SAR of recognised revenue lines (Phase 2 spec section 9).
	measure 'Line Discount' = CALCULATE ( SUM ( 'Charge Lines'[Line Discount Amount] ), 'Charge Lines'[Is Recognised Revenue] = "Yes" )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// VAT in SAR of recognised revenue lines (Phase 2 spec section 9).
	measure VAT = CALCULATE ( SUM ( 'Charge Lines'[VAT Amount] ), 'Charge Lines'[Is Recognised Revenue] = "Yes" )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Claimable revenue in SAR: Σ claimable_amount (Phase 2 spec section 9).
	measure 'Claimable Revenue' = SUM ( 'Charge Lines'[Claimable Amount] )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Revenue in SAR of patient-share (deductible and co-pay) lines (Phase 2 spec section 9).
	measure 'Patient Share Revenue' = CALCULATE ( [Revenue], KEEPFILTERS ( 'Charge Lines'[Is Patient Share] = "Yes" ) )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Revenue in SAR of cash-billed lines (Phase 2 spec section 9).
	measure 'Cash Revenue' = CALCULATE ( [Revenue], KEEPFILTERS ( 'Charge Lines'[Is Cash Billed] = "Yes" ) )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Revenue in SAR of medication lines (Phase 2 spec section 9).
	measure 'Medication Revenue' = CALCULATE ( [Revenue], KEEPFILTERS ( 'Charge Lines'[Is Medication] = "Yes" ) )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Revenue in SAR by the episode's payer, so a payer's patients include their co-pay; Revenue slices by the billed payer (Phase 2 spec section 9).
	measure 'Revenue by Episode Payer' =
			CALCULATE ( [Revenue], USERELATIONSHIP ( 'Charge Lines'[Episode Payer Key], Payer[Payer Key] ) )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Package content value in SAR: Σ package_content_amount (Phase 2 spec section 9).
	measure 'Package Content Value' = SUM ( 'Charge Lines'[Package Content Amount] )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Net amount in SAR of cancelled charge lines (Phase 2 spec section 9).
	measure 'Cancelled Charges' = CALCULATE ( SUM ( 'Charge Lines'[Net Amount] ), KEEPFILTERS ( 'Charge Lines'[Charge Status] = "Cancelled" ) )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Post-invoice discount in SAR: Σ adjustment_amount of the credit documents (Phase 2 spec section 9).
	measure 'Post-invoice Discount' = SUM ( 'Revenue Adjustments'[Adjustment Amount] )
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Revenue plus post-invoice discount in SAR (Phase 2 spec section 9).
	measure 'Net Revenue After Adjustments' = [Revenue] + [Post-invoice Discount]
		formatString: #,0
		displayFolder: Revenue Cycle\Revenue

	/// Billed amount in SAR of verified invoices (Phase 2 spec section 9).
	measure 'Verified Billed Amount' = CALCULATE ( [Billed Amount], KEEPFILTERS ( Invoices[Is Verified] = "Yes" ) )
		formatString: #,0
		displayFolder: Revenue Cycle\Billing

	/// Unbilled amount in SAR of episodes, by the episode's last delivery date (Phase 2 spec section 9).
	measure 'Unbilled Amount' = SUM ( 'Episode Billing'[Unbilled Amount] )
		formatString: #,0
		displayFolder: Revenue Cycle\Billing

	/// Refunds paid back to patients in SAR: Σ receipt_amount of Refund rows (receiving notes).
	measure 'Patient Refunds' = CALCULATE ( SUM ( 'Cash Receipts'[Receipt Amount] ), 'Cash Receipts'[Receipt Kind] = "Refund" )
		formatString: #,0
		displayFolder: Revenue Cycle\Collections

	/// Outpatient order lines in leak scope; inpatient lines only when Is Inpatient is selected (order fulfilment spec section 8; receiving notes).
	measure 'Order Lines' =
			VAR Inpatient =
				FILTER (
					ALL ( 'Order Lines'[Is Inpatient] ),
					IF ( ISFILTERED ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] IN VALUES ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] = "No" )
				)
			RETURN CALCULATE ( COUNTROWS ( 'Order Lines' ), Inpatient, 'Order Lines'[Is In Leak Scope] = "Yes" )
		formatString: #,0
		displayFolder: Revenue Cycle\Order Fulfilment

	/// Lost order lines in leak scope, outpatient by default (order fulfilment spec section 8).
	measure 'Lost Lines' =
			VAR Inpatient =
				FILTER (
					ALL ( 'Order Lines'[Is Inpatient] ),
					IF ( ISFILTERED ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] IN VALUES ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] = "No" )
				)
			RETURN
				CALCULATE (
					COUNTROWS ( 'Order Lines' ),
					Inpatient,
					'Order Lines'[Is In Leak Scope] = "Yes",
					'Order Lines'[Is Lost] = "Yes"
				)
		formatString: #,0
		displayFolder: Revenue Cycle\Order Fulfilment

	/// Lost lines ÷ order lines (order fulfilment spec section 8).
	measure 'Leak Rate %' = DIVIDE ( [Lost Lines], [Order Lines] )
		formatString: 0.0%
		displayFolder: Revenue Cycle\Order Fulfilment

	/// Ordered value in SAR of lost lines, unit outliers excluded (order fulfilment spec section 8).
	measure 'Lost Value' =
			VAR Inpatient =
				FILTER (
					ALL ( 'Order Lines'[Is Inpatient] ),
					IF ( ISFILTERED ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] IN VALUES ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] = "No" )
				)
			RETURN
				CALCULATE (
					SUM ( 'Order Lines'[Ordered Value] ),
					Inpatient,
					'Order Lines'[Is In Leak Scope] = "Yes",
					'Order Lines'[Is Lost] = "Yes",
					'Order Lines'[Is Unit Outlier] = "No"
				)
		formatString: #,0
		displayFolder: Revenue Cycle\Order Fulfilment

	/// Average of the per-line unit fulfilment ratio (capped at 1) over lines in leak scope; outliers kept (order fulfilment spec section 8).
	measure 'Unit Fulfilment Rate %' =
			VAR Inpatient =
				FILTER (
					ALL ( 'Order Lines'[Is Inpatient] ),
					IF ( ISFILTERED ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] IN VALUES ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] = "No" )
				)
			RETURN CALCULATE ( AVERAGE ( 'Order Lines'[Unit Fulfilment Ratio] ), Inpatient, 'Order Lines'[Is In Leak Scope] = "Yes" )
		formatString: 0.0%
		displayFolder: Revenue Cycle\Order Fulfilment

	/// Partially delivered lines in leak scope, unit outliers excluded (order fulfilment spec section 8; receiving notes).
	measure 'Partially Delivered Lines' =
			VAR Inpatient =
				FILTER (
					ALL ( 'Order Lines'[Is Inpatient] ),
					IF ( ISFILTERED ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] IN VALUES ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] = "No" )
				)
			RETURN
				CALCULATE (
					COUNTROWS ( 'Order Lines' ),
					Inpatient,
					'Order Lines'[Is In Leak Scope] = "Yes",
					'Order Lines'[Is Partially Delivered] = "Yes",
					'Order Lines'[Is Unit Outlier] = "No"
				)
		formatString: #,0
		displayFolder: Revenue Cycle\Order Fulfilment

	/// Lost lines in context ÷ lost lines with every filter except the ordering doctor's specialty (order fulfilment spec section 8).
	measure 'Share of Total Lost %' =
			DIVIDE ( [Lost Lines], CALCULATE ( [Lost Lines], REMOVEFILTERS ( Staff[Unified Specialty], Staff[Specialty] ) ) )
		formatString: 0.0%
		displayFolder: Revenue Cycle\Order Fulfilment

	/// Median minutes from order to first delivery of delivered lines; Consultation and Package are left out (charged at order time) (order fulfilment spec section 8).
	measure 'Order to Delivery Median (min)' =
			VAR Inpatient =
				FILTER (
					ALL ( 'Order Lines'[Is Inpatient] ),
					IF ( ISFILTERED ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] IN VALUES ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] = "No" )
				)
			RETURN
				CALCULATE (
					MEDIAN ( 'Order Lines'[Order To Delivery Minutes] ),
					Inpatient,
					'Order Lines'[Line Status] = "Delivered",
					KEEPFILTERS ( NOT ( 'Order Lines'[Order Category] IN { "Consultation", "Package" } ) )
				)
		formatString: #,0.0
		displayFolder: Revenue Cycle\Order Fulfilment

	/// Cancelled lines ÷ all lines (cancelled lines are out of leak scope, so no scope filter), outpatient by default (order fulfilment spec section 8).
	measure 'Order Cancellation Rate %' =
			VAR Inpatient =
				FILTER (
					ALL ( 'Order Lines'[Is Inpatient] ),
					IF ( ISFILTERED ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] IN VALUES ( 'Order Lines'[Is Inpatient] ), 'Order Lines'[Is Inpatient] = "No" )
				)
			VAR AllLines = CALCULATE ( COUNTROWS ( 'Order Lines' ), Inpatient )
			VAR Cancelled = CALCULATE ( COUNTROWS ( 'Order Lines' ), Inpatient, 'Order Lines'[Line Status] = "Cancelled" )
			RETURN DIVIDE ( Cancelled, AllLines )
		formatString: 0.0%
		displayFolder: Revenue Cycle\Order Fulfilment

```

- [ ] **Step 4: Sync perspectives and run the offline checks**

Run: `python ssas/tools/sync_perspectives.py`
Expected: `updated Executive.tmdl`, `updated Patient Details.tmdl`, `updated Revenue Cycle.tmdl`.

Run: `python -m pytest ssas/tools -q` and the Best Practice Analyzer command from Task 1 Step 9.
Expected: all pass; no `type=error`.

- [ ] **Step 5: Check on the test database. Ask the user first.**

Ask the user the Task 3 Step 5 question, naming the Revenue Cycle measures. Only after a yes, run `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`.
Expected: every `measure …` line PASS (the earlier checks plus 25 new); exit code 0. Diagnose any FAIL as in Task 3 Step 5.

- [ ] **Step 6: Commit**

```bash
git add ssas/tests/measures/revenue_cycle.json ssas/HNH_Analytics/tables/_Measures.tmdl ssas/HNH_Analytics/perspectives
git commit -m "Add the Revenue Cycle and order-fulfilment KPI measures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Claims & Pre-auth measures (Phase 2B spec section 8, Phase 2 spec section 9 pre-auth rows, receiving notes)

**Files:**
- Create: `ssas/tests/measures/claims_preauth.json`
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl`, `ssas/HNH_Analytics/perspectives/*.tmdl`

**Interfaces:**
- Consumes: catalogue test, `deploy.ps1 -Stage TestMeasures`.
- Produces: `[Claims Rejected]`, `[Pre-auth Services]`, `[Pre-auth Requests]`, `[Pre-auth Rejected Lines]`, `[Unutilised Approvals]`, which the ratios in this task reuse.

- [ ] **Step 1: Write the checks**

Create `ssas/tests/measures/claims_preauth.json`:

```json
[
  {"name": "Claims Submitted, branch 1, 2026-06", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Claims Submitted], Branch[Branch Key] = 1, 'Date'[Year Month] = 202606))",
   "sql": "select sum(claimed_amount) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and is_sent = 'Yes' and is_latest_submission = 'Yes' and is_cancelled_claim = 'No'"},
  {"name": "Claims Approved, branch 1, 2026-06", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Claims Approved], Branch[Branch Key] = 1, 'Date'[Year Month] = 202606))",
   "sql": "select sum(approved_amount) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and is_latest_submission = 'Yes' and is_cancelled_claim = 'No'"},
  {"name": "Claims Rejected, branch 1, 2026-06", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Claims Rejected], Branch[Branch Key] = 1, 'Date'[Year Month] = 202606))",
   "sql": "select sum(rejected_amount) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and is_latest_submission = 'Yes' and is_cancelled_claim = 'No'"},
  {"name": "Claim Rejection Rate %, branch 1, 2026-06", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Claim Rejection Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202606))",
   "sql": "select sum(rejected_amount) / sum(submitted_amount) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and is_latest_submission = 'Yes' and is_cancelled_claim = 'No' and adjudication_status = 'Adjudicated'"},
  {"name": "First-pass Rejection Rate %, branch 1, 2026-06", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([First-pass Rejection Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202606))",
   "sql": "select sum(rejected_amount) / sum(submitted_amount) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and submission_number = 1 and adjudication_status = 'Adjudicated'"},
  {"name": "Resubmission Recovery, branch 1, 2026-06", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Resubmission Recovery], Branch[Branch Key] = 1, 'Date'[Year Month] = 202606))",
   "sql": "select sum(approved_amount) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and is_latest_submission = 'Yes' and is_cancelled_claim = 'No' and submission_number > 1"},
  {"name": "Pending Adjudication, branch 1, 2026-06", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pending Adjudication], Branch[Branch Key] = 1, 'Date'[Year Month] = 202606))",
   "sql": "select sum(claimed_amount) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and is_sent = 'Yes' and is_latest_submission = 'Yes' and is_cancelled_claim = 'No' and adjudication_status in ('No response', 'Pended')"},
  {"name": "Remitted, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Remitted], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(payment_amount) from gold.ssas_fact_claim_payment where branch_key = 1 and payment_date_key >= 20260801 and payment_date_key < 20260901 and detail_type = 'payment'"},
  {"name": "Payer Advances, all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Payer Advances], 'Date'[Year] = 2026))",
   "sql": "select sum(payment_amount) from gold.ssas_fact_claim_payment where payment_date_key >= 20260101 and payment_date_key < 20270101 and detail_type = 'advance'"},
  {"name": "Early Fee, all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Early Fee], 'Date'[Year] = 2026))",
   "sql": "select sum(early_fee) from gold.ssas_fact_claim_payment where payment_date_key >= 20260101 and payment_date_key < 20270101"},
  {"name": "NPHIES Fee, all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([NPHIES Fee], 'Date'[Year] = 2026))",
   "sql": "select sum(nphies_fee) from gold.ssas_fact_claim_payment where payment_date_key >= 20260101 and payment_date_key < 20270101"},
  {"name": "Median Days to Payment, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Median Days to Payment], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(days_to_payment)) from gold.ssas_fact_claim_payment where branch_key = 1 and payment_date_key >= 20260801 and payment_date_key < 20260901 and detail_type = 'payment'"},
  {"name": "Median Days to Payment is blank over a year (review focus 5)", "tolerance": 0, "allow_zero": true,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Median Days to Payment], 'Date'[Year] = 2026))",
   "sql": "select 0"},
  {"name": "Pre-auth Services, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Services], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Pre-auth Services, Payer advance selected, 2026 (review focus 2)", "tolerance": 0, "allow_zero": true,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Services], 'Date'[Year] = 2026, 'Pre-auth Lines'[Line Source] = \"Payer advance\"))",
   "sql": "select 0"},
  {"name": "Pre-auth Requests, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Requests], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select uniqExact(request_no) from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Pre-auth Requests, all branches, 2026 (counted per branch)", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Requests], 'Date'[Year] = 2026))",
   "sql": "select sum(n) from (select branch_key, uniqExact(request_no) as n from gold.ssas_fact_preauth_line where request_date_key >= 20260101 and request_date_key < 20270101 and line_source <> 'Payer advance' group by branch_key)"},
  {"name": "Pre-auth Approval Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Approval Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_approved = 'Yes' and has_final_response = 'Yes') / countIf(has_final_response = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Pre-auth Rejection Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Rejection Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(preauth_outcome = 'Rejected' and has_final_response = 'Yes') / countIf(has_final_response = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Approved First Time %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Approved First Time %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_approved = 'Yes' and has_final_response = 'Yes' and is_first_response_approved = 'Yes') / countIf(is_approved = 'Yes' and has_final_response = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Pre-auth Resubmission Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Resubmission Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select uniqExactIf(request_no, is_resubmitted = 'Yes') / uniqExact(request_no) from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Pre-auth Transfer Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Transfer Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_transfer = 'Yes') / count() from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Request to Sent Avg (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Request to Sent Avg (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select avg(request_to_sent_minutes) from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Request to Sent Median (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Request to Sent Median (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(request_to_sent_minutes)) from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Sent to Response Avg (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Sent to Response Avg (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select avg(sent_to_response_minutes) from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Sent to Response Median (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Sent to Response Median (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(sent_to_response_minutes)) from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Total Turnaround Avg (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Total Turnaround Avg (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select avg(total_turnaround_minutes) from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Total Turnaround Median (min), branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Total Turnaround Median (min)], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(total_turnaround_minutes)) from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Unutilised Approvals, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Unutilised Approvals], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_approved_not_delivered = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Unutilised Approval Rate %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Unutilised Approval Rate %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_approved_not_delivered = 'Yes') / count() from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Pre-auth Lost Revenue, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Lost Revenue], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sumIf(approved_estimated_amount, is_approved_not_delivered = 'Yes' and is_latest_request_for_service = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Pre-auth Rejected Revenue, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Rejected Revenue], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sumIf(estimated_amount, preauth_outcome = 'Rejected' and is_latest_request_for_service = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Delivered Without Approval, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Delivered Without Approval], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(is_delivered_not_approved = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Delivered Without Approval Amount, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Delivered Without Approval Amount], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sumIf(estimated_amount, is_delivered_not_approved = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Pre-auth Rejected Lines, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pre-auth Rejected Lines], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select countIf(preauth_outcome = 'Rejected' and has_final_response = 'Yes') from gold.ssas_fact_preauth_line where branch_key = 1 and request_date_key >= 20260801 and request_date_key < 20260901 and line_source <> 'Payer advance'"},
  {"name": "Advance Authorisations, all branches, 2026", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Advance Authorisations], 'Date'[Year] = 2026))",
   "sql": "select count() from gold.ssas_fact_preauth_line where request_date_key >= 20260101 and request_date_key < 20270101 and line_source = 'Payer advance'"},
  {"name": "Advance Approved Amount, all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Advance Approved Amount], 'Date'[Year] = 2026))",
   "sql": "select sum(payer_approved_amount) from gold.ssas_fact_preauth_line where request_date_key >= 20260101 and request_date_key < 20270101 and line_source = 'Payer advance'"}
]
```

- [ ] **Step 2: Run the catalogue test to verify it fails**

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: `test_checks_reference_existing_columns_and_measures` fails, listing the 34 new measure names.

- [ ] **Step 3: Add the measures**

Insert before `	column Measure`:

```
	/// Claimed amount in SAR of sent lines of the latest, not cancelled submission (Phase 2B spec section 8).
	measure 'Claims Submitted' =
			CALCULATE (
				SUM ( 'Claim Lines'[Line Claimed Amount] ),
				'Claim Lines'[Is Sent] = "Yes",
				'Claim Lines'[Is Latest Submission] = "Yes",
				'Claim Lines'[Is Cancelled Claim] = "No"
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Claims

	/// Approved amount in SAR of the latest, not cancelled submission (Phase 2B spec section 8).
	measure 'Claims Approved' =
			CALCULATE (
				SUM ( 'Claim Lines'[Approved Amount] ),
				'Claim Lines'[Is Latest Submission] = "Yes",
				'Claim Lines'[Is Cancelled Claim] = "No"
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Claims

	/// Outcome-aware rejected amount in SAR of the latest, not cancelled submission; slice by NPHIES Reason for rejections by reason (Phase 2B spec section 8).
	measure 'Claims Rejected' =
			CALCULATE (
				SUM ( 'Claim Lines'[Rejected Amount] ),
				'Claim Lines'[Is Latest Submission] = "Yes",
				'Claim Lines'[Is Cancelled Claim] = "No"
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Claims

	/// Rejected ÷ submitted amount of adjudicated lines of the latest, not cancelled submission (Phase 2B spec section 8; receiving notes).
	measure 'Claim Rejection Rate %' =
			VAR Rejected = CALCULATE ( [Claims Rejected], 'Claim Lines'[Adjudication Status] = "Adjudicated" )
			VAR Submitted =
				CALCULATE (
					SUM ( 'Claim Lines'[Submitted Amount] ),
					'Claim Lines'[Is Latest Submission] = "Yes",
					'Claim Lines'[Is Cancelled Claim] = "No",
					'Claim Lines'[Adjudication Status] = "Adjudicated"
				)
			RETURN DIVIDE ( Rejected, Submitted )
		formatString: 0.0%
		displayFolder: Claims & Pre-auth\Claims

	/// Rejection rate of first submissions (submission 1 as sent, cancelled claims included: the one exception to the cancelled rule) (Phase 2B spec section 8; receiving notes).
	measure 'First-pass Rejection Rate %' =
			VAR Rejected =
				CALCULATE (
					SUM ( 'Claim Lines'[Rejected Amount] ),
					'Claim Lines'[Submission Number] = 1,
					'Claim Lines'[Adjudication Status] = "Adjudicated"
				)
			VAR Submitted =
				CALCULATE (
					SUM ( 'Claim Lines'[Submitted Amount] ),
					'Claim Lines'[Submission Number] = 1,
					'Claim Lines'[Adjudication Status] = "Adjudicated"
				)
			RETURN DIVIDE ( Rejected, Submitted )
		formatString: 0.0%
		displayFolder: Claims & Pre-auth\Claims

	/// Approved amount in SAR of latest, not cancelled resubmissions (submission number above 1) (Phase 2B spec section 8).
	measure 'Resubmission Recovery' =
			CALCULATE (
				SUM ( 'Claim Lines'[Approved Amount] ),
				'Claim Lines'[Is Latest Submission] = "Yes",
				'Claim Lines'[Is Cancelled Claim] = "No",
				'Claim Lines'[Submission Number] > 1
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Claims

	/// Claimed amount in SAR of sent, latest, not cancelled lines with no response or pended (Phase 2B spec section 8).
	measure 'Pending Adjudication' =
			CALCULATE (
				SUM ( 'Claim Lines'[Line Claimed Amount] ),
				'Claim Lines'[Is Sent] = "Yes",
				'Claim Lines'[Is Latest Submission] = "Yes",
				'Claim Lines'[Is Cancelled Claim] = "No",
				KEEPFILTERS ( 'Claim Lines'[Adjudication Status] IN { "No response", "Pended" } )
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Claims

	/// Claim remittance in SAR from NPHIES payment lines; advances are in Payer Advances; not insurer AR (Phase 2B spec section 8; receiving notes).
	measure Remitted = CALCULATE ( SUM ( 'Claim Payments'[Payment Amount] ), 'Claim Payments'[Detail Type] = "payment" )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Payments

	/// Money paid by payers as advances in SAR (detail type advance); not claim remittance (receiving notes).
	measure 'Payer Advances' = CALCULATE ( SUM ( 'Claim Payments'[Payment Amount] ), 'Claim Payments'[Detail Type] = "advance" )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Payments

	/// Early fee in SAR as signed by the payer; reported beside the NPHIES fee, never netted (Phase 2B spec section 8).
	measure 'Early Fee' = SUM ( 'Claim Payments'[Early Fee] )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Payments

	/// NPHIES fee in SAR as signed by the payer (Phase 2B spec section 8).
	measure 'NPHIES Fee' = SUM ( 'Claim Payments'[NPHIES Fee] )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Payments

	/// Median days from statement to payment of payment lines, for one payment month only (blank over longer periods: bulk back-settlements skew them) (Phase 2B spec section 8; receiving notes).
	measure 'Median Days to Payment' =
			IF (
				HASONEVALUE ( 'Date'[Year Month] ),
				CALCULATE ( MEDIAN ( 'Claim Payments'[Days To Payment] ), 'Claim Payments'[Detail Type] = "payment" )
			)
		formatString: #,0.0
		displayFolder: Claims & Pre-auth\Payments

	/// Pre-auth service lines, payer advance authorisations excluded (Phase 2 spec section 9; receiving notes).
	measure 'Pre-auth Services' =
			CALCULATE ( COUNTROWS ( 'Pre-auth Lines' ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ) )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Distinct pre-auth requests per branch, added over branches; payer advances excluded (Phase 2 spec section 9).
	measure 'Pre-auth Requests' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				CALCULATE (
					DISTINCTCOUNTNOBLANK ( 'Pre-auth Lines'[Request No] ),
					KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" )
				)
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Approved lines with a final response ÷ lines with a final response (Phase 2 spec section 9; receiving notes).
	measure 'Pre-auth Approval Rate %' =
			VAR Final = CALCULATE ( [Pre-auth Services], 'Pre-auth Lines'[Has Final Response] = "Yes" )
			VAR Approved =
				CALCULATE ( [Pre-auth Services], 'Pre-auth Lines'[Has Final Response] = "Yes", 'Pre-auth Lines'[Is Approved] = "Yes" )
			RETURN DIVIDE ( Approved, Final )
		formatString: 0.0%
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Rejected lines with a final response ÷ lines with a final response (Phase 2 spec section 9; receiving notes).
	measure 'Pre-auth Rejection Rate %' =
			DIVIDE ( [Pre-auth Rejected Lines], CALCULATE ( [Pre-auth Services], 'Pre-auth Lines'[Has Final Response] = "Yes" ) )
		formatString: 0.0%
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Lines approved at the first response ÷ approved lines with a final response (Phase 2 spec section 9).
	measure 'Approved First Time %' =
			VAR Approved =
				CALCULATE ( [Pre-auth Services], 'Pre-auth Lines'[Has Final Response] = "Yes", 'Pre-auth Lines'[Is Approved] = "Yes" )
			VAR FirstTime =
				CALCULATE (
					[Pre-auth Services],
					'Pre-auth Lines'[Has Final Response] = "Yes",
					'Pre-auth Lines'[Is Approved] = "Yes",
					'Pre-auth Lines'[Is First Response Approved] = "Yes"
				)
			RETURN DIVIDE ( FirstTime, Approved )
		formatString: 0.0%
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Requests with a resubmitted line ÷ requests (Phase 2 spec section 9).
	measure 'Pre-auth Resubmission Rate %' =
			DIVIDE ( CALCULATE ( [Pre-auth Requests], 'Pre-auth Lines'[Is Resubmitted] = "Yes" ), [Pre-auth Requests] )
		formatString: 0.0%
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Transfer lines ÷ lines (Phase 2 spec section 9).
	measure 'Pre-auth Transfer Rate %' =
			DIVIDE ( CALCULATE ( [Pre-auth Services], 'Pre-auth Lines'[Is Transfer] = "Yes" ), [Pre-auth Services] )
		formatString: 0.0%
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Average minutes from request to first send (Phase 2 spec section 9).
	measure 'Request to Sent Avg (min)' =
			CALCULATE ( AVERAGE ( 'Pre-auth Lines'[Request To Sent Minutes] ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ) )
		formatString: #,0.0
		displayFolder: Claims & Pre-auth\Pre-auth Turnaround

	/// Median minutes from request to first send (Phase 2 spec section 9).
	measure 'Request to Sent Median (min)' =
			CALCULATE ( MEDIAN ( 'Pre-auth Lines'[Request To Sent Minutes] ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ) )
		formatString: #,0.0
		displayFolder: Claims & Pre-auth\Pre-auth Turnaround

	/// Average minutes from send to the final response (Phase 2 spec section 9).
	measure 'Sent to Response Avg (min)' =
			CALCULATE ( AVERAGE ( 'Pre-auth Lines'[Sent To Response Minutes] ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ) )
		formatString: #,0.0
		displayFolder: Claims & Pre-auth\Pre-auth Turnaround

	/// Median minutes from send to the final response (Phase 2 spec section 9).
	measure 'Sent to Response Median (min)' =
			CALCULATE ( MEDIAN ( 'Pre-auth Lines'[Sent To Response Minutes] ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ) )
		formatString: #,0.0
		displayFolder: Claims & Pre-auth\Pre-auth Turnaround

	/// Average minutes from request to the final response (Phase 2 spec section 9).
	measure 'Total Turnaround Avg (min)' =
			CALCULATE ( AVERAGE ( 'Pre-auth Lines'[Total Turnaround Minutes] ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ) )
		formatString: #,0.0
		displayFolder: Claims & Pre-auth\Pre-auth Turnaround

	/// Median minutes from request to the final response (Phase 2 spec section 9).
	measure 'Total Turnaround Median (min)' =
			CALCULATE ( MEDIAN ( 'Pre-auth Lines'[Total Turnaround Minutes] ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ) )
		formatString: #,0.0
		displayFolder: Claims & Pre-auth\Pre-auth Turnaround

	/// Approved lines that were never delivered (Phase 2 spec section 9).
	measure 'Unutilised Approvals' = CALCULATE ( [Pre-auth Services], 'Pre-auth Lines'[Is Approved Not Delivered] = "Yes" )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Unutilised approvals ÷ lines (Phase 2 spec section 9).
	measure 'Unutilised Approval Rate %' = DIVIDE ( [Unutilised Approvals], [Pre-auth Services] )
		formatString: 0.0%
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Approved estimated amount in SAR of approved, undelivered lines on the latest request for the service (Phase 2 spec section 9).
	measure 'Pre-auth Lost Revenue' =
			CALCULATE (
				SUM ( 'Pre-auth Lines'[Approved Estimated Amount] ),
				KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ),
				'Pre-auth Lines'[Is Approved Not Delivered] = "Yes",
				'Pre-auth Lines'[Is Latest Request For Service] = "Yes"
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Estimated amount in SAR of rejected lines on the latest request for the service (Phase 2 spec section 9).
	measure 'Pre-auth Rejected Revenue' =
			CALCULATE (
				SUM ( 'Pre-auth Lines'[Estimated Amount] ),
				KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ),
				'Pre-auth Lines'[Preauth Outcome] = "Rejected",
				'Pre-auth Lines'[Is Latest Request For Service] = "Yes"
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Lines delivered without an approval (Phase 2 spec section 9).
	measure 'Delivered Without Approval' = CALCULATE ( [Pre-auth Services], 'Pre-auth Lines'[Is Delivered Not Approved] = "Yes" )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Estimated amount in SAR of lines delivered without an approval (Phase 2 spec section 9).
	measure 'Delivered Without Approval Amount' =
			CALCULATE (
				SUM ( 'Pre-auth Lines'[Estimated Amount] ),
				KEEPFILTERS ( 'Pre-auth Lines'[Line Source] <> "Payer advance" ),
				'Pre-auth Lines'[Is Delivered Not Approved] = "Yes"
			)
		formatString: #,0
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Rejected pre-auth lines with a final response; slice by NPHIES Reason for rejections by reason (Phase 2B spec section 8).
	measure 'Pre-auth Rejected Lines' =
			CALCULATE ( [Pre-auth Services], 'Pre-auth Lines'[Preauth Outcome] = "Rejected", 'Pre-auth Lines'[Has Final Response] = "Yes" )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Pre-auth

	/// Payer-initiated advance authorisations, by the payer's creation date (receiving notes).
	measure 'Advance Authorisations' =
			CALCULATE ( COUNTROWS ( 'Pre-auth Lines' ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] = "Payer advance" ) )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Advance Authorisations

	/// Payer approved amount in SAR of advance authorisations, placeholders of 0 and 1 SAR included as sent (receiving notes).
	measure 'Advance Approved Amount' =
			CALCULATE ( SUM ( 'Pre-auth Lines'[Payer Approved Amount] ), KEEPFILTERS ( 'Pre-auth Lines'[Line Source] = "Payer advance" ) )
		formatString: #,0
		displayFolder: Claims & Pre-auth\Advance Authorisations

```

- [ ] **Step 4: Sync perspectives and run the offline checks**

Run: `python ssas/tools/sync_perspectives.py`
Expected: `updated Claims & Pre-auth.tmdl`, `updated Executive.tmdl`.

Run: `python -m pytest ssas/tools -q` and the Best Practice Analyzer command from Task 1 Step 9.
Expected: all pass; no `type=error`.

- [ ] **Step 5: Check on the test database. Ask the user first.**

Ask the user the Task 3 Step 5 question, naming the Claims & Pre-auth measures. Only after a yes, run `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`.
Expected: every `measure …` line PASS (37 new); exit code 0. Diagnose any FAIL as in Task 3 Step 5.

- [ ] **Step 6: Commit**

```bash
git add ssas/tests/measures/claims_preauth.json ssas/HNH_Analytics/tables/_Measures.tmdl ssas/HNH_Analytics/perspectives
git commit -m "Add the Claims and Pre-auth KPI measures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Finance measures (Phase 3 spec section 8, receiving notes)

**Files:**
- Create: `ssas/tests/measures/finance.json`
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl`, `ssas/HNH_Analytics/tables/Time Calculation.tmdl`, `ssas/HNH_Analytics/perspectives/*.tmdl`

**Interfaces:**
- Consumes: starter `[GL Closing Balance]` (its per-branch last-period pattern is repeated here).
- Produces: `[IS Actual]`, `[IS Budget]`, `[IS Budget (Comparable)]`, `[Budget Variance]`, `[Supplier Spend]` (reused by Task 8's `[PO-Matched Spend Share %]`). Five new snapshot measures.

- [ ] **Step 1: Write the checks**

Create `ssas/tests/measures/finance.json`:

```json
[
  {"name": "GL Closing Balance (incl. Unposted), branch 7, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([GL Closing Balance (incl. Unposted)], Branch[Branch Key] = 7, 'Date'[Year Month] = 202608))",
   "sql": "select sum(b.closing_balance * f.display_sign) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key inner join gold.ssas_dim_fs_line as f on f.fs_line_key = a.fs_line_key where b.branch_key = 7 and b.balance_view = 'including_unposted' and b.period_key = (select max(period_key) from gold.ssas_fact_gl_balance_monthly where branch_key = 7 and period_end_date_key >= 20260801 and period_end_date_key < 20260901)"},
  {"name": "GL Closing Balance (incl. Unposted) YTD equals the month (review focus 3)", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([GL Closing Balance (incl. Unposted)], Branch[Branch Key] = 7, 'Date'[Year Month] = 202608, 'Time Calculation'[Time Calculation] = \"YTD\"))",
   "sql": "select sum(b.closing_balance * f.display_sign) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key inner join gold.ssas_dim_fs_line as f on f.fs_line_key = a.fs_line_key where b.branch_key = 7 and b.balance_view = 'including_unposted' and b.period_key = (select max(period_key) from gold.ssas_fact_gl_balance_monthly where branch_key = 7 and period_end_date_key >= 20260801 and period_end_date_key < 20260901)"},
  {"name": "GL Movement, branch 7, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([GL Movement], Branch[Branch Key] = 7, 'Date'[Year Month] = 202608))",
   "sql": "select sum(b.period_movement * f.display_sign) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key inner join gold.ssas_dim_fs_line as f on f.fs_line_key = a.fs_line_key where b.branch_key = 7 and b.balance_view = 'posted' and b.period_end_date_key >= 20260801 and b.period_end_date_key < 20260901"},
  {"name": "GL Movement (incl. Unposted), branch 7, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([GL Movement (incl. Unposted)], Branch[Branch Key] = 7, 'Date'[Year Month] = 202608))",
   "sql": "select sum(b.period_movement * f.display_sign) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key inner join gold.ssas_dim_fs_line as f on f.fs_line_key = a.fs_line_key where b.branch_key = 7 and b.balance_view = 'including_unposted' and b.period_end_date_key >= 20260801 and b.period_end_date_key < 20260901"},
  {"name": "GL Movement Trend, all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([GL Movement Trend], 'Date'[Year] = 2026))",
   "sql": "select sum(b.period_movement_excl_opening * f.display_sign) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key inner join gold.ssas_dim_fs_line as f on f.fs_line_key = a.fs_line_key where b.balance_view = 'posted' and b.period_end_date_key >= 20260101 and b.period_end_date_key < 20270101"},
  {"name": "GL Movement Trend (incl. Unposted), all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([GL Movement Trend (incl. Unposted)], 'Date'[Year] = 2026))",
   "sql": "select sum(b.period_movement_excl_opening * f.display_sign) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key inner join gold.ssas_dim_fs_line as f on f.fs_line_key = a.fs_line_key where b.balance_view = 'including_unposted' and b.period_end_date_key >= 20260101 and b.period_end_date_key < 20270101"},
  {"name": "Profit for the Year, branch 7, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Profit for the Year], Branch[Branch Key] = 7, 'Date'[Year Month] = 202608))",
   "sql": "select -sum(b.closing_balance) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key where b.branch_key = 7 and b.balance_view = 'posted' and a.balance_side = 'IS' and b.period_key = (select max(period_key) from gold.ssas_fact_gl_balance_monthly where branch_key = 7 and period_end_date_key >= 20260801 and period_end_date_key < 20260901)"},
  {"name": "Profit for the Year (incl. Unposted), branch 7, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Profit for the Year (incl. Unposted)], Branch[Branch Key] = 7, 'Date'[Year Month] = 202608))",
   "sql": "select -sum(b.closing_balance) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key where b.branch_key = 7 and b.balance_view = 'including_unposted' and a.balance_side = 'IS' and b.period_key = (select max(period_key) from gold.ssas_fact_gl_balance_monthly where branch_key = 7 and period_end_date_key >= 20260801 and period_end_date_key < 20260901)"},
  {"name": "IS Actual, REV_NET, branch 4, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([IS Actual], Branch[Branch Key] = 4, 'Date'[Year Month] = 202608, 'Budget Line'[Budget Line Code] = \"REV_NET\"))",
   "sql": "select sum(i.actual_posted) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 4 and i.month_date_key >= 20260801 and i.month_date_key < 20260901 and b.budget_line_code = 'REV_NET'"},
  {"name": "IS Actual is blank across budget codes (review focus 5)", "tolerance": 0, "allow_zero": true,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([IS Actual], Branch[Branch Key] = 4, 'Date'[Year Month] = 202608))",
   "sql": "select 0"},
  {"name": "IS Actual (incl. Unposted), REV_NET, branch 4, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([IS Actual (incl. Unposted)], Branch[Branch Key] = 4, 'Date'[Year Month] = 202608, 'Budget Line'[Budget Line Code] = \"REV_NET\"))",
   "sql": "select sum(i.actual_including_unposted) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 4 and i.month_date_key >= 20260801 and i.month_date_key < 20260901 and b.budget_line_code = 'REV_NET'"},
  {"name": "IS Actual (excl. Opening), REV_NET, branch 4, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([IS Actual (excl. Opening)], Branch[Branch Key] = 4, 'Date'[Year Month] = 202608, 'Budget Line'[Budget Line Code] = \"REV_NET\"))",
   "sql": "select sum(i.actual_excl_opening) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 4 and i.month_date_key >= 20260801 and i.month_date_key < 20260901 and b.budget_line_code = 'REV_NET'"},
  {"name": "IS Budget, REV_NET, branch 4, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([IS Budget], Branch[Branch Key] = 4, 'Date'[Year Month] = 202608, 'Budget Line'[Budget Line Code] = \"REV_NET\"))",
   "sql": "select sum(i.budget_most_likely) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 4 and i.month_date_key >= 20260801 and i.month_date_key < 20260901 and b.budget_line_code = 'REV_NET'"},
  {"name": "IS Budget (Comparable), DC_MEDICINES adds DC_CONSUMABLES, branch 3, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([IS Budget (Comparable)], Branch[Branch Key] = 3, 'Date'[Year Month] = 202608, 'Budget Line'[Budget Line Code] = \"DC_MEDICINES\"))",
   "sql": "select sum(i.budget_most_likely) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 3 and i.month_date_key >= 20260801 and i.month_date_key < 20260901 and b.budget_line_code in ('DC_MEDICINES', 'DC_CONSUMABLES')"},
  {"name": "Budget Variance, DC_MEDICINES, branch 3, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Budget Variance], Branch[Branch Key] = 3, 'Date'[Year Month] = 202608, 'Budget Line'[Budget Line Code] = \"DC_MEDICINES\"))",
   "sql": "select sumIf(i.actual_posted, b.budget_line_code = 'DC_MEDICINES') - sum(i.budget_most_likely) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 3 and i.month_date_key >= 20260801 and i.month_date_key < 20260901 and b.budget_line_code in ('DC_MEDICINES', 'DC_CONSUMABLES')"},
  {"name": "Budget Variance %, REV_NET, branch 4, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Budget Variance %], Branch[Branch Key] = 4, 'Date'[Year Month] = 202608, 'Budget Line'[Budget Line Code] = \"REV_NET\"))",
   "sql": "select (sum(i.actual_posted) - sum(i.budget_most_likely)) / abs(sum(i.budget_most_likely)) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 4 and i.month_date_key >= 20260801 and i.month_date_key < 20260901 and b.budget_line_code = 'REV_NET'"},
  {"name": "EBITDA, branch 4, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([EBITDA], Branch[Branch Key] = 4, 'Date'[Year Month] = 202608))",
   "sql": "select sum(i.actual_posted) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 4 and i.month_date_key >= 20260801 and i.month_date_key < 20260901 and b.budget_line_code = 'EBITDA'"},
  {"name": "Gross Profit, all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Gross Profit], 'Date'[Year] = 2026))",
   "sql": "select sum(i.actual_posted) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.month_date_key >= 20260101 and i.month_date_key < 20270101 and b.budget_line_code = 'GROSS_PROFIT'"},
  {"name": "Net Profit, all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Net Profit], 'Date'[Year] = 2026))",
   "sql": "select sum(i.actual_posted) from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.month_date_key >= 20260101 and i.month_date_key < 20270101 and b.budget_line_code = 'NET_PROFIT'"},
  {"name": "EBITDA Margin %, branch 4, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([EBITDA Margin %], Branch[Branch Key] = 4, 'Date'[Year Month] = 202608))",
   "sql": "select sumIf(i.actual_posted, b.budget_line_code = 'EBITDA') / sumIf(i.actual_posted, b.budget_line_code = 'REV_NET') from gold.ssas_fact_income_statement_monthly as i inner join gold.ssas_dim_budget_line as b on b.budget_line_key = i.budget_line_key where i.branch_key = 4 and i.month_date_key >= 20260801 and i.month_date_key < 20260901"},
  {"name": "Supplier Spend, all branches, 2026", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Supplier Spend], 'Date'[Year] = 2026))",
   "sql": "select sum(spend_amount) from gold.ssas_fact_ap_invoice_line where accounting_date_key >= 20260101 and accounting_date_key < 20270101"},
  {"name": "Open Payables, all", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", [Open Payables])",
   "sql": "select sum(amount_remaining) from gold.ssas_fact_ap_open_item"},
  {"name": "Open Payables YTD equals the August invoices (review focus 3)", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Open Payables], 'Date'[Year Month] = 202608, 'Time Calculation'[Time Calculation] = \"YTD\"))",
   "sql": "select sum(amount_remaining) from gold.ssas_fact_ap_open_item where invoice_date_key >= 20260801 and invoice_date_key < 20260901"},
  {"name": "Overdue Payables, all", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", [Overdue Payables])",
   "sql": "select sum(amount_remaining) from gold.ssas_fact_ap_open_item where days_overdue > 0"},
  {"name": "Median Days to Pay, all branches, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Median Days to Pay], 'Date'[Year] = 2026))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(days_invoice_to_payment)) from gold.ssas_fact_ap_payment where is_voided = 'No' and payment_date_key >= 20260101 and payment_date_key < 20270101"},
  {"name": "On-time Payment Rate %, all branches, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([On-time Payment Rate %], 'Date'[Year] = 2026))",
   "sql": "select countIf(days_after_due <= 0) / count() from gold.ssas_fact_ap_payment where is_voided = 'No' and payment_date_key >= 20260101 and payment_date_key < 20270101"}
]
```

- [ ] **Step 2: Run the catalogue test to verify it fails**

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: `test_checks_reference_existing_columns_and_measures` fails, listing the 23 new measure names.

- [ ] **Step 3: Add the measures**

Insert before `	column Measure`:

```
	/// Closing balance in SAR including unposted journals, at the last period of the selection per branch, signed for display (Phase 3 spec section 8; receiving notes). Snapshot.
	measure 'GL Closing Balance (incl. Unposted)' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastPeriod = CALCULATE ( MAX ( 'GL Balances'[Period Key] ) )
				RETURN
					CALCULATE (
						SUMX ( 'GL Balances', 'GL Balances'[Closing Balance] * RELATED ( 'FS Line'[Display Sign] ) ),
						'GL Balances'[Period Key] = LastPeriod,
						'GL Balances'[Balance View] = "including_unposted"
					)
			)
		formatString: #,0
		displayFolder: Finance\Balances

		annotation hnh_snapshot = 1

	/// Posted period movement in SAR, signed for display; use it for balances and year to date (Phase 3 spec section 8).
	measure 'GL Movement' =
			CALCULATE (
				SUMX ( 'GL Balances', 'GL Balances'[Period Movement] * RELATED ( 'FS Line'[Display Sign] ) ),
				'GL Balances'[Balance View] = "posted"
			)
		formatString: #,0
		displayFolder: Finance\Balances

	/// Period movement in SAR including unposted journals, signed for display (Phase 3 spec section 8).
	measure 'GL Movement (incl. Unposted)' =
			CALCULATE (
				SUMX ( 'GL Balances', 'GL Balances'[Period Movement] * RELATED ( 'FS Line'[Display Sign] ) ),
				'GL Balances'[Balance View] = "including_unposted"
			)
		formatString: #,0
		displayFolder: Finance\Balances

	/// Posted movement in SAR without the go-live opening-balance journals, for monthly trends (Phase 3 spec section 8; receiving notes).
	measure 'GL Movement Trend' =
			CALCULATE (
				SUMX ( 'GL Balances', 'GL Balances'[Period Movement Excl Opening] * RELATED ( 'FS Line'[Display Sign] ) ),
				'GL Balances'[Balance View] = "posted"
			)
		formatString: #,0
		displayFolder: Finance\Balances

	/// Movement in SAR including unposted journals, without opening-balance journals, for monthly trends (Phase 3 spec section 8).
	measure 'GL Movement Trend (incl. Unposted)' =
			CALCULATE (
				SUMX ( 'GL Balances', 'GL Balances'[Period Movement Excl Opening] * RELATED ( 'FS Line'[Display Sign] ) ),
				'GL Balances'[Balance View] = "including_unposted"
			)
		formatString: #,0
		displayFolder: Finance\Balances

	/// Equity line Profit for the year in SAR = −Σ posted closing balance of income-statement accounts at the last period per branch, so assets = liabilities + equity (receiving notes). Snapshot.
	measure 'Profit for the Year' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastPeriod = CALCULATE ( MAX ( 'GL Balances'[Period Key] ) )
				RETURN
					- CALCULATE (
						SUM ( 'GL Balances'[Closing Balance] ),
						'GL Balances'[Period Key] = LastPeriod,
						'GL Balances'[Balance View] = "posted",
						'GL Account'[Balance Side] = "IS"
					)
			)
		formatString: #,0
		displayFolder: Finance\Balances

		annotation hnh_snapshot = 1

	/// Profit for the year in SAR including unposted journals (receiving notes). Snapshot.
	measure 'Profit for the Year (incl. Unposted)' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastPeriod = CALCULATE ( MAX ( 'GL Balances'[Period Key] ) )
				RETURN
					- CALCULATE (
						SUM ( 'GL Balances'[Closing Balance] ),
						'GL Balances'[Period Key] = LastPeriod,
						'GL Balances'[Balance View] = "including_unposted",
						'GL Account'[Balance Side] = "IS"
					)
			)
		formatString: #,0
		displayFolder: Finance\Balances

		annotation hnh_snapshot = 1

	/// Posted actual in SAR of one budget code, on the code's natural side; blank across several codes, whose sum is meaningless (Phase 3 spec section 8; receiving notes).
	measure 'IS Actual' =
			IF ( HASONEVALUE ( 'Budget Line'[Budget Line Code] ), SUM ( 'Income Statement'[Actual Posted] ) )
		formatString: #,0
		displayFolder: Finance\Statement

	/// Actual in SAR including unposted journals, of one budget code (Phase 3 spec section 8).
	measure 'IS Actual (incl. Unposted)' =
			IF ( HASONEVALUE ( 'Budget Line'[Budget Line Code] ), SUM ( 'Income Statement'[Actual Including Unposted] ) )
		formatString: #,0
		displayFolder: Finance\Statement

	/// Actual in SAR without opening-balance journals, of one budget code, for monthly trends (Phase 3 spec 6.3).
	measure 'IS Actual (excl. Opening)' =
			IF ( HASONEVALUE ( 'Budget Line'[Budget Line Code] ), SUM ( 'Income Statement'[Actual Excl Opening] ) )
		formatString: #,0
		displayFolder: Finance\Statement

	/// Most likely budget in SAR of one budget code (Phase 3 spec section 8; budget covers branches 1-6).
	measure 'IS Budget' =
			IF ( HASONEVALUE ( 'Budget Line'[Budget Line Code] ), SUM ( 'Income Statement'[Budget Most Likely] ) )
		formatString: #,0
		displayFolder: Finance\Budget

	/// Budget to compare with the actual: IS Budget, except DC_MEDICINES, which compares with the DC_MEDICINES + DC_CONSUMABLES budget (receiving notes, O-P3-8).
	measure 'IS Budget (Comparable)' =
			IF (
				HASONEVALUE ( 'Budget Line'[Budget Line Code] ),
				IF (
					SELECTEDVALUE ( 'Budget Line'[Budget Line Code] ) = "DC_MEDICINES",
					CALCULATE (
						SUM ( 'Income Statement'[Budget Most Likely] ),
						'Budget Line'[Budget Line Code] IN { "DC_MEDICINES", "DC_CONSUMABLES" }
					),
					[IS Budget]
				)
			)
		formatString: #,0
		displayFolder: Finance\Budget

	/// Actual − comparable budget in SAR of one budget code (Phase 3 spec section 8).
	measure 'Budget Variance' = [IS Actual] - [IS Budget (Comparable)]
		formatString: #,0
		displayFolder: Finance\Budget

	/// Budget variance ÷ the absolute comparable budget (Phase 3 spec section 8).
	measure 'Budget Variance %' = DIVIDE ( [Budget Variance], ABS ( [IS Budget (Comparable)] ) )
		formatString: 0.0%
		displayFolder: Finance\Budget

	/// EBITDA in SAR: the EBITDA subtotal of the income statement, posted (Phase 3 spec section 8; never re-derived in DAX).
	measure EBITDA = CALCULATE ( SUM ( 'Income Statement'[Actual Posted] ), 'Budget Line'[Budget Line Code] = "EBITDA" )
		formatString: #,0
		displayFolder: Finance\Statement

	/// Gross profit in SAR: the GROSS_PROFIT subtotal, posted (Phase 3 spec section 8).
	measure 'Gross Profit' = CALCULATE ( SUM ( 'Income Statement'[Actual Posted] ), 'Budget Line'[Budget Line Code] = "GROSS_PROFIT" )
		formatString: #,0
		displayFolder: Finance\Statement

	/// Net profit in SAR: the NET_PROFIT subtotal, posted (Phase 3 spec section 8).
	measure 'Net Profit' = CALCULATE ( SUM ( 'Income Statement'[Actual Posted] ), 'Budget Line'[Budget Line Code] = "NET_PROFIT" )
		formatString: #,0
		displayFolder: Finance\Statement

	/// EBITDA ÷ net revenue (REV_NET) (Phase 3 spec section 8).
	measure 'EBITDA Margin %' =
			DIVIDE ( [EBITDA], CALCULATE ( SUM ( 'Income Statement'[Actual Posted] ), 'Budget Line'[Budget Line Code] = "REV_NET" ) )
		formatString: 0.0%
		displayFolder: Finance\Statement

	/// Supplier spend in SAR: Σ spend_amount of AP invoice lines by accounting date (Phase 3 spec section 8).
	measure 'Supplier Spend' = SUM ( 'AP Invoice Lines'[Spend Amount] )
		formatString: #,0
		displayFolder: Finance\Payables

	/// Open payables in SAR at the last refresh, by invoice date; credit memos reduce it; filter Invoice Type for invoices only (Phase 3 spec section 8; receiving notes). Snapshot.
	measure 'Open Payables' = SUM ( 'AP Open Items'[Amount Remaining] )
		formatString: #,0
		displayFolder: Finance\Payables

		annotation hnh_snapshot = 1

	/// Open payables in SAR past their due date (days overdue above 0) at the last refresh (Phase 3 spec section 8). Snapshot.
	measure 'Overdue Payables' = CALCULATE ( SUM ( 'AP Open Items'[Amount Remaining] ), 'AP Open Items'[Days Overdue] > 0 )
		formatString: #,0
		displayFolder: Finance\Payables

		annotation hnh_snapshot = 1

	/// Median days from invoice to payment of payments that are not voided (Phase 3 spec section 8).
	measure 'Median Days to Pay' =
			CALCULATE ( MEDIAN ( 'AP Payments'[Days Invoice To Payment] ), 'AP Payments'[Is Voided] = "No" )
		formatString: #,0.0
		displayFolder: Finance\Payables

	/// Payments made on or before the due date ÷ payments, voided payments excluded (Phase 3 spec section 8).
	measure 'On-time Payment Rate %' =
			VAR Payments = CALCULATE ( COUNTROWS ( 'AP Payments' ), 'AP Payments'[Is Voided] = "No" )
			VAR OnTime =
				CALCULATE (
					COUNTROWS ( 'AP Payments' ),
					'AP Payments'[Is Voided] = "No",
					'AP Payments'[Days After Due] <= 0 && NOT ISBLANK ( 'AP Payments'[Days After Due] )
				)
			RETURN DIVIDE ( OnTime, Payments )
		formatString: 0.0%
		displayFolder: Finance\Payables

```

- [ ] **Step 4: Extend the snapshot lists**

In `ssas/HNH_Analytics/tables/Time Calculation.tmdl`, replace all five occurrences (MTD, QTD, YTD, PY YTD, Rolling 12M) of:

```
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance] ),
```

with:

```
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance], [GL Closing Balance (incl. Unposted)], [Profit for the Year], [Profit for the Year (incl. Unposted)], [Open Payables], [Overdue Payables] ),
```

- [ ] **Step 5: Sync perspectives and run the offline checks**

Run: `python ssas/tools/sync_perspectives.py`
Expected: `updated Executive.tmdl`, `updated Finance.tmdl`.

Run: `python -m pytest ssas/tools -q` and the Best Practice Analyzer command from Task 1 Step 9.
Expected: all pass (the snapshot test now expects 8 names in each list); no `type=error`.

- [ ] **Step 6: Check on the test database. Ask the user first.**

Ask the user the Task 3 Step 5 question, naming the Finance measures. Only after a yes, run `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`.
Expected: every `measure …` line PASS (26 new); exit code 0. Diagnose any FAIL as in Task 3 Step 5.

- [ ] **Step 7: Commit**

```bash
git add ssas/tests/measures/finance.json ssas/HNH_Analytics/tables/_Measures.tmdl "ssas/HNH_Analytics/tables/Time Calculation.tmdl" ssas/HNH_Analytics/perspectives
git commit -m "Add the Finance KPI measures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Workforce measures (Phase 4 spec section 7, receiving notes)

**Files:**
- Create: `ssas/tests/measures/workforce.json`
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl`, `ssas/HNH_Analytics/tables/Time Calculation.tmdl`, `ssas/HNH_Analytics/perspectives/*.tmdl`

**Interfaces:**
- Consumes: starter `[Headcount]`, `[Payroll Cost]`.
- Produces: `[FTE]`, `[Average Headcount]`, `[Average FTE]`, `[Gross Pay]`, `[Leavers]`, `[Sick Days]` (reused by the ratios here). Four new snapshot measures.

- [ ] **Step 1: Write the checks**

Create `ssas/tests/measures/workforce.json`:

```json
[
  {"name": "FTE, 2026-09", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([FTE], 'Date'[Year Month] = 202609))",
   "sql": "select sum(fte) from gold.ssas_fact_headcount_monthly where month_date_key = 20260930 and is_closed_month = 'Yes' and is_contingent = 'No'"},
  {"name": "Saudisation Rate %, 2026-09", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Saudisation Rate %], 'Date'[Year Month] = 202609))",
   "sql": "select sumIf(headcount, is_saudi = 'Yes') / sum(headcount) from gold.ssas_fact_headcount_monthly where month_date_key = 20260930 and is_closed_month = 'Yes' and is_contingent = 'No'"},
  {"name": "Average Headcount, 2026 Q3", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Average Headcount], 'Date'[Year Quarter] = 20263))",
   "sql": "select avg(h) from (select month_date_key, sum(headcount) as h from gold.ssas_fact_headcount_monthly where is_contingent = 'No' and is_closed_month = 'Yes' and month_date_key in (20260731, 20260831, 20260930) group by month_date_key)"},
  {"name": "Hires, 2026 Q3", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Hires], 'Date'[Year Quarter] = 20263))",
   "sql": "select count() from gold.ssas_fact_worker_movement where is_hire = 'Yes' and action_date_key >= 20260701 and action_date_key < 20261001"},
  {"name": "Leavers, 2026 Q3", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Leavers], 'Date'[Year Quarter] = 20263))",
   "sql": "select count() from gold.ssas_fact_worker_movement where is_leaver = 'Yes' and action_date_key >= 20260701 and action_date_key < 20261001"},
  {"name": "Voluntary Leavers, 2026 Q3", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Voluntary Leavers], 'Date'[Year Quarter] = 20263))",
   "sql": "select count() from gold.ssas_fact_worker_movement where is_voluntary_leaver = 'Yes' and action_date_key >= 20260701 and action_date_key < 20261001"},
  {"name": "Turnover Rate %, 2026 Q3", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Turnover Rate %], 'Date'[Year Quarter] = 20263))",
   "sql": "select (select count() from gold.ssas_fact_worker_movement where is_leaver = 'Yes' and action_date_key >= 20260701 and action_date_key < 20261001) / (select avg(h) from (select month_date_key, sum(headcount) as h from gold.ssas_fact_headcount_monthly where is_contingent = 'No' and is_closed_month = 'Yes' and month_date_key in (20260731, 20260831, 20260930) group by month_date_key))"},
  {"name": "Voluntary Turnover Rate %, 2026 Q3", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Voluntary Turnover Rate %], 'Date'[Year Quarter] = 20263))",
   "sql": "select (select count() from gold.ssas_fact_worker_movement where is_voluntary_leaver = 'Yes' and action_date_key >= 20260701 and action_date_key < 20261001) / (select avg(h) from (select month_date_key, sum(headcount) as h from gold.ssas_fact_headcount_monthly where is_contingent = 'No' and is_closed_month = 'Yes' and month_date_key in (20260731, 20260831, 20260930) group by month_date_key))"},
  {"name": "Gross Pay, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Gross Pay], 'Date'[Year Month] = 202608))",
   "sql": "select sum(gross_pay) from gold.ssas_fact_payroll_monthly where month_date_key = 20260801"},
  {"name": "Gross Pay (Open Payroll), 2026-09", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Gross Pay (Open Payroll)], 'Date'[Year Month] = 202609))",
   "sql": "select sum(gross_pay) from gold.ssas_fact_payroll_monthly where month_date_key = 20260901 and is_closed_payroll = 'No'"},
  {"name": "Overtime Share %, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Overtime Share %], 'Date'[Year Month] = 202608))",
   "sql": "select sumIf(p.gross_pay, c.pay_category = 'Overtime') / sum(p.gross_pay) from gold.ssas_fact_payroll_monthly as p inner join gold.ssas_dim_pay_category as c on c.pay_category_key = p.pay_category_key where p.month_date_key = 20260801"},
  {"name": "Average FTE, 2026 Q3", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Average FTE], 'Date'[Year Quarter] = 20263))",
   "sql": "select avg(f) from (select month_date_key, sum(fte) as f from gold.ssas_fact_headcount_monthly where is_contingent = 'No' and is_closed_month = 'Yes' and month_date_key in (20260731, 20260831, 20260930) group by month_date_key)"},
  {"name": "Payroll Cost per FTE, 2026 Q3", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Payroll Cost per FTE], 'Date'[Year Quarter] = 20263))",
   "sql": "select (select sum(cost_amount) from gold.ssas_fact_payroll_monthly where month_date_key in (20260701, 20260801, 20260901)) / (select avg(f) from (select month_date_key, sum(fte) as f from gold.ssas_fact_headcount_monthly where is_contingent = 'No' and is_closed_month = 'Yes' and month_date_key in (20260731, 20260831, 20260930) group by month_date_key))"},
  {"name": "Sick Days, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Sick Days], 'Date'[Year Month] = 202608))",
   "sql": "select sum(d.absence_days) from gold.ssas_fact_absence_daily as d inner join gold.ssas_dim_absence_type as t on t.absence_type_key = d.absence_type_key where t.absence_category = 'Sick' and d.date_key >= 20260801 and d.date_key < 20260901"},
  {"name": "Sick Leave Rate %, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Sick Leave Rate %], 'Date'[Year Month] = 202608))",
   "sql": "select (select sum(d.absence_days) from gold.ssas_fact_absence_daily as d inner join gold.ssas_dim_absence_type as t on t.absence_type_key = d.absence_type_key where t.absence_category = 'Sick' and d.date_key >= 20260801 and d.date_key < 20260901) / ((select sum(fte) from gold.ssas_fact_headcount_monthly where is_contingent = 'No' and is_closed_month = 'Yes' and month_date_key = 20260831) * 31)"},
  {"name": "Leave Balance (days), all branches, 2026-08 (review focus 4)", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Leave Balance (days)], 'Date'[Year Month] = 202608))",
   "sql": "select sum(end_balance) from gold.ssas_fact_leave_balance_monthly where is_latest_in_month = 'Yes' and is_closed_period = 'Yes' and accrual_period_date_key >= 20260801 and accrual_period_date_key < 20260901"},
  {"name": "Leave Balance (days) YTD equals August (review focus 3)", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Leave Balance (days)], 'Date'[Year Month] = 202608, 'Time Calculation'[Time Calculation] = \"YTD\"))",
   "sql": "select sum(end_balance) from gold.ssas_fact_leave_balance_monthly where is_latest_in_month = 'Yes' and is_closed_period = 'Yes' and accrual_period_date_key >= 20260801 and accrual_period_date_key < 20260901"},
  {"name": "Leave Liability, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Leave Liability], 'Date'[Year Month] = 202608))",
   "sql": "select sum(leave_liability_amount) from gold.ssas_fact_leave_balance_monthly where is_latest_in_month = 'Yes' and is_closed_period = 'Yes' and accrual_period_date_key >= 20260801 and accrual_period_date_key < 20260901"},
  {"name": "Current Leave Balance (days) ignores the date filter", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Current Leave Balance (days)], 'Date'[Year Month] = 202401))",
   "sql": "select sum(end_balance) from gold.ssas_fact_leave_balance_monthly where is_current_balance = 'Yes'"},
  {"name": "Current Leave Liability", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", [Current Leave Liability])",
   "sql": "select sum(leave_liability_amount) from gold.ssas_fact_leave_balance_monthly where is_current_balance = 'Yes'"},
  {"name": "Revenue per Payroll SAR, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Revenue per Payroll SAR], 'Date'[Year Month] = 202608))",
   "sql": "select sum(revenue_amount) / sum(payroll_cost) from gold.ssas_agg_staff_productivity_monthly where month_date_key = 20260801"},
  {"name": "Visits per FTE, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Visits per FTE], 'Date'[Year Month] = 202608))",
   "sql": "select sum(encounters_seen) / sum(fte) from gold.ssas_agg_staff_productivity_monthly where month_date_key = 20260801"},
  {"name": "Payroll Cost per Visit, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Payroll Cost per Visit], 'Date'[Year Month] = 202608))",
   "sql": "select sum(payroll_cost) / sum(encounters_seen) from gold.ssas_agg_staff_productivity_monthly where month_date_key = 20260801"}
]
```

- [ ] **Step 2: Run the catalogue test to verify it fails**

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: `test_checks_reference_existing_columns_and_measures` fails, listing the 22 new measure names.

- [ ] **Step 3: Add the measures**

Insert before `	column Measure`:

```
	/// Month-end FTE of the last closed month in the selection per branch, contingent workers excluded (Phase 4 spec section 7). Snapshot.
	measure FTE =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastMonth = CALCULATE ( MAX ( Headcount[Month Date Key] ), Headcount[Is Closed Month] = "Yes" )
				RETURN
					CALCULATE (
						SUM ( Headcount[FTE] ),
						Headcount[Month Date Key] = LastMonth,
						Headcount[Is Closed Month] = "Yes",
						Headcount[Is Contingent] = "No"
					)
			)
		formatString: #,0.0
		displayFolder: Workforce\Headcount

		annotation hnh_snapshot = 1

	/// Saudi headcount ÷ headcount at the last closed month (Phase 4 spec section 7). Snapshot.
	measure 'Saudisation Rate %' = DIVIDE ( CALCULATE ( [Headcount], KEEPFILTERS ( Headcount[Is Saudi] = "Yes" ) ), [Headcount] )
		formatString: 0.0%
		displayFolder: Workforce\Headcount

		annotation hnh_snapshot = 1

	/// Average month-end headcount over the closed months of the selection, from 2026 (Phase 4 spec section 7; receiving notes).
	measure 'Average Headcount' = AVERAGEX ( VALUES ( 'Date'[Year Month] ), [Headcount] )
		formatString: #,0.0
		displayFolder: Workforce\Headcount

	/// Hire movements in the period (Phase 4 spec section 7).
	measure Hires = CALCULATE ( COUNTROWS ( 'Worker Movements' ), 'Worker Movements'[Is Hire] = "Yes" )
		formatString: #,0
		displayFolder: Workforce\Movements

	/// Leaver movements in the period (Phase 4 spec section 7).
	measure Leavers = CALCULATE ( COUNTROWS ( 'Worker Movements' ), 'Worker Movements'[Is Leaver] = "Yes" )
		formatString: #,0
		displayFolder: Workforce\Movements

	/// Voluntary leaver movements in the period (Phase 4 spec section 7).
	measure 'Voluntary Leavers' = CALCULATE ( COUNTROWS ( 'Worker Movements' ), 'Worker Movements'[Is Voluntary Leaver] = "Yes" )
		formatString: #,0
		displayFolder: Workforce\Movements

	/// Leavers ÷ average month-end headcount of the period, from 2026 (Phase 4 spec section 7; receiving notes).
	measure 'Turnover Rate %' = DIVIDE ( [Leavers], [Average Headcount] )
		formatString: 0.0%
		displayFolder: Workforce\Movements

	/// Voluntary leavers ÷ average month-end headcount of the period, from 2026 (Phase 4 spec section 7).
	measure 'Voluntary Turnover Rate %' = DIVIDE ( [Voluntary Leavers], [Average Headcount] )
		formatString: 0.0%
		displayFolder: Workforce\Movements

	/// Gross pay in SAR: Σ gross_pay, parallel-run rows already excluded; open Oasis payroll included (Phase 4 spec section 7; receiving notes).
	measure 'Gross Pay' = SUM ( Payroll[Gross Pay] )
		formatString: #,0
		displayFolder: Workforce\Payroll

	/// Gross pay in SAR of payroll the branch has not closed yet; it changes until the month is closed (receiving notes).
	measure 'Gross Pay (Open Payroll)' = CALCULATE ( [Gross Pay], KEEPFILTERS ( Payroll[Is Closed Payroll] = "No" ) )
		formatString: #,0
		displayFolder: Workforce\Payroll

	/// Overtime gross pay ÷ gross pay (Phase 4 spec section 7).
	measure 'Overtime Share %' =
			DIVIDE ( CALCULATE ( [Gross Pay], KEEPFILTERS ( 'Pay Category'[Pay Category] = "Overtime" ) ), [Gross Pay] )
		formatString: 0.0%
		displayFolder: Workforce\Payroll

	/// Average month-end FTE over the closed months of the selection (Phase 4 spec section 7).
	measure 'Average FTE' = AVERAGEX ( VALUES ( 'Date'[Year Month] ), [FTE] )
		formatString: #,0.0
		displayFolder: Workforce\Headcount

	/// Payroll cost in SAR ÷ average FTE of the period (Phase 4 spec section 7).
	measure 'Payroll Cost per FTE' = DIVIDE ( [Payroll Cost], [Average FTE] )
		formatString: #,0
		displayFolder: Workforce\Payroll

	/// Counted sick-leave days up to today (receiving notes: planned absence runs into 2027).
	measure 'Sick Days' =
			CALCULATE (
				SUM ( 'Absence Days'[Absence Days] ),
				KEEPFILTERS ( 'Absence Type'[Absence Category] = "Sick" ),
				'Date'[Is Past] = "Yes"
			)
		formatString: #,0
		displayFolder: Workforce\Absence

	/// Sick days ÷ (month-end FTE × past calendar days), over months with a closed headcount (Phase 4 spec section 7).
	measure 'Sick Leave Rate %' =
			VAR Months =
				FILTER (
					ADDCOLUMNS (
						VALUES ( 'Date'[Year Month] ),
						"@Fte", [FTE],
						"@Days", CALCULATE ( COUNTROWS ( 'Date' ), 'Date'[Is Past] = "Yes" ),
						"@Sick", [Sick Days]
					),
					NOT ISBLANK ( [@Fte] )
				)
			RETURN DIVIDE ( SUMX ( Months, [@Sick] ), SUMX ( Months, [@Fte] * [@Days] ) )
		formatString: 0.0%
		displayFolder: Workforce\Absence

	/// Leave balance in days at the last closed accrual month of the selection per branch: the latest period of each employee and plan in that month (receiving notes). Snapshot.
	measure 'Leave Balance (days)' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastDate =
					CALCULATE (
						MAX ( 'Leave Balances'[Accrual Period Date Key] ),
						'Leave Balances'[Is Latest In Month] = "Yes",
						'Leave Balances'[Is Closed Period] = "Yes",
						'Date'[Is Past] = "Yes"
					)
				RETURN
					CALCULATE (
						SUM ( 'Leave Balances'[End Balance] ),
						'Leave Balances'[Is Latest In Month] = "Yes",
						'Leave Balances'[Is Closed Period] = "Yes",
						'Date'[Year Month] = INT ( LastDate / 100 )
					)
			)
		formatString: #,0.0
		displayFolder: Workforce\Leave

		annotation hnh_snapshot = 1

	/// Leave liability in SAR at the last closed accrual month of the selection per branch (receiving notes). Snapshot.
	measure 'Leave Liability' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastDate =
					CALCULATE (
						MAX ( 'Leave Balances'[Accrual Period Date Key] ),
						'Leave Balances'[Is Latest In Month] = "Yes",
						'Leave Balances'[Is Closed Period] = "Yes",
						'Date'[Is Past] = "Yes"
					)
				RETURN
					CALCULATE (
						SUM ( 'Leave Balances'[Leave Liability Amount] ),
						'Leave Balances'[Is Latest In Month] = "Yes",
						'Leave Balances'[Is Closed Period] = "Yes",
						'Date'[Year Month] = INT ( LastDate / 100 )
					)
			)
		formatString: #,0
		displayFolder: Workforce\Leave

		annotation hnh_snapshot = 1

	/// Leave balance in days at the latest closed accrual period, whatever dates are selected (receiving notes: latest-position KPI).
	measure 'Current Leave Balance (days)' =
			CALCULATE ( SUM ( 'Leave Balances'[End Balance] ), 'Leave Balances'[Is Current Balance] = "Yes", REMOVEFILTERS ( 'Date' ) )
		formatString: #,0.0
		displayFolder: Workforce\Leave

	/// Leave liability in SAR at the latest closed accrual period, whatever dates are selected (receiving notes).
	measure 'Current Leave Liability' =
			CALCULATE ( SUM ( 'Leave Balances'[Leave Liability Amount] ), 'Leave Balances'[Is Current Balance] = "Yes", REMOVEFILTERS ( 'Date' ) )
		formatString: #,0
		displayFolder: Workforce\Leave

	/// Revenue ÷ payroll cost of linked doctors and nurses, a ratio of sums (Phase 4 spec section 7; receiving notes).
	measure 'Revenue per Payroll SAR' =
			DIVIDE ( SUM ( 'Staff Productivity'[Revenue Amount] ), SUM ( 'Staff Productivity'[Payroll Cost] ) )
		formatString: #,0.00
		displayFolder: Workforce\Productivity

	/// Encounters seen ÷ FTE-months of linked doctors and nurses (Phase 4 spec section 7).
	measure 'Visits per FTE' = DIVIDE ( SUM ( 'Staff Productivity'[Encounters Seen] ), SUM ( 'Staff Productivity'[FTE] ) )
		formatString: #,0.0
		displayFolder: Workforce\Productivity

	/// Payroll cost in SAR ÷ encounters seen of linked doctors and nurses (Phase 4 spec section 7).
	measure 'Payroll Cost per Visit' =
			DIVIDE ( SUM ( 'Staff Productivity'[Payroll Cost] ), SUM ( 'Staff Productivity'[Encounters Seen] ) )
		formatString: #,0
		displayFolder: Workforce\Productivity

```

- [ ] **Step 4: Extend the snapshot lists**

In `ssas/HNH_Analytics/tables/Time Calculation.tmdl`, replace all five occurrences of:

```
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance], [GL Closing Balance (incl. Unposted)], [Profit for the Year], [Profit for the Year (incl. Unposted)], [Open Payables], [Overdue Payables] ),
```

with:

```
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance], [GL Closing Balance (incl. Unposted)], [Profit for the Year], [Profit for the Year (incl. Unposted)], [Open Payables], [Overdue Payables], [FTE], [Saudisation Rate %], [Leave Balance (days)], [Leave Liability] ),
```

- [ ] **Step 5: Sync perspectives and run the offline checks**

Run: `python ssas/tools/sync_perspectives.py`
Expected: `updated Executive.tmdl`, `updated Workforce.tmdl`.

Run: `python -m pytest ssas/tools -q` and the Best Practice Analyzer command from Task 1 Step 9.
Expected: all pass; no `type=error`.

- [ ] **Step 6: Check on the test database. Ask the user first.**

Ask the user the Task 3 Step 5 question, naming the Workforce measures. Only after a yes, run `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`.
Expected: every `measure …` line PASS (23 new); exit code 0. Diagnose any FAIL as in Task 3 Step 5. Checks of pay-restricted tables (Payroll, Leave Balances, Staff Productivity) run as the administrator, so row filters do not apply here; the security stage covers them.

- [ ] **Step 7: Commit**

```bash
git add ssas/tests/measures/workforce.json ssas/HNH_Analytics/tables/_Measures.tmdl "ssas/HNH_Analytics/tables/Time Calculation.tmdl" ssas/HNH_Analytics/perspectives
git commit -m "Add the Workforce KPI measures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Supply Chain measures (Phase 5 spec section 7, receiving notes)

**Files:**
- Create: `ssas/tests/measures/supply_chain.json`
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl`, `ssas/HNH_Analytics/tables/Time Calculation.tmdl`, `ssas/HNH_Analytics/perspectives/*.tmdl`

**Interfaces:**
- Consumes: starter `[Consumption Cost]`, `[Stock Value]`; Task 6 `[Supplier Spend]`.
- Produces: `[Last PO Unit Price]` (reused by `[PO Price Change %]`). Six new snapshot measures.

- [ ] **Step 1: Write the checks**

Create `ssas/tests/measures/supply_chain.json`:

```json
[
  {"name": "Consumption Quantity, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Consumption Quantity], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(consumption_quantity) from gold.ssas_fact_stock_movement where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and is_consumption = 'Yes'"},
  {"name": "Pharmacy Consumption Cost, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Pharmacy Consumption Cost], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(m.consumption_cost) from gold.ssas_fact_stock_movement as m inner join gold.ssas_dim_store as s on s.store_key = m.store_key inner join gold.ssas_dim_item as i on i.item_key = m.item_key where m.branch_key = 1 and m.date_key >= 20260801 and m.date_key < 20260901 and m.is_consumption = 'Yes' and (s.store_type = 'Pharmacy' or (s.store_type = 'Ward' and i.item_group = 'Medication'))"},
  {"name": "Patient Consumption Cost, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Patient Consumption Cost], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(cost_amount) from gold.ssas_fact_patient_consumption where branch_key = 1 and date_key >= 20260801 and date_key < 20260901"},
  {"name": "Drug and Supply Margin, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Drug and Supply Margin], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(revenue_amount) - sum(consumption_cost) from gold.ssas_fact_patient_consumption where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and revenue_basis = 'charge'"},
  {"name": "Drug and Supply Margin %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Drug and Supply Margin %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select (sum(revenue_amount) - sum(consumption_cost)) / sum(revenue_amount) from gold.ssas_fact_patient_consumption where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and revenue_basis = 'charge'"},
  {"name": "Package Component Cost, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Package Component Cost], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(consumption_cost) from gold.ssas_fact_patient_consumption where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and revenue_basis = 'package_component'"},
  {"name": "Days of Stock, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Days of Stock], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select (select sum(stock_value) from gold.ssas_fact_stock_monthly where branch_key = 1 and month_date_key = 20260831 and is_expiry_store = 'No') / ((select sum(consumption_cost) from gold.ssas_fact_stock_movement where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and is_consumption = 'Yes') / 31)"},
  {"name": "Days of Stock, all branches, 2026-08 (review focus 4)", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Days of Stock], 'Date'[Year Month] = 202608))",
   "sql": "select (select sum(stock_value) from gold.ssas_fact_stock_monthly where month_date_key = 20260831 and is_expiry_store = 'No') / ((select sum(consumption_cost) from gold.ssas_fact_stock_movement where date_key >= 20260801 and date_key < 20260901 and is_consumption = 'Yes' and branch_key in (select branch_key from gold.ssas_fact_stock_monthly where month_date_key = 20260831)) / 31)"},
  {"name": "Days of Stock YTD equals August (review focus 3)", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Days of Stock], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608, 'Time Calculation'[Time Calculation] = \"YTD\"))",
   "sql": "select (select sum(stock_value) from gold.ssas_fact_stock_monthly where branch_key = 1 and month_date_key = 20260831 and is_expiry_store = 'No') / ((select sum(consumption_cost) from gold.ssas_fact_stock_movement where branch_key = 1 and date_key >= 20260801 and date_key < 20260901 and is_consumption = 'Yes') / 31)"},
  {"name": "Inventory Turnover, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Inventory Turnover], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select (select sum(consumption_cost) from gold.ssas_fact_stock_movement where branch_key = 1 and is_consumption = 'Yes' and date_key >= 20250901 and date_key < 20260901) / (select avg(v) from (select month_date_key, sum(stock_value) as v from gold.ssas_fact_stock_monthly where branch_key = 1 and is_expiry_store = 'No' and month_date_key >= 20250930 and month_date_key <= 20260831 group by month_date_key))"},
  {"name": "Slow-Moving Items, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Slow-Moving Items], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select uniqExact(item_key) from gold.ssas_fact_stock_monthly where branch_key = 1 and month_date_key = 20260831 and is_expiry_store = 'No' and quantity > 0 and item_key not in (select item_key from gold.ssas_fact_stock_movement where branch_key = 1 and is_consumption = 'Yes' and date_key >= 20260603 and date_key <= 20260831)"},
  {"name": "Slow-Moving Stock Value, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Slow-Moving Stock Value], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(stock_value) from gold.ssas_fact_stock_monthly where branch_key = 1 and month_date_key = 20260831 and is_expiry_store = 'No' and quantity > 0 and item_key not in (select item_key from gold.ssas_fact_stock_movement where branch_key = 1 and is_consumption = 'Yes' and date_key >= 20260603 and date_key <= 20260831)"},
  {"name": "Dead Stock Items, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Dead Stock Items], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select uniqExact(item_key) from gold.ssas_fact_stock_monthly where branch_key = 1 and month_date_key = 20260831 and is_expiry_store = 'No' and quantity > 0 and item_key not in (select item_key from gold.ssas_fact_stock_movement where branch_key = 1 and is_consumption = 'Yes' and date_key >= 20260305 and date_key <= 20260831)"},
  {"name": "Dead Stock Value, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Dead Stock Value], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(stock_value) from gold.ssas_fact_stock_monthly where branch_key = 1 and month_date_key = 20260831 and is_expiry_store = 'No' and quantity > 0 and item_key not in (select item_key from gold.ssas_fact_stock_movement where branch_key = 1 and is_consumption = 'Yes' and date_key >= 20260305 and date_key <= 20260831)"},
  {"name": "PO Lead Time Median (days), branch 1, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([PO Lead Time Median (days)], Branch[Branch Key] = 1, 'Date'[Year] = 2026))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(lead_time_days)) from gold.ssas_fact_purchase_line where branch_key = 1 and po_date_key >= 20260101 and po_date_key < 20270101 and is_approved_po = 'Yes'"},
  {"name": "PO Lead Time Average (days), branch 1, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([PO Lead Time Average (days)], Branch[Branch Key] = 1, 'Date'[Year] = 2026))",
   "sql": "select avg(lead_time_days) from gold.ssas_fact_purchase_line where branch_key = 1 and po_date_key >= 20260101 and po_date_key < 20270101 and is_approved_po = 'Yes'"},
  {"name": "PO Fill Rate %, branch 1, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([PO Fill Rate %], Branch[Branch Key] = 1, 'Date'[Year] = 2026))",
   "sql": "select sum(quantity_received) / (sum(quantity_ordered) - sum(quantity_cancelled)) from gold.ssas_fact_purchase_line where branch_key = 1 and po_date_key >= 20260101 and po_date_key < 20270101 and is_approved_po = 'Yes'"},
  {"name": "Last PO Unit Price, one item and supplier, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Last PO Unit Price], Item[Item Key] = 3049680236030117017, Supplier[Supplier Key] = 7887068244902110179, 'Date'[Year] = 2026))",
   "sql": "select toFloat64(max(unit_price)) from gold.ssas_fact_purchase_line where item_key = 3049680236030117017 and supplier_key = 7887068244902110179 and is_approved_po = 'Yes' and po_date_key = (select max(po_date_key) from gold.ssas_fact_purchase_line where item_key = 3049680236030117017 and supplier_key = 7887068244902110179 and is_approved_po = 'Yes' and po_date_key >= 20260101 and po_date_key < 20270101)"},
  {"name": "Last PO Unit Price is blank over several items (review focus 5)", "tolerance": 0, "allow_zero": true,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Last PO Unit Price], 'Date'[Year] = 2026))",
   "sql": "select 0"},
  {"name": "PO Price Change %, one item and supplier, 2026-01 to 2026-09", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([PO Price Change %], Item[Item Key] = 3049680236030117017, Supplier[Supplier Key] = 7887068244902110179, 'Date'[Year] = 2026, 'Date'[Month] <= 9))",
   "sql": "select toFloat64((select max(unit_price) from gold.ssas_fact_purchase_line where item_key = 3049680236030117017 and supplier_key = 7887068244902110179 and is_approved_po = 'Yes' and po_date_key = (select max(po_date_key) from gold.ssas_fact_purchase_line where item_key = 3049680236030117017 and supplier_key = 7887068244902110179 and is_approved_po = 'Yes' and po_date_key >= 20260101 and po_date_key < 20261001))) / toFloat64((select max(unit_price) from gold.ssas_fact_purchase_line where item_key = 3049680236030117017 and supplier_key = 7887068244902110179 and is_approved_po = 'Yes' and po_date_key = (select max(po_date_key) from gold.ssas_fact_purchase_line where item_key = 3049680236030117017 and supplier_key = 7887068244902110179 and is_approved_po = 'Yes' and po_date_key >= 20260101 and po_date_key < (select max(po_date_key) from gold.ssas_fact_purchase_line where item_key = 3049680236030117017 and supplier_key = 7887068244902110179 and is_approved_po = 'Yes' and po_date_key >= 20260101 and po_date_key < 20261001)))) - 1"},
  {"name": "PO-Matched Spend Share %, all branches, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([PO-Matched Spend Share %], 'Date'[Year] = 2026))",
   "sql": "select sumIf(spend_amount, is_po_matched = 'Yes') / sum(spend_amount) from gold.ssas_fact_ap_invoice_line where accounting_date_key >= 20260101 and accounting_date_key < 20270101"},
  {"name": "Fusion Interface Gap %, all branches, 2026-08 (rec_stock_interface_daily)", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Fusion Interface Gap %], 'Date'[Year Month] = 202608))",
   "sql": "select sum(gap_lines) / sum(lines_from_go_live) from gold.rec_stock_interface_daily where date_key >= 20260801 and date_key < 20260901"}
]
```

- [ ] **Step 2: Run the catalogue test to verify it fails**

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: `test_checks_reference_existing_columns_and_measures` fails, listing the 19 new measure names.

- [ ] **Step 3: Add the measures**

Insert before `	column Measure`:

```
	/// Consumption quantity in primary units of consumption movements (patient sales − returns + department issues) (Phase 5 spec section 7).
	measure 'Consumption Quantity' =
			CALCULATE ( SUM ( 'Stock Movements'[Consumption Quantity] ), 'Stock Movements'[Is Consumption] = "Yes" )
		formatString: #,0
		displayFolder: Supply Chain\Consumption

	/// Consumption cost in SAR at pharmacy stores, plus medication issued from wards (Phase 5 spec section 7).
	measure 'Pharmacy Consumption Cost' =
			CALCULATE ( [Consumption Cost], KEEPFILTERS ( Store[Store Type] = "Pharmacy" ) )
				+ CALCULATE ( [Consumption Cost], KEEPFILTERS ( Store[Store Type] = "Ward" ), KEEPFILTERS ( Item[Item Group] = "Medication" ) )
		formatString: #,0
		displayFolder: Supply Chain\Consumption

	/// Recorded cost in SAR of patient consumption lines (Phase 5 spec section 7).
	measure 'Patient Consumption Cost' = SUM ( 'Patient Consumption'[Cost Amount] )
		formatString: #,0
		displayFolder: Supply Chain\Consumption

	/// Revenue − consumption cost in SAR of patient consumption lines whose revenue basis is a charge (receiving notes; package components are separate).
	measure 'Drug and Supply Margin' =
			CALCULATE (
				SUM ( 'Patient Consumption'[Revenue Amount] ) - SUM ( 'Patient Consumption'[Consumption Cost] ),
				'Patient Consumption'[Revenue Basis] = "charge"
			)
		formatString: #,0
		displayFolder: Supply Chain\Margin

	/// Margin ÷ revenue of charge-based patient consumption, a ratio of sums (Phase 5 spec section 7).
	measure 'Drug and Supply Margin %' =
			DIVIDE (
				[Drug and Supply Margin],
				CALCULATE ( SUM ( 'Patient Consumption'[Revenue Amount] ), 'Patient Consumption'[Revenue Basis] = "charge" )
			)
		formatString: 0.0%
		displayFolder: Supply Chain\Margin

	/// Consumption cost in SAR of package-component dispenses, whose revenue is on the package header (receiving notes).
	measure 'Package Component Cost' =
			CALCULATE ( SUM ( 'Patient Consumption'[Consumption Cost] ), 'Patient Consumption'[Revenue Basis] = "package_component" )
		formatString: #,0
		displayFolder: Supply Chain\Margin

	/// Stock value at the last month-end ÷ (that month's consumption cost ÷ days in the month), per branch, then summed (Phase 5 spec section 7). Snapshot.
	measure 'Days of Stock' =
			VAR DailyUse =
				SUMX (
					VALUES ( Branch[Branch Key] ),
					VAR LastMonth = CALCULATE ( MAX ( 'Stock Monthly'[Month Date Key] ) )
					RETURN DIVIDE ( CALCULATE ( [Consumption Cost], 'Date'[Year Month] = INT ( LastMonth / 100 ) ), MOD ( LastMonth, 100 ) )
				)
			RETURN DIVIDE ( [Stock Value], DailyUse )
		formatString: #,0.0
		displayFolder: Supply Chain\Stock

		annotation hnh_snapshot = 1

	/// Consumption cost of the 12 months to the last month-end ÷ average month-end stock value of those months, per branch, then summed (Phase 5 spec section 7). Snapshot.
	measure 'Inventory Turnover' =
			VAR Consumption12 =
				SUMX (
					VALUES ( Branch[Branch Key] ),
					VAR LastMonth = CALCULATE ( MAX ( 'Stock Monthly'[Month Date Key] ) )
					VAR LastDate = DATE ( INT ( LastMonth / 10000 ), MOD ( INT ( LastMonth / 100 ), 100 ), MOD ( LastMonth, 100 ) )
					RETURN IF ( NOT ISBLANK ( LastMonth ), CALCULATE ( [Consumption Cost], DATESINPERIOD ( 'Date'[Date], LastDate, -12, MONTH ) ) )
				)
			VAR AverageStock =
				SUMX (
					VALUES ( Branch[Branch Key] ),
					VAR LastMonth = CALCULATE ( MAX ( 'Stock Monthly'[Month Date Key] ) )
					VAR LastDate = DATE ( INT ( LastMonth / 10000 ), MOD ( INT ( LastMonth / 100 ), 100 ), MOD ( LastMonth, 100 ) )
					RETURN
						IF (
							NOT ISBLANK ( LastMonth ),
							CALCULATE ( AVERAGEX ( VALUES ( 'Date'[Year Month] ), [Stock Value] ), DATESINPERIOD ( 'Date'[Date], LastDate, -12, MONTH ) )
						)
				)
			RETURN DIVIDE ( Consumption12, AverageStock )
		formatString: #,0.00
		displayFolder: Supply Chain\Stock

		annotation hnh_snapshot = 1

	/// Items with stock at the last month-end and no consumption in the 90 days to it, per branch (Phase 5 spec section 7). Snapshot.
	measure 'Slow-Moving Items' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastMonth = CALCULATE ( MAX ( 'Stock Monthly'[Month Date Key] ) )
				VAR LastDate = DATE ( INT ( LastMonth / 10000 ), MOD ( INT ( LastMonth / 100 ), 100 ), MOD ( LastMonth, 100 ) )
				VAR InStock =
					CALCULATETABLE (
						VALUES ( 'Stock Monthly'[Item Key] ),
						'Stock Monthly'[Month Date Key] = LastMonth,
						'Stock Monthly'[Is Expiry Store] = "No",
						'Stock Monthly'[Quantity] > 0
					)
				VAR Consumed =
					CALCULATETABLE (
						VALUES ( 'Stock Movements'[Item Key] ),
						'Stock Movements'[Is Consumption] = "Yes",
						DATESINPERIOD ( 'Date'[Date], LastDate, -90, DAY )
					)
				RETURN IF ( NOT ISBLANK ( LastMonth ), COUNTROWS ( EXCEPT ( InStock, Consumed ) ) )
			)
		formatString: #,0
		displayFolder: Supply Chain\Stock

		annotation hnh_snapshot = 1

	/// Stock value in SAR at the last month-end of items with no consumption in the 90 days to it (Phase 5 spec section 7). Snapshot.
	measure 'Slow-Moving Stock Value' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastMonth = CALCULATE ( MAX ( 'Stock Monthly'[Month Date Key] ) )
				VAR LastDate = DATE ( INT ( LastMonth / 10000 ), MOD ( INT ( LastMonth / 100 ), 100 ), MOD ( LastMonth, 100 ) )
				VAR InStock =
					CALCULATETABLE (
						VALUES ( 'Stock Monthly'[Item Key] ),
						'Stock Monthly'[Month Date Key] = LastMonth,
						'Stock Monthly'[Is Expiry Store] = "No",
						'Stock Monthly'[Quantity] > 0
					)
				VAR Consumed =
					CALCULATETABLE (
						VALUES ( 'Stock Movements'[Item Key] ),
						'Stock Movements'[Is Consumption] = "Yes",
						DATESINPERIOD ( 'Date'[Date], LastDate, -90, DAY )
					)
				RETURN
					IF (
						NOT ISBLANK ( LastMonth ),
						CALCULATE (
							SUM ( 'Stock Monthly'[Stock Value Amount] ),
							'Stock Monthly'[Month Date Key] = LastMonth,
							'Stock Monthly'[Is Expiry Store] = "No",
							'Stock Monthly'[Quantity] > 0,
							EXCEPT ( InStock, Consumed )
						)
					)
			)
		formatString: #,0
		displayFolder: Supply Chain\Stock

		annotation hnh_snapshot = 1

	/// Items with stock at the last month-end and no consumption in the 180 days to it, per branch (Phase 5 spec section 7). Snapshot.
	measure 'Dead Stock Items' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastMonth = CALCULATE ( MAX ( 'Stock Monthly'[Month Date Key] ) )
				VAR LastDate = DATE ( INT ( LastMonth / 10000 ), MOD ( INT ( LastMonth / 100 ), 100 ), MOD ( LastMonth, 100 ) )
				VAR InStock =
					CALCULATETABLE (
						VALUES ( 'Stock Monthly'[Item Key] ),
						'Stock Monthly'[Month Date Key] = LastMonth,
						'Stock Monthly'[Is Expiry Store] = "No",
						'Stock Monthly'[Quantity] > 0
					)
				VAR Consumed =
					CALCULATETABLE (
						VALUES ( 'Stock Movements'[Item Key] ),
						'Stock Movements'[Is Consumption] = "Yes",
						DATESINPERIOD ( 'Date'[Date], LastDate, -180, DAY )
					)
				RETURN IF ( NOT ISBLANK ( LastMonth ), COUNTROWS ( EXCEPT ( InStock, Consumed ) ) )
			)
		formatString: #,0
		displayFolder: Supply Chain\Stock

		annotation hnh_snapshot = 1

	/// Stock value in SAR at the last month-end of items with no consumption in the 180 days to it (Phase 5 spec section 7). Snapshot.
	measure 'Dead Stock Value' =
			SUMX (
				VALUES ( Branch[Branch Key] ),
				VAR LastMonth = CALCULATE ( MAX ( 'Stock Monthly'[Month Date Key] ) )
				VAR LastDate = DATE ( INT ( LastMonth / 10000 ), MOD ( INT ( LastMonth / 100 ), 100 ), MOD ( LastMonth, 100 ) )
				VAR InStock =
					CALCULATETABLE (
						VALUES ( 'Stock Monthly'[Item Key] ),
						'Stock Monthly'[Month Date Key] = LastMonth,
						'Stock Monthly'[Is Expiry Store] = "No",
						'Stock Monthly'[Quantity] > 0
					)
				VAR Consumed =
					CALCULATETABLE (
						VALUES ( 'Stock Movements'[Item Key] ),
						'Stock Movements'[Is Consumption] = "Yes",
						DATESINPERIOD ( 'Date'[Date], LastDate, -180, DAY )
					)
				RETURN
					IF (
						NOT ISBLANK ( LastMonth ),
						CALCULATE (
							SUM ( 'Stock Monthly'[Stock Value Amount] ),
							'Stock Monthly'[Month Date Key] = LastMonth,
							'Stock Monthly'[Is Expiry Store] = "No",
							'Stock Monthly'[Quantity] > 0,
							EXCEPT ( InStock, Consumed )
						)
					)
			)
		formatString: #,0
		displayFolder: Supply Chain\Stock

		annotation hnh_snapshot = 1

	/// Median days from PO to first receipt of approved POs; prefer it to the average (Oasis outliers above 365 days) (Phase 5 spec section 7; receiving notes).
	measure 'PO Lead Time Median (days)' =
			CALCULATE ( MEDIAN ( 'Purchase Lines'[Lead Time Days] ), 'Purchase Lines'[Is Approved PO] = "Yes" )
		formatString: #,0.0
		displayFolder: Supply Chain\Purchasing

	/// Average days from PO to first receipt of approved POs (Phase 5 spec section 7).
	measure 'PO Lead Time Average (days)' =
			CALCULATE ( AVERAGE ( 'Purchase Lines'[Lead Time Days] ), 'Purchase Lines'[Is Approved PO] = "Yes" )
		formatString: #,0.0
		displayFolder: Supply Chain\Purchasing

	/// Quantity received ÷ (quantity ordered − quantity cancelled) of approved POs, in the ordering unit (Phase 5 spec section 7).
	measure 'PO Fill Rate %' =
			CALCULATE (
				DIVIDE (
					SUM ( 'Purchase Lines'[Quantity Received] ),
					SUM ( 'Purchase Lines'[Quantity Ordered] ) - SUM ( 'Purchase Lines'[Quantity Cancelled] )
				),
				'Purchase Lines'[Is Approved PO] = "Yes"
			)
		formatString: 0.0%
		displayFolder: Supply Chain\Purchasing

	/// Unit price of the latest approved PO line for one item and one supplier (the highest price if several lines share that date); blank otherwise (Phase 5 spec section 7).
	measure 'Last PO Unit Price' =
			IF (
				HASONEVALUE ( Item[Item Key] ) && HASONEVALUE ( Supplier[Supplier Key] ),
				VAR LastPo = CALCULATE ( MAX ( 'Purchase Lines'[PO Date Key] ), 'Purchase Lines'[Is Approved PO] = "Yes" )
				RETURN
					CALCULATE (
						MAX ( 'Purchase Lines'[Unit Price] ),
						'Purchase Lines'[PO Date Key] = LastPo,
						'Purchase Lines'[Is Approved PO] = "Yes"
					)
			)
		formatString: #,0.00
		displayFolder: Supply Chain\Purchasing

	/// Latest ÷ previous approved PO unit price − 1, for one item and one supplier (Phase 5 spec section 7).
	measure 'PO Price Change %' =
			IF (
				HASONEVALUE ( Item[Item Key] ) && HASONEVALUE ( Supplier[Supplier Key] ),
				VAR LastPo = CALCULATE ( MAX ( 'Purchase Lines'[PO Date Key] ), 'Purchase Lines'[Is Approved PO] = "Yes" )
				VAR PreviousPo =
					CALCULATE (
						MAX ( 'Purchase Lines'[PO Date Key] ),
						'Purchase Lines'[Is Approved PO] = "Yes",
						'Purchase Lines'[PO Date Key] < LastPo
					)
				VAR PreviousPrice =
					CALCULATE (
						MAX ( 'Purchase Lines'[Unit Price] ),
						'Purchase Lines'[PO Date Key] = PreviousPo,
						'Purchase Lines'[Is Approved PO] = "Yes"
					)
				VAR Ratio = DIVIDE ( [Last PO Unit Price], PreviousPrice )
				RETURN IF ( NOT ISBLANK ( PreviousPo ) && NOT ISBLANK ( Ratio ), Ratio - 1 )
			)
		formatString: 0.0%
		displayFolder: Supply Chain\Purchasing

	/// AP spend matched to POs ÷ total AP spend (Phase 5 spec section 7, with Phase 3's AP invoice lines).
	measure 'PO-Matched Spend Share %' =
			DIVIDE ( CALCULATE ( [Supplier Spend], KEEPFILTERS ( 'AP Invoice Lines'[Is PO Matched] = "Yes" ) ), [Supplier Spend] )
		formatString: 0.0%
		displayFolder: Supply Chain\Purchasing

	/// Oasis lines Fusion has not received ÷ Oasis lines from go-live (in Fusion or a gap), as rec_stock_interface_daily (Phase 5 spec section 7).
	measure 'Fusion Interface Gap %' =
			VAR Gap =
				CALCULATE ( COUNTROWS ( 'Stock Movements' ), 'Stock Movements'[Is Fusion Gap] = "Yes", 'Stock Movements'[Is In Oasis] = "Yes" )
			VAR InFusion =
				CALCULATE ( COUNTROWS ( 'Stock Movements' ), 'Stock Movements'[Source System] = "fusion", 'Stock Movements'[Is In Oasis] = "Yes" )
			RETURN DIVIDE ( Gap, Gap + InFusion )
		formatString: 0.0%
		displayFolder: Supply Chain\Interface

```

- [ ] **Step 4: Extend the snapshot lists**

In `ssas/HNH_Analytics/tables/Time Calculation.tmdl`, replace all five occurrences of:

```
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance], [GL Closing Balance (incl. Unposted)], [Profit for the Year], [Profit for the Year (incl. Unposted)], [Open Payables], [Overdue Payables], [FTE], [Saudisation Rate %], [Leave Balance (days)], [Leave Liability] ),
```

with:

```
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance], [GL Closing Balance (incl. Unposted)], [Profit for the Year], [Profit for the Year (incl. Unposted)], [Open Payables], [Overdue Payables], [FTE], [Saudisation Rate %], [Leave Balance (days)], [Leave Liability], [Days of Stock], [Inventory Turnover], [Slow-Moving Items], [Slow-Moving Stock Value], [Dead Stock Items], [Dead Stock Value] ),
```

- [ ] **Step 5: Sync perspectives and run the offline checks**

Run: `python ssas/tools/sync_perspectives.py`
Expected: `updated Executive.tmdl`, `updated Supply Chain.tmdl`.

Run: `python -m pytest ssas/tools -q` and the Best Practice Analyzer command from Task 1 Step 9.
Expected: all pass; no `type=error`.

- [ ] **Step 6: Check on the test database. Ask the user first.**

Ask the user the Task 3 Step 5 question, naming the Supply Chain measures. Only after a yes, run `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`.
Expected: every `measure …` line PASS (22 new); exit code 0. Diagnose any FAIL as in Task 3 Step 5. Also note the time of the four slow-moving and dead-stock checks in the log. If one takes over 10 s, report it: the performance budget is under 3 s cold (spec 11.5), and they may need a gold aggregate.

- [ ] **Step 7: Commit**

```bash
git add ssas/tests/measures/supply_chain.json ssas/HNH_Analytics/tables/_Measures.tmdl "ssas/HNH_Analytics/tables/Time Calculation.tmdl" ssas/HNH_Analytics/perspectives
git commit -m "Add the Supply Chain KPI measures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Patient Experience measures (Phase 6 spec section 7, receiving notes)

**Files:**
- Create: `ssas/tests/measures/patient_experience.json`
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl`, `ssas/HNH_Analytics/perspectives/*.tmdl`

**Interfaces:**
- Consumes: starter `[Invitations]`.
- Produces: `[All Invitations]`, `[NPS Answers]` (reused by the shares and NPS here).

- [ ] **Step 1: Write the checks**

Create `ssas/tests/measures/patient_experience.json`:

```json
[
  {"name": "All Invitations, 2026", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([All Invitations], 'Date'[Year] = 2026))",
   "sql": "select count() from gold.ssas_fact_survey_response where visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "SMS Reach %, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([SMS Reach %], 'Date'[Year] = 2026))",
   "sql": "select countIf(is_sms_sent = 'Yes') / count() from gold.ssas_fact_survey_response where is_primary_for_encounter = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Completion Rate %, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Completion Rate %], 'Date'[Year] = 2026))",
   "sql": "select countIf(is_submitted = 'Yes') / countIf(is_responded = 'Yes') from gold.ssas_fact_survey_response where is_primary_for_encounter = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Answer Completeness %, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Answer Completeness %], 'Date'[Year] = 2026))",
   "sql": "select sum(scored_questions_answered) / sum(scored_questions_offered) from gold.ssas_fact_survey_response where is_primary_for_encounter = 'Yes' and is_responded = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Median Days Visit to Answer, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Median Days Visit to Answer], 'Date'[Year] = 2026))",
   "sql": "select quantileExactInclusive(0.5)(toFloat64(days_visit_to_answer)) from gold.ssas_fact_survey_response where is_primary_for_encounter = 'Yes' and is_responded = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Encounter Link %, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Encounter Link %], 'Date'[Year] = 2026))",
   "sql": "select countIf(link_status = 'Linked') / count() from gold.ssas_fact_survey_response where is_primary_for_encounter = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Doctor Attribution %, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Doctor Attribution %], 'Date'[Year] = 2026))",
   "sql": "select countIf(staff_key <> -1) / count() from gold.ssas_fact_survey_response where is_primary_for_encounter = 'Yes' and is_responded = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Repeat Invitation Rate %, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Repeat Invitation Rate %], 'Date'[Year] = 2026))",
   "sql": "select countIf(is_primary_for_encounter = 'No') / count() from gold.ssas_fact_survey_response where visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Physician NPS (5-point), 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Physician NPS (5-point)], 'Date'[Year] = 2026))",
   "sql": "select (sum(is_promoter) - sum(is_detractor)) * 100 / count() from gold.ssas_fact_survey_answer where nps_role = 'Physician NPS' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "NPS (5-point), all scored answers, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([NPS (5-point)], 'Date'[Year] = 2026))",
   "sql": "select (sum(is_promoter) - sum(is_detractor)) * 100 / count() from gold.ssas_fact_survey_answer where is_scored = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "NPS (5-point), branch 1, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([NPS (5-point)], Branch[Branch Key] = 1, 'Date'[Year] = 2026))",
   "sql": "select (sum(is_promoter) - sum(is_detractor)) * 100 / count() from gold.ssas_fact_survey_answer where branch_key = 1 and is_scored = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "NPS Answers, 2026", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([NPS Answers], 'Date'[Year] = 2026))",
   "sql": "select count() from gold.ssas_fact_survey_answer where is_scored = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "% Promoters, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([% Promoters], 'Date'[Year] = 2026))",
   "sql": "select sum(is_promoter) / count() from gold.ssas_fact_survey_answer where is_scored = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "% Passives, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([% Passives], 'Date'[Year] = 2026))",
   "sql": "select sum(is_passive) / count() from gold.ssas_fact_survey_answer where is_scored = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "% Detractors, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([% Detractors], 'Date'[Year] = 2026))",
   "sql": "select sum(is_detractor) / count() from gold.ssas_fact_survey_answer where is_scored = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"}
]
```

- [ ] **Step 2: Run the catalogue test to verify it fails**

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: `test_checks_reference_existing_columns_and_measures` fails, listing the 14 new measure names.

- [ ] **Step 3: Add the measures**

Insert before `	column Measure`:

```
	/// Every survey invitation, primary or repeat (Phase 6 spec 7.1, secondary measure).
	measure 'All Invitations' = COUNTROWS ( 'Survey Responses' )
		formatString: #,0
		displayFolder: Patient Experience\Survey Quality

	/// Primary invitations with an SMS sent ÷ primary invitations (Phase 6 spec 7.1).
	measure 'SMS Reach %' = DIVIDE ( CALCULATE ( [Invitations], 'Survey Responses'[Is SMS Sent] = "Yes" ), [Invitations] )
		formatString: 0.0%
		displayFolder: Patient Experience\Survey Quality

	/// Submitted ÷ responded primary invitations (Phase 6 spec 7.1).
	measure 'Completion Rate %' =
			DIVIDE (
				CALCULATE ( [Invitations], 'Survey Responses'[Is Submitted] = "Yes" ),
				CALCULATE ( [Invitations], 'Survey Responses'[Is Responded] = "Yes" )
			)
		formatString: 0.0%
		displayFolder: Patient Experience\Survey Quality

	/// Scored questions answered ÷ offered, over responded primary invitations (Phase 6 spec 7.1).
	measure 'Answer Completeness %' =
			CALCULATE (
				DIVIDE ( SUM ( 'Survey Responses'[Scored Questions Answered] ), SUM ( 'Survey Responses'[Scored Questions Offered] ) ),
				'Survey Responses'[Is Primary For Encounter] = "Yes",
				'Survey Responses'[Is Responded] = "Yes"
			)
		formatString: 0.0%
		displayFolder: Patient Experience\Survey Quality

	/// Median days from visit to answer of responded primary invitations; only submitted surveys have it (Phase 6 spec 7.1; receiving notes).
	measure 'Median Days Visit to Answer' =
			CALCULATE (
				MEDIAN ( 'Survey Responses'[Days Visit To Answer] ),
				'Survey Responses'[Is Primary For Encounter] = "Yes",
				'Survey Responses'[Is Responded] = "Yes"
			)
		formatString: #,0.0
		displayFolder: Patient Experience\Survey Quality

	/// Primary invitations linked to an encounter ÷ primary invitations (Phase 6 spec 7.1).
	measure 'Encounter Link %' =
			DIVIDE ( CALCULATE ( [Invitations], KEEPFILTERS ( 'Survey Responses'[Link Status] = "Linked" ) ), [Invitations] )
		formatString: 0.0%
		displayFolder: Patient Experience\Survey Quality

	/// Responded primary invitations with a known doctor ÷ responded primary invitations (Phase 6 spec 7.1; receiving notes: staff_key <> -1).
	measure 'Doctor Attribution %' =
			VAR Responded = CALCULATE ( [Invitations], 'Survey Responses'[Is Responded] = "Yes" )
			VAR Attributed =
				CALCULATE ( [Invitations], 'Survey Responses'[Is Responded] = "Yes", 'Survey Responses'[Staff Key] <> -1 )
			RETURN DIVIDE ( Attributed, Responded )
		formatString: 0.0%
		displayFolder: Patient Experience\Survey Quality

	/// Repeat (non-primary) invitations ÷ all invitations (Phase 6 spec 7.1).
	measure 'Repeat Invitation Rate %' =
			DIVIDE ( CALCULATE ( [All Invitations], 'Survey Responses'[Is Primary For Encounter] = "No" ), [All Invitations] )
		formatString: 0.0%
		displayFolder: Patient Experience\Survey Quality

	/// Physician NPS on the 5-point question: (promoters − detractors) ÷ answers × 100; under 30 answers shows "insufficient sample" (Phase 6 spec 7.2).
	measure 'Physician NPS (5-point)' =
			VAR Answers = CALCULATE ( COUNTROWS ( 'Survey Answers' ), 'Survey Answers'[NPS Role] = "Physician NPS" )
			VAR Net =
				CALCULATE (
					SUM ( 'Survey Answers'[Is Promoter] ) - SUM ( 'Survey Answers'[Is Detractor] ),
					'Survey Answers'[NPS Role] = "Physician NPS"
				)
			RETURN IF ( Answers > 0, DIVIDE ( Net, Answers ) * 100 )
		displayFolder: Patient Experience\NPS
	
		formatStringDefinition =
				VAR Answers = CALCULATE ( COUNTROWS ( 'Survey Answers' ), 'Survey Answers'[NPS Role] = "Physician NPS" )
				RETURN IF ( Answers < 30, """insufficient sample""", "0.0" )

	/// NPS of any selection (domain, question, doctor, specialty) over scored answers; under 30 answers shows "insufficient sample" (Phase 6 spec 7.2).
	measure 'NPS (5-point)' =
			VAR Answers = [NPS Answers]
			VAR Net =
				CALCULATE (
					SUM ( 'Survey Answers'[Is Promoter] ) - SUM ( 'Survey Answers'[Is Detractor] ),
					'Survey Answers'[Is Scored] = "Yes"
				)
			RETURN IF ( Answers > 0, DIVIDE ( Net, Answers ) * 100 )
		displayFolder: Patient Experience\NPS
	
		formatStringDefinition =
				IF ( [NPS Answers] < 30, """insufficient sample""", "0.0" )

	/// Scored answers (n), shown next to every NPS (Phase 6 spec 7.2).
	measure 'NPS Answers' = CALCULATE ( COUNTROWS ( 'Survey Answers' ), 'Survey Answers'[Is Scored] = "Yes" )
		formatString: #,0
		displayFolder: Patient Experience\NPS

	/// Promoter answers ÷ scored answers (Phase 6 spec 7.2).
	measure '% Promoters' = DIVIDE ( CALCULATE ( SUM ( 'Survey Answers'[Is Promoter] ), 'Survey Answers'[Is Scored] = "Yes" ), [NPS Answers] )
		formatString: 0.0%
		displayFolder: Patient Experience\NPS

	/// Passive answers ÷ scored answers (Phase 6 spec 7.2).
	measure '% Passives' = DIVIDE ( CALCULATE ( SUM ( 'Survey Answers'[Is Passive] ), 'Survey Answers'[Is Scored] = "Yes" ), [NPS Answers] )
		formatString: 0.0%
		displayFolder: Patient Experience\NPS

	/// Detractor answers ÷ scored answers (Phase 6 spec 7.2).
	measure '% Detractors' = DIVIDE ( CALCULATE ( SUM ( 'Survey Answers'[Is Detractor] ), 'Survey Answers'[Is Scored] = "Yes" ), [NPS Answers] )
		formatString: 0.0%
		displayFolder: Patient Experience\NPS

```

The line between `displayFolder` and `formatStringDefinition` is a single tab, as in the starter `Hospital NPS (5-point)`.

- [ ] **Step 4: Sync perspectives and run the offline checks**

Run: `python ssas/tools/sync_perspectives.py`
Expected: `updated Executive.tmdl`, `updated Patient Experience.tmdl`.

Run: `python -m pytest ssas/tools -q` and the Best Practice Analyzer command from Task 1 Step 9.
Expected: all pass (including `test_nps_measures_show_insufficient_sample`); no `type=error`.

- [ ] **Step 5: Check on the test database. Ask the user first.**

Ask the user the Task 3 Step 5 question, naming the Patient Experience measures. Only after a yes, run `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`.
Expected: every `measure …` line PASS (15 new; 193 checks in total); exit code 0. Diagnose any FAIL as in Task 3 Step 5.

- [ ] **Step 6: Commit**

```bash
git add ssas/tests/measures/patient_experience.json ssas/HNH_Analytics/tables/_Measures.tmdl ssas/HNH_Analytics/perspectives
git commit -m "Add the Patient Experience KPI measures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Record the decisions and promote

**Files:**
- Modify: `docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md` (section 14 table, the "Parked for the KPI catalogue plan" paragraph)
- Modify: `ssas/README.md` (measure count line, if any)

**Interfaces:**
- Consumes: everything above.
- Produces: the promoted model and the decision record.

- [ ] **Step 1: Record the decisions in the spec**

Append these rows to the section 14 table of the SSAS spec (after P27):

```
| P28 | 8.1 | The KPI catalogue plan (`plans/2026-10-11-ssas-kpi-catalogue.md`) adds 161 measures to the 16 starter measures. Six KPIs wait for a gold change: Orders, order-line Census and Contribution (distinct counts over 58.8M order lines, rule 8.2.2), Paid headcount (`paid_person_key` not in the payroll view), Near-expiry stock (no lot-level stock) and ABC class (an item attribute) | Each needs a gold aggregate or a view column; listed in the plan's "Deferred KPIs" |
| P29 | 8.3 | Balance last year, change and change % are the Time Calculation items PY, YoY Δ and YoY %, not separate measures | YoY % already divides by the absolute prior value and is blank without one |
| P30 | 8.2.4, 8.3 | A snapshot measure carries `annotation hnh_snapshot = 1`; `ssas/tools/test_measure_catalogue.py` keeps the five `ISSELECTEDMEASURE` lists equal to the annotated measures (18 at the end of the plan) | A snapshot missing from the list would be summed over months under YTD |
| P31 | 8.2 | Defaults the user can override (`Is Inpatient` = No for order fulfilment, `Scenario` = most_likely for targets) are a `FILTER ( ALL ( <column> ), IF ( ISFILTERED ( <column> ), <column> IN VALUES ( <column> ), <column> = <default> ) )` filter; pre-auth measures exclude payer advances with `KEEPFILTERS` | A selected value replaces the default instead of adding to it |
| P32 | 8.2.6 | Income-statement detail measures (`IS Actual`, `IS Budget`, …) are blank unless one budget code is in context; `IS Budget (Comparable)` compares DC_MEDICINES with the DC_MEDICINES + DC_CONSUMABLES budget | Receiving notes: a sum across codes is meaningless; O-P3-8 comparison |
| P33 | 8.2.6 | `Remitted` excludes advances (`Detail Type = advance` → `Payer Advances`); `Median Days to Payment` is blank unless one payment month is selected | Receiving notes: advances are not remittance; medians per payment month only |
| P34 | 11.2 | Every measure outside Diagnostics has at least one check in `ssas/tests/measures/*.json`; a check where SSAS and ClickHouse both return 0 fails unless it sets `allow_zero` | Blank becomes 0 in `Get-HnhScalar`, so two empty answers proved nothing |
| P35 | 10.2 | `deploy.ps1 -Stage TestMeasures` deploys metadata to `HNH_Analytics_Test` keeping its partitions, loads what is not processed and runs the measure checks | A measure change needs no full process of the test database |
| P36 | 7 | `ssas/tools/sync_perspectives.py` rewrites the perspectives' measure lists offline; generate.py writes the same blocks | The server has no `clickhouse_connect`, and measures change more often than views |
```

In the paragraph that starts "Parked for the KPI catalogue plan or the server run:", leave the parked items as they are and add one sentence at the end: "The KPI catalogue plan did not change them."

- [ ] **Step 2: Run every offline check**

Run: `python -m pytest ssas/tools -q`
Run: `powershell -NoProfile -Command "Invoke-Pester -Script ssas\scripts"`
Run: `& 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe' ssas\HNH_Analytics -A ssas\bpa_rules.json -V`
Expected: all pass; no `type=error`.

- [ ] **Step 3: Commit the record**

```bash
git add docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md ssas/README.md
git commit -m "Record the KPI catalogue decisions in the SSAS spec

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Full deployment to production. Ask the user first.**

Ask the user: "May I run `deploy.ps1 -Stage All`? It runs the Best Practice Analyzer, then deploys to `HNH_Analytics_Test`, fully processes it (about 1.5 hours) and runs every test: row counts, security as the test users, all 193 measure checks, performance and size. If they all pass, it backs up `HNH_Analytics`, deploys the same model to production and clears the test database. Report users keep the old model until the promotion commits. Rollback is `deploy.ps1 -Stage Rollback -BackupFile <latest .abf>`."

Only after a yes, run: `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage All`
Expected: `PASS` on every test line, `loaded 0 unprocessed partition(s)` on promote (only measures, perspectives and the calculation group changed), `Promoted.`, exit code 0. Then the user merges `ssas-kpi-catalogue` into `main` and tags the commit `ssas-2026.MM.DD`. The performance stage times one card and one matrix per perspective. A FAIL there blocks the promotion: report which query and its time.
