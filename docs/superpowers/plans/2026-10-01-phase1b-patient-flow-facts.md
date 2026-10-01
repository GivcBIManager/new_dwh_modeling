# Phase 1B — Patient-Flow Facts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the patient-flow intermediate models and the seven Phase 1 facts in `gold`, with the corrected KPI rules, their `legacy_*` reconciliation fields, and a monthly reconciliation model.

**Architecture:** Transactional Oasis tables are staged as views, unified in four intermediate tables (`int_episode`, `int_bed_segment` / `int_bed_day`, `int_admission`, `int_encounter`), and published as facts that join to the conformed dimensions from Phase 1A. Row-level rules are macros tested with literal inputs; multi-row rules (tie-breaks, look-back, midnight census, no-show) are covered by dbt unit tests with SQL fixtures.

**Tech Stack:** ClickHouse 26.5, dbt-core 1.11.12, dbt-clickhouse 1.9.8.

**Spec:** `docs/superpowers/specs/2026-10-01-hnh-dwh-gold-layer-design.md`

**Prerequisite:** every task of `docs/superpowers/plans/2026-10-01-phase1a-foundation-and-dimensions.md` is complete and `python scripts/run_dbt.py build --select tag:hnh` passes.

## Global Constraints

- All constraints of the Phase 1A plan apply unchanged (databases, portability, staging rules, `branch_id` as `UInt8`, wall-clock timestamps, `hnh_surrogate_key`, `{{ hnh_settings() }}` on every model with a `left join`, `tests:` YAML key, `python scripts/run_dbt.py`).
- `use_lw_deletes: true` must be present in `hnh_dwh/profiles.yml` (added to the example in Phase 1A) before Task 7.
- Facts start at `var('hnh_history_start_date')` (default `2022-01-01`). Intermediate models keep all history so look-back rules are correct.
- Fact dimension keys are never null: a reference missing from its dimension becomes `-1`. Optional date and time keys (`*_date_key`, `*_time_key`) are nullable.
- Every fact has `_loaded_at` (`now()`), engine `MergeTree`, and an `order_by` starting with `branch_key`.
- Fields that reproduce old-warehouse behaviour are prefixed `legacy_` and are never used by a new KPI.
- dbt unit tests live in files named `*_unit_tests.yml`, use `format: sql` for every `given` input, and need dbt-core 1.8 or later.
- Durations are whole minutes; a duration below 0 or above 1,440 is null in the guarded column and kept in the matching `*_raw` column.
- Cancellation is decided only by the outcome group (`Cancelled`, `Rescheduled`), never by a hard-coded code list, except inside `legacy_*` fields.

## Review Focus

1. **A stay with no discharge yet** (about 1,500 open stays at any time): `los_hours` must be null rather than negative or growing, the stay must still count as an admission, and its bed must be occupied in the daily snapshot up to yesterday. Pinned in Task 4 (`int_admission` unit test, row "open stay") and Task 3 (`int_bed_day` unit test).
2. **A booked appointment that never became an episode** (patient booked, did not arrive): the row must be kept, typed `OP`, and be eligible for the no-show count. Pinned in Task 5 (`int_encounter` unit test, row "booked, no episode").
3. **A patient who misses a booked slot but walks in the same day:** the booked slot must not be a no-show. Pinned in Task 5 (`int_encounter` unit test, row "missed but walked in").
4. **An admission whose last bed is in an excluded ward** (pre-op, booking, nursing): the admission must stay in `fact_admission`, with first and last ward taken from non-excluded segments. Pinned in Task 4 (`int_admission` unit test, row "last bed excluded").
5. **Timestamps out of order** (seen before arrived, or a completion days later): the guarded minutes must be null and the raw value preserved. Pinned in Task 5 (`int_encounter` unit test, row "seen before arrived").

## File Structure

```
hnh_dwh/
  macros/hnh/hnh_rules_flow.sql                      admission and visit rules
  macros/hnh/hnh_log_run.sql                         run-log hook
  tests/hnh/assert_hnh_flow_rule_macros.sql
  tests/hnh/assert_*.sql, warn_*.sql                 conservation and monitor tests
  models/hnh/staging/oasis/stg_oasis__*.sql          ten transactional staging views
  models/hnh/staging/reference/stg_ref__budget.sql
  models/hnh/intermediate/patient_flow/
    _patient_flow__models.yml
    _patient_flow_unit_tests.yml
    int_episode.sql, int_bed_segment.sql, int_bed_day.sql, int_admission.sql, int_encounter.sql
  models/hnh/marts/patient_flow/
    _patient_flow_marts__models.yml
    fact_encounter.sql, fact_admission.sql, fact_episode.sql, fact_bed_occupancy_daily.sql,
    agg_clinic_capacity_daily.sql, fact_surgery.sql, fact_target_daily.sql
  models/hnh/marts/reconciliation/
    _reconciliation__models.yml, rec_patient_flow_monthly.sql
docs/reconciliation_phase1.md
```

---

### Task 1: Transactional staging and flow rule macros

**Files:**
- Create in `hnh_dwh/models/hnh/staging/oasis/`: `stg_oasis__appointments.sql`, `stg_oasis__er_visits.sql`, `stg_oasis__admissions.sql`, `stg_oasis__admission_requests.sql`, `stg_oasis__episodes.sql`, `stg_oasis__eligibility.sql`, `stg_oasis__bill_agreements.sql`, `stg_oasis__operating_slots.sql`, `stg_oasis__operations.sql`, `stg_oasis__service_items.sql`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__budget.sql`
- Modify: `hnh_dwh/models/hnh/staging/oasis/_oasis__models.yml` (append)
- Create: `hnh_dwh/macros/hnh/hnh_rules_flow.sql`
- Test: `hnh_dwh/tests/hnh/assert_hnh_flow_rule_macros.sql`

**Interfaces:**
- Consumes: core macros (1A Task 1), sources declared in `_oasis__sources.yml` and `_reference__sources.yml` (1A Tasks 3–4).
- Produces (timestamps are `Nullable(DateTime('Asia/Riyadh'))`; ids `Int64`; staff ids `Nullable(String)`):
  - `stg_oasis__appointments(branch_id, appointment_id, slot_date, work_entity, starts_at, ends_at, slot_minutes, patient_id, episode_no, arrived_at, seen_at, completed_at, booked_staff_id, treating_staff_id, new_followup_flag, outcome_code, break_code, is_walk_in, is_virtual, is_online_booking, booked_from, booked_at, updated_at)`
  - `stg_oasis__er_visits(branch_id, er_visit_id, patient_id, episode_no, priority, arrived_at, triaged_at, treatment_started_at, completed_at, referred_type_code, outcome_code, er_status, work_entity, treating_staff_id)`
  - `stg_oasis__admissions(branch_id, admission_no, patient_id, episode_no, admitted_at, seen_at, estimated_discharge_at, clinical_discharge_at, physical_discharge_at, financial_discharge_at, status_code, outcome_code, bed_class, referred_type_code, admission_mode_code, treating_staff_id)`
  - `stg_oasis__admission_requests(branch_id, admission_request_id, admission_no, patient_id, episode_no, consultant_staff_id, planned_admit_at, work_entity, service_dept, reason_code, admission_department_code, urgency_code, admission_type, created_at)`
  - `stg_oasis__episodes(branch_id, patient_id, episode_no, started_at, ended_at, eligibility_type)`
  - `stg_oasis__eligibility(branch_id, patient_eligibility_id, patient_id, episode_no, sequence, responsibility, attendance_type, consultant_staff_id, service_dept, work_entity, eligibility_work_entity, admission_no)`
  - `stg_oasis__bill_agreements(branch_id, patient_id, episode_no, responsibility_seq, purchaser_code, policy_code, contract_no, status)`
  - `stg_oasis__operating_slots(branch_id, operating_slot_code, work_entity, slot_staff_id, patient_id, episode_no, scheduled_start_at, scheduled_end_at, is_cancelled, cancel_code, hall_arrived_at, theatre_arrived_at, anaesthesia_started_at, anaesthesia_ended_at, operation_started_at, operation_ended_at, recovery_at, ward_at, entity_type)`
  - `stg_oasis__operations(branch_id, operating_slot_code, operation_seq, ios_main, operation_status_code, service_dept, surgeon_staff_id, operation_type_code, anaesthesia_type_code, anaesthetist_staff_id, operation_started_at, operation_ended_at)`
  - `stg_oasis__service_items(branch_id, ios_main, description, product_code, product_category_code)`
  - `stg_ref__budget(branch_id, target_date, scenario, care_type, stay_type, creditor, specialty, census, episodes, cost_per_episode, alos, revenue, is_latest)`
  - Macros: `hnh_is_short_stay(admitted_col, discharged_col)` → `UInt8`; `hnh_is_ltc(los_days_expr, referred_upper_col)` → `UInt8`; `hnh_admission_source(admission_department_upper_col, previous_care_type_col)` → `'OP' | 'ER' | 'Direct'`; `hnh_admission_source_key(expr)` → `Int8`; `hnh_visit_type(is_first_episode_col, is_follow_up_col)` → `'New patient' | 'Free follow-up' | 'Paid visit'`; `hnh_procedure_type(description_upper_col, entity_type_col)` → label; `hnh_procedure_type_key(expr)` → `Int8`.

- [ ] **Step 1: Write the failing macro test**

`hnh_dwh/tests/hnh/assert_hnh_flow_rule_macros.sql`:

```sql
select 'short stay wrong' as failure
where {{ hnh_is_short_stay("toDateTime('2026-09-01 10:00:00')", "toDateTime('2026-09-01 10:59:00')") }} != 1
   or {{ hnh_is_short_stay("toDateTime('2026-09-01 10:00:00')", "toDateTime('2026-09-01 11:00:00')") }} != 0
   or {{ hnh_is_short_stay("toDateTime('2026-09-01 10:00:00')", "cast(null as Nullable(DateTime))") }} != 0

union all
select 'ltc wrong'
where {{ hnh_is_ltc("toFloat64(30)", "'WALK IN'") }} != 0
   or {{ hnh_is_ltc("toFloat64(30.01)", "'WALK IN'") }} != 1
   or {{ hnh_is_ltc("toFloat64(2)", "'LTC'") }} != 1
   or {{ hnh_is_ltc("cast(null as Nullable(Float64))", "cast(null as Nullable(String))") }} != 0

union all
select 'admission source wrong'
where {{ hnh_admission_source("'OUTPATIENT CLINICS'", "'ER'") }} != 'OP'
   or {{ hnh_admission_source("'OPD'", "cast(null as Nullable(String))") }} != 'OP'
   or {{ hnh_admission_source("'ACCIDENT & EMERGENCY'", "'OP'") }} != 'ER'
   or {{ hnh_admission_source("'ER'", "cast(null as Nullable(String))") }} != 'ER'
   or {{ hnh_admission_source("cast(null as Nullable(String))", "'ER'") }} != 'ER'
   or {{ hnh_admission_source("'DELIVERY ROOM'", "'OP'") }} != 'OP'
   or {{ hnh_admission_source("cast(null as Nullable(String))", "'IP'") }} != 'Direct'
   or {{ hnh_admission_source("cast(null as Nullable(String))", "cast(null as Nullable(String))") }} != 'Direct'

union all
select 'admission source key wrong'
where {{ hnh_admission_source_key("'OP'") }} != 1 or {{ hnh_admission_source_key("'ER'") }} != 2
   or {{ hnh_admission_source_key("'Direct'") }} != 3 or {{ hnh_admission_source_key("'x'") }} != -1

union all
select 'visit type wrong'
where {{ hnh_visit_type("toUInt8(1)", "toUInt8(1)") }} != 'New patient'
   or {{ hnh_visit_type("toUInt8(0)", "toUInt8(1)") }} != 'Free follow-up'
   or {{ hnh_visit_type("toUInt8(0)", "toUInt8(0)") }} != 'Paid visit'

union all
select 'procedure type wrong'
where {{ hnh_procedure_type("'LOWER SEGMENT C.S. WITH TUBAL LIGATION'", "'D'") }} != 'Cesarean'
   or {{ hnh_procedure_type("'CESAREAN SECTION'", "'Z'") }} != 'Cesarean'
   or {{ hnh_procedure_type("'CORONARY ANGIOGRAPHY'", "'J'") }} != 'Cath Lab'
   or {{ hnh_procedure_type("'COLONOSCOPY'", "'F'") }} != 'Endoscopy'
   or {{ hnh_procedure_type("'NORMAL DELIVERY'", "'Z'") }} != 'L&D'
   or {{ hnh_procedure_type("'APPENDECTOMY'", "'D'") }} != 'Surgery'
   or {{ hnh_procedure_type("cast(null as Nullable(String))", "cast(null as Nullable(String))") }} != 'Surgery'

