# Phase 6 — Patient Experience: Press Ganey Surveys, NPS and Survey Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the patient-experience gold layer: Press Ganey staging, two reviewed reference maps (NPS question per service, conformed background answers), the survey-to-encounter link, a question and a service dimension, a response fact (one row per invitation, survey-quality and NPS columns, background attributes) and an answer fact (one row per answered question with the NPS-style band), plus a reconciliation model and monitors.

**Architecture:** `press_ganey` tables are staged with `final` (responses) and the `responses` JSON is expanded once in `stg_pg__survey_answer`. `int_survey_encounter_link` resolves each invitation to `fact_encounter` (branch + encounter type from the id prefix + Oasis id) and to the doctor; `int_survey_background` pivots the background answers through the two maps. The response fact joins both and derives status, primary invitation and NPS; the answer fact copies the response keys so domain-by-doctor NPS reads one table. Rules are `hnh_` macros tested with literals; multi-row rules are dbt unit tests with SQL fixtures.

**Tech Stack:** ClickHouse 26.5, dbt-core 1.11.12, dbt-clickhouse 1.9.8, Python 3.13 with `clickhouse_connect`.

**Spec:** `docs/superpowers/specs/2026-10-07-hnh-dwh-phase6-patient-experience-design.md` (parent: `2026-10-01-hnh-dwh-gold-layer-design.md`, section 13.1)

**Prerequisite:** Phases 1–5 are on `main` and `python scripts/run_dbt.py build --select tag:hnh` passes. Work happens on branch `phase6-patient-experience` (created; the spec is committed there).

## Global Constraints

- All earlier-phase constraints apply: databases `stg` / `int` / `gold`; never write to `oasis`, `fusion`, `press_ganey`; models, macros and tests only under `hnh/` folders; macros prefixed `hnh_`; no packages, no seeds; `branch_id` / `branch_key` are `UInt8`; keys through `hnh_surrogate_key`; YAML uses the `tests:` key.
- **A ClickHouse SETTINGS clause after `union all` binds only to the last branch.** Every CTE (or union branch) that contains a left join whose NULLs matter ends with its own `{{ hnh_settings() }}` and a one-line comment; every model with a left join keeps its trailing `{{ hnh_settings() }}`. The SQL below already does this; keep it.
- **Sort-key columns are non-Nullable.** Fact dimension keys are never null (missing → `-1`; `survey_service_key` / `question_key` missing → `'-1'`).
- **Alias shadowing.** In ClickHouse a select alias equal to a source column used inside an aggregate of the same select fails with ILLEGAL_AGGREGATION (error 184); an alias equal to a column also replaces that column in later expressions of the same select. The SQL below uses distinct aliases (`k_*`, `e_*`, `st_*`, `n_*`, `s_*`, `g_*`); keep them.
- Press Ganey tables are read only through `source('press_ganey', ...)`: `pg_survey_responses` and `dim_pg_service` with `final` (ReplacingMergeTree), `pg_survey_questions` and `pg_survey_answer_options` without (plain MergeTree, unique per key — measured). Never read the source's own views (`pg_survey_answers`, `pg_survey_answers_detail`, `*_v`). Reference tables only through `source('reference', ...)`.
- Run dbt only through `python scripts/run_dbt.py <dbt args>` from the repository root; add `--no-partial-parse` after YAML or unit-test edits. Ad hoc reads through `scripts/ch_env.py` (`from ch_env import client`); never the machine-wide `CLICKHOUSE_PASSWORD`.
- Names checked against the receiving project's `dbt/models`: there is no `press_ganey` source and no model named `stg_pg__*`, `int_survey_*`, `dim_survey_*`, `fact_survey_*` or `rec_survey_monthly`, so no `hnh_` prefix or alias is needed (this closes spec open item O-P6-6).
- Every fact has `_loaded_at` (`now()`), engine `MergeTree`, and an `order_by` starting with `branch_key`.
- Reference CSVs under `static_mappings/` are git-ignored (`*.csv`) and never committed; the draft script is committed; `scripts/load_reference_data.py` never overwrites a table that has rows.
- **Unit tests** live in `*_unit_tests.yml`, use `format: sql`, mock every `ref()` of the model with only the columns it reads. **Fixtures cannot call `hnh_` macros.** Every unit test and singular test below was run against the model SQL with these exact fixtures during planning (read-only, models rendered outside dbt) and returned the expected rows.
- Commit messages end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (the commit commands below pass it as a second `-m`).
- Counts quoted as "measured" were read on 2026-10-07 and grow daily; a build within about 2% of them, or above them by the days since, is correct. Report every measured count you are asked to record.

### Spec refinements made while planning

| Spec says | Plan does | Why (measured 2026-10-07) |
|---|---|---|
| `response_status` Submitted = source status `submitted` | Submitted = `submitted` **and** at least one answer; a `submitted` survey without answers is Not started (`source_status` keeps the source value) | 84 `submitted` surveys carry no answer; counting them would push completion rate (submitted ÷ responded) above the true value. |
| Response rate % = responded ÷ invitations with an SMS sent | Response rate % = responded ÷ invitations (primary); SMS reach stays a separate measure | 8,259 of 24,968 submitted surveys have no `sms_send_date` (Muhayil: all 77 invitations), so they were answered through another channel; an SMS denominator would exclude answered surveys. |
| O-P6-2: outpatient rehab links only 50%, to be investigated | Closed: every branch-service-month (100+ invitations) under 80% link rate is Khamis (2), December 2025 to July 2026, services OP, DEN and OR — the known appointment gap (O-P6-1). `warn_survey_link_rate` leaves that window out | `rec_survey_monthly` rendered on live data: 24 cells below 80%, all branch 2. |
| `map_pg_question_role` about 40 rows | 61 rows: 16 NPS (13 Hospital, 3 Physician) and 45 attribute rows | `hl_disclaimer` and `filling` exist per service. |
| `map_pg_background_value` about 103 rows | 104 rows: the 103 workbook options plus LTC `csurvey` code `2` → `Family member` | LTC `csurvey` code 2 is answered 92 times but has no option row; code 4 (Family member) is never used. Drafted for review (O-P6-7); the answer fact flags it `is_option_unknown`. |
| Booking channel: Call centre, Reception, Online, Walk-in, Referral | Adds `Appointment` | OR `visadvan` answer 1 is "Appointment" with no channel. |
| Background attribute: value or `Not answered` | Adds `Unmapped` for an answered code with no row in `map_pg_background_value` | An unreviewed new code must not look like "Not answered". None today. |
| Answer fact about 740K rows | 739,968 | The 54 `initial_response` values are skipped (spec P2). |
| — | `contact_consent` is always `Not answered` today | No `hl_disclaimer` answer is non-null in the source; the column is kept for when the consent box is used. |

## Review Focus

1. **A patient invited several times for one visit** (79,801 encounters): exactly one primary invitation, and it is the answered one even when a later invitation exists (A1 older + answered beats A2 newer + not started). Pinned in Task 6 (`fact_survey_response_status_primary_and_nps`).
2. **A 0–10 answer read as its raw code** (code 11 = score 10, code 7 = score 6): band from the option score, not the code. Pinned in Task 7 (`fact_survey_answer_scores_and_bands`, D1/D2).
3. **An outpatient survey whose Oasis id equals an ER visit id in the same branch**: no link (prefix decides the encounter type). Pinned in Task 4 (`int_survey_encounter_link_resolves_encounter_and_doctor`, S5).
4. **A `submitted` survey with no answers**: Not started, not submitted, so completion rate is not inflated. Pinned in Task 6 (B1).
5. **A question code whose meaning differs by survey** (`o3` = recommend in IP, overall rating in OP) and **an answer code missing from the option master** (LTC `csurvey` 2): NPS role from the map per service (C1/D1 in Task 6, D1 `IP|o3` in Task 7), unknown code flagged without a score (L1 in Task 7).

## File Structure

```
scripts/draft_pg_maps.py                              draft map_pg_question_role and map_pg_background_value CSVs
scripts/load_reference_data.py                        + map_pg_question_role, map_pg_background_value
static_mappings/ (git-ignored)                        pg_question_role.csv, pg_background_value.csv
hnh_dwh/macros/hnh/hnh_rules_experience.sql           hnh_survey_band, hnh_survey_encounter_type, hnh_survey_source_id
hnh_dwh/tests/hnh/assert_hnh_experience_macros.sql, assert_survey_hospital_nps_per_service.sql, warn_survey_link_rate.sql
hnh_dwh/models/hnh/staging/reference/                 + stg_ref__pg_question_role, stg_ref__pg_background_value (+ YAML entries)
hnh_dwh/models/hnh/staging/press_ganey/               _press_ganey__sources.yml, _press_ganey__models.yml, stg_pg__survey_response,
                                                        stg_pg__survey_answer, stg_pg__survey_question, stg_pg__answer_option, stg_pg__service
hnh_dwh/models/hnh/intermediate/experience/           int_survey_encounter_link, int_survey_background, _experience__models.yml,
                                                        _experience_unit_tests.yml
hnh_dwh/models/hnh/marts/experience/                  dim_survey_service, dim_survey_question, fact_survey_response, fact_survey_answer,
                                                        _experience_marts__models.yml, _experience_marts_unit_tests.yml
hnh_dwh/models/hnh/marts/reconciliation/              + rec_survey_monthly (+ YAML entry)
docs/reconciliation_phase6.md, docs/receiving_project_config.md, spec section 11, parent spec O10
```

No change to `hnh_dwh/dbt_project.yml`: the new folders inherit the `staging` / `intermediate` / `marts` configs, and no var is needed.

---

### Task 1: Experience macros

**Files:**
- Create: `hnh_dwh/macros/hnh/hnh_rules_experience.sql`, `hnh_dwh/tests/hnh/assert_hnh_experience_macros.sql`

**Interfaces:**
- Produces: `hnh_survey_band(scale_type, score)` → Nullable String `'Promoter'` / `'Passive'` / `'Detractor'`; `hnh_survey_encounter_type(encounter_id)` → Nullable String `'OP'` / `'ER'` / `'IP'`; `hnh_survey_source_id(encounter_id)` → Nullable Int64.
- Scale types (exact strings from `pg_survey_questions.scale_type`): `rating_1_5`, `agree_1_5`, `definitely_1_4`, `likelihood_0_10`, `categorical`, `checkbox`.

- [ ] **Step 1: Write the failing macro test**

`hnh_dwh/tests/hnh/assert_hnh_experience_macros.sql` (bands from spec X1–X3; ids are real Press Ganey encounter ids):

```sql
{% set null_s = "cast(null as Nullable(String))" %}
{% set null_f = "cast(null as Nullable(Float64))" %}

select 'band 1-5 wrong' as failure
where not ({{ hnh_survey_band("'rating_1_5'", 'toFloat64(5)') }} = 'Promoter' and {{ hnh_survey_band("'rating_1_5'", 'toFloat64(4)') }} = 'Promoter'
       and {{ hnh_survey_band("'rating_1_5'", 'toFloat64(3)') }} = 'Passive' and {{ hnh_survey_band("'rating_1_5'", 'toFloat64(2)') }} = 'Detractor'
       and {{ hnh_survey_band("'rating_1_5'", 'toFloat64(1)') }} = 'Detractor' and {{ hnh_survey_band("'agree_1_5'", 'toFloat64(4)') }} = 'Promoter'
       and {{ hnh_survey_band("'agree_1_5'", 'toFloat64(3)') }} = 'Passive' and {{ hnh_survey_band("'agree_1_5'", 'toFloat64(2)') }} = 'Detractor')

union all
select 'band 1-4 wrong'
where not ({{ hnh_survey_band("'definitely_1_4'", 'toFloat64(4)') }} = 'Promoter' and {{ hnh_survey_band("'definitely_1_4'", 'toFloat64(3)') }} = 'Promoter'
       and {{ hnh_survey_band("'definitely_1_4'", 'toFloat64(2)') }} = 'Detractor' and {{ hnh_survey_band("'definitely_1_4'", 'toFloat64(1)') }} = 'Detractor')

union all
select 'band 0-10 wrong'
where not ({{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(10)') }} = 'Promoter' and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(8)') }} = 'Promoter'
       and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(7)') }} = 'Passive' and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(5)') }} = 'Passive'
       and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(4)') }} = 'Detractor' and {{ hnh_survey_band("'likelihood_0_10'", 'toFloat64(0)') }} = 'Detractor')

union all
select 'band null handling wrong'
where not ({{ hnh_survey_band("'rating_1_5'", null_f) }} is null and {{ hnh_survey_band("'categorical'", 'toFloat64(1)') }} is null
       and {{ hnh_survey_band(null_s, 'toFloat64(5)') }} is null)

union all
select 'encounter type wrong'
where not ({{ hnh_survey_encounter_type("'o135025664'") }} = 'OP' and {{ hnh_survey_encounter_type("'e162062201'") }} = 'ER'
       and {{ hnh_survey_encounter_type("'i183761712'") }} = 'IP' and {{ hnh_survey_encounter_type("'x12'") }} is null
       and {{ hnh_survey_encounter_type("'o'") }} is null and {{ hnh_survey_encounter_type("'o12a'") }} is null
       and {{ hnh_survey_encounter_type(null_s) }} is null)

union all
select 'source id wrong'
where not ({{ hnh_survey_source_id("'o135025664'") }} = 135025664 and {{ hnh_survey_source_id("'i7'") }} = 7
       and {{ hnh_survey_source_id("'x12'") }} is null and {{ hnh_survey_source_id("'e'") }} is null
       and {{ hnh_survey_source_id(null_s) }} is null)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_experience_macros`