union all
select 'procedure type key wrong'
where {{ hnh_procedure_type_key("'Surgery'") }} != 1 or {{ hnh_procedure_type_key("'Cesarean'") }} != 2
   or {{ hnh_procedure_type_key("'Cath Lab'") }} != 3 or {{ hnh_procedure_type_key("'Endoscopy'") }} != 4
   or {{ hnh_procedure_type_key("'L&D'") }} != 5
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_flow_rule_macros`
Expected: a compilation error containing `'hnh_is_short_stay' is undefined`.

- [ ] **Step 3: Write the flow rule macros**

`hnh_dwh/macros/hnh/hnh_rules_flow.sql`:

```sql
{# A closed stay shorter than one hour. An open stay is never a short stay. #}
{% macro hnh_is_short_stay(admitted_col, discharged_col) -%}
toUInt8(ifNull(dateDiff('minute', {{ admitted_col }}, {{ discharged_col }}) < 60, 0))
{%- endmacro %}

{# Long-term care: longer than 30 days, or referred as LTC. #}
{% macro hnh_is_ltc(los_days_expr, referred_upper_col) -%}
toUInt8(ifNull({{ los_days_expr }} > 30, 0) or ifNull({{ referred_upper_col }}, '') = 'LTC')
{%- endmacro %}

{# Where an admission came from: the request's admission department first,
   then the care type of the patient's previous episode. #}
{% macro hnh_admission_source(admission_department_upper_col, previous_care_type_col) -%}
multiIf(
    ifNull({{ admission_department_upper_col }}, '') in ('OUTPATIENT CLINICS', 'OPD'), 'OP',
    ifNull({{ admission_department_upper_col }}, '') in ('ACCIDENT & EMERGENCY', 'ER', 'EMERGENCY'), 'ER',
    ifNull({{ previous_care_type_col }}, '') in ('OP', 'ER'), ifNull({{ previous_care_type_col }}, ''),
    'Direct'
)
{%- endmacro %}

{% macro hnh_admission_source_key(expr) -%}
toInt8(multiIf({{ expr }} = 'OP', 1, {{ expr }} = 'ER', 2, {{ expr }} = 'Direct', 3, -1))
{%- endmacro %}

{% macro hnh_visit_type(is_first_episode_col, is_follow_up_col) -%}
multiIf({{ is_first_episode_col }} = 1, 'New patient', {{ is_follow_up_col }} = 1, 'Free follow-up', 'Paid visit')
{%- endmacro %}

{# Procedure type: Cesarean by description, otherwise by the theatre's entity type. #}
{% macro hnh_procedure_type(description_upper_col, entity_type_col) -%}
multiIf(
    multiSearchAny(ifNull({{ description_upper_col }}, ''), ['C.S ', 'C.S.', 'CESARIAN', 'CESAREAN']), 'Cesarean',
    ifNull({{ entity_type_col }}, '') = 'J', 'Cath Lab',
    ifNull({{ entity_type_col }}, '') = 'F', 'Endoscopy',
    ifNull({{ entity_type_col }}, '') = 'Z', 'L&D',
    'Surgery'
)
{%- endmacro %}

{% macro hnh_procedure_type_key(expr) -%}
toInt8(multiIf({{ expr }} = 'Surgery', 1, {{ expr }} = 'Cesarean', 2, {{ expr }} = 'Cath Lab', 3,
               {{ expr }} = 'Endoscopy', 4, {{ expr }} = 'L&D', 5, -1))
{%- endmacro %}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python scripts/run_dbt.py test --select assert_hnh_flow_rule_macros`
Expected: `PASS=1 WARN=0 ERROR=0`.

- [ ] **Step 5: Append the staging tests**

Append to `hnh_dwh/models/hnh/staging/oasis/_oasis__models.yml`:

```yaml
  - name: stg_oasis__appointments
    tests:
      - hnh_unique_combination:
          columns: [branch_id, appointment_id]
          config:
            where: "patient_id is not null"
  - name: stg_oasis__er_visits
    tests:
      - hnh_unique_combination:
          columns: [branch_id, er_visit_id]
  - name: stg_oasis__admissions
    tests:
      - hnh_unique_combination:
          columns: [branch_id, admission_no]
  - name: stg_oasis__admission_requests
    tests:
      - hnh_unique_combination:
          columns: [branch_id, admission_request_id]
  - name: stg_oasis__episodes
    tests:
      - hnh_unique_combination:
          columns: [branch_id, patient_id, episode_no]
  - name: stg_oasis__eligibility
    tests:
      - hnh_unique_combination:
          columns: [branch_id, patient_eligibility_id]
  - name: stg_oasis__bill_agreements
    tests:
      - hnh_unique_combination:
          columns: [branch_id, patient_id, episode_no, responsibility_seq]
  - name: stg_oasis__operating_slots
    tests:
      - hnh_unique_combination:
          columns: [branch_id, operating_slot_code]
          config:
            where: "patient_id is not null"
  - name: stg_oasis__operations
    tests:
      - hnh_unique_combination:
          columns: [branch_id, operating_slot_code, operation_seq]
  - name: stg_oasis__service_items
    tests:
      - hnh_unique_combination:
          columns: [branch_id, ios_main]
```

The `where` on the two slot tables keeps the uniqueness check on booked rows only; grouping all 372M appointment rows would add minutes to every build for no extra safety.

- [ ] **Step 6: Write the staging models**

`stg_oasis__appointments.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(appointment_id)                     as appointment_id,
    {{ hnh_julian_to_date('julian_date') }}     as slot_date,
    {{ hnh_id('work_entity') }}                 as work_entity,
    {{ hnh_ksa_wall_clock('start_date') }}      as starts_at,
    {{ hnh_ksa_wall_clock('end_date') }}        as ends_at,
    toInt32(appt_length)                        as slot_minutes,
    {{ hnh_id('patient_id') }}                  as patient_id,
    {{ hnh_id('episode_no') }}                  as episode_no,
    {{ hnh_ksa_wall_clock('time_arrived') }}    as arrived_at,
    {{ hnh_ksa_wall_clock('time_seen') }}       as seen_at,
    {{ hnh_ksa_wall_clock('time_complete') }}   as completed_at,
    {{ hnh_code('consultant') }}                as booked_staff_id,
    {{ hnh_code('treated_by') }}                as treating_staff_id,
    {{ hnh_code('new_followup_flag') }}         as new_followup_flag,
    {{ hnh_id('outcome_code') }}                as outcome_code,
    {{ hnh_id('break_code') }}                  as break_code,
    {{ hnh_flag('walkin_flag') }}               as is_walk_in,
    {{ hnh_flag('virtual') }}                   as is_virtual,
    {{ hnh_flag('on_line_booking') }}           as is_online_booking,
    {{ hnh_str('booked_from') }}                as booked_from,
    {{ hnh_ksa_wall_clock('creation_date') }}   as booked_at,
    recorded_updated_at                         as updated_at
from {{ source('oasis', 'appointments') }} final
```

`stg_oasis__er_visits.sql`:

```sql
select
    toUInt8(branch_id)                                  as branch_id,
    toInt64(er_visit_id)                                as er_visit_id,
    {{ hnh_id('patient_id') }}                          as patient_id,
    {{ hnh_id('episode_no') }}                          as episode_no,
    {{ hnh_id('priority') }}                            as priority,
    {{ hnh_ksa_wall_clock('time_arrived') }}            as arrived_at,
    {{ hnh_ksa_wall_clock('time_triaged') }}            as triaged_at,
    {{ hnh_ksa_wall_clock('time_treatment_started') }}  as treatment_started_at,
    {{ hnh_ksa_wall_clock('time_complete') }}           as completed_at,
    {{ hnh_id('referred_type') }}                       as referred_type_code,
    {{ hnh_id('outcome_code') }}                        as outcome_code,
    {{ hnh_code('er_status') }}                         as er_status,
    {{ hnh_id('work_entity') }}                         as work_entity,
    {{ hnh_code('treated_by') }}                        as treating_staff_id
from {{ source('oasis', 'patient_emergency_visit') }} final
```

`stg_oasis__admissions.sql`:

```sql
select
    toUInt8(branch_id)                                    as branch_id,
    toInt64(admission_no)                                 as admission_no,
    {{ hnh_id('patient_id') }}                            as patient_id,
    {{ hnh_id('episode_no') }}                            as episode_no,
    {{ hnh_ksa_wall_clock('admit_date') }}                as admitted_at,
    {{ hnh_ksa_wall_clock('seen_date') }}                 as seen_at,
    {{ hnh_ksa_wall_clock('est_discharge_date') }}        as estimated_discharge_at,
    {{ hnh_ksa_wall_clock('clinical_discharge_date') }}   as clinical_discharge_at,
    {{ hnh_ksa_wall_clock('physical_discharge_date') }}   as physical_discharge_at,
    {{ hnh_ksa_wall_clock('financial_discharge_date') }}  as financial_discharge_at,
    {{ hnh_id('status') }}                                as status_code,
    {{ hnh_id('outcome') }}                               as outcome_code,
    {{ hnh_id('bed_class') }}                             as bed_class,
    {{ hnh_id('referred_type') }}                         as referred_type_code,
    {{ hnh_id('admission_mode') }}                        as admission_mode_code,
    {{ hnh_code('treated_by') }}                          as treating_staff_id
from {{ source('oasis', 'patient_ad') }} final
```

`stg_oasis__admission_requests.sql`:

```sql
select
    toUInt8(branch_id)                               as branch_id,
    toInt64(admission_request_id)                    as admission_request_id,
    {{ hnh_id('admission_no') }}                     as admission_no,
    {{ hnh_id('patient_id') }}                       as patient_id,
    {{ hnh_id('episode_no') }}                       as episode_no,
    {{ hnh_code('consultant_id') }}                  as consultant_staff_id,
    {{ hnh_ksa_wall_clock('planned_admit_date') }}   as planned_admit_at,
    {{ hnh_id('work_entity') }}                      as work_entity,
    {{ hnh_id('service_dept') }}                     as service_dept,
    {{ hnh_id('reason_for_admit') }}                 as reason_code,
    {{ hnh_id('admission_department') }}             as admission_department_code,
    {{ hnh_id('urgency') }}                          as urgency_code,
    {{ hnh_code('admission_type') }}                 as admission_type,
    {{ hnh_ksa_wall_clock('creation_date') }}        as created_at
from {{ source('oasis', 'admission_request') }} final
```

`stg_oasis__episodes.sql`:

```sql
select
    toUInt8(branch_id)                       as branch_id,
    toInt64(patient_id)                      as patient_id,
    toInt64(episode_no)                      as episode_no,
    {{ hnh_ksa_wall_clock('start_date') }}   as started_at,
    {{ hnh_ksa_wall_clock('end_date') }}     as ended_at,
    {{ hnh_id('eligibility_type') }}         as eligibility_type
from {{ source('oasis', 'patient_episodes') }} final
```

`stg_oasis__eligibility.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(patient_eligibility_id)             as patient_eligibility_id,
    {{ hnh_id('patient_id') }}                  as patient_id,
    {{ hnh_id('episode_no') }}                  as episode_no,
    toInt64(sequence)                           as sequence,
    {{ hnh_str('responsibility') }}             as responsibility,
    {{ hnh_code('attendance_type') }}           as attendance_type,
    {{ hnh_code('consultant_id') }}             as consultant_staff_id,
    {{ hnh_id('eligibility_service_dept') }}    as service_dept,
    {{ hnh_id('work_entity') }}                 as work_entity,
    {{ hnh_id('eligibility_work_entity') }}     as eligibility_work_entity,
    {{ hnh_id('admission_no') }}                as admission_no
from {{ source('oasis', 'patient_eligibility') }} final
```

`stg_oasis__bill_agreements.sql`:

```sql
select
    toUInt8(branch_id)                 as branch_id,
    toInt64(patient_id)                as patient_id,
    toInt64(episode_no)                as episode_no,
    toInt64(responsibility_seq)        as responsibility_seq,
    {{ hnh_id('purchaser_code') }}     as purchaser_code,
    {{ hnh_id('policy_code') }}        as policy_code,
    {{ hnh_id('contract_no') }}        as contract_no,
    {{ hnh_code('status') }}           as status
from {{ source('oasis', 'patient_bill_agreements') }} final
```

`stg_oasis__operating_slots.sql`:

```sql
select
    toUInt8(branch_id)                                          as branch_id,
    toInt64(operating_slot_code)                                as operating_slot_code,
    {{ hnh_id('work_entity') }}                                 as work_entity,
    {{ hnh_code('staff_id') }}                                  as slot_staff_id,
    {{ hnh_id('patient_id') }}                                  as patient_id,
    {{ hnh_id('episode_no') }}                                  as episode_no,
    {{ hnh_ksa_wall_clock('operating_start') }}                 as scheduled_start_at,
    {{ hnh_ksa_wall_clock('operating_end') }}                   as scheduled_end_at,
    {{ hnh_flag('cancel_flag') }}                               as is_cancelled,
    {{ hnh_id('cancel_code') }}                                 as cancel_code,
    {{ hnh_ksa_wall_clock('time_arrived_to_hall') }}            as hall_arrived_at,
    {{ hnh_ksa_wall_clock('time_arrived_to_or') }}              as theatre_arrived_at,
    {{ hnh_ksa_wall_clock('anesthesia_started') }}              as anaesthesia_started_at,
    {{ hnh_ksa_wall_clock('anesthesia_ended') }}                as anaesthesia_ended_at,
    {{ hnh_ksa_wall_clock('operation_started') }}               as operation_started_at,
    {{ hnh_ksa_wall_clock('operation_end') }}                   as operation_ended_at,
    {{ hnh_ksa_wall_clock('transfered_to_recovery_room_at') }}  as recovery_at,
    {{ hnh_ksa_wall_clock('transfered_to_ward_at') }}           as ward_at,
    {{ hnh_code('entity_type') }}                               as entity_type
from {{ source('oasis', 'operating_diary_slots') }} final
```

`stg_oasis__operations.sql`:

```sql
select
    toUInt8(branch_id)                              as branch_id,
    toInt64(operating_slot_code)                    as operating_slot_code,
    toInt64(operation_seq)                          as operation_seq,
    {{ hnh_id('ios_main') }}                        as ios_main,
    {{ hnh_id('operation_status') }}                as operation_status_code,
    {{ hnh_id('speciality_service_dept') }}         as service_dept,
    {{ hnh_code('operation_staff_id') }}            as surgeon_staff_id,
    {{ hnh_id('operation_type') }}                  as operation_type_code,
    {{ hnh_id('anesthesia_type') }}                 as anaesthesia_type_code,
    {{ hnh_code('anesthetist_staff_id') }}          as anaesthetist_staff_id,
    {{ hnh_ksa_wall_clock('operation_started') }}   as operation_started_at,
    {{ hnh_ksa_wall_clock('operation_end') }}       as operation_ended_at
from {{ source('oasis', 'operating_slot_details') }} final
```

`stg_oasis__service_items.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(ios_main)                           as ios_main,
    {{ hnh_str('description') }}                as description,
    {{ hnh_code('product_code') }}              as product_code,
    {{ hnh_code('product_category_code') }}     as product_category_code
from {{ source('oasis', 'ios_main_data') }} final
```

`hnh_dwh/models/hnh/staging/reference/stg_ref__budget.sql`:

```sql
select
    toUInt8(BranchId)           as branch_id,
    TableDate                   as target_date,
    Scenario                    as scenario,
    CareType                    as care_type,
    StayType                    as stay_type,
    {{ hnh_str('Creditor') }}   as creditor,
    {{ hnh_str('Speciality') }} as specialty,
    Census                      as census,
    Episodes                    as episodes,
    CPE                         as cost_per_episode,
    ALOS                        as alos,
    Revenue                     as revenue,
    toUInt8(is_last_value)      as is_latest
from {{ source('reference', 'budget_data') }}
```

- [ ] **Step 7: Build and test**

Run: `python scripts/run_dbt.py build --select stg_oasis__appointments stg_oasis__er_visits stg_oasis__admissions stg_oasis__admission_requests stg_oasis__episodes stg_oasis__eligibility stg_oasis__bill_agreements stg_oasis__operating_slots stg_oasis__operations stg_oasis__service_items stg_ref__budget`
Expected: 11 views created, all tests pass.

- [ ] **Step 8: Spot-check counts and the Julian date**

Run: `python scripts/run_dbt.py show --inline "select (select count() from {{ ref('stg_oasis__admissions') }}) as admissions, (select count() from {{ ref('stg_oasis__er_visits') }}) as er_visits, (select count() from {{ ref('stg_oasis__episodes') }}) as episodes, (select countIf(slot_date != toDate(starts_at)) from {{ ref('stg_oasis__appointments') }} where branch_id = 3 and patient_id is not null) as julian_mismatch"`
Expected: about 531,549 admissions, 609,872 ER visits, 4,570,051 episodes, and `julian_mismatch` = 0. A non-zero mismatch means the Julian conversion is off by a day: stop and report before continuing.

- [ ] **Step 9: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_flow.sql hnh_dwh/tests/hnh/assert_hnh_flow_rule_macros.sql hnh_dwh/models/hnh/staging
git commit -m "Add transactional staging and patient-flow rule macros

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Episode model

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/patient_flow/int_episode.sql`
- Create: `hnh_dwh/models/hnh/intermediate/patient_flow/_patient_flow__models.yml`
- Create: `hnh_dwh/models/hnh/intermediate/patient_flow/_patient_flow_unit_tests.yml`

**Interfaces:**
- Consumes: `stg_oasis__episodes`, `stg_oasis__eligibility`, `stg_oasis__bill_agreements` (Task 1); `hnh_care_type` (1A Task 2).
- Produces: `int_episode(branch_id, patient_id, episode_no, started_at, ended_at, eligibility_type, care_type, has_eligibility, consultant_staff_id, service_dept, work_entity, eligibility_admission_no, purchaser_code, policy_code, contract_no, episode_seq, is_first_episode, previous_care_type, legacy_care_type, legacy_purchaser_code)` — one row per `(branch_id, patient_id, episode_no)` that exists in `stg_oasis__episodes`. `purchaser_code` is never null (`9999` when the episode has no active agreement). `previous_care_type` is null for a patient's first episode.

- [ ] **Step 1: Write the tests**

`_patient_flow__models.yml`:

```yaml
version: 2

models:
  - name: int_episode
    tests:
      - hnh_unique_combination:
          columns: [branch_id, patient_id, episode_no]
    columns:
      - name: care_type
        tests:
          - accepted_values:
              values: ["OP", "ER", "IP", "DAYCASE", "Unknown"]
      - name: purchaser_code
        tests: [not_null]
      - name: episode_seq
        tests: [not_null]
```

`_patient_flow_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: int_episode_picks_primary_rows_deterministically
    description: >
      The eligibility row with the lowest sequence wins, then the lowest id. The active
      bill agreement with the lowest responsibility sequence wins. Episode rank counts
      episodes that exist only in the pre-2022 eligibility history.
    model: int_episode
    given:
      - input: ref('stg_oasis__episodes')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(100) as patient_id, toInt64(5) as episode_no,
                 toNullable(toDateTime('2026-03-01 09:00:00', 'Asia/Riyadh')) as started_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as ended_at,
                 toNullable(toInt64(279)) as eligibility_type
          union all
          select toUInt8(1), toInt64(200), toInt64(1),
                 toNullable(toDateTime('2026-03-02 09:00:00', 'Asia/Riyadh')),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(Int64))
      - input: ref('stg_oasis__eligibility')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(900) as patient_eligibility_id,
                 toNullable(toInt64(100)) as patient_id, toNullable(toInt64(5)) as episode_no,
                 toNullable(toInt64(2)) as sequence, toNullable('1') as responsibility,
                 toNullable('I') as attendance_type, toNullable('D900') as consultant_staff_id,
                 toNullable(toInt64(10)) as service_dept, toNullable(toInt64(1000)) as work_entity,
                 cast(null as Nullable(Int64)) as eligibility_work_entity, cast(null as Nullable(Int64)) as admission_no
          union all
          select toUInt8(1), toInt64(950), toNullable(toInt64(100)), toNullable(toInt64(5)),
                 toNullable(toInt64(1)), toNullable('1'), toNullable('O'), toNullable('D950'),
                 toNullable(toInt64(11)), toNullable(toInt64(1001)), toNullable(toInt64(2002)), cast(null as Nullable(Int64))
          union all
          select toUInt8(1), toInt64(10), toNullable(toInt64(100)), toNullable(toInt64(2)),
                 toNullable(toInt64(1)), toNullable('1'), toNullable('E'), toNullable('D010'),
                 cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64))
      - input: ref('stg_oasis__bill_agreements')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(100) as patient_id, toInt64(5) as episode_no,
                 toInt64(2) as responsibility_seq, toNullable(toInt64(300)) as purchaser_code,
                 toNullable(toInt64(30)) as policy_code, toNullable(toInt64(3)) as contract_no, toNullable('I') as status
          union all
          select toUInt8(1), toInt64(100), toInt64(5), toInt64(1), toNullable(toInt64(200)),
                 toNullable(toInt64(20)), toNullable(toInt64(2)), cast(null as Nullable(String))
          union all
          select toUInt8(1), toInt64(100), toInt64(5), toInt64(0), toNullable(toInt64(999)),
                 toNullable(toInt64(99)), toNullable(toInt64(9)), toNullable('C')
    expect:
      rows:
        - {branch_id: 1, patient_id: 100, episode_no: 5, care_type: "OP", has_eligibility: 1, consultant_staff_id: "D950", work_entity: 2002, purchaser_code: 200, policy_code: 20, episode_seq: 2, is_first_episode: 0, previous_care_type: "ER"}
        - {branch_id: 1, patient_id: 200, episode_no: 1, care_type: "Unknown", has_eligibility: 0, consultant_staff_id: null, work_entity: null, purchaser_code: 9999, policy_code: null, episode_seq: 1, is_first_episode: 1, previous_care_type: null}
```

- [ ] **Step 2: Run to verify the unit test fails**

Run: `python scripts/run_dbt.py test --select int_episode_picks_primary_rows_deterministically`
Expected: an error that the model `int_episode` was not found.

- [ ] **Step 3: Write `int_episode`**

```sql
{{ config(order_by='(branch_id, patient_id, episode_no)') }}

with eligibility as (
    select * from {{ ref('stg_oasis__eligibility') }}
    where patient_id is not null and episode_no is not null
),

primary_eligibility as (
    -- One row per episode: lowest sequence, then lowest id. The whole row is taken
    -- as a tuple so every attribute comes from the same source row.
    select
        branch_id, patient_id, episode_no,
        argMin(
            tuple(attendance_type, consultant_staff_id, service_dept, coalesce(eligibility_work_entity, work_entity), admission_no),
            tuple(ifNull(sequence, 999999999), patient_eligibility_id)
        )                       as chosen,
        any(attendance_type)    as legacy_attendance_type
    from eligibility
    where responsibility = '1'
    group by branch_id, patient_id, episode_no
),

payer as (
    select
        branch_id, patient_id, episode_no,
        argMin(tuple(purchaser_code, policy_code, contract_no), tuple(responsibility_seq, ifNull(contract_no, 0))) as chosen,
        any(purchaser_code) as legacy_purchaser_code
    from {{ ref('stg_oasis__bill_agreements') }}
    where ifNull(status, 'I') = 'I'
    group by branch_id, patient_id, episode_no
),

episode_history as (
    -- Every episode ever recorded for a patient, including pre-2022 episodes that
    -- exist only in eligibility, so rank and look-back are correct.
    select h.branch_id as branch_id, h.patient_id as patient_id, h.episode_no as episode_no,
           tupleElement(pe.chosen, 1) as attendance_type
    from (
        select distinct branch_id, assumeNotNull(patient_id) as patient_id, assumeNotNull(episode_no) as episode_no from eligibility
        union distinct
        select branch_id, patient_id, episode_no from {{ ref('stg_oasis__episodes') }}
    ) as h
    left join primary_eligibility as pe
        on pe.branch_id = h.branch_id and pe.patient_id = h.patient_id and pe.episode_no = h.episode_no
),

ranked as (
    select
        branch_id, patient_id, episode_no,
        row_number() over (partition by branch_id, patient_id order by episode_no) as episode_seq,
        lagInFrame(toNullable(attendance_type), 1) over (
            partition by branch_id, patient_id order by episode_no
            rows between unbounded preceding and current row
        ) as previous_attendance_type
    from episode_history
)

select
    e.branch_id                                              as branch_id,
    e.patient_id                                             as patient_id,
    e.episode_no                                             as episode_no,
    e.started_at                                             as started_at,
    e.ended_at                                               as ended_at,
    e.eligibility_type                                       as eligibility_type,
    {{ hnh_care_type('tupleElement(pe.chosen, 1)') }}        as care_type,
    toUInt8(pe.branch_id is not null)                        as has_eligibility,
    tupleElement(pe.chosen, 2)                               as consultant_staff_id,
    tupleElement(pe.chosen, 3)                               as service_dept,
    tupleElement(pe.chosen, 4)                               as work_entity,
    tupleElement(pe.chosen, 5)                               as eligibility_admission_no,
    ifNull(tupleElement(py.chosen, 1), toInt64(9999))        as purchaser_code,
    tupleElement(py.chosen, 2)                               as policy_code,
    tupleElement(py.chosen, 3)                               as contract_no,
    toUInt32(r.episode_seq)                                  as episode_seq,
    toUInt8(r.episode_seq = 1)                               as is_first_episode,
    if(r.episode_seq = 1 or r.previous_attendance_type is null, null,
       {{ hnh_care_type('r.previous_attendance_type') }})    as previous_care_type,
    {{ hnh_care_type('pe.legacy_attendance_type') }}         as legacy_care_type,
    ifNull(py.legacy_purchaser_code, toInt64(9999))          as legacy_purchaser_code
from {{ ref('stg_oasis__episodes') }} as e
left join primary_eligibility as pe
    on pe.branch_id = e.branch_id and pe.patient_id = e.patient_id and pe.episode_no = e.episode_no
left join payer as py
    on py.branch_id = e.branch_id and py.patient_id = e.patient_id and py.episode_no = e.episode_no
left join ranked as r
    on r.branch_id = e.branch_id and r.patient_id = e.patient_id and r.episode_no = e.episode_no
{{ hnh_settings() }}
```

`legacy_care_type` and `legacy_purchaser_code` use `any()`, like the old `mv_eligibility`. The old pick was arbitrary, so these two fields are approximate and are excluded from the reconciliation threshold.

- [ ] **Step 4: Run the unit test, then build**

Run: `python scripts/run_dbt.py test --select int_episode_picks_primary_rows_deterministically`
Expected: `PASS=1`.

Run: `python scripts/run_dbt.py build --select int_episode`
Expected: 1 table created, all tests pass (the unit test runs again as part of the build).

- [ ] **Step 5: Spot-check**

Run: `python scripts/run_dbt.py show --inline "select care_type, count() as episodes, countIf(is_first_episode = 1) as first_episodes, countIf(purchaser_code = 9999) as cash from {{ ref('int_episode') }} group by care_type order by episodes desc"`
Expected: `OP` is the largest group, `Unknown` is a small fraction (episodes with no eligibility row), and `first_episodes` is well below `episodes`.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/patient_flow
git commit -m "Add int_episode with deterministic care type and payer

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Bed segments and daily bed state

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/patient_flow/int_bed_segment.sql`, `int_bed_day.sql`
- Modify: `_patient_flow__models.yml`, `_patient_flow_unit_tests.yml` (append)

**Interfaces:**
- Consumes: `stg_oasis__bed_details` (1A Task 5); `stg_ref__bed_classification` (1A Task 3); `int_department_conformed` (1A Task 7); `int_code_decode` (1A Task 4).
- Produces:
  - `int_bed_segment(branch_id, bed_detail_id, admission_no, patient_id, episode_no, work_entity, bed_location, bed_class, started_at, ended_at, classification, is_critical, is_excluded_ward, segment_seq, segment_seq_desc)` — one row per bed-detail row that belongs to an admission.
  - `int_bed_day(branch_id, bed_location, date_day, work_entity, is_available, is_occupied, admission_no, patient_id, is_excluded_ward)` — one row per bed per day from the later of the history start and the bed's first appearance, through yesterday.

- [ ] **Step 1: Write the tests**

Append to `_patient_flow__models.yml`:

```yaml
  - name: int_bed_segment
    tests:
      - hnh_unique_combination:
          columns: [branch_id, bed_detail_id]
    columns:
      - name: admission_no
        tests: [not_null]
      - name: started_at
        tests: [not_null]
  - name: int_bed_day
    tests:
      - hnh_unique_combination:
          columns: [branch_id, bed_location, date_day]
```

Append to `_patient_flow_unit_tests.yml` under `unit_tests:`:

```yaml
  - name: int_bed_day_uses_midnight_census
    description: >
      A bed is occupied on a day when a stay covers the end of that day. A stay that
      starts and ends on the same day occupies no night. An open stay occupies every
      night through yesterday. A day covered by a NOT AVAILABLE row is unavailable.
    model: int_bed_day
    overrides:
      vars:
        hnh_history_start_date: "2022-01-01"
    given:
      - input: ref('stg_oasis__bed_details')
        format: sql
        rows: |
          -- bed A1: stay from 4 days ago 10:00 to 2 days ago 09:00 (two nights)
          select toUInt8(1) as branch_id, toInt64(1) as bed_detail_id, toNullable('N') as is_current,
                 toNullable(toInt64(500)) as work_entity, cast(null as Nullable(Int64)) as room_no,
                 toNullable('A1') as bed_location, toNullable(toInt64(29)) as bed_status,
                 cast(null as Nullable(Int64)) as bed_class,
                 toNullable(toDateTime(today() - 4, 'Asia/Riyadh') + toIntervalHour(10)) as started_at,
                 toNullable(toDateTime(today() - 2, 'Asia/Riyadh') + toIntervalHour(9)) as ended_at,
                 toNullable(toInt64(100)) as patient_id, toNullable(toInt64(7001)) as admission_no,
                 toNullable(toInt64(1)) as episode_no, cast(null as Nullable(String)) as bed_sex,
                 cast(null as Nullable(Int64)) as transferred_from_work_entity
          union all
          -- bed A2: same-day stay 3 days ago, no night
          select toUInt8(1), toInt64(2), toNullable('N'), toNullable(toInt64(500)), cast(null as Nullable(Int64)),
                 toNullable('A2'), toNullable(toInt64(29)), cast(null as Nullable(Int64)),
                 toNullable(toDateTime(today() - 3, 'Asia/Riyadh') + toIntervalHour(8)),
                 toNullable(toDateTime(today() - 3, 'Asia/Riyadh') + toIntervalHour(15)),
                 toNullable(toInt64(101)), toNullable(toInt64(7002)), toNullable(toInt64(1)),
                 cast(null as Nullable(String)), cast(null as Nullable(Int64))
          union all
          -- bed A3: open stay since 2 days ago
          select toUInt8(1), toInt64(3), toNullable('Y'), toNullable(toInt64(500)), cast(null as Nullable(Int64)),
                 toNullable('A3'), toNullable(toInt64(29)), cast(null as Nullable(Int64)),
                 toNullable(toDateTime(today() - 2, 'Asia/Riyadh') + toIntervalHour(20)),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(102)), toNullable(toInt64(7003)), toNullable(toInt64(1)),
                 cast(null as Nullable(String)), cast(null as Nullable(Int64))
          union all
          -- bed A4: exists since 3 days ago, out of service from 2 days ago, never occupied
          select toUInt8(1), toInt64(4), toNullable('N'), toNullable(toInt64(500)), cast(null as Nullable(Int64)),
                 toNullable('A4'), toNullable(toInt64(28)), cast(null as Nullable(Int64)),
                 toNullable(toDateTime(today() - 3, 'Asia/Riyadh') + toIntervalHour(1)),
                 toNullable(toDateTime(today() - 2, 'Asia/Riyadh') + toIntervalHour(1)),
                 cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)),
                 cast(null as Nullable(String)), cast(null as Nullable(Int64))
          union all
          select toUInt8(1), toInt64(5), toNullable('Y'), toNullable(toInt64(500)), cast(null as Nullable(Int64)),
                 toNullable('A4'), toNullable(toInt64(30)), cast(null as Nullable(Int64)),
                 toNullable(toDateTime(today() - 2, 'Asia/Riyadh') + toIntervalHour(1)),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)),
                 cast(null as Nullable(String)), cast(null as Nullable(Int64))
      - input: ref('int_bed_segment')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(1) as bed_detail_id, toInt64(7001) as admission_no,
                 toNullable(toInt64(100)) as patient_id, toNullable(toInt64(500)) as work_entity, 'A1' as bed_location,
                 toDateTime(today() - 4, 'Asia/Riyadh') + toIntervalHour(10) as started_at,
                 toNullable(toDateTime(today() - 2, 'Asia/Riyadh') + toIntervalHour(9)) as ended_at,
                 toUInt8(0) as is_excluded_ward
          union all
          select toUInt8(1), toInt64(2), toInt64(7002), toNullable(toInt64(101)), toNullable(toInt64(500)), 'A2',
                 toDateTime(today() - 3, 'Asia/Riyadh') + toIntervalHour(8),
                 toNullable(toDateTime(today() - 3, 'Asia/Riyadh') + toIntervalHour(15)), toUInt8(0)
          union all
          select toUInt8(1), toInt64(3), toInt64(7003), toNullable(toInt64(102)), toNullable(toInt64(500)), 'A3',
                 toDateTime(today() - 2, 'Asia/Riyadh') + toIntervalHour(20),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toUInt8(0)
      - input: ref('int_code_decode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(30) as code, toNullable('NOT AVAILABLE') as description_upper
          union all
          select toUInt8(1), toInt64(28), toNullable('READY FOR USE')
          union all
          select toUInt8(1), toInt64(29), toNullable('IN USE')
      - input: ref('int_department_conformed')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(500) as work_entity, toUInt8(0) as is_excluded_ward
    expect:
      format: sql
      rows: |
        select toUInt8(1) as branch_id, 'A1' as bed_location, today() - 4 as date_day, toUInt8(1) as is_occupied, toUInt8(1) as is_available
        union all select toUInt8(1), 'A1', today() - 3, toUInt8(1), toUInt8(1)
        union all select toUInt8(1), 'A1', today() - 2, toUInt8(0), toUInt8(1)
        union all select toUInt8(1), 'A1', today() - 1, toUInt8(0), toUInt8(1)
        union all select toUInt8(1), 'A2', today() - 3, toUInt8(0), toUInt8(1)
        union all select toUInt8(1), 'A2', today() - 2, toUInt8(0), toUInt8(1)
        union all select toUInt8(1), 'A2', today() - 1, toUInt8(0), toUInt8(1)
        union all select toUInt8(1), 'A3', today() - 2, toUInt8(1), toUInt8(1)
        union all select toUInt8(1), 'A3', today() - 1, toUInt8(1), toUInt8(1)
        union all select toUInt8(1), 'A4', today() - 3, toUInt8(0), toUInt8(1)
        union all select toUInt8(1), 'A4', today() - 2, toUInt8(0), toUInt8(0)
        union all select toUInt8(1), 'A4', today() - 1, toUInt8(0), toUInt8(0)
```

- [ ] **Step 2: Run to verify the unit test fails**

Run: `python scripts/run_dbt.py test --select int_bed_day_uses_midnight_census`
Expected: an error that the model `int_bed_day` was not found.

- [ ] **Step 3: Write `int_bed_segment`**

```sql
{{ config(order_by='(branch_id, admission_no, bed_detail_id)') }}

select
    b.branch_id                                               as branch_id,
    b.bed_detail_id                                           as bed_detail_id,
    assumeNotNull(b.admission_no)                             as admission_no,
    b.patient_id                                              as patient_id,
    b.episode_no                                              as episode_no,
    b.work_entity                                             as work_entity,
    assumeNotNull(b.bed_location)                             as bed_location,
    b.bed_class                                               as bed_class,
    assumeNotNull(b.started_at)                               as started_at,
    b.ended_at                                                as ended_at,
    ifNull(cls.classification, 'Not Mapped')                  as classification,
    toUInt8(ifNull(cls.classification, '') = 'Critical')      as is_critical,
    toUInt8(ifNull(d.is_excluded_ward, 0))                    as is_excluded_ward,
    row_number() over (partition by b.branch_id, b.admission_no order by b.started_at asc, b.bed_detail_id asc)   as segment_seq,
    row_number() over (partition by b.branch_id, b.admission_no order by b.started_at desc, b.bed_detail_id desc) as segment_seq_desc
from {{ ref('stg_oasis__bed_details') }} as b
left join {{ ref('stg_ref__bed_classification') }} as cls
    on cls.branch_id = b.branch_id and cls.bed_location = b.bed_location
left join {{ ref('int_department_conformed') }} as d
    on d.branch_id = b.branch_id and d.work_entity = b.work_entity
where b.admission_no is not null
  and b.bed_location is not null
  and b.started_at is not null
{{ hnh_settings() }}
```

- [ ] **Step 4: Write `int_bed_day`**

```sql
{{ config(order_by='(branch_id, bed_location, date_day)') }}

{% set start_date = "toDate('" ~ var('hnh_history_start_date') ~ "')" %}
{% set end_date = "(today() - 1)" %}

with beds as (
    select
        branch_id, bed_location,
        toDate(min(started_at)) as first_seen_date,
        argMax(work_entity, tuple(started_at, bed_detail_id)) as current_work_entity
    from {{ ref('stg_oasis__bed_details') }}
    where bed_location is not null and started_at is not null
    group by branch_id, bed_location
),

spine as (
    select
        branch_id, bed_location, current_work_entity,
        arrayJoin(arrayMap(
            x -> greatest(first_seen_date, {{ start_date }}) + x,
            range(toUInt32(greatest(dateDiff('day', greatest(first_seen_date, {{ start_date }}), {{ end_date }}) + 1, 0)))
        )) as date_day
    from beds
),

occupied_days as (
    -- A stay occupies the night of every day from its start date up to the day
    -- before its end date; an open stay occupies every night through yesterday.
    select
        branch_id, bed_location, date_day,
        argMax(admission_no, started_at)      as admission_no,
        argMax(patient_id, started_at)        as patient_id,
        argMax(work_entity, started_at)       as work_entity,
        argMax(is_excluded_ward, started_at)  as is_excluded_ward
    from (
        select
            branch_id, bed_location, admission_no, patient_id, work_entity, is_excluded_ward, started_at,
            arrayJoin(arrayMap(
                x -> toDate(started_at) + x,
                range(toUInt32(greatest(
                    dateDiff('day', toDate(started_at), if(ended_at is null, {{ end_date }} + 1, toDate(assumeNotNull(ended_at)))),
                    0)))
            )) as date_day
        from {{ ref('int_bed_segment') }}
    )
    group by branch_id, bed_location, date_day
),

unavailable_days as (
    select distinct
        b.branch_id as branch_id, b.bed_location as bed_location,
        arrayJoin(arrayMap(
            x -> toDate(b.started_at) + x,
            range(toUInt32(greatest(
                dateDiff('day', toDate(b.started_at), if(b.ended_at is null, {{ end_date }} + 1, toDate(assumeNotNull(b.ended_at)))),
                0)))
        )) as date_day
    from {{ ref('stg_oasis__bed_details') }} as b
    inner join {{ ref('int_code_decode') }} as st
        on st.branch_id = b.branch_id and st.code = b.bed_status
    where b.bed_location is not null and b.started_at is not null
      and st.description_upper in ('NO BED IN SLOT', 'NOT AVAILABLE')
)

select
    s.branch_id                                            as branch_id,
    assumeNotNull(s.bed_location)                          as bed_location,
    s.date_day                                             as date_day,
    coalesce(o.work_entity, s.current_work_entity)         as work_entity,
    toUInt8(u.bed_location is null or o.bed_location is not null) as is_available,
    toUInt8(o.bed_location is not null)                    as is_occupied,
    o.admission_no                                         as admission_no,
    o.patient_id                                           as patient_id,
    toUInt8(coalesce(o.is_excluded_ward, d.is_excluded_ward, 0)) as is_excluded_ward
from spine as s
left join occupied_days as o
    on o.branch_id = s.branch_id and o.bed_location = s.bed_location and o.date_day = s.date_day
left join unavailable_days as u
    on u.branch_id = s.branch_id and u.bed_location = s.bed_location and u.date_day = s.date_day
left join {{ ref('int_department_conformed') }} as d
    on d.branch_id = s.branch_id and d.work_entity = s.current_work_entity
{{ hnh_settings() }}
```

An occupied bed is always counted as available, so occupancy can never exceed 100% because of a stale status row.

- [ ] **Step 5: Run the unit test, then build**

Run: `python scripts/run_dbt.py test --select int_bed_day_uses_midnight_census`
Expected: `PASS=1`.

Run: `python scripts/run_dbt.py build --select int_bed_segment int_bed_day`
Expected: 2 tables created, all tests pass.

- [ ] **Step 6: Spot-check the occupancy level**

Run: `python scripts/run_dbt.py show --inline "select branch_id, round(100 * sum(is_occupied) / sum(is_available), 1) as occupancy_pct, round(sum(is_available) / uniqExact(date_day)) as avg_available_beds, round(sum(is_occupied) / uniqExact(date_day)) as avg_occupied from {{ ref('int_bed_day') }} where date_day >= today() - 30 and is_excluded_ward = 0 group by branch_id order by branch_id"`
Expected: each branch shows an occupancy between 0 and 100, and `avg_available_beds` is of the same order as the licensed beds (310, 200, 120, 250, 220, 100, 100, 100). An available-bed count several times the licensed beds means retired bed locations are still counted: report it rather than adjusting the rule.

- [ ] **Step 7: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/patient_flow
git commit -m "Add bed segments and midnight-census bed days

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Admission model

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/patient_flow/int_admission.sql`
- Modify: `_patient_flow__models.yml`, `_patient_flow_unit_tests.yml` (append)

**Interfaces:**
- Consumes: `stg_oasis__admissions`, `stg_oasis__admission_requests` (Task 1); `int_bed_segment` (Task 3); `int_episode` (Task 2); `int_code_decode` (1A Task 4); `hnh_is_short_stay`, `hnh_is_ltc`, `hnh_admission_source` (Task 1); `hnh_discharge_outcome_group` (1A Task 2).
- Produces: `int_admission(branch_id, admission_no, patient_id, episode_no, admitted_at, seen_at, estimated_discharge_at, clinical_discharge_at, physical_discharge_at, financial_discharge_at, treating_staff_id, request_consultant_staff_id, request_planned_admit_at, request_urgency_code, request_admission_type, outcome_code, discharge_outcome_group, admission_source, referred_type, bed_class, los_hours, los_days, los_days_to_date, is_open, is_short_stay, is_wrong_admission_outcome, is_countable, is_ltc, is_ltc_to_date, first_work_entity, last_work_entity, last_bed_location, has_bed, had_critical_bed, critical_bed_hours, first_critical_at, last_critical_left_at, days_since_previous_discharge, is_readmission_30d, is_icu_readmission_48h, is_died, is_dama, legacy_is_wrong_admission, legacy_is_ltc, legacy_days_since_previous_admission, legacy_in_vw_inpatients)` — one row per `(branch_id, admission_no)`, all history.

- [ ] **Step 1: Write the tests**

Append to `_patient_flow__models.yml`:

```yaml
  - name: int_admission
    tests:
      - hnh_unique_combination:
          columns: [branch_id, admission_no]
    columns:
      - name: admission_source
        tests:
          - accepted_values:
              values: ["OP", "ER", "Direct"]
      - name: discharge_outcome_group
        tests:
          - accepted_values:
              values: ["Normal discharge", "Left against advice", "Died", "Transferred out", "Transferred to another episode", "Wrong admission", "Absconded", "Other", "Not recorded"]
```

Append to `_patient_flow_unit_tests.yml` under `unit_tests:`:

```yaml
  - name: int_admission_rules
    description: >
      Open stay, short stay, wrong-admission outcome, last bed in an excluded ward,
      30-day readmission measured from the previous discharge, and ICU readmission
      measured in hours between Critical beds.
    model: int_admission
    given:
      - input: ref('stg_oasis__admissions')
        format: sql
        rows: |
          -- patient 100: stay 1 (10 days), stay 2 admitted 30 days after stay 1's discharge, stay 3 admitted 31 days after stay 2's discharge
          select toUInt8(1) as branch_id, toInt64(1) as admission_no, toNullable(toInt64(100)) as patient_id, toNullable(toInt64(1)) as episode_no,
                 toNullable(toDateTime('2026-01-01 10:00:00', 'Asia/Riyadh')) as admitted_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as seen_at, cast(null as Nullable(DateTime('Asia/Riyadh'))) as estimated_discharge_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as clinical_discharge_at,
                 toNullable(toDateTime('2026-01-11 10:00:00', 'Asia/Riyadh')) as physical_discharge_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as financial_discharge_at,
                 toNullable(toInt64(90)) as status_code, toNullable(toInt64(33)) as outcome_code, cast(null as Nullable(Int64)) as bed_class,
                 cast(null as Nullable(Int64)) as referred_type_code, cast(null as Nullable(Int64)) as admission_mode_code,
                 toNullable('D1') as treating_staff_id
          union all
          select toUInt8(1), toInt64(2), toNullable(toInt64(100)), toNullable(toInt64(2)),
                 toNullable(toDateTime('2026-02-10 09:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime('2026-02-12 09:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), toNullable(toInt64(33)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), toNullable('D1')
          union all
          select toUInt8(1), toInt64(3), toNullable(toInt64(100)), toNullable(toInt64(3)),
                 toNullable(toDateTime('2026-03-15 09:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime('2026-03-16 09:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), toNullable(toInt64(33)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), toNullable('D1')
          union all
          -- patient 200: open stay
          select toUInt8(1), toInt64(4), toNullable(toInt64(200)), toNullable(toInt64(1)),
                 toNullable(toDateTime('2026-09-20 12:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), toNullable('D2')
          union all
          -- patient 300: 40-minute stay
          select toUInt8(1), toInt64(5), toNullable(toInt64(300)), toNullable(toInt64(1)),
                 toNullable(toDateTime('2026-05-01 10:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime('2026-05-01 10:40:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), toNullable(toInt64(33)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), toNullable('D3')
          union all
          -- patient 400: wrong-admission outcome
          select toUInt8(1), toInt64(6), toNullable(toInt64(400)), toNullable(toInt64(1)),
                 toNullable(toDateTime('2026-05-01 10:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime('2026-05-02 10:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), toNullable(toInt64(52300)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), toNullable('D4')
          union all
          -- patient 500: two stays; leaves a Critical bed, back in one 47 hours later
          select toUInt8(1), toInt64(7), toNullable(toInt64(500)), toNullable(toInt64(1)),
                 toNullable(toDateTime('2026-06-01 08:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime('2026-06-03 08:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), toNullable(toInt64(33)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), toNullable('D5')
          union all
          select toUInt8(1), toInt64(8), toNullable(toInt64(500)), toNullable(toInt64(2)),
                 toNullable(toDateTime('2026-06-05 06:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime('2026-06-08 06:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), toNullable(toInt64(33)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), toNullable('D5')
      - input: ref('stg_oasis__admission_requests')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(11) as admission_request_id, toNullable(toInt64(2)) as admission_no,
                 toNullable('C9') as consultant_staff_id, cast(null as Nullable(DateTime('Asia/Riyadh'))) as planned_admit_at,
                 toNullable(toInt64(10549)) as admission_department_code, cast(null as Nullable(Int64)) as urgency_code,
                 cast(null as Nullable(String)) as admission_type
          union all
          select toUInt8(1), toInt64(12), toNullable(toInt64(2)), toNullable('C8'), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(10550)), cast(null as Nullable(Int64)), cast(null as Nullable(String))
      - input: ref('int_bed_segment')
        format: sql
        rows: |
          -- admission 1: ward 500 then a pre-op (excluded) ward 600 as its last bed
          select toUInt8(1) as branch_id, toInt64(101) as bed_detail_id, toInt64(1) as admission_no, toNullable(toInt64(500)) as work_entity,
                 'A1' as bed_location, toDateTime('2026-01-01 10:00:00', 'Asia/Riyadh') as started_at,
                 toNullable(toDateTime('2026-01-10 10:00:00', 'Asia/Riyadh')) as ended_at,
                 toUInt8(0) as is_critical, toUInt8(0) as is_excluded_ward
          union all
          select toUInt8(1), toInt64(102), toInt64(1), toNullable(toInt64(600)), 'P1',
                 toDateTime('2026-01-10 10:00:00', 'Asia/Riyadh'), toNullable(toDateTime('2026-01-11 10:00:00', 'Asia/Riyadh')), toUInt8(0), toUInt8(1)
          union all
          -- admission 7: Critical bed until 2026-06-02 08:00, then ward
          select toUInt8(1), toInt64(701), toInt64(7), toNullable(toInt64(700)), 'I1',
                 toDateTime('2026-06-01 08:00:00', 'Asia/Riyadh'), toNullable(toDateTime('2026-06-02 08:00:00', 'Asia/Riyadh')), toUInt8(1), toUInt8(0)
          union all
          select toUInt8(1), toInt64(702), toInt64(7), toNullable(toInt64(500)), 'A2',
                 toDateTime('2026-06-02 08:00:00', 'Asia/Riyadh'), toNullable(toDateTime('2026-06-03 08:00:00', 'Asia/Riyadh')), toUInt8(0), toUInt8(0)
          union all
          -- admission 8: ward first, Critical bed from 2026-06-04 07:00 (47 hours after leaving the last one)
          select toUInt8(1), toInt64(801), toInt64(8), toNullable(toInt64(500)), 'A2',
                 toDateTime('2026-06-05 06:00:00', 'Asia/Riyadh'), toNullable(toDateTime('2026-06-05 07:00:00', 'Asia/Riyadh')), toUInt8(0), toUInt8(0)
          union all
          select toUInt8(1), toInt64(802), toInt64(8), toNullable(toInt64(700)), 'I1',
                 toDateTime('2026-06-04 07:00:00', 'Asia/Riyadh'), toNullable(toDateTime('2026-06-08 06:00:00', 'Asia/Riyadh')), toUInt8(1), toUInt8(0)
      - input: ref('int_episode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(100) as patient_id, toInt64(3) as episode_no, toNullable('ER') as previous_care_type
      - input: ref('int_code_decode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(33) as code, toNullable('NORMAL DISCHARGE') as description_upper
          union all select toUInt8(1), toInt64(52300), toNullable('WRONG ADMISSION')
          union all select toUInt8(1), toInt64(10549), toNullable('OUTPATIENT CLINICS')
          union all select toUInt8(1), toInt64(10550), toNullable('ACCIDENT & EMERGENCY')
    expect:
      rows:
        - {admission_no: 1, is_open: 0, los_days: 10, is_short_stay: 0, is_countable: 1, first_work_entity: 500, last_work_entity: 500, legacy_in_vw_inpatients: 0, days_since_previous_discharge: null, is_readmission_30d: 0, admission_source: "Direct"}
        - {admission_no: 2, is_open: 0, los_days: 2, is_short_stay: 0, is_countable: 1, first_work_entity: null, last_work_entity: null, legacy_in_vw_inpatients: 0, days_since_previous_discharge: 30, is_readmission_30d: 1, admission_source: "OP"}
        - {admission_no: 3, is_open: 0, los_days: 1, is_short_stay: 0, is_countable: 1, first_work_entity: null, last_work_entity: null, legacy_in_vw_inpatients: 0, days_since_previous_discharge: 31, is_readmission_30d: 0, admission_source: "ER"}
        - {admission_no: 4, is_open: 1, los_days: null, is_short_stay: 0, is_countable: 1, first_work_entity: null, last_work_entity: null, legacy_in_vw_inpatients: 0, days_since_previous_discharge: null, is_readmission_30d: 0, admission_source: "Direct"}
        - {admission_no: 5, is_open: 0, los_days: 0.027777777777777776, is_short_stay: 1, is_countable: 0, first_work_entity: null, last_work_entity: null, legacy_in_vw_inpatients: 0, days_since_previous_discharge: null, is_readmission_30d: 0, admission_source: "Direct"}
        - {admission_no: 6, is_open: 0, los_days: 1, is_short_stay: 0, is_countable: 0, first_work_entity: null, last_work_entity: null, legacy_in_vw_inpatients: 0, days_since_previous_discharge: null, is_readmission_30d: 0, admission_source: "Direct"}
        - {admission_no: 7, is_open: 0, los_days: 2, is_short_stay: 0, is_countable: 1, first_work_entity: 700, last_work_entity: 500, legacy_in_vw_inpatients: 1, days_since_previous_discharge: null, is_readmission_30d: 0, admission_source: "Direct"}
        - {admission_no: 8, is_open: 0, los_days: 3, is_short_stay: 0, is_countable: 1, first_work_entity: 700, last_work_entity: 500, legacy_in_vw_inpatients: 1, days_since_previous_discharge: 2, is_readmission_30d: 1, admission_source: "Direct"}
```

Notes on the expected rows: admission 2 takes its source from the earliest request (id 11, outpatient clinics). Admission 8's segments are deliberately given out of id order (segment 802 starts before 801) to prove that first and last ward follow `started_at`, not the id. Admission 1 is the excluded-ward case: its last bed is in a pre-op ward, so `legacy_in_vw_inpatients` is 0 while the stay is still countable and keeps ward 500 as both first and last ward.

Add one more test file for the ICU rule, appended under `unit_tests:`:

```yaml
  - name: int_admission_icu_readmission_window
    description: Back in a Critical bed 47 hours after leaving one is a 48-hour ICU readmission; 49 hours is not.
    model: int_admission
    given:
      - input: ref('stg_oasis__admissions')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(1) as admission_no, toNullable(toInt64(900)) as patient_id, toNullable(toInt64(1)) as episode_no,
                 toNullable(toDateTime('2026-06-01 08:00:00', 'Asia/Riyadh')) as admitted_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as seen_at, cast(null as Nullable(DateTime('Asia/Riyadh'))) as estimated_discharge_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as clinical_discharge_at,
                 toNullable(toDateTime('2026-06-03 08:00:00', 'Asia/Riyadh')) as physical_discharge_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as financial_discharge_at,
                 toNullable(toInt64(90)) as status_code, cast(null as Nullable(Int64)) as outcome_code, cast(null as Nullable(Int64)) as bed_class,
                 cast(null as Nullable(Int64)) as referred_type_code, cast(null as Nullable(Int64)) as admission_mode_code,
                 cast(null as Nullable(String)) as treating_staff_id
          union all
          select toUInt8(1), toInt64(2), toNullable(toInt64(900)), toNullable(toInt64(2)),
                 toNullable(toDateTime('2026-06-04 06:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime('2026-06-06 06:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(String))
          union all
          select toUInt8(1), toInt64(3), toNullable(toInt64(900)), toNullable(toInt64(3)),
                 toNullable(toDateTime('2026-06-08 06:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime('2026-06-10 06:00:00', 'Asia/Riyadh')), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable(toInt64(90)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(Int64)), cast(null as Nullable(String))
      - input: ref('stg_oasis__admission_requests')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(1) as admission_request_id, cast(null as Nullable(Int64)) as admission_no,
                 cast(null as Nullable(String)) as consultant_staff_id, cast(null as Nullable(DateTime('Asia/Riyadh'))) as planned_admit_at,
                 cast(null as Nullable(Int64)) as admission_department_code, cast(null as Nullable(Int64)) as urgency_code,
                 cast(null as Nullable(String)) as admission_type
      - input: ref('int_bed_segment')
        format: sql
        rows: |
          -- stay 1 leaves Critical at 2026-06-02 08:00; stay 2 enters Critical 47 hours later; leaves at 2026-06-06 06:00; stay 3 enters 49 hours later
          select toUInt8(1) as branch_id, toInt64(11) as bed_detail_id, toInt64(1) as admission_no, toNullable(toInt64(700)) as work_entity,
                 'I1' as bed_location, toDateTime('2026-06-01 08:00:00', 'Asia/Riyadh') as started_at,
                 toNullable(toDateTime('2026-06-02 08:00:00', 'Asia/Riyadh')) as ended_at, toUInt8(1) as is_critical, toUInt8(0) as is_excluded_ward
          union all
          select toUInt8(1), toInt64(21), toInt64(2), toNullable(toInt64(700)), 'I1',
                 toDateTime('2026-06-04 07:00:00', 'Asia/Riyadh'), toNullable(toDateTime('2026-06-06 06:00:00', 'Asia/Riyadh')), toUInt8(1), toUInt8(0)
          union all
          select toUInt8(1), toInt64(31), toInt64(3), toNullable(toInt64(700)), 'I1',
                 toDateTime('2026-06-08 07:00:00', 'Asia/Riyadh'), toNullable(toDateTime('2026-06-10 06:00:00', 'Asia/Riyadh')), toUInt8(1), toUInt8(0)
      - input: ref('int_episode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(0) as patient_id, toInt64(0) as episode_no, cast(null as Nullable(String)) as previous_care_type
      - input: ref('int_code_decode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(0) as code, cast(null as Nullable(String)) as description_upper
    expect:
      rows:
        - {admission_no: 1, had_critical_bed: 1, is_icu_readmission_48h: 0}
        - {admission_no: 2, had_critical_bed: 1, is_icu_readmission_48h: 1}
        - {admission_no: 3, had_critical_bed: 1, is_icu_readmission_48h: 0}
```

- [ ] **Step 2: Run to verify the unit tests fail**

Run: `python scripts/run_dbt.py test --select int_admission_rules int_admission_icu_readmission_window`
Expected: an error that the model `int_admission` was not found.

- [ ] **Step 3: Write `int_admission`**

```sql
{{ config(order_by='(branch_id, admission_no)') }}

with first_request as (
    -- The earliest request per admission, so a second request never duplicates the stay.
    select
        branch_id, assumeNotNull(admission_no) as admission_no,
        argMin(tuple(consultant_staff_id, planned_admit_at, admission_department_code, urgency_code, admission_type),
               admission_request_id) as chosen
    from {{ ref('stg_oasis__admission_requests') }}
    where admission_no is not null
    group by branch_id, admission_no
),

beds as (
    select
        branch_id, admission_no,
        argMinIf(work_entity, tuple(started_at, bed_detail_id), is_excluded_ward = 0)   as first_work_entity,
        argMaxIf(work_entity, tuple(started_at, bed_detail_id), is_excluded_ward = 0)   as last_work_entity,
        argMaxIf(toNullable(bed_location), tuple(started_at, bed_detail_id), is_excluded_ward = 0) as last_bed_location,
        toUInt8(count() > 0)                                                            as has_bed,
        toUInt8(max(is_critical))                                                       as had_critical_bed,
        sumIf(dateDiff('minute', started_at, ifNull(ended_at, now('Asia/Riyadh'))), is_critical = 1) / 60 as critical_bed_hours,
        minIf(toNullable(started_at), is_critical = 1)                                  as first_critical_at,
        maxIf(ended_at, is_critical = 1)                                                as last_critical_left_at,
        toUInt8(argMax(is_excluded_ward, bed_detail_id) = 0)                            as legacy_last_bed_ok
    from {{ ref('int_bed_segment') }}
    group by branch_id, admission_no
),

base as (
    select
        a.branch_id                 as branch_id,
        a.admission_no              as admission_no,
        a.patient_id                as patient_id,
        a.episode_no                as episode_no,
        a.admitted_at               as admitted_at,
        a.seen_at                   as seen_at,
        a.estimated_discharge_at    as estimated_discharge_at,
        a.clinical_discharge_at     as clinical_discharge_at,
        a.physical_discharge_at     as physical_discharge_at,
        a.financial_discharge_at    as financial_discharge_at,
        a.treating_staff_id         as treating_staff_id,
        a.outcome_code              as outcome_code,
        a.bed_class                 as bed_class,
        tupleElement(rq.chosen, 1)  as request_consultant_staff_id,
        tupleElement(rq.chosen, 2)  as request_planned_admit_at,
        tupleElement(rq.chosen, 4)  as request_urgency_code,
        tupleElement(rq.chosen, 5)  as request_admission_type,
        dep.description_upper       as admission_department_upper,
        ref_t.description_upper     as referred_upper,
        if(a.outcome_code is null, 'Not recorded', {{ hnh_discharge_outcome_group('out.description_upper') }}) as discharge_outcome_group,
        ep.previous_care_type       as previous_care_type,
        b.first_work_entity         as first_work_entity,
        b.last_work_entity          as last_work_entity,
        b.last_bed_location         as last_bed_location,
        toUInt8(ifNull(b.has_bed, 0))            as has_bed,
        toUInt8(ifNull(b.had_critical_bed, 0))   as had_critical_bed,
        ifNull(b.critical_bed_hours, 0)          as critical_bed_hours,
        b.first_critical_at         as first_critical_at,
        b.last_critical_left_at     as last_critical_left_at,
        toUInt8(ifNull(b.legacy_last_bed_ok, 0)) as legacy_last_bed_ok,
        toUInt8(a.physical_discharge_at is null) as is_open,
        dateDiff('minute', a.admitted_at, a.physical_discharge_at) / 60       as los_hours,
        dateDiff('minute', a.admitted_at, ifNull(a.physical_discharge_at, now('Asia/Riyadh'))) / 1440 as los_days_to_date
    from {{ ref('stg_oasis__admissions') }} as a
    left join first_request as rq on rq.branch_id = a.branch_id and rq.admission_no = a.admission_no
    left join beds as b on b.branch_id = a.branch_id and b.admission_no = a.admission_no
    left join {{ ref('int_episode') }} as ep
        on ep.branch_id = a.branch_id and ep.patient_id = a.patient_id and ep.episode_no = a.episode_no
    left join {{ ref('int_code_decode') }} as out on out.branch_id = a.branch_id and out.code = a.outcome_code
    left join {{ ref('int_code_decode') }} as ref_t on ref_t.branch_id = a.branch_id and ref_t.code = a.referred_type_code
    left join {{ ref('int_code_decode') }} as dep
        on dep.branch_id = a.branch_id and dep.code = tupleElement(rq.chosen, 3)
),

flagged as (
    select
        *,
        los_hours / 24                                                          as los_days,
        {{ hnh_is_short_stay('admitted_at', 'physical_discharge_at') }}         as is_short_stay,
        toUInt8(discharge_outcome_group = 'Wrong admission')                    as is_wrong_admission_outcome
    from base
),

countable as (
    select *, toUInt8(is_short_stay = 0 and is_wrong_admission_outcome = 0) as is_countable
    from flagged
),

previous_stay as (
    -- Look-back over countable stays only: the previous stay's discharge and the
    -- moment it last left a Critical bed.
    select
        branch_id, admission_no,
        lagInFrame(physical_discharge_at, 1) over w   as previous_discharge_at,
        lagInFrame(last_critical_left_at, 1) over w   as previous_critical_left_at
    from countable
    where is_countable = 1 and patient_id is not null and admitted_at is not null
    window w as (partition by branch_id, patient_id order by admitted_at asc, admission_no asc
                 rows between unbounded preceding and current row)
),

previous_any as (
    -- The old rule: previous admission date over every admission, countable or not.
    select
        branch_id, admission_no,
        lagInFrame(admitted_at, 1) over (partition by branch_id, patient_id order by admitted_at asc, admission_no asc
                                         rows between unbounded preceding and current row) as previous_admitted_at
    from countable
    where patient_id is not null and admitted_at is not null
)

select
    c.branch_id, c.admission_no, c.patient_id, c.episode_no,
    c.admitted_at, c.seen_at, c.estimated_discharge_at, c.clinical_discharge_at, c.physical_discharge_at, c.financial_discharge_at,
    c.treating_staff_id, c.request_consultant_staff_id, c.request_planned_admit_at, c.request_urgency_code, c.request_admission_type,
    c.outcome_code, c.discharge_outcome_group,
    {{ hnh_admission_source('c.admission_department_upper', 'c.previous_care_type') }} as admission_source,
    c.referred_upper as referred_type,
    c.bed_class,
    c.los_hours, c.los_days, c.los_days_to_date,
    c.is_open, c.is_short_stay, c.is_wrong_admission_outcome, c.is_countable,
    {{ hnh_is_ltc('c.los_days', 'c.referred_upper') }}          as is_ltc,
    {{ hnh_is_ltc('c.los_days_to_date', 'c.referred_upper') }}  as is_ltc_to_date,
    c.first_work_entity, c.last_work_entity, c.last_bed_location, c.has_bed,
    c.had_critical_bed, c.critical_bed_hours, c.first_critical_at, c.last_critical_left_at,
    if(ps.previous_discharge_at is null, null, dateDiff('day', ps.previous_discharge_at, c.admitted_at)) as days_since_previous_discharge,
    toUInt8(ifNull(dateDiff('day', ps.previous_discharge_at, c.admitted_at) between 0 and 30, 0))        as is_readmission_30d,
    toUInt8(ifNull(dateDiff('minute', ps.previous_critical_left_at, c.first_critical_at) between 0 and 2880, 0)) as is_icu_readmission_48h,
    toUInt8(c.discharge_outcome_group = 'Died')                  as is_died,
    toUInt8(c.discharge_outcome_group = 'Left against advice')   as is_dama,
    toUInt8(dateDiff('hour', c.admitted_at, ifNull(c.physical_discharge_at, now('Asia/Riyadh'))) <= 1) as legacy_is_wrong_admission,
    toUInt8(dateDiff('hour', c.admitted_at, ifNull(c.physical_discharge_at, now('Asia/Riyadh'))) / 24 > 30
            or ifNull(c.referred_upper, '') = 'LTC')             as legacy_is_ltc,
    if(pa.previous_admitted_at is null, null, dateDiff('day', pa.previous_admitted_at, c.admitted_at)) as legacy_days_since_previous_admission,
    toUInt8(c.has_bed = 1 and c.legacy_last_bed_ok = 1)          as legacy_in_vw_inpatients
from countable as c
left join previous_stay as ps on ps.branch_id = c.branch_id and ps.admission_no = c.admission_no
left join previous_any as pa on pa.branch_id = c.branch_id and pa.admission_no = c.admission_no
{{ hnh_settings() }}
```

`legacy_is_wrong_admission`, `legacy_is_ltc` and `los_days_to_date` are the only expressions that read the clock. The first two reproduce the old drifting behaviour on purpose; no new KPI uses them.

- [ ] **Step 4: Run the unit tests, then build**

Run: `python scripts/run_dbt.py test --select int_admission_rules int_admission_icu_readmission_window`
Expected: `PASS=2`.

If `int_admission_rules` fails only on the `los_days` of admission 5, the expected value is 40 minutes expressed in days (`40 / 1440`); adjust the literal's precision to what ClickHouse returns rather than changing the model.

Run: `python scripts/run_dbt.py build --select int_admission`
Expected: 1 table created, all tests pass.

- [ ] **Step 5: Spot-check the exclusions**

Run: `python scripts/run_dbt.py show --inline "select toYear(admitted_at) as y, count() as stays, sum(is_countable) as countable, sum(is_short_stay) as short_stays, sum(is_wrong_admission_outcome) as wrong_outcome, sum(1 - legacy_in_vw_inpatients) as dropped_by_legacy, sum(is_readmission_30d) as readmit_30d, sum(is_icu_readmission_48h) as icu_48h, round(avgIf(los_days, is_countable = 1 and is_ltc = 0), 2) as alos_non_ltc from {{ ref('int_admission') }} where admitted_at >= '2024-01-01' group by y order by y"`
Expected: `countable` is slightly below `stays`; `alos_non_ltc` is between 2 and 6 days; `icu_48h` is small compared with `readmit_30d`. Record the row in the commit message.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/patient_flow
git commit -m "Add int_admission with corrected stay, readmission and ICU rules

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Encounter model

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/patient_flow/int_encounter.sql`
- Modify: `_patient_flow__models.yml`, `_patient_flow_unit_tests.yml` (append)
- Test: `hnh_dwh/tests/hnh/assert_int_encounter_row_conservation.sql`

**Interfaces:**
- Consumes: `stg_oasis__appointments`, `stg_oasis__er_visits` (Task 1); `int_admission` (Task 4); `int_episode` (Task 2); `int_code_decode` (1A Task 4); `hnh_outcome_group`, `hnh_minutes_between`, `hnh_visit_type`.
- Produces: `int_encounter(branch_id, encounter_type, source_id, patient_id, episode_no, encounter_at, arrived_at, seen_at, completed_at, triaged_at, booked_at, work_entity, booked_staff_id, treating_staff_id, outcome_code, er_priority, care_type, purchaser_code, eligibility_type, outcome_group, is_arrived, is_seen, is_cancelled, is_no_show, is_walk_in, is_follow_up, is_virtual, is_online_booking, booked_from, is_first_episode, visit_type, prior_encounters_4m, is_returning, wait_minutes, wait_minutes_raw, door_to_triage_minutes, service_minutes, service_minutes_raw, er_los_minutes, booking_lead_days, legacy_in_op_census, legacy_is_cancelled_outpatient_model)` — one row per `(branch_id, encounter_type, source_id)`; `encounter_type` ∈ `OP`, `ER`, `IP`; all history.

- [ ] **Step 1: Write the tests**

Append to `_patient_flow__models.yml`:

```yaml
  - name: int_encounter
    tests:
      - hnh_unique_combination:
          columns: [branch_id, encounter_type, source_id]
    columns:
      - name: encounter_type
        tests:
          - accepted_values:
              values: ["OP", "ER", "IP"]
      - name: care_type
        tests:
          - accepted_values:
              values: ["OP", "ER", "IP", "DAYCASE"]
      - name: visit_type
        tests:
          - accepted_values:
              values: ["New patient", "Free follow-up", "Paid visit"]
```

`hnh_dwh/tests/hnh/assert_int_encounter_row_conservation.sql`:

```sql
-- The union must neither drop nor multiply rows.
select 'int_encounter row count differs from its inputs' as failure, e.n as encounters, s.n as inputs
from (select count() as n from {{ ref('int_encounter') }}) as e
cross join (
    select
        (select count() from {{ ref('stg_oasis__appointments') }} where patient_id is not null)
      + (select count() from {{ ref('stg_oasis__er_visits') }})
      + (select count() from {{ ref('int_admission') }}) as n
) as s
where e.n != s.n
```

Append to `_patient_flow_unit_tests.yml` under `unit_tests:`:

```yaml
  - name: int_encounter_flags
    description: >
      Cancellation from the outcome group; no-show only when the patient did not arrive
      anywhere in the branch that day; booked row without an episode is kept as OP;
      out-of-order timestamps give null guarded minutes; returning patient from prior months.
    model: int_encounter
    given:
      - input: ref('stg_oasis__appointments')
        format: sql
        rows: |
          -- 1: attended, waited 20 minutes, patient's first episode
          select toUInt8(1) as branch_id, toInt64(1) as appointment_id, toNullable(toInt64(500)) as work_entity,
                 toNullable(toDateTime('2026-06-10 09:00:00', 'Asia/Riyadh')) as starts_at,
                 toNullable(toInt64(100)) as patient_id, toNullable(toInt64(1)) as episode_no,
                 toNullable(toDateTime('2026-06-10 08:50:00', 'Asia/Riyadh')) as arrived_at,
                 toNullable(toDateTime('2026-06-10 09:10:00', 'Asia/Riyadh')) as seen_at,
                 toNullable(toDateTime('2026-06-10 09:30:00', 'Asia/Riyadh')) as completed_at,
                 toNullable('D1') as booked_staff_id, toNullable('D1') as treating_staff_id,
                 toNullable('N') as new_followup_flag, toNullable(toInt64(95)) as outcome_code,
                 toUInt8(0) as is_walk_in, toUInt8(0) as is_virtual, toUInt8(0) as is_online_booking,
                 cast(null as Nullable(String)) as booked_from,
                 toNullable(toDateTime('2026-06-01 09:00:00', 'Asia/Riyadh')) as booked_at
          union all
          -- 2: cancelled by patient
          select toUInt8(1), toInt64(2), toNullable(toInt64(500)), toNullable(toDateTime('2026-07-05 09:00:00', 'Asia/Riyadh')),
                 toNullable(toInt64(100)), cast(null as Nullable(Int64)),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable('D1'), cast(null as Nullable(String)), toNullable('N'), toNullable(toInt64(107)),
                 toUInt8(0), toUInt8(0), toUInt8(0), cast(null as Nullable(String)), cast(null as Nullable(DateTime('Asia/Riyadh')))
          union all
          -- 3: booked, no episode, never arrived, no other arrival that day -> no-show
          select toUInt8(1), toInt64(3), toNullable(toInt64(500)), toNullable(toDateTime('2026-07-20 09:00:00', 'Asia/Riyadh')),
                 toNullable(toInt64(100)), cast(null as Nullable(Int64)),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable('D1'), cast(null as Nullable(String)), toNullable('N'), cast(null as Nullable(Int64)),
                 toUInt8(0), toUInt8(0), toUInt8(0), cast(null as Nullable(String)), cast(null as Nullable(DateTime('Asia/Riyadh')))
          union all
          -- 4: missed the booked slot ...
          select toUInt8(1), toInt64(4), toNullable(toInt64(500)), toNullable(toDateTime('2026-08-03 09:00:00', 'Asia/Riyadh')),
                 toNullable(toInt64(100)), cast(null as Nullable(Int64)),
                 cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
                 toNullable('D1'), cast(null as Nullable(String)), toNullable('N'), cast(null as Nullable(Int64)),
                 toUInt8(0), toUInt8(0), toUInt8(0), cast(null as Nullable(String)), cast(null as Nullable(DateTime('Asia/Riyadh')))
          union all
          -- 5: ... but walked in the same day; seen before arrival is recorded
          select toUInt8(1), toInt64(5), toNullable(toInt64(501)), toNullable(toDateTime('2026-08-03 17:00:00', 'Asia/Riyadh')),
                 toNullable(toInt64(100)), toNullable(toInt64(2)),
                 toNullable(toDateTime('2026-08-03 17:05:00', 'Asia/Riyadh')),
                 toNullable(toDateTime('2026-08-03 16:55:00', 'Asia/Riyadh')),
                 toNullable(toDateTime('2026-08-03 17:20:00', 'Asia/Riyadh')),
                 toNullable('D2'), toNullable('D2'), toNullable('F'), toNullable(toInt64(1781)),
                 toUInt8(1), toUInt8(0), toUInt8(0), cast(null as Nullable(String)), cast(null as Nullable(DateTime('Asia/Riyadh')))
      - input: ref('stg_oasis__er_visits')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(9001) as er_visit_id, toNullable(toInt64(100)) as patient_id,
                 toNullable(toInt64(3)) as episode_no, toNullable(toInt64(3)) as priority,
                 toNullable(toDateTime('2026-09-10 22:00:00', 'Asia/Riyadh')) as arrived_at,
                 toNullable(toDateTime('2026-09-10 22:06:00', 'Asia/Riyadh')) as triaged_at,
                 toNullable(toDateTime('2026-09-10 22:30:00', 'Asia/Riyadh')) as treatment_started_at,
                 toNullable(toDateTime('2026-09-11 01:00:00', 'Asia/Riyadh')) as completed_at,
                 toNullable(toInt64(96)) as outcome_code, toNullable(toInt64(700)) as work_entity,
                 toNullable('E1') as treating_staff_id
      - input: ref('int_admission')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(7001) as admission_no, toNullable(toInt64(100)) as patient_id,
                 toNullable(toInt64(4)) as episode_no,
                 toNullable(toDateTime('2026-09-11 01:10:00', 'Asia/Riyadh')) as admitted_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as seen_at,
                 cast(null as Nullable(DateTime('Asia/Riyadh'))) as physical_discharge_at,
                 toNullable(toInt64(800)) as first_work_entity,
                 toNullable('C1') as request_consultant_staff_id, toNullable('T1') as treating_staff_id
      - input: ref('int_episode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(100) as patient_id, toInt64(1) as episode_no, 'OP' as care_type,
                 toNullable('D1') as consultant_staff_id, toInt64(200) as purchaser_code,
                 toNullable(toInt64(279)) as eligibility_type, toUInt8(1) as is_first_episode
          union all select toUInt8(1), toInt64(100), toInt64(2), 'OP', toNullable('D2'), toInt64(200), toNullable(toInt64(231)), toUInt8(0)
          union all select toUInt8(1), toInt64(100), toInt64(3), 'ER', toNullable('E9'), toInt64(9999), cast(null as Nullable(Int64)), toUInt8(0)
          union all select toUInt8(1), toInt64(100), toInt64(4), 'IP', toNullable('C1'), toInt64(200), cast(null as Nullable(Int64)), toUInt8(0)
      - input: ref('int_code_decode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(95) as code, toNullable('FOLLOW-UP BOOKED') as description_upper
          union all select toUInt8(1), toInt64(107), toNullable('CANCELLED BY PATIENT')
          union all select toUInt8(1), toInt64(1781), toNullable('CONDITION CURED')
          union all select toUInt8(1), toInt64(96), toNullable('DISCHARGED')
    expect:
      rows:
        - {encounter_type: "OP", source_id: 1, care_type: "OP", is_arrived: 1, is_cancelled: 0, is_no_show: 0, wait_minutes: 20, service_minutes: 20, booking_lead_days: 9, visit_type: "New patient", prior_encounters_4m: 0, is_returning: 0, booked_staff_id: "D1", purchaser_code: 200}
        - {encounter_type: "OP", source_id: 2, care_type: "OP", is_arrived: 0, is_cancelled: 1, is_no_show: 0, wait_minutes: null, service_minutes: null, booking_lead_days: null, visit_type: "Paid visit", prior_encounters_4m: 1, is_returning: 1, booked_staff_id: "D1", purchaser_code: 9999}
        - {encounter_type: "OP", source_id: 3, care_type: "OP", is_arrived: 0, is_cancelled: 0, is_no_show: 1, wait_minutes: null, service_minutes: null, booking_lead_days: null, visit_type: "Paid visit", prior_encounters_4m: 1, is_returning: 1, booked_staff_id: "D1", purchaser_code: 9999}
        - {encounter_type: "OP", source_id: 4, care_type: "OP", is_arrived: 0, is_cancelled: 0, is_no_show: 0, wait_minutes: null, service_minutes: null, booking_lead_days: null, visit_type: "Paid visit", prior_encounters_4m: 1, is_returning: 1, booked_staff_id: "D1", purchaser_code: 9999}
        - {encounter_type: "OP", source_id: 5, care_type: "OP", is_arrived: 1, is_cancelled: 0, is_no_show: 0, wait_minutes: null, service_minutes: 25, booking_lead_days: null, visit_type: "Free follow-up", prior_encounters_4m: 1, is_returning: 1, booked_staff_id: "D2", purchaser_code: 200}
        - {encounter_type: "ER", source_id: 9001, care_type: "ER", is_arrived: 1, is_cancelled: 0, is_no_show: 0, wait_minutes: 30, service_minutes: 150, booking_lead_days: null, visit_type: "Paid visit", prior_encounters_4m: 2, is_returning: 1, booked_staff_id: "E9", purchaser_code: 9999}
        - {encounter_type: "IP", source_id: 7001, care_type: "IP", is_arrived: 1, is_cancelled: 0, is_no_show: 0, wait_minutes: null, service_minutes: null, booking_lead_days: null, visit_type: "Paid visit", prior_encounters_4m: 2, is_returning: 1, booked_staff_id: "C1", purchaser_code: 200}
```

How the expected prior counts arise: encounter 1 (June) has nothing before it. Encounters 2–5 (July, August) see the one arrived June visit; the August walk-in is in the same month as rows 4 and 5, so it is not "prior". The September ER visit and admission see June and August: two arrived visits.

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select int_encounter_flags`
Expected: an error that the model `int_encounter` was not found.

- [ ] **Step 3: Write `int_encounter`**

```sql
{{ config(order_by='(branch_id, encounter_type, source_id)') }}

with op as (
    select
        branch_id                                           as branch_id,
        'OP'                                                as encounter_type,
        appointment_id                                      as source_id,
        patient_id                                          as patient_id,
        episode_no                                          as episode_no,
        starts_at                                           as encounter_at,
        arrived_at                                          as arrived_at,
        seen_at                                             as seen_at,
        completed_at                                        as completed_at,
        cast(null as Nullable(DateTime('Asia/Riyadh')))     as triaged_at,
        booked_at                                           as booked_at,
        work_entity                                         as work_entity,
        booked_staff_id                                     as booked_staff_id,
        treating_staff_id                                   as treating_staff_id,
        outcome_code                                        as outcome_code,
        cast(null as Nullable(Int64))                       as er_priority,
        toUInt8(arrived_at is not null)                     as is_arrived,
        toUInt8(seen_at is not null)                        as is_seen,
        is_walk_in                                          as is_walk_in,
        toUInt8(ifNull(new_followup_flag, '') = 'F')        as is_follow_up,
        is_virtual                                          as is_virtual,
        is_online_booking                                   as is_online_booking,
        booked_from                                         as booked_from
    from {{ ref('stg_oasis__appointments') }}
    where patient_id is not null
),

er as (
    select
        branch_id, 'ER', er_visit_id, patient_id, episode_no,
        arrived_at, arrived_at, treatment_started_at, completed_at, triaged_at,
        cast(null as Nullable(DateTime('Asia/Riyadh'))),
        work_entity, cast(null as Nullable(String)), treating_staff_id, outcome_code, priority,
        toUInt8(1), toUInt8(treatment_started_at is not null), toUInt8(0), toUInt8(0), toUInt8(0), toUInt8(0),
        cast(null as Nullable(String))
    from {{ ref('stg_oasis__er_visits') }}
),

ip as (
    select
        branch_id, 'IP', admission_no, patient_id, episode_no,
        admitted_at, admitted_at, seen_at, physical_discharge_at,
        cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
        first_work_entity, request_consultant_staff_id, treating_staff_id,
        cast(null as Nullable(Int64)), cast(null as Nullable(Int64)),
        toUInt8(1), toUInt8(1), toUInt8(0), toUInt8(0), toUInt8(0), toUInt8(0),
        cast(null as Nullable(String))
    from {{ ref('int_admission') }}
),

unioned as (
    select * from op
    union all
    select * from er
    union all
    select * from ip
),

decoded as (
    select
        u.*,
        if(u.outcome_code is null, 'Not recorded', {{ hnh_outcome_group('d.description_upper') }}) as outcome_group,
        if(ep.care_type is null or ep.care_type = 'Unknown', u.encounter_type, ep.care_type)       as care_type,
        coalesce(u.booked_staff_id, ep.consultant_staff_id)   as resolved_booked_staff_id,
        ifNull(ep.purchaser_code, toInt64(9999))              as purchaser_code,
        ep.eligibility_type                                   as eligibility_type,
        toUInt8(ifNull(ep.is_first_episode, 0))               as is_first_episode
    from unioned as u
    left join {{ ref('int_code_decode') }} as d
        on d.branch_id = u.branch_id and d.code = u.outcome_code
    left join {{ ref('int_episode') }} as ep
        on ep.branch_id = u.branch_id and ep.patient_id = u.patient_id and ep.episode_no = u.episode_no
),

flagged as (
    select *, toUInt8(outcome_group in ('Cancelled', 'Rescheduled')) as is_cancelled
    from decoded
),

arrival_days as (
    -- Days on which the patient arrived anywhere in the branch (clinic or ER).
    select distinct branch_id, assumeNotNull(patient_id) as patient_id, toDate(arrived_at) as arrival_date
    from flagged
    where encounter_type in ('OP', 'ER') and is_arrived = 1 and arrived_at is not null and patient_id is not null
),

monthly as (
    select
        branch_id, assumeNotNull(patient_id) as patient_id,
        toRelativeMonthNum(assumeNotNull(encounter_at)) as month_num,
        countIf(encounter_type in ('OP', 'ER') and is_arrived = 1 and is_cancelled = 0) as arrived_n
    from flagged
    where patient_id is not null and encounter_at is not null
    group by branch_id, patient_id, month_num
),

monthly_prior as (
    select
        branch_id, patient_id, month_num,
        sum(arrived_n) over (partition by branch_id, patient_id order by month_num
                             range between 4 preceding and 1 preceding) as prior_encounters_4m
    from monthly
)

select
    f.branch_id                         as branch_id,
    f.encounter_type                    as encounter_type,
    f.source_id                         as source_id,
    f.patient_id                        as patient_id,
    f.episode_no                        as episode_no,
    f.encounter_at                      as encounter_at,
    f.arrived_at                        as arrived_at,
    f.seen_at                           as seen_at,
    f.completed_at                      as completed_at,
    f.triaged_at                        as triaged_at,
    f.booked_at                         as booked_at,
    f.work_entity                       as work_entity,
    f.resolved_booked_staff_id          as booked_staff_id,
    f.treating_staff_id                 as treating_staff_id,
    f.outcome_code                      as outcome_code,
    f.er_priority                       as er_priority,
    f.care_type                         as care_type,
    f.purchaser_code                    as purchaser_code,
    f.eligibility_type                  as eligibility_type,
    f.outcome_group                     as outcome_group,
    f.is_arrived                        as is_arrived,
    f.is_seen                           as is_seen,
    f.is_cancelled                      as is_cancelled,
    toUInt8(f.encounter_type = 'OP' and f.is_walk_in = 0 and f.is_cancelled = 0 and f.is_arrived = 0
            and ifNull(toDate(f.encounter_at) < today(), 0) and ad.patient_id is null) as is_no_show,
    f.is_walk_in                        as is_walk_in,
    f.is_follow_up                      as is_follow_up,
    f.is_virtual                        as is_virtual,
    f.is_online_booking                 as is_online_booking,
    f.booked_from                       as booked_from,
    f.is_first_episode                  as is_first_episode,
    {{ hnh_visit_type('f.is_first_episode', 'f.is_follow_up') }} as visit_type,
    toUInt32(ifNull(mp.prior_encounters_4m, 0))                  as prior_encounters_4m,
    toUInt8(ifNull(mp.prior_encounters_4m, 0) > 0)               as is_returning,
    if(f.encounter_type = 'IP', null, {{ hnh_minutes_between('f.arrived_at', 'f.seen_at') }})      as wait_minutes,
    if(f.encounter_type = 'IP', null, dateDiff('minute', f.arrived_at, f.seen_at))                 as wait_minutes_raw,
    {{ hnh_minutes_between('f.arrived_at', 'f.triaged_at') }}                                      as door_to_triage_minutes,
    if(f.encounter_type = 'IP', null, {{ hnh_minutes_between('f.seen_at', 'f.completed_at') }})    as service_minutes,
    if(f.encounter_type = 'IP', null, dateDiff('minute', f.seen_at, f.completed_at))               as service_minutes_raw,
    if(f.encounter_type = 'ER' and dateDiff('minute', f.arrived_at, f.completed_at) between 0 and 10080,
       dateDiff('minute', f.arrived_at, f.completed_at), null)                                     as er_los_minutes,
    if(f.encounter_type = 'OP' and dateDiff('day', f.booked_at, f.encounter_at) >= 0,
       dateDiff('day', f.booked_at, f.encounter_at), null)                                         as booking_lead_days,
    toUInt8(f.encounter_type in ('OP', 'ER') and f.patient_id is not null and f.episode_no is not null
            and ifNull(f.outcome_code, 500) not in (93, 94, 106, 107))                             as legacy_in_op_census,
    toUInt8(ifNull(f.outcome_code, 0) in (93, 94, 107, 108))                                       as legacy_is_cancelled_outpatient_model
from flagged as f
left join arrival_days as ad
    on ad.branch_id = f.branch_id and ad.patient_id = f.patient_id and ad.arrival_date = toDate(f.encounter_at)
left join monthly_prior as mp
    on mp.branch_id = f.branch_id and mp.patient_id = f.patient_id
   and mp.month_num = toRelativeMonthNum(assumeNotNull(f.encounter_at))
{{ hnh_settings() }}
```

`prior_encounters_4m` only sees encounters that are in staging, which start on 2022-01-01. For January to April 2022 the look-back window is partly empty, so "returning" is understated for those four months. This is stated in `docs/reconciliation_phase1.md` (Task 9).

- [ ] **Step 4: Run the unit test, then build**

Run: `python scripts/run_dbt.py test --select int_encounter_flags`
Expected: `PASS=1`.

Run: `python scripts/run_dbt.py build --select int_encounter assert_int_encounter_row_conservation`
Expected: 1 table created, all tests pass.

- [ ] **Step 5: Spot-check the main rates**

Run: `python scripts/run_dbt.py show --inline "select encounter_type, count() as n, sum(is_arrived) as arrived, sum(is_cancelled) as cancelled, sum(is_no_show) as no_show, sum(legacy_in_op_census) as legacy_census, round(avgIf(wait_minutes, is_arrived = 1 and is_cancelled = 0), 1) as avg_wait, countIf(outcome_group = 'Other') as other_outcomes from {{ ref('int_encounter') }} where encounter_at >= '2026-01-01' group by encounter_type"`
Expected: `OP` average wait between 5 and 60 minutes; `ER` has no no-shows; `other_outcomes` is a small share of `n`. Record the row in the commit message.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/patient_flow hnh_dwh/tests/hnh/assert_int_encounter_row_conservation.sql
git commit -m "Add int_encounter unifying appointments, ER visits and admissions

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Encounter, admission and episode facts

**Files:**
- Create in `hnh_dwh/models/hnh/marts/patient_flow/`: `fact_encounter.sql`, `fact_admission.sql`, `fact_episode.sql`, `_patient_flow_marts__models.yml`
- Test: `hnh_dwh/tests/hnh/assert_fact_admission_matches_staging.sql`

**Interfaces:**
- Consumes: `int_encounter` (Task 5), `int_admission` (Task 4), `int_episode` (Task 2); every dimension from Phase 1A; `stg_ref__referral_policy` (1A Task 3); `hnh_surrogate_key`, `hnh_date_key`, `hnh_time_key`, `hnh_care_type_key`, `hnh_admission_source_key`.
- Produces:
  - `fact_encounter(encounter_key, branch_key, encounter_date_key, encounter_time_key, arrival_date_key, arrival_time_key, booking_date_key, episode_key, patient_key, booked_staff_key, treating_staff_key, department_key, payer_key, care_type_key, eligibility_type_key, outcome_key, er_priority_key, encounter_type, source_id, visit_type, booked_from, flags…, measures…, _loaded_at)`
  - `fact_admission(admission_key, encounter_key, branch_key, admit_date_key, admit_time_key, clinical_discharge_date_key, physical_discharge_date_key, financial_discharge_date_key, episode_key, patient_key, consultant_staff_key, treating_staff_key, first_department_key, last_department_key, last_bed_key, payer_key, care_type_key, admission_source_key, discharge_outcome_key, admission_no, …measures and flags of int_admission…, _loaded_at)`
  - `fact_episode(episode_key, branch_key, start_date_key, end_date_key, patient_key, consultant_staff_key, department_key, payer_key, care_type_key, eligibility_type_key, episode_no, episode_seq, is_first_episode, previous_care_type, policy_code, contract_no, is_referral_policy, op_encounters, er_encounters, ip_encounters, has_arrived_non_follow_up_encounter, _loaded_at)`
  - Key formulas (the same in every fact): `encounter_key = hnh_surrogate_key([branch_id, encounter_type, source_id])`; `admission_key = hnh_surrogate_key([branch_id, admission_no])`; `episode_key = hnh_surrogate_key([branch_id, patient_id, episode_no])`.

- [ ] **Step 1: Write the tests**

`_patient_flow_marts__models.yml`:

```yaml
version: 2

models:
  - name: fact_encounter
    columns:
      - name: encounter_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('dim_branch'), field: branch_key}
      - name: encounter_date_key
        tests:
          - not_null
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: booked_staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: treating_staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: department_key
        tests:
          - relationships: {to: ref('dim_department'), field: department_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
      - name: outcome_key
        tests:
          - relationships: {to: ref('dim_appointment_outcome'), field: outcome_key}
      - name: eligibility_type_key
        tests:
          - relationships: {to: ref('dim_eligibility_type'), field: eligibility_type_key}
      - name: er_priority_key
        tests:
          - relationships: {to: ref('dim_er_priority'), field: er_priority_key}
  - name: fact_admission
    columns:
      - name: admission_key
        tests: [unique, not_null]
      - name: admit_date_key
        tests:
          - not_null
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: physical_discharge_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: consultant_staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: first_department_key
        tests:
          - relationships: {to: ref('dim_department'), field: department_key}
      - name: last_department_key
        tests:
          - relationships: {to: ref('dim_department'), field: department_key}
      - name: last_bed_key
        tests:
          - relationships: {to: ref('dim_bed'), field: bed_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: admission_source_key
        tests:
          - relationships: {to: ref('dim_admission_source'), field: admission_source_key}
      - name: discharge_outcome_key
        tests:
          - relationships: {to: ref('dim_discharge_outcome'), field: discharge_outcome_key}
  - name: fact_episode
    columns:
      - name: episode_key
        tests: [unique, not_null]
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
```

`hnh_dwh/tests/hnh/assert_fact_admission_matches_staging.sql`:

```sql
-- Every admission in the reporting window is in the fact exactly once.
{% set start_ts = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
select 'fact_admission row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_admission') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__admissions') }}
    where admitted_at >= {{ start_ts }}
       or (admitted_at < {{ start_ts }} and (physical_discharge_at is null or physical_discharge_at >= {{ start_ts }}))
) as s
where f.n != s.n
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select assert_fact_admission_matches_staging`
Expected: a compilation error: `depends on a node named 'fact_admission' which was not found`.

- [ ] **Step 3: Write `fact_encounter`**

```sql
{{ config(order_by='(branch_key, encounter_date_key, encounter_key)') }}

with e as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'encounter_type', 'source_id']) }}   as encounter_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id', 'episode_no']) }}      as episode_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}                    as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'booked_staff_id']) }}               as booked_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'treating_staff_id']) }}             as treating_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'work_entity']) }}                   as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'purchaser_code']) }}                as payer_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'eligibility_type']) }}              as eligibility_type_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'outcome_code']) }}                  as outcome_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'er_priority']) }}                   as er_priority_key_raw
    from {{ ref('int_encounter') }}
    where encounter_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
)

select
    e.encounter_key                                          as encounter_key,
    e.branch_id                                              as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(e.encounter_at)))       as encounter_date_key,
    {{ hnh_time_key('e.encounter_at') }}                     as encounter_time_key,
    {{ hnh_date_key('e.arrived_at') }}                       as arrival_date_key,
    {{ hnh_time_key('e.arrived_at') }}                       as arrival_time_key,
    {{ hnh_date_key('e.booked_at') }}                        as booking_date_key,
    e.episode_key                                            as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                      as patient_key,
    ifNull(dbs.staff_key, toInt64(-1))                       as booked_staff_key,
    ifNull(dts.staff_key, toInt64(-1))                       as treating_staff_key,
    ifNull(dd.department_key, toInt64(-1))                   as department_key,
    ifNull(dpy.payer_key, toInt64(-1))                       as payer_key,
    {{ hnh_care_type_key('e.care_type') }}                   as care_type_key,
    ifNull(det.eligibility_type_key, toInt64(-1))            as eligibility_type_key,
    ifNull(dout.outcome_key, toInt64(-1))                    as outcome_key,
    ifNull(dpr.er_priority_key, toInt64(-1))                 as er_priority_key,
    e.encounter_type                                         as encounter_type,
    e.source_id                                              as source_id,
    e.visit_type                                             as visit_type,
    e.booked_from                                            as booked_from,
    e.is_arrived, e.is_seen, e.is_cancelled, e.is_no_show, e.is_walk_in, e.is_follow_up,
    e.is_virtual, e.is_online_booking, e.is_first_episode, e.is_returning,
    e.prior_encounters_4m,
    e.wait_minutes, e.wait_minutes_raw, e.door_to_triage_minutes,
    e.service_minutes, e.service_minutes_raw, e.er_los_minutes, e.booking_lead_days,
    e.legacy_in_op_census, e.legacy_is_cancelled_outpatient_model,
    now()                                                    as _loaded_at
from e
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = e.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dbs on dbs.staff_key = e.booked_staff_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dts on dts.staff_key = e.treating_staff_key_raw
left join (select department_key from {{ ref('dim_department') }}) as dd on dd.department_key = e.department_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = e.payer_key_raw
left join (select eligibility_type_key from {{ ref('dim_eligibility_type') }}) as det on det.eligibility_type_key = e.eligibility_type_key_raw
left join (select outcome_key from {{ ref('dim_appointment_outcome') }}) as dout on dout.outcome_key = e.outcome_key_raw
left join (select er_priority_key from {{ ref('dim_er_priority') }}) as dpr on dpr.er_priority_key = e.er_priority_key_raw
{{ hnh_settings() }}
```

Every dimension join exists only to turn a reference that is missing from its dimension into `-1`; the `-1` row of each dimension matches a raw key of `-1`.

- [ ] **Step 4: Write `fact_admission`**

```sql
{{ config(order_by='(branch_key, admit_date_key, admission_key)') }}

{% set start_ts = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}

with a as (
    select
        adm.*,
        ep.purchaser_code                                                           as purchaser_code,
        coalesce(adm.request_consultant_staff_id, ep.consultant_staff_id)           as consultant_staff_id,
        if(ep.care_type is null or ep.care_type = 'Unknown', 'IP', ep.care_type)    as care_type
    from {{ ref('int_admission') }} as adm
    left join {{ ref('int_episode') }} as ep
        on ep.branch_id = adm.branch_id and ep.patient_id = adm.patient_id and ep.episode_no = adm.episode_no
    where adm.admitted_at >= {{ start_ts }}
       or (adm.admitted_at < {{ start_ts }} and (adm.physical_discharge_at is null or adm.physical_discharge_at >= {{ start_ts }}))
),

k as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'admission_no']) }}                  as admission_key,
        {{ hnh_surrogate_key(['branch_id', "'IP'", 'admission_no']) }}          as encounter_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id', 'episode_no']) }}      as episode_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}                    as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'consultant_staff_id']) }}           as consultant_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'treating_staff_id']) }}             as treating_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'first_work_entity']) }}             as first_department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'last_work_entity']) }}              as last_department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'last_bed_location']) }}             as last_bed_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'ifNull(purchaser_code, toInt64(9999))']) }} as payer_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'outcome_code']) }}                  as discharge_outcome_key_raw
    from a
)

select
    k.admission_key                                          as admission_key,
    k.encounter_key                                          as encounter_key,
    k.branch_id                                              as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(k.admitted_at)))        as admit_date_key,
    {{ hnh_time_key('k.admitted_at') }}                      as admit_time_key,
    {{ hnh_date_key('k.clinical_discharge_at') }}            as clinical_discharge_date_key,
    {{ hnh_date_key('k.physical_discharge_at') }}            as physical_discharge_date_key,
    {{ hnh_date_key('k.financial_discharge_at') }}           as financial_discharge_date_key,
    k.episode_key                                            as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                      as patient_key,
    ifNull(dcs.staff_key, toInt64(-1))                       as consultant_staff_key,
    ifNull(dts.staff_key, toInt64(-1))                       as treating_staff_key,
    ifNull(dfd.department_key, toInt64(-1))                  as first_department_key,
    ifNull(dld.department_key, toInt64(-1))                  as last_department_key,
    ifNull(db.bed_key, toInt64(-1))                          as last_bed_key,
    ifNull(dpy.payer_key, toInt64(-1))                       as payer_key,
    {{ hnh_care_type_key('k.care_type') }}                   as care_type_key,
    {{ hnh_admission_source_key('k.admission_source') }}     as admission_source_key,
    ifNull(ddo.discharge_outcome_key, toInt64(-1))           as discharge_outcome_key,
    k.admission_no                                           as admission_no,
    k.admitted_at                                            as admitted_at,
    k.physical_discharge_at                                  as physical_discharge_at,
    k.request_planned_admit_at                               as planned_admit_at,
    k.request_admission_type                                 as admission_type,
    k.referred_type                                          as referred_type,
    k.discharge_outcome_group                                as discharge_outcome_group,
    k.los_hours, k.los_days, k.los_days_to_date,
    k.is_open, k.is_short_stay, k.is_wrong_admission_outcome, k.is_countable,
    k.is_ltc, k.is_ltc_to_date,
    k.has_bed, k.had_critical_bed, k.critical_bed_hours,
    k.days_since_previous_discharge, k.is_readmission_30d, k.is_icu_readmission_48h,
    k.is_died, k.is_dama,
    k.legacy_is_wrong_admission, k.legacy_is_ltc, k.legacy_days_since_previous_admission, k.legacy_in_vw_inpatients,
    now()                                                    as _loaded_at
from k
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dcs on dcs.staff_key = k.consultant_staff_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dts on dts.staff_key = k.treating_staff_key_raw
left join (select department_key from {{ ref('dim_department') }}) as dfd on dfd.department_key = k.first_department_key_raw
left join (select department_key from {{ ref('dim_department') }}) as dld on dld.department_key = k.last_department_key_raw
left join (select bed_key from {{ ref('dim_bed') }}) as db on db.bed_key = k.last_bed_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = k.payer_key_raw
left join (select discharge_outcome_key from {{ ref('dim_discharge_outcome') }}) as ddo on ddo.discharge_outcome_key = k.discharge_outcome_key_raw
{{ hnh_settings() }}
```

- [ ] **Step 5: Write `fact_episode`**

```sql
{{ config(order_by='(branch_key, start_date_key, episode_key)') }}

with encounter_counts as (
    select
        branch_id, assumeNotNull(patient_id) as patient_id, assumeNotNull(episode_no) as episode_no,
        countIf(encounter_type = 'OP') as op_encounters,
        countIf(encounter_type = 'ER') as er_encounters,
        countIf(encounter_type = 'IP') as ip_encounters,
        toUInt8(countIf(encounter_type in ('OP', 'ER') and is_arrived = 1 and is_cancelled = 0 and is_follow_up = 0) > 0) as has_arrived_non_follow_up_encounter
    from {{ ref('int_encounter') }}
    where patient_id is not null and episode_no is not null
    group by branch_id, patient_id, episode_no
),

e as (
    select
        ep.*,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.patient_id', 'ep.episode_no']) }}  as episode_key,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.patient_id']) }}                   as patient_key_raw,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.consultant_staff_id']) }}          as consultant_staff_key_raw,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.work_entity']) }}                  as department_key_raw,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.purchaser_code']) }}               as payer_key_raw,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.eligibility_type']) }}             as eligibility_type_key_raw
    from {{ ref('int_episode') }} as ep
    where ep.started_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
)

select
    e.episode_key                                        as episode_key,
    e.branch_id                                          as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(e.started_at)))     as start_date_key,
    {{ hnh_date_key('e.ended_at') }}                     as end_date_key,
    ifNull(dp.patient_key, toInt64(-1))                  as patient_key,
    ifNull(ds.staff_key, toInt64(-1))                    as consultant_staff_key,
    ifNull(dd.department_key, toInt64(-1))               as department_key,
    ifNull(dpy.payer_key, toInt64(-1))                   as payer_key,
    {{ hnh_care_type_key('e.care_type') }}               as care_type_key,
    ifNull(det.eligibility_type_key, toInt64(-1))        as eligibility_type_key,
    e.episode_no                                         as episode_no,
    e.episode_seq                                        as episode_seq,
    e.is_first_episode                                   as is_first_episode,
    e.previous_care_type                                 as previous_care_type,
    e.policy_code                                        as policy_code,
    e.contract_no                                        as contract_no,
    toUInt8(rp.policy_code is not null)                  as is_referral_policy,
    toUInt32(ifNull(c.op_encounters, 0))                 as op_encounters,
    toUInt32(ifNull(c.er_encounters, 0))                 as er_encounters,
    toUInt32(ifNull(c.ip_encounters, 0))                 as ip_encounters,
    toUInt8(ifNull(c.has_arrived_non_follow_up_encounter, 0)) as has_arrived_non_follow_up_encounter,
    e.legacy_care_type                                   as legacy_care_type,
    e.legacy_purchaser_code                              as legacy_purchaser_code,
    now()                                                as _loaded_at
from e
left join encounter_counts as c
    on c.branch_id = e.branch_id and c.patient_id = e.patient_id and c.episode_no = e.episode_no
left join (select distinct branch_id, policy_code from {{ ref('stg_ref__referral_policy') }}) as rp
    on rp.branch_id = e.branch_id and rp.policy_code = e.policy_code
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = e.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = e.consultant_staff_key_raw
left join (select department_key from {{ ref('dim_department') }}) as dd on dd.department_key = e.department_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = e.payer_key_raw
left join (select eligibility_type_key from {{ ref('dim_eligibility_type') }}) as det on det.eligibility_type_key = e.eligibility_type_key_raw
{{ hnh_settings() }}
```

- [ ] **Step 6: Build and test**

Run: `python scripts/run_dbt.py build --select fact_encounter fact_admission fact_episode assert_fact_admission_matches_staging`
Expected: 3 tables created, all tests pass. If the build fails on memory, re-run with `--threads 1`; the three facts each join several dimensions.

- [ ] **Step 7: Spot-check unknown-key rates**

Run: `python scripts/run_dbt.py show --inline "select 'encounter' as fact, count() as n, countIf(patient_key = -1) as no_patient, countIf(booked_staff_key = -1) as no_booked_staff, countIf(department_key = -1) as no_department, countIf(payer_key = -1) as no_payer, countIf(outcome_key = -1) as no_outcome from {{ ref('fact_encounter') }} union all select 'admission', count(), countIf(patient_key = -1), countIf(consultant_staff_key = -1), countIf(first_department_key = -1), countIf(payer_key = -1), countIf(discharge_outcome_key = -1) from {{ ref('fact_admission') }}"`
Expected: `no_patient` and `no_payer` are zero or near zero. `no_outcome` is large for encounters (outcomes not recorded) and equals the number of open stays plus unrecorded outcomes for admissions. Record the row in the commit message.

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/models/hnh/marts/patient_flow hnh_dwh/tests/hnh/assert_fact_admission_matches_staging.sql
git commit -m "Add encounter, admission and episode facts

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Bed occupancy and clinic capacity

**Files:**
- Create in `hnh_dwh/models/hnh/marts/patient_flow/`: `fact_bed_occupancy_daily.sql`, `agg_clinic_capacity_daily.sql`
- Modify: `_patient_flow_marts__models.yml` (append)
- Test: `hnh_dwh/tests/hnh/assert_clinic_capacity_slot_conservation.sql`

**Interfaces:**
- Consumes: `int_bed_day` (Task 3); `stg_oasis__appointments` (Task 1); `int_encounter` (Task 5); `dim_bed`, `dim_department`, `dim_patient`, `dim_staff` (1A).
- Produces:
  - `fact_bed_occupancy_daily(branch_key, date_key, bed_key, department_key, patient_key, admission_key, is_available, is_occupied, is_excluded_ward, _loaded_at)`
  - `agg_clinic_capacity_daily(branch_key, date_key, department_key, staff_key, slots_total, slots_booked, slots_attended, slots_no_show, slots_cancelled, slots_rescheduled, slots_walk_in, break_slots, scheduled_minutes, legacy_capacity_slots, _loaded_at)`

- [ ] **Step 1: Write the tests**

Append to `_patient_flow_marts__models.yml`:

```yaml
  - name: fact_bed_occupancy_daily
    tests:
      - hnh_unique_combination:
          columns: [branch_key, date_key, bed_key]
    columns:
      - name: date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: bed_key
        tests:
          - relationships: {to: ref('dim_bed'), field: bed_key}
      - name: department_key
        tests:
          - relationships: {to: ref('dim_department'), field: department_key}
  - name: agg_clinic_capacity_daily
    tests:
      - hnh_unique_combination:
          columns: [branch_key, date_key, department_key, staff_key]
    columns:
      - name: date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: department_key
        tests:
          - relationships: {to: ref('dim_department'), field: department_key}
      - name: staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
```

`hnh_dwh/tests/hnh/assert_clinic_capacity_slot_conservation.sql`:

```sql
-- Every appointment slot with a date inside the dim_date range is counted exactly once.
-- This also proves an incremental run equals a full refresh.
select a.branch_key as branch_key, a.slots as in_aggregate, s.slots as in_staging
from (
    select branch_key, sum(slots_total) as slots
    from {{ ref('agg_clinic_capacity_daily') }}
    group by branch_key
) as a
inner join (
    select branch_id as branch_key, count() as slots
    from {{ ref('stg_oasis__appointments') }}
    where ifNull(slot_date, toDate(starts_at)) between toDate('{{ var("hnh_history_start_date") }}')
          and (select max(date_day) from {{ ref('dim_date') }})
    group by branch_id
) as s on s.branch_key = a.branch_key
where a.slots != s.slots
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select assert_clinic_capacity_slot_conservation`
Expected: a compilation error: `depends on a node named 'agg_clinic_capacity_daily' which was not found`.

- [ ] **Step 3: Write `fact_bed_occupancy_daily`**

```sql
{{ config(order_by='(branch_key, date_key, bed_key)') }}

with d as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'bed_location']) }}   as bed_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'work_entity']) }}    as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}     as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'admission_no']) }}   as admission_key
    from {{ ref('int_bed_day') }}
)

select
    d.branch_id                                 as branch_key,
    toInt32(toYYYYMMDD(d.date_day))             as date_key,
    ifNull(db.bed_key, toInt64(-1))             as bed_key,
    ifNull(dd.department_key, toInt64(-1))      as department_key,
    ifNull(dp.patient_key, toInt64(-1))         as patient_key,
    d.admission_key                             as admission_key,
    d.is_available                              as is_available,
    d.is_occupied                               as is_occupied,
    d.is_excluded_ward                          as is_excluded_ward,
    now()                                       as _loaded_at
from d
left join (select bed_key from {{ ref('dim_bed') }}) as db on db.bed_key = d.bed_key_raw
left join (select department_key from {{ ref('dim_department') }}) as dd on dd.department_key = d.department_key_raw
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = d.patient_key_raw
{{ hnh_settings() }}
```

- [ ] **Step 4: Write `agg_clinic_capacity_daily`**

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['branch_key', 'date_key'],
    order_by='(branch_key, date_key, department_key, staff_key)'
) }}

{% set first_date = "toDate('" ~ var('hnh_history_start_date') ~ "')" %}
{% set last_date = "(select max(date_day) from " ~ ref('dim_date') ~ ")" %}

with slots as (
    select
        branch_id, appointment_id, patient_id, work_entity, booked_staff_id, break_code, slot_minutes,
        ifNull(slot_date, toDate(starts_at)) as slot_day,
        updated_at
    from {{ ref('stg_oasis__appointments') }}
    where ifNull(slot_date, toDate(starts_at)) between {{ first_date }} and {{ last_date }}
),

{% if is_incremental() %}
changed_days as (
    -- Rebuild whole days: every day that has a slot changed since the last load.
    select distinct branch_id, slot_day
    from slots
    where updated_at > (select max(_loaded_at) - toIntervalDay(1) from {{ this }})
),
{% endif %}

in_scope as (
    select s.*
    from slots as s
    {% if is_incremental() %}
    inner join changed_days as c on c.branch_id = s.branch_id and c.slot_day = s.slot_day
    {% endif %}
),

booked as (
    select branch_id, source_id as appointment_id, is_arrived, is_cancelled, is_no_show, is_walk_in, outcome_group
    from {{ ref('int_encounter') }}
    where encounter_type = 'OP'
),

per_day as (
    select
        s.branch_id         as branch_id,
        s.slot_day          as slot_day,
        s.work_entity       as work_entity,
        s.booked_staff_id   as booked_staff_id,
        count()                                                              as slots_total,
        countIf(s.patient_id is not null)                                    as slots_booked,
        countIf(b.is_arrived = 1 and b.is_cancelled = 0)                     as slots_attended,
        countIf(b.is_no_show = 1)                                            as slots_no_show,
        countIf(b.outcome_group = 'Cancelled')                               as slots_cancelled,
        countIf(b.outcome_group = 'Rescheduled')                             as slots_rescheduled,
        countIf(b.is_walk_in = 1)                                            as slots_walk_in,
        countIf(s.break_code is not null)                                    as break_slots,
        sum(ifNull(s.slot_minutes, 0))                                       as scheduled_minutes
    from in_scope as s
    left join booked as b on b.branch_id = s.branch_id and b.appointment_id = s.appointment_id
    group by s.branch_id, s.slot_day, s.work_entity, s.booked_staff_id
),