Expected: compilation error — `'hnh_survey_band' is undefined`.

- [ ] **Step 3: Write the macros**

`hnh_dwh/macros/hnh/hnh_rules_experience.sql`:

```sql
{# NPS-style band of a scored answer (spec X1-X3). Every scale is oriented higher = better. The 1-4 scale has no
   passive. score is the option score from pg_survey_answer_options, never the raw answer code (spec P4). #}
{% macro hnh_survey_band(scale_type, score) -%}
multiIf({{ score }} is null, cast(null as Nullable(String)),
        ifNull({{ scale_type }}, '') in ('rating_1_5', 'agree_1_5'),
            multiIf({{ score }} >= 4, 'Promoter', {{ score }} >= 3, 'Passive', 'Detractor'),
        ifNull({{ scale_type }}, '') = 'definitely_1_4',
            if({{ score }} >= 3, 'Promoter', 'Detractor'),
        ifNull({{ scale_type }}, '') = 'likelihood_0_10',
            multiIf({{ score }} >= 8, 'Promoter', {{ score }} >= 5, 'Passive', 'Detractor'),
        cast(null as Nullable(String)))
{%- endmacro %}

{# Encounter type of a Press Ganey encounter id from its prefix letter: o = OP, e = ER, i = IP (spec P6). #}
{% macro hnh_survey_encounter_type(encounter_id) -%}
multiIf(match(ifNull({{ encounter_id }}, ''), '^o[0-9]+$'), 'OP',
        match(ifNull({{ encounter_id }}, ''), '^e[0-9]+$'), 'ER',
        match(ifNull({{ encounter_id }}, ''), '^i[0-9]+$'), 'IP',
        cast(null as Nullable(String)))
{%- endmacro %}

{# Oasis id in a Press Ganey encounter id (appointment id, ER visit id or admission no); null when malformed. #}
{% macro hnh_survey_source_id(encounter_id) -%}
if(match(ifNull({{ encounter_id }}, ''), '^[oei][0-9]+$'), toInt64OrNull(substring({{ encounter_id }}, 2)), cast(null as Nullable(Int64)))
{%- endmacro %}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python scripts/run_dbt.py test --select assert_hnh_experience_macros`
Expected: `PASS=1`.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_experience.sql hnh_dwh/tests/hnh/assert_hnh_experience_macros.sql
git commit -m "Add patient-experience rule macros" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Question-role and background-value reference maps

**Files:**
- Create: `scripts/draft_pg_maps.py`; git-ignored data `static_mappings/pg_question_role.csv`, `static_mappings/pg_background_value.csv` (generated)
- Modify: `scripts/load_reference_data.py`, `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`, `_reference__models.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__pg_question_role.sql`, `stg_ref__pg_background_value.sql`

**Interfaces:**
- Produces: `stg_ref__pg_question_role(service_code String, question_code String, role String)`; `stg_ref__pg_background_value(service_code String, question_code String, answer_code String, conformed_value String)`.
- Roles (exact strings): `Hospital NPS`, `Physician NPS`, `respondent`, `first_visit`, `booking_channel`, `admitted_via_er`, `used_lab`, `used_radiology`, `used_pharmacy`, `used_insurance_office`, `used_physio`, `used_speech`, `treatment_complete`, `meds_delivered`, `tele_spared_visit`, `tele_channel`, `hhc_service`, `dental_service`, `dialysis_done`, `contact_consent`.
- Conformed values: respondent `Patient` / `Parent or guardian` / `Family member` / `Other`; booking channel `Call centre` / `Reception` / `Online` / `Walk-in` / `Referral` / `Appointment`; Yes/No roles `Yes` / `No`; `dental_service`, `hhc_service`, `tele_channel` the English option label without its routing note.

- [ ] **Step 1: Declare the sources and write the failing tests**

Append to the `reference` source `tables:` in `_reference__sources.yml`:

```yaml
      - name: map_pg_question_role
      - name: map_pg_background_value
```

Append to `_reference__models.yml`:

```yaml
  - name: stg_ref__pg_question_role
    tests:
      - hnh_unique_combination:
          columns: [service_code, question_code]
    columns:
      - name: role
        tests:
          - accepted_values:
              values: ['Hospital NPS', 'Physician NPS', 'respondent', 'first_visit', 'booking_channel', 'admitted_via_er',
                       'used_lab', 'used_radiology', 'used_pharmacy', 'used_insurance_office', 'used_physio', 'used_speech',
                       'treatment_complete', 'meds_delivered', 'tele_spared_visit', 'tele_channel', 'hhc_service',
                       'dental_service', 'dialysis_done', 'contact_consent']
  - name: stg_ref__pg_background_value
    tests:
      - hnh_unique_combination:
          columns: [service_code, question_code, answer_code]
    columns:
      - name: conformed_value
        tests: [not_null]
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_ref__pg_question_role stg_ref__pg_background_value`
Expected: FAIL — the models do not exist.

- [ ] **Step 2: Write and run the draft script**

`scripts/draft_pg_maps.py`:

```python
"""Draft the two Press Ganey reference maps (spec 4.1, 4.2) for review:

  static_mappings/pg_question_role.csv       SERVICE, QUESTION_CODE, ROLE
  static_mappings/pg_background_value.csv    SERVICE, QUESTION_CODE, ANSWER_CODE, CONFORMED_VALUE

Roles: 'Hospital NPS' and 'Physician NPS' mark each service's recommend questions; the other roles name the conformed
background attribute a background or routing question feeds. Conformed values come from the option labels:
respondent and booking channel by keyword, Yes/No questions by their first word, the rest by the English label without
its routing note. Only questions that exist in pg_survey_questions are written. LTC csurvey answer code 2 is used in
the responses but missing from the option master; it is drafted as 'Family member' (code 4, Family member, is never
used) and must be confirmed in review (open item O-P6-7).

Usage:  python scripts/draft_pg_maps.py [--out-dir DIR]
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent.parent / "static_mappings"

NPS = {
    ("OP", "o4"): "Hospital NPS", ("OP", "cp10"): "Physician NPS",
    ("TM", "o4"): "Hospital NPS", ("TM", "cp10"): "Physician NPS",
    ("ER", "f4"): "Hospital NPS",
    ("IP", "o3"): "Hospital NPS", ("PIP", "o3"): "Hospital NPS",
    ("DEN", "o12"): "Hospital NPS", ("DEN", "o1"): "Physician NPS",
    ("OR", "o4"): "Hospital NPS",
    ("HHC", "h3"): "Hospital NPS",
    ("LTC", "n10"): "Hospital NPS",
    ("AS", "f3"): "Hospital NPS",
    ("DIA", "e4"): "Hospital NPS", ("ON", "e4"): "Hospital NPS", ("OU", "e4"): "Hospital NPS",
}
ATTRIBUTES = {
    "filling": "respondent", "csurvey": "respondent", "relation": "respondent",
    "fvisit": "first_visit", "fstay": "first_visit",
    "howschvs": "booking_channel", "itsource": "booking_channel", "visadvan": "booking_channel",
    "admther": "admitted_via_er",
    "labtests": "used_lab", "xraytest": "used_radiology", "onstphar": "used_pharmacy", "insurver": "used_insurance_office",
    "physther": "used_physio", "spchther": "used_speech", "complete": "treatment_complete",
    "medshome": "meds_delivered", "telespar": "tele_spared_visit", "visttype": "tele_channel",
    "itservic": "hhc_service",
    "service": "dental_service",
    "dialytim": "dialysis_done",
    "hl_disclaimer": "contact_consent", "hl_disclamer": "contact_consent",
}
RESPONDENT = [(r"^PATIENT", "Patient"), (r"PARENT|GUARDIAN", "Parent or guardian"), (r"FAMILY", "Family member"),
              (r"^OTHER", "Other")]
CHANNEL = [(r"CALL CENT", "Call centre"), (r"RECEPTION", "Reception"), (r"ONLINE|APPLICATION|WEBSITE", "Online"),
           (r"WITHOUT AN APPOINTMENT|WALK-IN", "Walk-in"), (r"REFERRAL", "Referral"), (r"^APPOINTMENT$", "Appointment")]
MISSING_OPTIONS = [("LTC", "csurvey", "2", "Family member")]


def first(rules, text):
    up = text.upper().strip()
    return next((value for pattern, value in rules if re.search(pattern, up)), None)


def clean_label(label):
    # 'No (Go to Next Section)' -> 'No'; 'Voice Call (TMT1)' -> 'Voice Call'; keep descriptive brackets
    return re.sub(r"\s*\((go to|next section|end survey|tmt1|b2)[^)]*\)\s*$", "", label.strip(), flags=re.I).strip()


def conformed(role, label):
    if role == "respondent":
        return first(RESPONDENT, label) or "Other"
    if role == "booking_channel":
        return first(CHANNEL, label) or "Other"
    if role in ("hhc_service", "dental_service", "tele_channel"):
        return clean_label(label)
    word = label.strip().split()[0].strip("()").capitalize() if label.strip() else ""
    return word if word in ("Yes", "No") else clean_label(label)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=str(OUT_DIR))
    args = ap.parse_args()
    out = Path(args.out_dir)
    c = client()
    questions = {(s, q) for s, q in c.query(
        "select upper(trimBoth(service)), trimBoth(question_code) from press_ganey.pg_survey_questions").result_rows}
    roles = sorted([(s, q, r) for (s, q), r in NPS.items() if (s, q) in questions]
                   + [(s, q, ATTRIBUTES[q]) for s, q in questions if q in ATTRIBUTES])
    with open(out / "pg_question_role.csv", "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SERVICE", "QUESTION_CODE", "ROLE"])
        w.writerows(roles)
    role_of = {(s, q): r for s, q, r in roles}
    options = c.query(
        "select upper(trimBoth(service)), trimBoth(question_code), trimBoth(answer_code), label_en "
        "from press_ganey.pg_survey_answer_options where score is null order by 1, 2, sort_order").result_rows
    values = [(s, q, a, conformed(role_of[(s, q)], label)) for s, q, a, label in options if (s, q) in role_of]
    values += [m for m in MISSING_OPTIONS if (m[0], m[1]) in role_of]
    with open(out / "pg_background_value.csv", "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SERVICE", "QUESTION_CODE", "ANSWER_CODE", "CONFORMED_VALUE"])
        w.writerows(values)
    nps = sum(1 for r in roles if r[2].endswith("NPS"))
    unmapped = [(s, q, a) for s, q, a, label in options if (s, q) not in role_of]
    print(f"{len(roles)} question roles ({nps} NPS, {len(roles) - nps} attribute), {len(values)} background values, "
          f"{len(unmapped)} unscored options without a role -> {out}")


if __name__ == "__main__":
    main()
```

Run: `python scripts/draft_pg_maps.py`
Expected (measured): `61 question roles (16 NPS, 45 attribute), 104 background values, 0 unscored options without a role -> ...static_mappings`. Open the CSVs and confirm these rows: `OP,o4,Hospital NPS`, `OP,cp10,Physician NPS`, `IP,o3,Hospital NPS`, `DEN,o1,Physician NPS`, `TM,hl_disclamer,contact_consent`; `DEN,relation,5,Patient`, `ER,filling,7,Parent or guardian`, `OP,howschvs,5,Walk-in`, `OP,labtests,2,No`, `OR,visadvan,1,Appointment`, `TM,visttype,2,Voice Call`, `LTC,csurvey,2,Family member` (last line).

- [ ] **Step 3: Add the loader entries and load**