keyed as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'work_entity']) }}      as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'booked_staff_id']) }}  as staff_key_raw
    from per_day
)

select
    k.branch_id                                  as branch_key,
    toInt32(toYYYYMMDD(k.slot_day))              as date_key,
    ifNull(dd.department_key, toInt64(-1))       as department_key,
    ifNull(ds.staff_key, toInt64(-1))            as staff_key,
    sum(k.slots_total)                           as slots_total,
    sum(k.slots_booked)                          as slots_booked,
    sum(k.slots_attended)                        as slots_attended,
    sum(k.slots_no_show)                         as slots_no_show,
    sum(k.slots_cancelled)                       as slots_cancelled,
    sum(k.slots_rescheduled)                     as slots_rescheduled,
    sum(k.slots_walk_in)                         as slots_walk_in,
    sum(k.break_slots)                           as break_slots,
    sum(k.scheduled_minutes)                     as scheduled_minutes,
    -- Old capacity rule: clinic hours x slots per hour, for a doctor-day with at least one attended visit.
    toFloat64(if(sum(k.slots_attended) > 0,
       ifNull(any(ds.clinic_duration_hours) * any(ds.slots_per_hour), 0), 0)) as legacy_capacity_slots,
    now()                                        as _loaded_at
from keyed as k
left join (select department_key from {{ ref('dim_department') }}) as dd on dd.department_key = k.department_key_raw
left join (select staff_key, clinic_duration_hours, slots_per_hour from {{ ref('dim_staff') }}) as ds on ds.staff_key = k.staff_key_raw
group by k.branch_id, k.slot_day, department_key, staff_key
{{ hnh_settings() }}
```

The final `group by` merges rows whose clinic or doctor is missing from its dimension into one `-1` row per day, which keeps the grain unique. The cancellation split into "by hospital" and "by patient" is available from `fact_encounter` through `dim_appointment_outcome`; here the two are counted together as `slots_cancelled`.

- [ ] **Step 5: Build with a full refresh and test**

Run: `python scripts/run_dbt.py build --full-refresh --select fact_bed_occupancy_daily agg_clinic_capacity_daily assert_clinic_capacity_slot_conservation`
Expected: 2 tables created, all tests pass. `agg_clinic_capacity_daily` reads all 372M appointment rows and takes several minutes.

- [ ] **Step 6: Verify the incremental path**

Run: `python scripts/run_dbt.py build --select agg_clinic_capacity_daily assert_clinic_capacity_slot_conservation`
Expected: the model runs as an incremental load (the log shows `delete` then `insert`), finishes much faster than the full refresh, and `assert_clinic_capacity_slot_conservation` still passes. That test passing after an incremental run is the proof that the incremental result equals a full refresh.

- [ ] **Step 7: Spot-check utilisation and occupancy**

Run: `python scripts/run_dbt.py show --inline "select c.branch_key, round(100 * sum(c.slots_attended) / sum(c.slots_total), 1) as utilisation_pct, round(100 * sum(c.slots_no_show) / nullIf(sum(c.slots_booked - c.slots_walk_in), 0), 1) as no_show_pct from {{ ref('agg_clinic_capacity_daily') }} as c where c.date_key between 20260901 and 20260930 group by c.branch_key order by c.branch_key"`
Expected: utilisation is a low single-digit to low double-digit percentage (most slots are empty by design), and the no-show percentage is between 0 and 60. Record the rows in the commit message.

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/models/hnh/marts/patient_flow hnh_dwh/tests/hnh/assert_clinic_capacity_slot_conservation.sql
git commit -m "Add daily bed occupancy and incremental clinic capacity

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Surgery and target facts

**Files:**
- Create in `hnh_dwh/models/hnh/marts/patient_flow/`: `fact_surgery.sql`, `fact_target_daily.sql`
- Modify: `_patient_flow_marts__models.yml` (append)
- Test: `hnh_dwh/tests/hnh/assert_fact_surgery_row_conservation.sql`, `hnh_dwh/tests/hnh/warn_branches_without_targets.sql`

**Interfaces:**
- Consumes: `stg_oasis__operations`, `stg_oasis__operating_slots`, `stg_oasis__service_items`, `stg_ref__budget` (Task 1); `int_episode` (Task 2); `int_code_decode`; dimensions; `hnh_procedure_type`, `hnh_procedure_type_key`, `hnh_minutes_between`.
- Produces:
  - `fact_surgery(surgery_key, branch_key, operation_date_key, operation_time_key, episode_key, patient_key, surgeon_staff_key, anaesthetist_staff_key, department_key, payer_key, care_type_key, procedure_type_key, operating_slot_code, operation_seq, procedure_name, operation_type, anaesthesia_type, operation_status, is_cancelled, cancel_reason, hall_to_theatre_minutes, anaesthesia_minutes, operating_minutes, recovery_handover_minutes, _loaded_at)`
  - `fact_target_daily(branch_key, date_key, care_type_key, scenario, stay_type, creditor, specialty, target_census, target_episodes, target_revenue, target_cost_per_episode, target_alos, _loaded_at)`

- [ ] **Step 1: Write the tests**

Append to `_patient_flow_marts__models.yml`:

```yaml
  - name: fact_surgery
    columns:
      - name: surgery_key
        tests: [unique, not_null]
      - name: operation_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: surgeon_staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: department_key
        tests:
          - relationships: {to: ref('dim_department'), field: department_key}
      - name: procedure_type_key
        tests:
          - relationships: {to: ref('dim_procedure_type'), field: procedure_type_key}
  - name: fact_target_daily
    tests:
      - hnh_unique_combination:
          columns: [branch_key, date_key, scenario, care_type_key, stay_type, creditor, specialty]
    columns:
      - name: branch_key
        tests:
          - relationships: {to: ref('dim_branch'), field: branch_key}
      - name: date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: scenario
        tests:
          - accepted_values:
              values: ["most_likely", "best_case", "worst_case"]
```

`hnh_dwh/tests/hnh/assert_fact_surgery_row_conservation.sql`:

```sql
-- One fact row per operation whose slot has a patient.
select 'fact_surgery row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_surgery') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__operations') }} as o
    inner join {{ ref('stg_oasis__operating_slots') }} as sl
        on sl.branch_id = o.branch_id and sl.operating_slot_code = o.operating_slot_code
    where sl.patient_id is not null
      and coalesce(o.operation_started_at, sl.operation_started_at, sl.scheduled_start_at)
          >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
) as s
where f.n != s.n
```

`hnh_dwh/tests/hnh/warn_branches_without_targets.sql`:

```sql
{{ config(severity='warn') }}
-- Branches that have activity but no target rows for the current year.
select b.branch_key, b.branch_name
from {{ ref('dim_branch') }} as b
left join (
    select distinct branch_key
    from {{ ref('fact_target_daily') }}
    where intDiv(date_key, 10000) = toYear(today())
) as t on t.branch_key = b.branch_key
where b.branch_key between 1 and 8 and t.branch_key is null
{{ hnh_settings() }}
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select assert_fact_surgery_row_conservation`
Expected: a compilation error: `depends on a node named 'fact_surgery' which was not found`.

- [ ] **Step 3: Write `fact_surgery`**

```sql
{{ config(order_by='(branch_key, surgery_key)') }}