Add to `SMALL_TABLES` in `scripts/load_reference_data.py`:

```python
    # Role of each Press Ganey question per service: Hospital NPS, Physician NPS or a background attribute; drafted by
    # scripts/draft_pg_maps.py, reviewed by the user (open item O-P6-7).
    "map_pg_question_role": (
        "pg_question_role.csv",
        [("SERVICE", "LowCardinality(String)", s), ("QUESTION_CODE", "String", s), ("ROLE", "LowCardinality(String)", s)],
        "(SERVICE, QUESTION_CODE)",
    ),
    # Conformed value of each background or routing answer code per service; drafted by scripts/draft_pg_maps.py (O-P6-7).
    "map_pg_background_value": (
        "pg_background_value.csv",
        [("SERVICE", "LowCardinality(String)", s), ("QUESTION_CODE", "String", s), ("ANSWER_CODE", "String", s),
         ("CONFORMED_VALUE", "String", s)],
        "(SERVICE, QUESTION_CODE, ANSWER_CODE)",
    ),
```

Run: `python scripts/load_reference_data.py --only map_pg_question_role map_pg_background_value`
Expected: `default.map_pg_question_role: loaded 61`, `default.map_pg_background_value: loaded 104`.

- [ ] **Step 4: Write the staging views**

`stg_ref__pg_question_role.sql`:

```sql
-- Role of a Press Ganey question per service: 'Hospital NPS', 'Physician NPS' or a background attribute (spec 4.1).
select
    upper(trimBoth(SERVICE))                            as service_code,
    trimBoth(QUESTION_CODE)                             as question_code,
    trimBoth(ROLE)                                      as role
from {{ source('reference', 'map_pg_question_role') }}
```

`stg_ref__pg_background_value.sql`:

```sql
-- Conformed value of each background or routing answer code per service (spec 4.2).
select
    upper(trimBoth(SERVICE))                            as service_code,
    trimBoth(QUESTION_CODE)                             as question_code,
    trimBoth(ANSWER_CODE)                               as answer_code,
    trimBoth(CONFORMED_VALUE)                           as conformed_value
from {{ source('reference', 'map_pg_background_value') }}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_ref__pg_question_role stg_ref__pg_background_value`
Expected: all PASS; `select count() from stg.stg_ref__pg_question_role` = 61 and `stg.stg_ref__pg_background_value` = 104.

- [ ] **Step 6: Commit**

```bash
git add scripts/draft_pg_maps.py scripts/load_reference_data.py hnh_dwh/models/hnh/staging/reference/
git commit -m "Draft and load the Press Ganey question-role and background-value maps" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Press Ganey staging

**Files:**
- Create: `hnh_dwh/models/hnh/staging/press_ganey/_press_ganey__sources.yml`, `_press_ganey__models.yml`, `stg_pg__survey_response.sql`, `stg_pg__survey_answer.sql`, `stg_pg__survey_question.sql`, `stg_pg__answer_option.sql`, `stg_pg__service.sql`

**Interfaces:**
- Produces:
  - `stg_pg__survey_response(surveycode, pg_branch_code, service_code, encounter_id, visit_date Nullable(Date), receive_date, sms_send_date Nullable(Date), survey_date Nullable(Date), source_status, responses_json, fetched_at)`
  - `stg_pg__survey_answer(surveycode, service_code, question_code, answer_code)` — non-null answers only
  - `stg_pg__survey_question(service_code, question_code, pg_var, survey_sheet, survey_name_en, survey_name_ar, item_no UInt16, is_included UInt8, domain_en, domain_ar, question_en, question_ar, scale_en, scale_type, item_type, is_scored UInt8)`
  - `stg_pg__answer_option(service_code, question_code, answer_code, sort_order UInt8, label_en, label_ar, score Nullable(Float64), label_source)`
  - `stg_pg__service(service_code, service_desc, care_setting, is_enabled UInt8)`
- `service_code` is upper case everywhere (`OP`, `ER`, `IP`, `PIP`, `DEN`, …); `pg_branch_code` lower case (`hnhj`).

- [ ] **Step 1: Declare the source and write the failing tests**

`_press_ganey__sources.yml`:

```yaml
version: 2

sources:
  - name: press_ganey
    schema: press_ganey
    description: Press Ganey patient surveys. Responses are ReplacingMergeTree on _fetched_at; answers are a JSON string.
    tables:
      - name: pg_survey_responses
        loaded_at_field: _fetched_at
        freshness:
          warn_after: {count: 30, period: hour}
          error_after: {count: 54, period: hour}
      - name: pg_survey_questions
      - name: pg_survey_answer_options
      - name: dim_pg_service
```

`_press_ganey__models.yml`:

```yaml
version: 2

models:
  - name: stg_pg__survey_response
    columns:
      - name: surveycode
        tests: [unique, not_null]
      - name: visit_date
        tests: [not_null]
  - name: stg_pg__survey_answer
    tests:
      - hnh_unique_combination:
          columns: [surveycode, question_code]
  - name: stg_pg__survey_question
    tests:
      - hnh_unique_combination:
          columns: [service_code, question_code]
  - name: stg_pg__answer_option
    tests:
      - hnh_unique_combination:
          columns: [service_code, question_code, answer_code]
  - name: stg_pg__service
    columns:
      - name: service_code
        tests: [unique, not_null]
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select path:models/hnh/staging/press_ganey`
Expected: FAIL — the models do not exist.

- [ ] **Step 2: Write the staging views**

`stg_pg__survey_response.sql`:

```sql
-- One row per Press Ganey survey invitation (surveycode), latest version by _fetched_at (spec 3). The survey link URL
-- is not carried. sms_send_date is a timestamp at midnight in the source; only its date is used.
select
    surveycode                                          as surveycode,
    lower(trimBoth(hosp))                               as pg_branch_code,
    upper(trimBoth(service))                            as service_code,
    trimBoth(encounter_id)                              as encounter_id,
    visit_date                                          as visit_date,
    receive_date                                        as receive_date,
    if(sms_send_date is null, cast(null as Nullable(Date)), toDate(sms_send_date)) as sms_send_date,
    survey_date                                         as survey_date,
    toString(status)                                    as source_status,
    responses                                           as responses_json,
    _fetched_at                                         as fetched_at
from {{ source('press_ganey', 'pg_survey_responses') }} final
```

`stg_pg__survey_answer.sql`:

```sql
-- One row per survey and answered question: the responses JSON expanded (spec 3, P2). Null answers are dropped; the
-- always-empty comments key and the stray initial_response array are skipped. An array value takes its first element.
select surveycode, service_code, question_code, answer_code
from (
    select
        surveycode                                      as surveycode,
        upper(trimBoth(service))                        as service_code,
        kv.1                                            as question_code,
        trimBoth(if(startsWith(kv.2, '['), ifNull(JSONExtract(kv.2, 1, 'Nullable(String)'), ''), kv.2)) as answer_code
    from {{ source('press_ganey', 'pg_survey_responses') }} final
    array join JSONExtractKeysAndValues(responses, 'Nullable(String)') as kv
    where kv.2 is not null and kv.1 not in ('comments', 'initial_response')
)
where answer_code != ''
```

`stg_pg__survey_question.sql`:

```sql
-- Press Ganey question master: one row per service and question code (spec 5.2).
select
    upper(trimBoth(service))                            as service_code,
    trimBoth(question_code)                             as question_code,
    pg_var                                              as pg_var,
    toString(survey_sheet)                              as survey_sheet,
    survey_name_en                                      as survey_name_en,
    survey_name_ar                                      as survey_name_ar,
    toUInt16(item_no)                                   as item_no,
    toUInt8(included)                                   as is_included,
    domain_en                                           as domain_en,
    domain_ar                                           as domain_ar,
    question_en                                         as question_en,
    question_ar                                         as question_ar,
    scale_en                                            as scale_en,
    toString(scale_type)                                as scale_type,
    toString(item_type)                                 as item_type,
    toUInt8(is_scored)                                  as is_scored
from {{ source('press_ganey', 'pg_survey_questions') }}
```

`stg_pg__answer_option.sql`:

```sql
-- Press Ganey answer options: label and score per service, question and answer code (spec P3). Workbook options
-- (background and routing questions) have no score.
select
    upper(trimBoth(service))                            as service_code,
    trimBoth(question_code)                             as question_code,
    trimBoth(answer_code)                               as answer_code,
    toUInt8(sort_order)                                 as sort_order,
    label_en                                            as label_en,
    label_ar                                            as label_ar,
    if(score is null, cast(null as Nullable(Float64)), toFloat64(score)) as score,
    toString(label_source)                              as label_source
from {{ source('press_ganey', 'pg_survey_answer_options') }}
```

`stg_pg__service.sql`:

```sql
-- Press Ganey services (spec 5.1).
select
    upper(trimBoth(service_code))                       as service_code,
    service_desc                                        as service_desc,
    toString(care_setting)                              as care_setting,
    toUInt8(is_enabled)                                 as is_enabled
from {{ source('press_ganey', 'dim_pg_service') }} final
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select path:models/hnh/staging/press_ganey`
Expected: all PASS. Record the counts (measured): `stg_pg__survey_response` 702,879; `stg_pg__survey_answer` 739,968 (30,975 distinct surveys); `stg_pg__survey_question` 306; `stg_pg__answer_option` 1,418; `stg_pg__service` 17. Also run `python scripts/run_dbt.py source freshness --select source:press_ganey` and record the result (expected PASS: the latest `_fetched_at` was 2026-10-07 06:30).

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/staging/press_ganey/
git commit -m "Stage Press Ganey responses, answers, questions, options and services" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Survey-to-encounter link and background attributes

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/experience/int_survey_encounter_link.sql`, `int_survey_background.sql`, `_experience__models.yml`, `_experience_unit_tests.yml`

**Interfaces:**
- Consumes: `stg_pg__survey_response`, `stg_pg__survey_answer` (Task 3); `stg_ref__pg_question_role`, `stg_ref__pg_background_value` (Task 2); `hnh_dim_branch.pg_branch_code`, `fact_encounter`, `fact_admission.consultant_staff_key` (Phase 1); macros from Task 1.
- Produces: `int_survey_encounter_link(surveycode, branch_key UInt8, encounter_id, encounter_type Nullable(String), encounter_key, episode_key, patient_key, department_key, payer_key Int64, care_type_key Int8, staff_key Int64, link_status String)`, `link_status` ∈ `Linked` / `Encounter not found` / `Bad encounter id`; `int_survey_background(surveycode, respondent_type, first_visit, booking_channel, admitted_via_er, used_lab, used_radiology, used_pharmacy, used_insurance_office, used_physio, used_speech, treatment_complete, meds_delivered, tele_spared_visit, tele_channel, hhc_service, dental_service, dialysis_done, contact_consent)` — one row per survey with at least one background answer, every column a String (`Not answered` / `Unmapped` / a conformed value).

- [ ] **Step 1: Write the failing unit tests and schema tests**