with ops as (
    select
        o.branch_id                 as branch_id,
        o.operating_slot_code       as operating_slot_code,
        o.operation_seq             as operation_seq,
        o.ios_main                  as ios_main,
        o.surgeon_staff_id          as surgeon_staff_id,
        o.anaesthetist_staff_id     as anaesthetist_staff_id,
        o.operation_status_code     as operation_status_code,
        o.operation_type_code       as operation_type_code,
        o.anaesthesia_type_code     as anaesthesia_type_code,
        sl.work_entity              as work_entity,
        sl.patient_id               as patient_id,
        sl.episode_no               as episode_no,
        sl.entity_type              as entity_type,
        sl.is_cancelled             as is_cancelled,
        sl.cancel_code              as cancel_code,
        sl.hall_arrived_at          as hall_arrived_at,
        sl.theatre_arrived_at       as theatre_arrived_at,
        sl.anaesthesia_started_at   as anaesthesia_started_at,
        sl.anaesthesia_ended_at     as anaesthesia_ended_at,
        sl.recovery_at              as recovery_at,
        sl.ward_at                  as ward_at,
        coalesce(o.operation_started_at, sl.operation_started_at) as operation_started_at,
        coalesce(o.operation_ended_at, sl.operation_ended_at)     as operation_ended_at,
        coalesce(o.operation_started_at, sl.operation_started_at, sl.scheduled_start_at) as operation_at
    from {{ ref('stg_oasis__operations') }} as o
    inner join {{ ref('stg_oasis__operating_slots') }} as sl
        on sl.branch_id = o.branch_id and sl.operating_slot_code = o.operating_slot_code
    where sl.patient_id is not null
),