`_experience_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: int_survey_encounter_link_resolves_encounter_and_doctor
    description: >
      Branch from the Press Ganey code (hnhj = Jazan 3). S1 inpatient with an admission consultant takes the
      consultant (201), not the treating doctor. S2 inpatient whose admission has no consultant (-1) takes the treating
      doctor (202). S3 outpatient without a treating doctor takes the booked doctor (303). S4 ER takes the treating doctor
      (404). S5 'o5' must not match the ER visit with the same id 5: Encounter not found. S6 a malformed id: Bad encounter
      id. S7 an unknown hospital code gets branch 0 and does not link.
    model: int_survey_encounter_link
    given:
      - input: ref('stg_pg__survey_response')
        format: sql
        rows: |
          select s as surveycode, h as pg_branch_code, e as encounter_id
          from values('s String, h String, e String',
              ('S1', 'hnhj', 'i1'), ('S2', 'hnhj', 'i2'), ('S3', 'hnhj', 'o3'), ('S4', 'hnhj', 'e4'),
              ('S5', 'hnhj', 'o5'), ('S6', 'hnhj', 'x6'), ('S7', 'zzz', 'o3'))
      - input: ref('hnh_dim_branch')
        format: sql
        rows: |
          select toUInt8(3) as branch_key, toNullable('hnhj') as pg_branch_code
          union all select toUInt8(0), cast(null as Nullable(String))
      - input: ref('fact_encounter')
        format: sql
        rows: |
          select toUInt8(3) as branch_key, t as encounter_type, toInt64(sid) as source_id, toInt64(k) as encounter_key,
                 toInt64(k + 1000) as episode_key, toInt64(k + 2000) as patient_key, toInt64(k + 3000) as department_key,
                 toInt64(k + 4000) as payer_key, toInt8(ct) as care_type_key, toInt64(tr) as treating_staff_key,
                 toInt64(bk) as booked_staff_key
          from values('t String, sid Int64, k Int64, ct Int8, tr Int64, bk Int64',
              ('IP', 1, 11, 3, 101, 151), ('IP', 2, 12, 3, 202, 252), ('OP', 3, 13, 1, -1, 303),
              ('ER', 4, 14, 2, 404, 454), ('ER', 5, 15, 2, 505, 555))
      - input: ref('fact_admission')
        format: sql
        rows: |
          select toInt64(k) as encounter_key, toInt64(c) as consultant_staff_key
          from values('k Int64, c Int64', (11, 201), (12, -1))
    expect:
      rows:
        - {surveycode: S1, branch_key: 3, encounter_key: 11, staff_key: 201, department_key: 3011, care_type_key: 3, link_status: Linked}
        - {surveycode: S2, branch_key: 3, encounter_key: 12, staff_key: 202, department_key: 3012, care_type_key: 3, link_status: Linked}
        - {surveycode: S3, branch_key: 3, encounter_key: 13, staff_key: 303, department_key: 3013, care_type_key: 1, link_status: Linked}
        - {surveycode: S4, branch_key: 3, encounter_key: 14, staff_key: 404, department_key: 3014, care_type_key: 2, link_status: Linked}
        - {surveycode: S5, branch_key: 3, encounter_key: -1, staff_key: -1, department_key: -1, care_type_key: -1, link_status: Encounter not found}
        - {surveycode: S6, branch_key: 3, encounter_key: -1, staff_key: -1, department_key: -1, care_type_key: -1, link_status: Bad encounter id}
        - {surveycode: S7, branch_key: 0, encounter_key: -1, staff_key: -1, department_key: -1, care_type_key: -1, link_status: Encounter not found}

  - name: int_survey_background_conforms_answers
    description: >
      The same meaning arrives under different codes: DEN relation 5 and ER filling 1 are both Patient. An OP routing
      answer (labtests 2) gives used_lab = No. An answer code with no conformed value is Unmapped (ER filling 9). NPS
      answers are not background (S4 has only an NPS answer and gets no row). An attribute a survey did not answer is
      Not answered.
    model: int_survey_background
    given:
      - input: ref('stg_pg__survey_answer')
        format: sql
        rows: |
          select s as surveycode, sv as service_code, q as question_code, a as answer_code
          from values('s String, sv String, q String, a String',
              ('S1', 'DEN', 'relation', '5'), ('S1', 'DEN', 'fvisit', '1'), ('S2', 'ER', 'filling', '1'),
              ('S3', 'OP', 'labtests', '2'), ('S3', 'OP', 'howschvs', '5'), ('S5', 'ER', 'filling', '9'),
              ('S4', 'OP', 'o4', '5'))
      - input: ref('stg_ref__pg_question_role')
        format: sql
        rows: |
          select sv as service_code, q as question_code, r as role
          from values('sv String, q String, r String',
              ('DEN', 'relation', 'respondent'), ('DEN', 'fvisit', 'first_visit'), ('ER', 'filling', 'respondent'),
              ('OP', 'labtests', 'used_lab'), ('OP', 'howschvs', 'booking_channel'), ('OP', 'o4', 'Hospital NPS'))
      - input: ref('stg_ref__pg_background_value')
        format: sql
        rows: |
          select sv as service_code, q as question_code, a as answer_code, v as conformed_value
          from values('sv String, q String, a String, v String',
              ('DEN', 'relation', '5', 'Patient'), ('DEN', 'fvisit', '1', 'Yes'), ('ER', 'filling', '1', 'Patient'),
              ('OP', 'labtests', '2', 'No'), ('OP', 'howschvs', '5', 'Walk-in'))
    expect:
      rows:
        - {surveycode: S1, respondent_type: Patient, first_visit: 'Yes', used_lab: Not answered, booking_channel: Not answered}
        - {surveycode: S2, respondent_type: Patient, first_visit: Not answered, used_lab: Not answered, booking_channel: Not answered}
        - {surveycode: S3, respondent_type: Not answered, first_visit: Not answered, used_lab: 'No', booking_channel: Walk-in}
        - {surveycode: S5, respondent_type: Unmapped, first_visit: Not answered, used_lab: Not answered, booking_channel: Not answered}
```

`_experience__models.yml`:

```yaml
version: 2

models:
  - name: int_survey_encounter_link
    description: Survey invitation → encounter, episode, patient, clinic, payer, care type and doctor (spec 6.1).
    columns:
      - name: surveycode
        tests: [unique, not_null]
      - name: link_status
        tests:
          - accepted_values:
              values: ['Linked', 'Encounter not found', 'Bad encounter id']
  - name: int_survey_background
    description: Conformed background attributes per survey with at least one background answer (spec 4.2).
    columns:
      - name: surveycode
        tests: [unique, not_null]
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select int_survey_encounter_link int_survey_background`
Expected: FAIL — the models do not exist.

- [ ] **Step 2: Write `int_survey_encounter_link.sql`**

```sql
{{ config(order_by='surveycode') }}

-- One row per survey invitation with the encounter it was sent for (spec 6.1). Branch from dim_branch.pg_branch_code;
-- encounter by branch + encounter type (prefix o/e/i) + Oasis id (appointment id, ER visit id, admission no). Episode,
-- patient, clinic, payer and care type come from the encounter. Doctor: for IP the admission's consultant, else the
-- encounter's treating doctor, else its booked doctor (spec P8). Unlinked surveys get -1 keys.
with surveys as (
    select
        r.surveycode                                        as surveycode,
        r.encounter_id                                      as encounter_id,
        ifNull(b.branch_key, toUInt8(0))                    as branch_key,
        {{ hnh_survey_encounter_type('r.encounter_id') }}   as encounter_type,
        {{ hnh_survey_source_id('r.encounter_id') }}        as source_id
    from {{ ref('stg_pg__survey_response') }} as r
    left join (select branch_key, pg_branch_code from {{ ref('hnh_dim_branch') }} where pg_branch_code is not null) as b
        on b.pg_branch_code = r.pg_branch_code
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

encounters as (
    select branch_key as e_branch_key, encounter_type as e_encounter_type, source_id as e_source_id,
           encounter_key as e_encounter_key, episode_key as e_episode_key, patient_key as e_patient_key,
           department_key as e_department_key, payer_key as e_payer_key, care_type_key as e_care_type_key,
           treating_staff_key as e_treating_staff_key, booked_staff_key as e_booked_staff_key
    from {{ ref('fact_encounter') }}
)

select
    s.surveycode                                            as surveycode,
    s.branch_key                                            as branch_key,
    s.encounter_id                                          as encounter_id,
    s.encounter_type                                        as encounter_type,
    ifNull(e.e_encounter_key, toInt64(-1))                  as encounter_key,
    ifNull(e.e_episode_key, toInt64(-1))                    as episode_key,
    ifNull(e.e_patient_key, toInt64(-1))                    as patient_key,
    ifNull(e.e_department_key, toInt64(-1))                 as department_key,
    ifNull(e.e_payer_key, toInt64(-1))                      as payer_key,
    ifNull(e.e_care_type_key, toInt8(-1))                   as care_type_key,
    toInt64(multiIf(e.e_encounter_key is null, -1,
                    s.encounter_type = 'IP' and ifNull(a.consultant_staff_key, -1) != -1, a.consultant_staff_key,
                    ifNull(e.e_treating_staff_key, -1) != -1, e.e_treating_staff_key,
                    ifNull(e.e_booked_staff_key, -1)))      as staff_key,
    multiIf(e.e_encounter_key is not null, 'Linked',
            s.source_id is null, 'Bad encounter id',
            'Encounter not found')                          as link_status
from surveys as s
left join encounters as e
    on e.e_branch_key = s.branch_key and e.e_encounter_type = s.encounter_type and e.e_source_id = s.source_id
left join (select encounter_key, consultant_staff_key from {{ ref('fact_admission') }}) as a
    on a.encounter_key = e.e_encounter_key
{{ hnh_settings() }}
```

- [ ] **Step 3: Write `int_survey_background.sql`**

```sql
{{ config(order_by='surveycode') }}

-- One row per survey with at least one background or routing answer: the conformed value of each attribute
-- (spec 4.1, 4.2, 6.1). A survey without an answer for an attribute gets 'Not answered'; an answer code with no row in
-- map_pg_background_value gets 'Unmapped'.
{%- set attributes = {
    'respondent_type': 'respondent', 'first_visit': 'first_visit', 'booking_channel': 'booking_channel',
    'admitted_via_er': 'admitted_via_er', 'used_lab': 'used_lab', 'used_radiology': 'used_radiology',
    'used_pharmacy': 'used_pharmacy', 'used_insurance_office': 'used_insurance_office', 'used_physio': 'used_physio',
    'used_speech': 'used_speech', 'treatment_complete': 'treatment_complete', 'meds_delivered': 'meds_delivered',
    'tele_spared_visit': 'tele_spared_visit', 'tele_channel': 'tele_channel', 'hhc_service': 'hhc_service',
    'dental_service': 'dental_service', 'dialysis_done': 'dialysis_done', 'contact_consent': 'contact_consent'
} %}
with answers as (
    select a.surveycode as surveycode, q.role as role, ifNull(v.conformed_value, 'Unmapped') as conformed_value
    from {{ ref('stg_pg__survey_answer') }} as a
    inner join (select service_code, question_code, role from {{ ref('stg_ref__pg_question_role') }}
                where role not in ('Hospital NPS', 'Physician NPS')) as q
        on q.service_code = a.service_code and q.question_code = a.question_code
    left join {{ ref('stg_ref__pg_background_value') }} as v
        on v.service_code = a.service_code and v.question_code = a.question_code and v.answer_code = a.answer_code
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
)

select
    surveycode,
{%- for column, role in attributes.items() %}
    if(countIf(role = '{{ role }}') > 0, anyIf(conformed_value, role = '{{ role }}'), 'Not answered') as {{ column }}{{ ',' if not loop.last }}
{%- endfor %}
from answers
group by surveycode
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select int_survey_encounter_link int_survey_background`
Expected: both unit tests and all schema tests PASS. Record (measured): `int_survey_encounter_link` 702,879 rows — Linked OP 514,659, ER 80,892, IP 31,995; Encounter not found OP 74,742, ER 590, IP 1; Bad encounter id 0; branch 0 rows 0; Linked rows with `staff_key = -1`: 30 (ER); `int_survey_background` 30,791 rows, respondent_type Patient 9,696 / Parent or guardian 3,634 / Family member 92 / Other 410 / Not answered 16,959.

```sql
select link_status, encounter_type, count(), countIf(staff_key = -1) from int.int_survey_encounter_link group by 1, 2 order by 1, 2
```

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/experience/
git commit -m "Link surveys to encounters and doctors, and conform background answers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Survey service and question dimensions

**Files:**
- Create: `hnh_dwh/models/hnh/marts/experience/dim_survey_service.sql`, `dim_survey_question.sql`, `_experience_marts__models.yml`

**Interfaces:**
- Consumes: `stg_pg__service`, `stg_pg__survey_question` (Task 3), `stg_ref__pg_question_role` (Task 2).
- Produces: `dim_survey_service(survey_service_key String, service_name, care_setting, is_enabled UInt8, survey_name_en, survey_name_ar)` with member `'-1'`; `dim_survey_question(question_key String = service_code || '|' || question_code, service_code, question_code, pg_var, survey_name_en, survey_name_ar, item_no, domain_en, domain_ar, question_en, question_ar, scale_type, scale_en, item_type, is_scored UInt8, question_class, nps_role, attribute_role)` with member `'-1'`. `question_class` ∈ `Scored` / `Background` / `Routing`; `nps_role` ∈ `Hospital NPS` / `Physician NPS` / `''`.

- [ ] **Step 1: Write the failing schema tests**

`_experience_marts__models.yml` (Tasks 6 and 7 append to it):

```yaml
version: 2

models:
  - name: dim_survey_service
    description: Press Ganey services (spec 5.1), unknown member '-1'.
    columns:
      - name: survey_service_key
        tests: [unique, not_null]
  - name: dim_survey_question
    description: Press Ganey questions per service with domain, scale, class and NPS role (spec 5.2), unknown member '-1'.
    columns:
      - name: question_key
        tests: [unique, not_null]
      - name: question_class
        tests:
          - accepted_values:
              values: ['Scored', 'Background', 'Routing']
      - name: nps_role
        tests:
          - accepted_values:
              values: ['Hospital NPS', 'Physician NPS', '']
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select dim_survey_service dim_survey_question`
Expected: FAIL — the models do not exist.

- [ ] **Step 2: Write `dim_survey_service.sql`**

```sql
{{ config(order_by='survey_service_key') }}

-- One row per Press Ganey service (spec 5.1), plus the unknown member '-1'.
with services as (
    select
        s.service_code                                      as survey_service_key,
        s.service_desc                                      as service_name,
        s.care_setting                                      as care_setting,
        s.is_enabled                                        as is_enabled,
        ifNull(q.survey_name_en, '')                        as survey_name_en,
        ifNull(q.survey_name_ar, '')                        as survey_name_ar
    from {{ ref('stg_pg__service') }} as s
    left join (select service_code, any(survey_name_en) as survey_name_en, any(survey_name_ar) as survey_name_ar
               from {{ ref('stg_pg__survey_question') }} group by service_code) as q
        on q.service_code = s.service_code
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
)

select * from services
union all
select '-1', 'Unknown', 'Unknown', toUInt8(0), '', ''
```

- [ ] **Step 3: Write `dim_survey_question.sql`**

```sql
{{ config(order_by='question_key') }}

-- One row per Press Ganey service and question (spec 5.2), plus the unknown member '-1'. question_class: Scored when
-- the master scores it, Routing for routing items, else Background. nps_role and attribute_role come from
-- map_pg_question_role ('' when the question has none).
with questions as (
    select
        concat(q.service_code, '|', q.question_code)        as question_key,
        q.service_code                                      as service_code,
        q.question_code                                     as question_code,
        q.pg_var                                            as pg_var,
        q.survey_name_en                                    as survey_name_en,
        q.survey_name_ar                                    as survey_name_ar,
        q.item_no                                           as item_no,
        q.domain_en                                         as domain_en,
        q.domain_ar                                         as domain_ar,
        q.question_en                                       as question_en,
        q.question_ar                                       as question_ar,
        q.scale_type                                        as scale_type,
        q.scale_en                                          as scale_en,
        q.item_type                                         as item_type,
        q.is_scored                                         as is_scored,
        multiIf(q.is_scored = 1, 'Scored', q.item_type = 'Routing', 'Routing', 'Background') as question_class,
        if(ifNull(r.role, '') in ('Hospital NPS', 'Physician NPS'), assumeNotNull(r.role), '') as nps_role,
        if(ifNull(r.role, '') in ('Hospital NPS', 'Physician NPS'), '', ifNull(r.role, ''))  as attribute_role
    from {{ ref('stg_pg__survey_question') }} as q
    left join {{ ref('stg_ref__pg_question_role') }} as r
        on r.service_code = q.service_code and r.question_code = q.question_code
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
)

select * from questions
union all
select '-1', '-1', '-1', '', 'Unknown', '', toUInt16(0), 'Unknown', '', 'Unknown', '', '', '', '', toUInt8(0),
       'Background', '', ''
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select dim_survey_service dim_survey_question`
Expected: all PASS. Record (measured): `dim_survey_service` 18 rows (17 services + unknown); `dim_survey_question` 307 rows — Scored 261 (Hospital NPS 13, Physician NPS 3), Background 37 (36 questions + the unknown member), Routing 9.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/experience/
git commit -m "Add the survey service and survey question dimensions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Survey response fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/experience/fact_survey_response.sql`, `_experience_marts_unit_tests.yml`
- Modify: `hnh_dwh/models/hnh/marts/experience/_experience_marts__models.yml`

**Interfaces:**
- Consumes: `stg_pg__survey_response`, `stg_pg__survey_answer`, `stg_pg__survey_question`, `stg_pg__answer_option` (Task 3); `stg_ref__pg_question_role` (Task 2); `int_survey_encounter_link`, `int_survey_background` (Task 4); `hnh_survey_band` (Task 1).
- Produces: `fact_survey_response` — keys `survey_response_key Int64`, `surveycode`, `branch_key UInt8`, `survey_service_key String`, `care_type_key Int8`, `encounter_key`, `episode_key`, `patient_key`, `staff_key`, `department_key`, `payer_key Int64`, `visit_date_key Int32`, `sms_sent_date_key`, `survey_date_key Nullable(Int32)`; `encounter_id`, `source_status`, `response_status` (`Submitted` / `Partial` / `Not started`), `is_sms_sent`, `is_responded`, `is_submitted`, `is_primary_for_encounter` UInt8, `answers_count`, `scored_questions_offered`, `scored_questions_answered` UInt32, `days_visit_to_sms`, `days_visit_to_answer` Nullable, `link_status`, the 18 background attribute Strings of Task 4, `nps_score`, `physician_nps_score` Nullable(Float64), `nps_band`, `physician_nps_band` Nullable(String), `_loaded_at`. Task 7 reads `survey_response_key, surveycode, branch_key, survey_service_key, care_type_key, encounter_key, staff_key, department_key, patient_key, payer_key, visit_date_key, response_status, is_primary_for_encounter, link_status`.

- [ ] **Step 1: Write the failing unit test and schema tests**

`_experience_marts_unit_tests.yml` (Task 7 appends to it):

```yaml
version: 2

unit_tests:
  - name: fact_survey_response_status_primary_and_nps
    description: >
      Encounter o1 got two invitations: A1 (older, partially answered) and A2 (newer, not started). The answered one is
      primary although it is older. B1 is 'submitted' in the source but carries no answer: Not started. C1 is submitted,
      its Hospital NPS answer (o4) is code 3 = Passive and its Physician NPS answer (cp10) code 5 = Promoter; it answered
      2 of the 3 scored OP questions. D1 is an IP survey whose 0-10 answer (cms_23) is option code 9 = score 8 =
      Promoter on that scale, while its Hospital NPS (o3) is code 2 = Detractor. Background attributes default to Not
      answered.
    model: fact_survey_response
    given:
      - input: ref('stg_pg__survey_response')
        format: sql
        rows: |
          select s as surveycode, sv as service_code, e as encounter_id, toNullable(toDate(v)) as visit_date,
                 if(sms = '', cast(null as Nullable(Date)), toNullable(toDate(sms))) as sms_send_date,
                 toNullable(toDate(sd)) as survey_date, st as source_status
          from values('s String, sv String, e String, v String, sms String, sd String, st String',
              ('A1', 'OP', 'o1', '2026-09-01', '2026-09-01', '2026-09-02', 'incomplete'),
              ('A2', 'OP', 'o1', '2026-09-01', '2026-09-05', '2026-09-05', 'NOTSTARTED'),
              ('B1', 'OP', 'o2', '2026-09-01', '', '2026-09-03', 'submitted'),
              ('C1', 'OP', 'o3', '2026-09-01', '2026-09-01', '2026-09-04', 'submitted'),
              ('D1', 'IP', 'i4', '2026-09-01', '2026-09-02', '2026-09-03', 'submitted'))
      - input: ref('int_survey_encounter_link')
        format: sql
        rows: |
          select s as surveycode, toUInt8(3) as branch_key, toInt64(10) as encounter_key, toInt64(-1) as episode_key,
                 toInt64(20) as patient_key, toInt64(30) as staff_key, toInt64(40) as department_key,
                 toInt64(50) as payer_key, toInt8(1) as care_type_key, 'Linked' as link_status
          from values('s String', ('A1'), ('A2'), ('B1'), ('C1'), ('D1'))
      - input: ref('stg_pg__survey_answer')
        format: sql
        rows: |
          select s as surveycode, sv as service_code, q as question_code, a as answer_code
          from values('s String, sv String, q String, a String',
              ('A1', 'OP', 'v2', '4'), ('C1', 'OP', 'o4', '3'), ('C1', 'OP', 'cp10', '5'), ('C1', 'OP', 'fvisit', '1'),
              ('D1', 'IP', 'cms_23', '9'), ('D1', 'IP', 'o3', '2'))
      - input: ref('stg_pg__survey_question')
        format: sql
        rows: |
          select sv as service_code, q as question_code, sc as scale_type, toUInt8(isc) as is_scored
          from values('sv String, q String, sc String, isc UInt8',
              ('OP', 'v2', 'rating_1_5', 1), ('OP', 'o4', 'rating_1_5', 1), ('OP', 'cp10', 'rating_1_5', 1),
              ('OP', 'fvisit', 'categorical', 0), ('IP', 'cms_23', 'likelihood_0_10', 1), ('IP', 'o3', 'rating_1_5', 1))
      - input: ref('stg_ref__pg_question_role')
        format: sql
        rows: |
          select sv as service_code, q as question_code, r as role
          from values('sv String, q String, r String',
              ('OP', 'o4', 'Hospital NPS'), ('OP', 'cp10', 'Physician NPS'), ('IP', 'o3', 'Hospital NPS'), ('OP', 'fvisit', 'first_visit'))
      - input: ref('stg_pg__answer_option')
        format: sql
        rows: |
          select sv as service_code, q as question_code, a as answer_code, toNullable(toFloat64(sc)) as score
          from values('sv String, q String, a String, sc Float64',
              ('OP', 'v2', '4', 4), ('OP', 'o4', '3', 3), ('OP', 'cp10', '5', 5), ('IP', 'cms_23', '9', 8), ('IP', 'o3', '2', 2))
      - input: ref('int_survey_background')
        format: sql
        rows: |
          select 'C1' as surveycode, 'Yes' as first_visit, 'Not answered' as respondent_type, 'Not answered' as booking_channel,
                 'Not answered' as admitted_via_er, 'Not answered' as used_lab, 'Not answered' as used_radiology,
                 'Not answered' as used_pharmacy, 'Not answered' as used_insurance_office, 'Not answered' as used_physio,
                 'Not answered' as used_speech, 'Not answered' as treatment_complete, 'Not answered' as meds_delivered,
                 'Not answered' as tele_spared_visit, 'Not answered' as tele_channel, 'Not answered' as hhc_service,
                 'Not answered' as dental_service, 'Not answered' as dialysis_done, 'Not answered' as contact_consent
    expect:
      rows:
        - {surveycode: A1, response_status: Partial, is_responded: 1, is_submitted: 0, is_primary_for_encounter: 1, is_sms_sent: 1, answers_count: 1, scored_questions_offered: 3, scored_questions_answered: 1, nps_band: null, first_visit: Not answered}
        - {surveycode: A2, response_status: Not started, is_responded: 0, is_submitted: 0, is_primary_for_encounter: 0, is_sms_sent: 1, answers_count: 0, scored_questions_offered: 3, scored_questions_answered: 0, nps_band: null, first_visit: Not answered}
        - {surveycode: B1, response_status: Not started, is_responded: 0, is_submitted: 0, is_primary_for_encounter: 1, is_sms_sent: 0, answers_count: 0, scored_questions_offered: 3, scored_questions_answered: 0, nps_band: null, first_visit: Not answered}
        - {surveycode: C1, response_status: Submitted, is_responded: 1, is_submitted: 1, is_primary_for_encounter: 1, is_sms_sent: 1, answers_count: 3, scored_questions_offered: 3, scored_questions_answered: 2, nps_band: Passive, first_visit: 'Yes'}
        - {surveycode: D1, response_status: Submitted, is_responded: 1, is_submitted: 1, is_primary_for_encounter: 1, is_sms_sent: 1, answers_count: 2, scored_questions_offered: 2, scored_questions_answered: 2, nps_band: Detractor, first_visit: Not answered}
```

Append to `_experience_marts__models.yml` under `models:`:

```yaml
  - name: fact_survey_response
    description: One row per Press Ganey survey invitation with survey-quality, background and NPS columns (spec 6.1).
    tests:
      - hnh_unique_combination:
          columns: [branch_key, encounter_id]
          config: {where: "is_primary_for_encounter = 1"}
    columns:
      - name: survey_response_key
        tests: [unique, not_null]
      - name: surveycode
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: survey_service_key
        tests:
          - relationships: {to: ref('dim_survey_service'), field: survey_service_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
      - name: staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: department_key
        tests:
          - relationships: {to: ref('hnh_dim_department'), field: department_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: visit_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: sms_sent_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: survey_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: encounter_key
        tests:
          - relationships:
              to: ref('fact_encounter')
              field: encounter_key
              config: {severity: warn, where: "encounter_key != -1"}
      - name: response_status
        tests:
          - accepted_values:
              values: ['Submitted', 'Partial', 'Not started']
      - name: link_status
        tests:
          - accepted_values:
              values: ['Linked', 'Encounter not found', 'Bad encounter id']
      - name: nps_band
        tests:
          - accepted_values:
              values: ['Promoter', 'Passive', 'Detractor']
      - name: physician_nps_band
        tests:
          - accepted_values:
              values: ['Promoter', 'Passive', 'Detractor']
      - name: respondent_type
        tests:
          - accepted_values:
              values: ['Patient', 'Parent or guardian', 'Family member', 'Other', 'Not answered', 'Unmapped']
      - name: booking_channel
        tests:
          - accepted_values:
              values: ['Call centre', 'Reception', 'Online', 'Walk-in', 'Referral', 'Appointment', 'Not answered', 'Unmapped']
      - name: first_visit
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: admitted_via_er
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: used_lab
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: used_radiology
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: used_pharmacy
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: used_insurance_office
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: used_physio
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: used_speech
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: treatment_complete
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: meds_delivered
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: tele_spared_visit
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: dialysis_done
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
      - name: contact_consent
        tests:
          - accepted_values:
              values: ['Yes', 'No', 'Not answered', 'Unmapped']
```