enriched as (
    select
        ops.*,
        upper(it.description)                                   as procedure_upper,
        it.description                                          as procedure_name,
        st.description                                          as operation_status,
        ot.description                                          as operation_type,
        an.description                                          as anaesthesia_type,
        cr.description                                          as cancel_reason,
        ifNull(ep.purchaser_code, toInt64(9999))                as purchaser_code,
        if(ep.care_type is null, 'Unknown', ep.care_type)       as care_type
    from ops
    left join {{ ref('stg_oasis__service_items') }} as it on it.branch_id = ops.branch_id and it.ios_main = ops.ios_main
    left join {{ ref('int_code_decode') }} as st on st.branch_id = ops.branch_id and st.code = ops.operation_status_code
    left join {{ ref('int_code_decode') }} as ot on ot.branch_id = ops.branch_id and ot.code = ops.operation_type_code
    left join {{ ref('int_code_decode') }} as an on an.branch_id = ops.branch_id and an.code = ops.anaesthesia_type_code
    left join {{ ref('int_code_decode') }} as cr on cr.branch_id = ops.branch_id and cr.code = ops.cancel_code
    left join {{ ref('int_episode') }} as ep
        on ep.branch_id = ops.branch_id and ep.patient_id = ops.patient_id and ep.episode_no = ops.episode_no
    where ops.operation_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
),

k as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'operating_slot_code', 'operation_seq']) }} as surgery_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id', 'episode_no']) }}             as episode_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}                           as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'surgeon_staff_id']) }}                     as surgeon_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'anaesthetist_staff_id']) }}                as anaesthetist_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'work_entity']) }}                          as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'purchaser_code']) }}                       as payer_key_raw,
        {{ hnh_procedure_type('procedure_upper', 'entity_type') }}                     as procedure_type
    from enriched
)

select
    k.surgery_key                                        as surgery_key,
    k.branch_id                                          as branch_key,
    {{ hnh_date_key('k.operation_at') }}                 as operation_date_key,
    {{ hnh_time_key('k.operation_at') }}                 as operation_time_key,
    k.episode_key                                        as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                  as patient_key,
    ifNull(dsu.staff_key, toInt64(-1))                   as surgeon_staff_key,
    ifNull(dan.staff_key, toInt64(-1))                   as anaesthetist_staff_key,
    ifNull(dd.department_key, toInt64(-1))               as department_key,
    ifNull(dpy.payer_key, toInt64(-1))                   as payer_key,
    {{ hnh_care_type_key('k.care_type') }}               as care_type_key,
    {{ hnh_procedure_type_key('k.procedure_type') }}     as procedure_type_key,
    k.operating_slot_code                                as operating_slot_code,
    k.operation_seq                                      as operation_seq,
    k.procedure_name                                     as procedure_name,
    k.operation_type                                     as operation_type,
    k.anaesthesia_type                                   as anaesthesia_type,
    k.operation_status                                   as operation_status,
    k.is_cancelled                                       as is_cancelled,
    k.cancel_reason                                      as cancel_reason,
    {{ hnh_minutes_between('k.hall_arrived_at', 'k.theatre_arrived_at') }}        as hall_to_theatre_minutes,
    {{ hnh_minutes_between('k.anaesthesia_started_at', 'k.anaesthesia_ended_at') }} as anaesthesia_minutes,
    {{ hnh_minutes_between('k.operation_started_at', 'k.operation_ended_at') }}   as operating_minutes,
    {{ hnh_minutes_between('k.recovery_at', 'k.ward_at') }}                       as recovery_handover_minutes,
    now()                                                as _loaded_at
from k
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dsu on dsu.staff_key = k.surgeon_staff_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dan on dan.staff_key = k.anaesthetist_staff_key_raw
left join (select department_key from {{ ref('dim_department') }}) as dd on dd.department_key = k.department_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = k.payer_key_raw
{{ hnh_settings() }}
```

- [ ] **Step 4: Write `fact_target_daily`**

```sql
{{ config(order_by='(branch_key, date_key, scenario)') }}

select
    branch_id                                            as branch_key,
    toInt32(toYYYYMMDD(target_date))                     as date_key,
    {{ hnh_care_type_key('care_type') }}                 as care_type_key,
    scenario                                             as scenario,
    stay_type                                            as stay_type,
    ifNull(creditor, 'Not Mapped')                       as creditor,
    ifNull(specialty, 'Not Mapped')                      as specialty,
    sum(census)                                          as target_census,
    sum(episodes)                                        as target_episodes,
    sum(revenue)                                         as target_revenue,
    if(sum(episodes) = 0, 0, sum(revenue) / sum(episodes)) as target_cost_per_episode,
    max(alos)                                            as target_alos,
    now()                                                as _loaded_at
from {{ ref('stg_ref__budget') }}
where is_latest = 1
group by branch_key, date_key, care_type_key, scenario, stay_type, creditor, specialty
```

`creditor` and `specialty` are text attributes of the target. The budget is planned by payer class and unified specialty, which are attributes of `dim_payer` and `dim_staff` rather than keys, so the SSAS model compares targets with actuals on those attribute values.

- [ ] **Step 5: Build and test**

Run: `python scripts/run_dbt.py build --select fact_surgery fact_target_daily assert_fact_surgery_row_conservation warn_branches_without_targets`
Expected: 2 tables created, no errors. `warn_branches_without_targets` warns for branch 8 (Muhayil), which has no budget rows.

- [ ] **Step 6: Spot-check**

Run: `python scripts/run_dbt.py show --inline "select t.procedure_type, count() as operations, sum(s.is_cancelled) as cancelled, round(avg(s.operating_minutes)) as avg_operating_minutes from {{ ref('fact_surgery') }} as s inner join {{ ref('dim_procedure_type') }} as t on t.procedure_type_key = s.procedure_type_key group by t.procedure_type order by operations desc"`
Expected: `Surgery` is the largest group; `Cesarean`, `Cath Lab`, `Endoscopy` and `L&D` are present; average operating time is between 15 and 240 minutes.

Run: `python scripts/run_dbt.py show --inline "select scenario, round(sum(target_revenue)) as revenue, uniqExact(branch_key) as branches from {{ ref('fact_target_daily') }} group by scenario order by scenario"`
Expected: `most_likely` revenue of about 2,175,926,704 across 7 branches (the latest-version total measured when the budget was loaded).

- [ ] **Step 7: Commit**

```bash
git add hnh_dwh/models/hnh/marts/patient_flow hnh_dwh/tests/hnh/assert_fact_surgery_row_conservation.sql hnh_dwh/tests/hnh/warn_branches_without_targets.sql
git commit -m "Add surgery and daily target facts

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Reconciliation, run log and full build

**Files:**
- Create: `hnh_dwh/models/hnh/marts/reconciliation/rec_patient_flow_monthly.sql`, `_reconciliation__models.yml`
- Create: `hnh_dwh/macros/hnh/hnh_log_run.sql`
- Modify: `hnh_dwh/dbt_project.yml` (add `on-run-end`)
- Create: `docs/reconciliation_phase1.md`
- Modify: `docs/receiving_project_config.md` (add the hook line)

**Interfaces:**
- Consumes: `fact_encounter`, `fact_admission`, `fact_episode` (Task 6); `fact_bed_occupancy_daily` (Task 7).
- Produces:
  - `rec_patient_flow_monthly(branch_key, month_start, census, op_visits, er_visits, episodes, admissions, discharges, alos_non_ltc, occupied_bed_nights, available_bed_nights, occupancy_rate, legacy_census, legacy_op_census, legacy_er_census, legacy_admissions, legacy_discharges, legacy_alos_non_ltc, legacy_wait_minutes_sum)`
  - Macro `hnh_log_run(results)` writing `gold.etl_run_log(invocation_id, run_started_at, run_finished_at, status, models_built, nodes_failed, selected)`.

- [ ] **Step 1: Write the test**

`_reconciliation__models.yml`:

```yaml
version: 2

models:
  - name: rec_patient_flow_monthly
    description: New KPI values beside the values the old warehouse rules would give, per branch and month.
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
    columns:
      - name: branch_key
        tests:
          - relationships: {to: ref('dim_branch'), field: branch_key}
```

- [ ] **Step 2: Run to verify nothing is tested yet**

Run: `python scripts/run_dbt.py test --select rec_patient_flow_monthly`
Expected: a `Did not find matching node for patch` warning and `Nothing to do`.

- [ ] **Step 3: Write `rec_patient_flow_monthly`**

```sql
{{ config(order_by='(branch_key, month_start)') }}

with encounters as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(encounter_date_key))) as month_start,
        uniqExactIf(encounter_key, encounter_type in ('OP', 'ER') and is_arrived = 1 and is_cancelled = 0)  as census,
        uniqExactIf(encounter_key, encounter_type = 'OP' and is_arrived = 1 and is_cancelled = 0)           as op_visits,
        uniqExactIf(encounter_key, encounter_type = 'ER' and is_cancelled = 0)                              as er_visits,
        uniqExactIf(episode_key, encounter_type in ('OP', 'ER') and is_arrived = 1 and is_cancelled = 0 and is_follow_up = 0) as episodes,
        -- old bsc.vw_customer: OP and ER together, arrived, old cancellation list
        uniqExactIf(encounter_key, legacy_in_op_census = 1 and is_arrived = 1)                              as legacy_census,
        uniqExactIf(encounter_key, legacy_in_op_census = 1 and is_arrived = 1 and encounter_type = 'OP')    as legacy_op_census,
        uniqExactIf(encounter_key, legacy_in_op_census = 1 and is_arrived = 1 and encounter_type = 'ER')    as legacy_er_census,
        sumIf(wait_minutes_raw, legacy_in_op_census = 1 and is_arrived = 1 and encounter_type = 'OP')       as legacy_wait_minutes_sum
    from {{ ref('fact_encounter') }}
    group by branch_key, month_start
),

admissions as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(admit_date_key))) as month_start,
        countIf(is_countable = 1)                                                    as admissions,
        countIf(legacy_in_vw_inpatients = 1 and legacy_is_wrong_admission = 0)       as legacy_admissions
    from {{ ref('fact_admission') }}
    group by branch_key, month_start
),

discharges as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(assumeNotNull(physical_discharge_date_key)))) as month_start,
        countIf(is_countable = 1)                                                    as discharges,
        avgIf(los_days, is_countable = 1 and is_ltc = 0)                             as alos_non_ltc,
        countIf(legacy_in_vw_inpatients = 1 and legacy_is_wrong_admission = 0)       as legacy_discharges,
        avgIf(los_days, legacy_in_vw_inpatients = 1 and legacy_is_wrong_admission = 0 and legacy_is_ltc = 0) as legacy_alos_non_ltc
    from {{ ref('fact_admission') }}
    where physical_discharge_date_key is not null
    group by branch_key, month_start
),

beds as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(date_key))) as month_start,
        sumIf(is_occupied, is_excluded_ward = 0)   as occupied_bed_nights,
        sumIf(is_available, is_excluded_ward = 0)  as available_bed_nights
    from {{ ref('fact_bed_occupancy_daily') }}
    group by branch_key, month_start
),

spine as (
    select branch_key, month_start from encounters
    union distinct select branch_key, month_start from admissions
    union distinct select branch_key, month_start from discharges
    union distinct select branch_key, month_start from beds
)

select
    s.branch_key                           as branch_key,
    s.month_start                          as month_start,
    ifNull(e.census, 0)                    as census,
    ifNull(e.op_visits, 0)                 as op_visits,
    ifNull(e.er_visits, 0)                 as er_visits,
    ifNull(e.episodes, 0)                  as episodes,
    ifNull(a.admissions, 0)                as admissions,
    ifNull(d.discharges, 0)                as discharges,
    d.alos_non_ltc                         as alos_non_ltc,
    ifNull(b.occupied_bed_nights, 0)       as occupied_bed_nights,
    ifNull(b.available_bed_nights, 0)      as available_bed_nights,
    if(ifNull(b.available_bed_nights, 0) = 0, null, b.occupied_bed_nights / b.available_bed_nights) as occupancy_rate,
    ifNull(e.legacy_census, 0)             as legacy_census,
    ifNull(e.legacy_op_census, 0)          as legacy_op_census,
    ifNull(e.legacy_er_census, 0)          as legacy_er_census,
    ifNull(a.legacy_admissions, 0)         as legacy_admissions,
    ifNull(d.legacy_discharges, 0)         as legacy_discharges,
    d.legacy_alos_non_ltc                  as legacy_alos_non_ltc,
    ifNull(e.legacy_wait_minutes_sum, 0)   as legacy_wait_minutes_sum
from spine as s
left join encounters as e on e.branch_key = s.branch_key and e.month_start = s.month_start
left join admissions as a on a.branch_key = s.branch_key and a.month_start = s.month_start
left join discharges as d on d.branch_key = s.branch_key and d.month_start = s.month_start
left join beds as b on b.branch_key = s.branch_key and b.month_start = s.month_start
{{ hnh_settings() }}
```

The month spine is the union of all four sources, so a month with only discharges is not dropped (the old scorecard lost such months).

- [ ] **Step 4: Write the run-log hook**

`hnh_dwh/macros/hnh/hnh_log_run.sql`:

```sql
{# Append one row to gold.etl_run_log at the end of every dbt run or build. #}
{% macro hnh_log_run(results) %}
  {% if execute and flags.WHICH in ('run', 'build') %}
    {% set failed = results | selectattr('status', 'in', ['error', 'fail']) | list | length %}
    {% set built = results | selectattr('node.resource_type', 'equalto', 'model') | selectattr('status', 'equalto', 'success') | list | length %}
    {% set create_sql %}
      create table if not exists gold.etl_run_log (
          invocation_id String,
          run_started_at DateTime('Asia/Riyadh'),
          run_finished_at DateTime('Asia/Riyadh'),
          status LowCardinality(String),
          models_built UInt32,
          nodes_failed UInt32,
          selected String
      ) engine = MergeTree order by run_started_at
    {% endset %}
    {% do run_query(create_sql) %}
    {% set insert_sql %}
      insert into gold.etl_run_log values (
          '{{ invocation_id }}',
          toDateTime('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}', 'UTC'),
          now('Asia/Riyadh'),
          '{{ "failed" if failed > 0 else "success" }}',
          {{ built }},
          {{ failed }},
          '{{ (invocation_args_dict.get("select") or []) | join(" ") | replace("'", "") }}'
      )
    {% endset %}
    {% do run_query(insert_sql) %}
  {% endif %}
{% endmacro %}
```

Add to the end of `hnh_dwh/dbt_project.yml`:

```yaml
on-run-end:
  - "{{ hnh_log_run(results) }}"
```

Add to `docs/receiving_project_config.md`, as a new section before "Running":

````markdown
## Run log

Add this to the receiving `dbt_project.yml` so every run appends a row to `gold.etl_run_log`. SSAS processing should start only when the latest row has `status = 'success'`.

```yaml
on-run-end:
  - "{{ hnh_log_run(results) }}"
```
````

- [ ] **Step 5: Build the reconciliation model**

Run: `python scripts/run_dbt.py build --select rec_patient_flow_monthly`
Expected: 1 table created, all tests pass.

Run: `python scripts/run_dbt.py show --inline "select status, models_built, nodes_failed, selected from gold.etl_run_log order by run_finished_at desc limit 1"`
Expected: one row with `status` = `success` and `selected` = `rec_patient_flow_monthly`.

- [ ] **Step 6: Review the differences for the latest closed month**

Run: `python scripts/run_dbt.py show --inline "select branch_key, census, legacy_census, census - legacy_census as census_diff, admissions, legacy_admissions, admissions - legacy_admissions as admission_diff, round(alos_non_ltc, 2) as alos, round(legacy_alos_non_ltc, 2) as legacy_alos, round(100 * occupancy_rate, 1) as occupancy_pct from {{ ref('rec_patient_flow_monthly') }} where month_start = toStartOfMonth(today() - toIntervalMonth(1)) order by branch_key" --limit 10`
Expected: eight rows. `census_diff` is small and explained by the cancellation rule; `admission_diff` is positive where admissions had their last bed in an excluded ward. Copy this output into `docs/reconciliation_phase1.md` in the next step.

- [ ] **Step 7: Write the reconciliation guide**

`docs/reconciliation_phase1.md`:

````markdown
# Phase 1 reconciliation

`gold.rec_patient_flow_monthly` holds, per branch and month, each KPI under the new rules beside the value the old warehouse rules give on the same data.

## How to compare with the old warehouse

1. Pick a closed month with the business.
2. On the old server, export that month from `bsc.vw_customer` (`census`, `op_census`, `er_census`, `admissions`, `discharges`, `alos_non_ltc`, `op_waiting_time_in_minutes`) and `bsc.vw_hospital_beds_utilization` (`occupancy_rate`).
3. Compare each exported value with the matching `legacy_*` column:

| Old view column | Compare with |
|---|---|
| `census` | `legacy_census` |
| `op_census` | `legacy_op_census` |
| `er_census` | `legacy_er_census` |
| `admissions` | `legacy_admissions` |
| `discharges` | `legacy_discharges` |
| `alos_non_ltc` | `legacy_alos_non_ltc` |
| `op_waiting_time_in_minutes` | `legacy_wait_minutes_sum` |

4. Acceptance: every legacy value is within 0.5% of the old view. A larger gap means the data differs, not the rule, and must be explained before sign-off.

## Why the new values differ from the legacy values

| KPI | Reason |
|---|---|
| Census, OP visits, ER visits | Cancellation uses the outcome group. The old list (93, 94, 106, 107) missed "rescheduled by hospital" (108) and included 106, which is not an outcome. |
| Admissions, discharges | A stay is excluded when it is closed and shorter than one hour, or its outcome is "Wrong admission". The old rule used one hour or less measured to the current time, and dropped stays whose last bed was in an excluded ward. |
| ALOS | Closed stays only, measured to discharge. LTC is fixed at discharge. |
| Occupancy | Daily bed state. The old value divided by today's bed count for every month and lost one night per month; it has no legacy column because it cannot be reproduced from history. |
| Waiting time | Reported as average and median. `legacy_wait_minutes_sum` is the old sum of minutes. |

## Known limits

- `prior_encounters_4m` and "returning patients" are understated for January to April 2022, because encounters before 2022 are not in staging.
- `legacy_care_type` and `legacy_purchaser_code` are approximate. The old values were picked arbitrarily by `any()`, so they are excluded from the 0.5% threshold.
- Bed availability before a bed's first recorded row is unknown; the bed is treated as not existing until then.

## Latest closed month at build time

Paste the output of Step 6 here.
````

Replace the last line with the actual output table from Step 6.

- [ ] **Step 8: Run the whole project**

Run: `python scripts/run_dbt.py build --select tag:hnh`
Expected: every model in Phases 1A and 1B builds, every unit test passes, `ERROR=0`. Warnings come only from tests named `warn_*`.

Run: `python scripts/run_dbt.py source freshness --select source:oasis`
Expected: every transactional table reports `PASS` (or `WARN` if staging has not loaded for more than 30 hours).

- [ ] **Step 9: Commit**

```bash
git add hnh_dwh/models/hnh/marts/reconciliation hnh_dwh/macros/hnh/hnh_log_run.sql hnh_dwh/dbt_project.yml docs/reconciliation_phase1.md docs/receiving_project_config.md
git commit -m "Add monthly reconciliation, run log and Phase 1 reconciliation guide

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```