`tele_channel`, `hhc_service` and `dental_service` hold option labels and get no accepted-values test.

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_survey_response`
Expected: FAIL — the model does not exist.

- [ ] **Step 2: Write `fact_survey_response.sql`**

```sql
{{ config(order_by='(branch_key, visit_date_key, survey_response_key)') }}

-- One row per Press Ganey survey invitation (spec 6.1). response_status: Submitted = submitted with at least one
-- answer; Partial = answers but not submitted; Not started = no answer (also the few 'submitted' surveys that carry no
-- answer). is_primary_for_encounter marks one invitation per branch + encounter id: the answered one with the latest
-- survey date, else the latest invitation (tie-break highest surveycode). The NPS columns come from the service's
-- Hospital NPS and Physician NPS answers (spec X1).
{%- set attributes = ['respondent_type', 'first_visit', 'booking_channel', 'admitted_via_er', 'used_lab',
    'used_radiology', 'used_pharmacy', 'used_insurance_office', 'used_physio', 'used_speech', 'treatment_complete',
    'meds_delivered', 'tele_spared_visit', 'tele_channel', 'hhc_service', 'dental_service', 'dialysis_done',
    'contact_consent'] %}
with answer_stats as (
    select a.surveycode as st_surveycode, count() as k_answers, countIf(q.is_scored = 1) as k_scored_answered
    from {{ ref('stg_pg__survey_answer') }} as a
    left join (select service_code, question_code, is_scored from {{ ref('stg_pg__survey_question') }}) as q
        on q.service_code = a.service_code and q.question_code = a.question_code
    group by a.surveycode
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

offered as (
    select service_code as of_service_code, toUInt32(countIf(is_scored = 1)) as k_offered
    from {{ ref('stg_pg__survey_question') }}
    group by service_code
),

nps_answers as (
    select a.surveycode as n_surveycode,
           maxIf(o.score, r.role = 'Hospital NPS')          as k_nps_score,
           anyIf(q.scale_type, r.role = 'Hospital NPS')     as k_nps_scale,
           maxIf(o.score, r.role = 'Physician NPS')         as k_physician_score,
           anyIf(q.scale_type, r.role = 'Physician NPS')    as k_physician_scale
    from {{ ref('stg_pg__survey_answer') }} as a
    inner join (select service_code, question_code, role from {{ ref('stg_ref__pg_question_role') }}
                where role in ('Hospital NPS', 'Physician NPS')) as r
        on r.service_code = a.service_code and r.question_code = a.question_code
    left join (select service_code, question_code, scale_type from {{ ref('stg_pg__survey_question') }}) as q
        on q.service_code = a.service_code and q.question_code = a.question_code
    left join (select service_code, question_code, answer_code, score from {{ ref('stg_pg__answer_option') }}) as o
        on o.service_code = a.service_code and o.question_code = a.question_code and o.answer_code = a.answer_code
    group by a.surveycode
    {{ hnh_settings() }}  -- left joins in a CTE: settings must sit here
),

base as (
    select
        r.surveycode                                        as surveycode,
        l.branch_key                                        as branch_key,
        r.service_code                                      as service_code,
        r.encounter_id                                      as encounter_id,
        r.visit_date                                        as visit_date,
        r.sms_send_date                                     as sms_send_date,
        r.survey_date                                       as survey_date,
        r.source_status                                     as source_status,
        l.encounter_key                                     as encounter_key,
        l.episode_key                                       as episode_key,
        l.patient_key                                       as patient_key,
        l.staff_key                                         as staff_key,
        l.department_key                                    as department_key,
        l.payer_key                                         as payer_key,
        l.care_type_key                                     as care_type_key,
        l.link_status                                       as link_status,
        toUInt32(ifNull(st.k_answers, 0))                   as answers_count,
        toUInt32(ifNull(st.k_scored_answered, 0))           as scored_questions_answered,
        ifNull(ofr.k_offered, toUInt32(0))                  as scored_questions_offered,
        n.k_nps_score                                       as nps_score,
        n.k_nps_scale                                       as nps_scale,
        n.k_physician_score                                 as physician_nps_score,
        n.k_physician_scale                                 as physician_nps_scale,
{%- for a in attributes %}
        ifNull(bg.{{ a }}, 'Not answered')                  as {{ a }},
{%- endfor %}
        toUInt8(ifNull(st.k_answers, 0) > 0)                as is_responded
    from {{ ref('stg_pg__survey_response') }} as r
    inner join {{ ref('int_survey_encounter_link') }} as l on l.surveycode = r.surveycode
    left join answer_stats as st on st.st_surveycode = r.surveycode
    left join offered as ofr on ofr.of_service_code = r.service_code
    left join nps_answers as n on n.n_surveycode = r.surveycode
    left join {{ ref('int_survey_background') }} as bg on bg.surveycode = r.surveycode
    {{ hnh_settings() }}  -- left joins in a CTE: settings must sit here
)

select
    {{ hnh_surrogate_key(['surveycode']) }}                 as survey_response_key,
    surveycode,
    branch_key,
    service_code                                            as survey_service_key,
    care_type_key,
    encounter_key,
    episode_key,
    patient_key,
    staff_key,
    department_key,
    payer_key,
    {{ hnh_date_key('assumeNotNull(visit_date)') }}         as visit_date_key,
    {{ hnh_date_key_in_range('sms_send_date') }}            as sms_sent_date_key,
    {{ hnh_date_key_in_range('survey_date') }}              as survey_date_key,
    encounter_id,
    source_status,
    multiIf(is_responded = 1 and source_status = 'submitted', 'Submitted',
            is_responded = 1, 'Partial', 'Not started')     as response_status,
    toUInt8(sms_send_date is not null)                      as is_sms_sent,
    is_responded,
    toUInt8(is_responded = 1 and source_status = 'submitted') as is_submitted,
    toUInt8(row_number() over (partition by branch_key, encounter_id
                               order by is_responded desc, survey_date desc, surveycode desc) = 1) as is_primary_for_encounter,
    answers_count,
    scored_questions_offered,
    scored_questions_answered,
    if(sms_send_date is null, null, dateDiff('day', visit_date, sms_send_date)) as days_visit_to_sms,
    if(is_responded = 1, dateDiff('day', visit_date, survey_date), null)        as days_visit_to_answer,
    link_status,
{%- for a in attributes %}
    {{ a }},
{%- endfor %}
    nps_score,
    {{ hnh_survey_band('nps_scale', 'nps_score') }}         as nps_band,
    physician_nps_score,
    {{ hnh_survey_band('physician_nps_scale', 'physician_nps_score') }} as physician_nps_band,
    now()                                                   as _loaded_at
from base
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_survey_response`
Expected: the unit test and all schema tests PASS (the `encounter_key` relationship is a warning and returns 0 rows). Record (measured):

```sql
select response_status, source_status, count(), sum(is_primary_for_encounter), sum(is_sms_sent)
from gold.fact_survey_response group by 1, 2 order by 1, 2
```

Expected: Not started / NOTSTARTED 526,334 (primary 456,213); Not started / incomplete 145,486 (127,994); Not started / submitted 84 (82); Partial / incomplete 6,007 (5,991); Submitted / submitted 24,968 (24,772). `countIf(nps_band is not null)` = 25,440; `countIf(physician_nps_band is not null)` = 14,883; `countIf(scored_questions_answered > scored_questions_offered)` = 0; `min(days_visit_to_answer)` = 0.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/experience/
git commit -m "Add the survey response fact with survey-quality, background and NPS columns" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Survey answer fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/experience/fact_survey_answer.sql`
- Modify: `hnh_dwh/models/hnh/marts/experience/_experience_marts__models.yml`, `_experience_marts_unit_tests.yml`

**Interfaces:**
- Consumes: `fact_survey_response` (Task 6, the columns listed there); `stg_pg__survey_answer`, `stg_pg__survey_question` (reads `question_code, is_scored, item_type, scale_type`), `stg_pg__answer_option` (reads `answer_code, label_en, label_ar, score`) (Task 3); `stg_ref__pg_question_role` (Task 2); `hnh_survey_band` (Task 1).
- Produces: `fact_survey_answer(survey_response_key, surveycode, question_key String, question_code, branch_key, survey_service_key, care_type_key, encounter_key, staff_key, department_key, patient_key, payer_key, visit_date_key, response_status, is_primary_for_encounter, link_status, answer_code, answer_label_en, answer_label_ar Nullable(String), answer_score Nullable(Float64), is_scored UInt8, question_class, scale_type, band Nullable(String), is_promoter, is_passive, is_detractor UInt8, nps_role String, is_option_unknown UInt8, _loaded_at)`.

- [ ] **Step 1: Write the failing unit test and schema tests**

Append to `unit_tests:` in `_experience_marts_unit_tests.yml`:

```yaml
  - name: fact_survey_answer_scores_and_bands
    description: >
      The score comes from the option master, not the raw code: IP cms_23 code 11 = score 10 = Promoter, code 7 = score
      6 = Passive. A 1-4 answer of 2 is a Detractor. An unscored background answer has no score and no band. LTC csurvey
      code 2 has no option row: is_option_unknown = 1. The Hospital NPS question carries its role. The response's keys
      are copied.
    model: fact_survey_answer
    given:
      - input: ref('stg_pg__survey_answer')
        format: sql
        rows: |
          select s as surveycode, sv as service_code, q as question_code, a as answer_code
          from values('s String, sv String, q String, a String',
              ('D1', 'IP', 'cms_23', '11'), ('D2', 'IP', 'cms_23', '7'), ('D1', 'IP', 'cms_24', '2'),
              ('D1', 'IP', 'filling', '1'), ('L1', 'LTC', 'csurvey', '2'), ('D1', 'IP', 'o3', '5'))
      - input: ref('fact_survey_response')
        format: sql
        rows: |
          select s as surveycode, toInt64(k) as survey_response_key, toUInt8(5) as branch_key, sv as survey_service_key,
                 toInt8(3) as care_type_key, toInt64(70) as encounter_key, toInt64(71) as staff_key,
                 toInt64(72) as department_key, toInt64(73) as patient_key, toInt64(74) as payer_key,
                 toInt32(20260901) as visit_date_key, 'Submitted' as response_status,
                 toUInt8(1) as is_primary_for_encounter, 'Linked' as link_status
          from values('s String, k Int64, sv String', ('D1', 1, 'IP'), ('D2', 2, 'IP'), ('L1', 3, 'LTC'))
      - input: ref('stg_pg__survey_question')
        format: sql
        rows: |
          select sv as service_code, q as question_code, sc as scale_type, toUInt8(isc) as is_scored, it as item_type
          from values('sv String, q String, sc String, isc UInt8, it String',
              ('IP', 'cms_23', 'likelihood_0_10', 1, 'GCC Recommended'), ('IP', 'cms_24', 'definitely_1_4', 1, 'GCC Recommended'),
              ('IP', 'filling', 'categorical', 0, 'Background'), ('LTC', 'csurvey', 'categorical', 0, 'Background'),
              ('IP', 'o3', 'rating_1_5', 1, 'Standard'))
      - input: ref('stg_pg__answer_option')
        format: sql
        rows: |
          select sv as service_code, q as question_code, a as answer_code, le as label_en, le as label_ar,
                 if(sc < 0, cast(null as Nullable(Float64)), toNullable(toFloat64(sc))) as score
          from values('sv String, q String, a String, le String, sc Float64',
              ('IP', 'cms_23', '11', '10', 10), ('IP', 'cms_23', '7', '6', 6), ('IP', 'cms_24', '2', 'Probably No', 2),
              ('IP', 'filling', '1', 'Patient', -1), ('IP', 'o3', '5', 'Very Good', 5))
      - input: ref('stg_ref__pg_question_role')
        format: sql
        rows: |
          select sv as service_code, q as question_code, r as role
          from values('sv String, q String, r String', ('IP', 'o3', 'Hospital NPS'), ('IP', 'filling', 'respondent'))
    expect:
      rows:
        - {surveycode: D1, question_key: 'IP|cms_23', answer_score: 10, band: Promoter, is_promoter: 1, is_passive: 0, is_detractor: 0, question_class: Scored, nps_role: '', is_option_unknown: 0, staff_key: 71, branch_key: 5}
        - {surveycode: D2, question_key: 'IP|cms_23', answer_score: 6, band: Passive, is_promoter: 0, is_passive: 1, is_detractor: 0, question_class: Scored, nps_role: '', is_option_unknown: 0, staff_key: 71, branch_key: 5}
        - {surveycode: D1, question_key: 'IP|cms_24', answer_score: 2, band: Detractor, is_promoter: 0, is_passive: 0, is_detractor: 1, question_class: Scored, nps_role: '', is_option_unknown: 0, staff_key: 71, branch_key: 5}
        - {surveycode: D1, question_key: 'IP|filling', answer_score: null, band: null, is_promoter: 0, is_passive: 0, is_detractor: 0, question_class: Background, nps_role: '', is_option_unknown: 0, staff_key: 71, branch_key: 5}
        - {surveycode: L1, question_key: 'LTC|csurvey', answer_score: null, band: null, is_promoter: 0, is_passive: 0, is_detractor: 0, question_class: Background, nps_role: '', is_option_unknown: 1, staff_key: 71, branch_key: 5}
        - {surveycode: D1, question_key: 'IP|o3', answer_score: 5, band: Promoter, is_promoter: 1, is_passive: 0, is_detractor: 0, question_class: Scored, nps_role: Hospital NPS, is_option_unknown: 0, staff_key: 71, branch_key: 5}
```

Append to `_experience_marts__models.yml` under `models:`:

```yaml
  - name: fact_survey_answer
    description: One row per survey and answered question, scored or not, with the NPS-style band (spec 6.2).
    tests:
      - hnh_unique_combination:
          columns: [surveycode, question_code]
    columns:
      - name: survey_response_key
        tests:
          - not_null
          - relationships: {to: ref('fact_survey_response'), field: survey_response_key}
      - name: question_key
        tests:
          - relationships: {to: ref('dim_survey_question'), field: question_key}
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: survey_service_key
        tests:
          - relationships: {to: ref('dim_survey_service'), field: survey_service_key}
      - name: staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: department_key
        tests:
          - relationships: {to: ref('hnh_dim_department'), field: department_key}
      - name: visit_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: band
        tests:
          - accepted_values:
              values: ['Promoter', 'Passive', 'Detractor']
      - name: question_class
        tests:
          - accepted_values:
              values: ['Scored', 'Background', 'Routing']
      - name: nps_role
        tests:
          - accepted_values:
              values: ['Hospital NPS', 'Physician NPS', '']
      - name: is_option_unknown
        description: 1 when the answer code has no option row (LTC csurvey 2 today, open item O-P6-7).
        tests:
          - accepted_values:
              values: [0]
              quote: false
              config: {severity: warn}
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_survey_answer`
Expected: FAIL — the model does not exist.

- [ ] **Step 2: Write `fact_survey_answer.sql`**

```sql
{{ config(order_by='(branch_key, visit_date_key, survey_response_key, question_key)') }}

-- One row per survey and answered question, scored or not (spec 6.2). The response's keys are copied so that NPS by
-- domain, doctor and clinic reads this table alone. answer_score is the option score (never the raw code, spec P4);
-- band is the NPS-style band of a scored answer (hnh_survey_band). A code with no option row is flagged
-- is_option_unknown (LTC csurvey 2, spec O-P6-7); a question missing from the master gets question_key '-1'.
select
    r.survey_response_key                                   as survey_response_key,
    a.surveycode                                            as surveycode,
    if(q.question_code is null, '-1', concat(a.service_code, '|', a.question_code)) as question_key,
    a.question_code                                         as question_code,
    r.branch_key                                            as branch_key,
    r.survey_service_key                                    as survey_service_key,
    r.care_type_key                                         as care_type_key,
    r.encounter_key                                         as encounter_key,
    r.staff_key                                             as staff_key,
    r.department_key                                        as department_key,
    r.patient_key                                           as patient_key,
    r.payer_key                                             as payer_key,
    r.visit_date_key                                        as visit_date_key,
    r.response_status                                       as response_status,
    r.is_primary_for_encounter                              as is_primary_for_encounter,
    r.link_status                                           as link_status,
    a.answer_code                                           as answer_code,
    o.label_en                                              as answer_label_en,
    o.label_ar                                              as answer_label_ar,
    if(ifNull(q.is_scored, 0) = 1, o.score, null)           as answer_score,
    ifNull(q.is_scored, toUInt8(0))                         as is_scored,
    multiIf(q.question_code is null, 'Background', q.is_scored = 1, 'Scored',
            q.item_type = 'Routing', 'Routing', 'Background') as question_class,
    ifNull(q.scale_type, '')                                as scale_type,
    if(ifNull(q.is_scored, 0) = 1, {{ hnh_survey_band('q.scale_type', 'o.score') }}, null) as band,
    toUInt8(ifNull(q.is_scored, 0) = 1 and o.score is not null
            and {{ hnh_survey_band('q.scale_type', 'o.score') }} = 'Promoter')  as is_promoter,
    toUInt8(ifNull(q.is_scored, 0) = 1 and o.score is not null
            and {{ hnh_survey_band('q.scale_type', 'o.score') }} = 'Passive')   as is_passive,
    toUInt8(ifNull(q.is_scored, 0) = 1 and o.score is not null
            and {{ hnh_survey_band('q.scale_type', 'o.score') }} = 'Detractor') as is_detractor,
    if(ifNull(nr.role, '') in ('Hospital NPS', 'Physician NPS'), assumeNotNull(nr.role), '') as nps_role,
    toUInt8(o.answer_code is null)                          as is_option_unknown,
    now()                                                   as _loaded_at
from {{ ref('stg_pg__survey_answer') }} as a
inner join (select survey_response_key, surveycode, branch_key, survey_service_key, care_type_key, encounter_key,
                   staff_key, department_key, patient_key, payer_key, visit_date_key, response_status,
                   is_primary_for_encounter, link_status
            from {{ ref('fact_survey_response') }}) as r
    on r.surveycode = a.surveycode
left join {{ ref('stg_pg__survey_question') }} as q
    on q.service_code = a.service_code and q.question_code = a.question_code
left join {{ ref('stg_pg__answer_option') }} as o
    on o.service_code = a.service_code and o.question_code = a.question_code and o.answer_code = a.answer_code
left join {{ ref('stg_ref__pg_question_role') }} as nr
    on nr.service_code = a.service_code and nr.question_code = a.question_code
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_survey_answer`
Expected: the unit test and schema tests PASS, except `accepted_values_fact_survey_answer_is_option_unknown` which WARNs with 92 rows (LTC `csurvey` 2). Record (measured): 739,968 rows; 618,952 scored; 0 with `question_key = '-1'`; 0 scored rows without a band; and

```sql
select nps_role, count(), round((sum(is_promoter) - sum(is_detractor)) / count() * 100, 1) as nps
from gold.fact_survey_answer where is_scored = 1 group by 1
```

Expected: Hospital NPS 25,440 answers, NPS 68.3; Physician NPS 14,883, NPS 76.9; other scored questions (`nps_role = ''`) 578,629, NPS 73.6.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/experience/
git commit -m "Add the survey answer fact with option scores and NPS bands" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Reconciliation and monitors

**Files:**
- Create: `hnh_dwh/models/hnh/marts/reconciliation/rec_survey_monthly.sql`, `hnh_dwh/tests/hnh/assert_survey_hospital_nps_per_service.sql`, `hnh_dwh/tests/hnh/warn_survey_link_rate.sql`
- Modify: `hnh_dwh/models/hnh/marts/reconciliation/_reconciliation__models.yml`

**Interfaces:**
- Consumes: `stg_pg__survey_response`, `stg_pg__survey_answer`, `hnh_dim_branch`, `fact_survey_response`, `fact_survey_answer`, `stg_ref__pg_question_role`.
- Produces: `rec_survey_monthly(branch_key UInt8, survey_service_key String, month_start Date, source_invitations, gold_invitations, invitation_difference Int64, source_answers, gold_answers, answer_difference Int64, linked_invitations, link_rate Float64, responded, responded_with_doctor)`.

- [ ] **Step 1: Write the failing tests**

Append to `_reconciliation__models.yml` under `models:`:

```yaml
  - name: rec_survey_monthly
    description: Press Ganey source against gold per branch, survey service and visit month; link rate (spec 6.3, 8).
    tests:
      - hnh_unique_combination:
          columns: [branch_key, survey_service_key, month_start]
    columns:
      - name: invitation_difference
        tests:
          - hnh_within_tolerance:
              tolerance: 0
      - name: answer_difference
        tests:
          - hnh_within_tolerance:
              tolerance: 0
```

`hnh_dwh/tests/hnh/assert_survey_hospital_nps_per_service.sql`:

```sql
-- Every service with survey invitations has exactly one Hospital NPS question in map_pg_question_role (spec 8).
select r.service_code as service_code, countIf(q.role = 'Hospital NPS') as hospital_nps_questions
from (select distinct service_code from {{ ref('stg_pg__survey_response') }}) as r
left join {{ ref('stg_ref__pg_question_role') }} as q on q.service_code = r.service_code
group by r.service_code
having hospital_nps_questions != 1
```

`hnh_dwh/tests/hnh/warn_survey_link_rate.sql`:

```sql
{{ config(severity='warn') }}
-- Branch-service-months (100+ invitations) where under 80% of surveys link to an encounter (spec 8). Khamis (2) from
-- December 2025 to July 2026 is the known outpatient appointment gap (O-P6-1) and is left out.
select branch_key, survey_service_key, month_start, source_invitations, link_rate
from {{ ref('rec_survey_monthly') }}
where source_invitations >= 100 and link_rate < 0.8
  and not (branch_key = 2 and month_start between toDate('2025-12-01') and toDate('2026-07-01'))
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select rec_survey_monthly assert_survey_hospital_nps_per_service warn_survey_link_rate`
Expected: FAIL — `rec_survey_monthly` does not exist.

- [ ] **Step 2: Write `rec_survey_monthly.sql`**

```sql
{{ config(order_by='(branch_key, survey_service_key, month_start)') }}

-- Source against gold per branch, survey service and visit month (spec 6.3, 8): invitations and non-null answers must
-- match exactly; link rate is monitored. Branch from dim_branch.pg_branch_code (0 when the code is unknown).
with branches as (
    select branch_key, pg_branch_code from {{ ref('hnh_dim_branch') }} where pg_branch_code is not null
),

source_invitations as (
    select ifNull(b.branch_key, toUInt8(0)) as s_branch_key, r.service_code as s_service, toStartOfMonth(r.visit_date) as s_month,
           count() as k_source_invitations
    from {{ ref('stg_pg__survey_response') }} as r
    left join branches as b on b.pg_branch_code = r.pg_branch_code
    group by s_branch_key, s_service, s_month
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

source_answers as (
    select ifNull(b.branch_key, toUInt8(0)) as a_branch_key, r.service_code as a_service, toStartOfMonth(r.visit_date) as a_month,
           count() as k_source_answers
    from {{ ref('stg_pg__survey_answer') }} as a
    inner join (select surveycode, pg_branch_code, service_code, visit_date from {{ ref('stg_pg__survey_response') }}) as r
        on r.surveycode = a.surveycode
    left join branches as b on b.pg_branch_code = r.pg_branch_code
    group by a_branch_key, a_service, a_month
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

gold_responses as (
    select branch_key as g_branch_key, survey_service_key as g_service,
           toStartOfMonth(YYYYMMDDToDate(toUInt32(visit_date_key))) as g_month,
           count() as k_gold_invitations, countIf(link_status = 'Linked') as k_linked,
           countIf(is_responded = 1) as k_responded, countIf(is_responded = 1 and staff_key != -1) as k_responded_with_doctor
    from {{ ref('fact_survey_response') }}
    group by g_branch_key, g_service, g_month
),

gold_answers as (
    select branch_key as ga_branch_key, survey_service_key as ga_service,
           toStartOfMonth(YYYYMMDDToDate(toUInt32(visit_date_key))) as ga_month, count() as k_gold_answers
    from {{ ref('fact_survey_answer') }}
    group by ga_branch_key, ga_service, ga_month
)

select
    s.s_branch_key                                          as branch_key,
    s.s_service                                             as survey_service_key,
    s.s_month                                               as month_start,
    s.k_source_invitations                                  as source_invitations,
    ifNull(g.k_gold_invitations, 0)                         as gold_invitations,
    toInt64(s.k_source_invitations) - toInt64(ifNull(g.k_gold_invitations, 0)) as invitation_difference,
    ifNull(sa.k_source_answers, 0)                          as source_answers,
    ifNull(ga.k_gold_answers, 0)                            as gold_answers,
    toInt64(ifNull(sa.k_source_answers, 0)) - toInt64(ifNull(ga.k_gold_answers, 0)) as answer_difference,
    ifNull(g.k_linked, 0)                                   as linked_invitations,
    round(ifNull(g.k_linked, 0) / s.k_source_invitations, 4) as link_rate,
    ifNull(g.k_responded, 0)                                as responded,
    ifNull(g.k_responded_with_doctor, 0)                    as responded_with_doctor
from source_invitations as s
left join gold_responses as g on g.g_branch_key = s.s_branch_key and g.g_service = s.s_service and g.g_month = s.s_month
left join source_answers as sa on sa.a_branch_key = s.s_branch_key and sa.a_service = s.s_service and sa.a_month = s.s_month
left join gold_answers as ga on ga.ga_branch_key = s.s_branch_key and ga.ga_service = s.s_service and ga.ga_month = s.s_month
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select rec_survey_monthly assert_survey_hospital_nps_per_service warn_survey_link_rate`
Expected: all PASS; `warn_survey_link_rate` returns 0 rows (measured: every cell under 80% is Khamis December 2025 – July 2026, OP / DEN / OR). Record: `rec_survey_monthly` 505 rows; Σ `source_invitations` 702,879; Σ `source_answers` 739,968; Σ |differences| 0; and the cells the warning leaves out:

```sql
select branch_key, survey_service_key, month_start, source_invitations, link_rate
from gold.rec_survey_monthly where source_invitations >= 100 and link_rate < 0.8 order by 1, 2, 3
```

(measured: 24 cells, all branch 2, e.g. OP 2026-05 11,081 invitations, link rate 0.0).

- [ ] **Step 4: Prove the Hospital-NPS test can fail**

Run once, read-only, through `ch_env`, the test's SQL against a role map without IP (a quick check that the test is not vacuous):

```sql
select r.service_code, countIf(q.role = 'Hospital NPS') as n
from (select distinct service_code from stg.stg_pg__survey_response) as r
left join (select * from stg.stg_ref__pg_question_role where service_code != 'IP') as q on q.service_code = r.service_code
group by r.service_code having n != 1
```

Expected: one row, `('IP', 0)`.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/reconciliation/ hnh_dwh/tests/hnh/assert_survey_hospital_nps_per_service.sql hnh_dwh/tests/hnh/warn_survey_link_rate.sql
git commit -m "Reconcile Press Ganey surveys and monitor the encounter link rate" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Documentation, full build and measurements

**Files:**
- Create: `docs/reconciliation_phase6.md`
- Modify: `docs/receiving_project_config.md`, `docs/superpowers/specs/2026-10-07-hnh-dwh-phase6-patient-experience-design.md` (section 11), `docs/superpowers/specs/2026-10-01-hnh-dwh-gold-layer-design.md` (O10)

- [ ] **Step 1: Full build**

Run: `python scripts/run_dbt.py build --select tag:hnh`
Expected: `ERROR=0`. Note PASS, WARN and the duration (Phase 5 merge build: PASS=1040 WARN=49 ERROR=0; Phase 6 adds about 60 nodes and a few minutes). If a test errors, report BLOCKED with the node and error (do not change models in this task). Record the build's peak memory: `select formatReadableSize(max(memory_usage)), argMax(substring(query, 1, 120), memory_usage) from system.query_log where event_time > now() - interval 2 hour and type = 'QueryFinish'`.

- [ ] **Step 2: Measure**

Through `ch_env`, record:
1. Row counts of every Phase 6 model (staging views not counted).
2. Survey quality by branch for primary invitations with visit months 2026-01 to 2026-09: invitations, SMS reach %, response rate %, completion rate %, answer completeness %, median days visit → answer, encounter link %, doctor attribution %:

```sql
select branch_key,
       countIf(is_primary_for_encounter = 1) as invitations,
       round(countIf(is_primary_for_encounter = 1 and is_sms_sent = 1) / invitations * 100, 1) as sms_reach,
       round(countIf(is_primary_for_encounter = 1 and is_responded = 1) / invitations * 100, 1) as response_rate,
       round(countIf(is_primary_for_encounter = 1 and is_submitted = 1) / countIf(is_primary_for_encounter = 1 and is_responded = 1) * 100, 1) as completion_rate,
       round(sumIf(scored_questions_answered, is_primary_for_encounter = 1 and is_responded = 1)
             / sumIf(scored_questions_offered, is_primary_for_encounter = 1 and is_responded = 1) * 100, 1) as completeness,
       medianIf(days_visit_to_answer, is_primary_for_encounter = 1 and is_responded = 1) as median_days,
       round(countIf(is_primary_for_encounter = 1 and link_status = 'Linked') / invitations * 100, 1) as link_rate,
       round(countIf(is_primary_for_encounter = 1 and is_responded = 1 and staff_key != -1)
             / countIf(is_primary_for_encounter = 1 and is_responded = 1) * 100, 1) as doctor_attribution
from gold.fact_survey_response
where visit_date_key between 20260101 and 20260930
group by branch_key order by branch_key
```

3. Hospital NPS and Physician NPS by branch and service for 2026 (answers with `nps_role`), with n.
4. Domain NPS for OP group-wide for 2026 (join `gold.dim_survey_question` on `question_key`, group by `domain_en`, scored answers), with n.
5. The 10 doctors with the most OP Physician NPS answers in 2026: `dim_staff.staff_name`, `unified_specialty`, n, NPS (to show the doctor slice works; do not judge the doctors).
6. Background slices: Hospital NPS by `respondent_type` and by `booking_channel` (OP) for 2026.
7. Spot checks: trace 20 surveys (at least one IP with `cms_23` and `cms_24` answers) from `press_ganey.pg_survey_responses` `responses` JSON to their `gold.fact_survey_answer` rows — code, label, score, band; recompute Hospital NPS for Jazan (3) September 2026 straight from the source JSON and the option master, and compare with gold.

- [ ] **Step 3: Write `docs/reconciliation_phase6.md`**

Sections (fill every number from Steps 1–2; no placeholders left):
1. **Build and row counts** — the build totals, duration, peak memory; row counts.
2. **Source against gold (`gold.rec_survey_monthly`)** — invitations 702,879 and answers 739,968 at planning (current values from the build), zero differences; the 54 skipped `initial_response` values and the always-empty `comments` key (O-P6-3).
3. **Encounter link** — link rate by branch and service; the Khamis December 2025 – July 2026 gap (O-P6-1) covering OP, DEN and OR (why outpatient rehab looked like 50%, closing O-P6-2); 30 linked ER surveys without a doctor; doctor rule (IP consultant, else treating, else booked).
4. **Survey quality** — the Step 2.2 table; why response rate uses all primary invitations (8,259 submitted surveys without an SMS date, Muhayil none at all); the 84 `submitted` surveys without answers counted as Not started; repeat invitations (79,801 encounters with 2–5 invitations, 208 with more than one answered).
5. **NPS** — Hospital and Physician NPS by branch and service; OP domain NPS; the bands (1–5: 4–5 / 3 / 1–2; 1–4: 3–4 / – / 1–2; 0–10: 8–10 / 5–7 / 0–4) and that 5-point NPS is not comparable to external 0–10 benchmarks (O-P6-4).
6. **Background attributes** — coverage of each attribute (share of responded surveys not `Not answered`), NPS by respondent type and booking channel; `contact_consent` always Not answered.
7. **Monitors at first build** — `is_option_unknown` (92 rows, LTC `csurvey` 2), `warn_survey_link_rate` (0), the `encounter_key` relationship warning (0).
8. **Known data findings** — LTC `csurvey` code 2 missing from the option master and drafted as Family member (O-P6-7); TM `visttype` labels swapped between English and Arabic in the option master (code 1 "Video Call" / "الاتصال الهاتفي", code 2 "Voice Call" / "الاتصال المرئي"); Ghirnata and Muhayil surveys start mid-September 2026 (O-P6-5); DIA, ON and OU have questions but almost no surveys; the reference maps await review (O-P6-7) and, because the loader never overwrites, a reviewed version is loaded by truncating `default.map_pg_question_role` / `default.map_pg_background_value` first.

- [ ] **Step 4: Update `docs/receiving_project_config.md`**

1. In "How the models read Oasis" (it lists the sources the `hnh` YAML declares), add: the `hnh` YAML also declares a source named `press_ganey` (tables `pg_survey_responses`, `pg_survey_questions`, `pg_survey_answer_options`, `dim_pg_service`), read with `source()` — the receiving project has no source of that name (checked against `dbt/models`); the staging never reads the database's own views.
2. In "Reference tables that must exist in `default`" add `map_pg_question_role` and `map_pg_background_value` (drafted by `scripts/draft_pg_maps.py`, loaded with `python scripts/load_reference_data.py --only map_pg_question_role map_pg_background_value`; review pending, O-P6-7).
3. Append to "Notes for the SSAS model" (spec 7, 9):
   - Put `fact_survey_response` and `fact_survey_answer` in a patient-experience perspective; both join `dim_branch`, so branch row-level security applies. `fact_survey_answer` → `fact_survey_response` is not a relationship: the answer fact carries the response keys itself.
   - Relationships: both facts → `dim_branch`, `dim_survey_service`, `dim_staff` (survey doctor), `dim_department` (clinic), `dim_care_type`, `dim_date` on `visit_date_key` (active); `fact_survey_response` also → `dim_patient`, `dim_payer`, `dim_date` on `sms_sent_date_key` and `survey_date_key` (inactive); `fact_survey_answer` → `dim_survey_question`.
   - Survey quality (spec 7.1) uses `is_primary_for_encounter = 1`: Invitations = count; SMS reach = `is_sms_sent`; Response rate = `is_responded` ÷ invitations (not ÷ SMS sent, see `docs/reconciliation_phase6.md`); Completion = `is_submitted` ÷ `is_responded`; Answer completeness = Σ `scored_questions_answered` ÷ Σ `scored_questions_offered` over responded; Link % = `link_status = "Linked"`; Doctor attribution = responded with `staff_key <> -1` ÷ responded.
   - NPS (spec 7.2) = (Σ `is_promoter` − Σ `is_detractor`) ÷ COUNTROWS × 100 over `fact_survey_answer` with `is_scored = 1`; Hospital NPS filters `nps_role = "Hospital NPS"`, Physician NPS `nps_role = "Physician NPS"`; domain and question NPS use the same measure under a `dim_survey_question` filter. Always show n next to NPS and display "insufficient sample" when n < 30. Label it "NPS (5-point)".
   - Background attributes (`respondent_type`, `first_visit`, `booking_channel`, …) are columns on `fact_survey_response`; to slice answer-level NPS by them, relate through `survey_response_key` in DAX (`TREATAS`) or add them to a survey-attribute dimension in SSAS.
4. Under "Deployment checklist" step 6, add the Phase 6 build totals from Step 1.

- [ ] **Step 5: Record changes in the specs**

1. In the Phase 6 spec add `## 11. Changes during implementation (<date>)` with one sentence per row of this plan's "Spec refinements made while planning" table, plus any change made while implementing; mark O-P6-2 and O-P6-6 closed in section 10.
2. In the parent spec `2026-10-01-hnh-dwh-gold-layer-design.md`, section 14, change the O10 row's default to "Closed 2026-10-07: outpatient link 87% (514,659 of 589,401), ER 99.3%, IP 100%; misses are the Khamis Dec 2025 – Jul 2026 appointment gap (Phase 6 spec P6, P7)".

- [ ] **Step 6: Commit**

```bash
git add docs/reconciliation_phase6.md docs/receiving_project_config.md docs/superpowers/specs/2026-10-07-hnh-dwh-phase6-patient-experience-design.md docs/superpowers/specs/2026-10-01-hnh-dwh-gold-layer-design.md
git commit -m "Document Phase 6 hand-off and patient-experience reconciliation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
