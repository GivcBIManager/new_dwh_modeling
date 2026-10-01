# HNH Data Warehouse — Gold Layer Design

- **Date:** 2026-10-01
- **Status:** Draft for review
- **Scope of this spec:** overall architecture for all domains, plus the detailed design of **Phase 1 — Foundation and Patient Flow**. Phases 2–6 are outlined only; each gets its own spec.
- **Visual blueprint:** https://claude.ai/artifact/QYzkCrNM1NwKzcLPKiAciE

---

## 1. Purpose

Build a dbt-managed golden layer on ClickHouse over three staging databases — `oasis` (HIS), `fusion` (Oracle Fusion HCM, Finance, SCM) and `press_ganey` (patient surveys) — for a hospital group with eight branches in Saudi Arabia. The layer feeds one on-prem SSAS Tabular model (Import mode) that Power BI connects to live, for management scorecards and staff self-service.

### Success criteria

1. One definition per KPI, implemented in dbt, consumed unchanged by SSAS.
2. Phase 1 reproduces the patient-flow content of the existing *Executive Dashboard* and *Outpatient Dashboard* Power BI models.
3. Every number that differs from the old warehouse is explainable: a `legacy_*` field reproduces the old rule, so the difference is provably the rule and not the data.
4. Branch-level and specialty-level row security supplied by the warehouse and failing closed.
5. A full nightly build with tests, orchestrated by Dagster, that leaves yesterday's SSAS model in place if any test fails.

### Non-goals

- No change to the ingestion that fills `oasis`, `fusion` or `press_ganey`.
- No SSAS or Power BI artefacts in Phase 1 beyond a documented handoff contract (section 12).
- No real-time or intra-day refresh.
- No master patient index. A best-effort `person_key` is provided; identity resolution is out of scope.

---

## 2. Context

### 2.1 Sources (measured 2026-10-01, ClickHouse 26.5, single node, server timezone Asia/Riyadh)

| Database | Tables | Rows | Shape |
|---|---|---|---|
| `oasis` | 97 | 1.28B (71 GB) | Near-raw copies of HIS tables. Every table has `branch_id`, `insert_at`, `recorded_updated_at`, `merge_hash`. `ReplacingMergeTree(recorded_updated_at)`, partitioned by `branch_id`. |
| `fusion` | 110 | 32M | Already `dim_` / `fact_` / `bridge_`. SCD2 dimensions (`valid_from`, `valid_to`, `is_current`). `ReplacingMergeTree(last_update_date)`. |
| `press_ganey` | 4 tables, 4 views | 695K responses | Answers stored as a JSON string in `responses`; question and answer-option masters alongside. |
| `default` | 6 | small | `branch_dict_source`, `map_unified_department`, `map_purchasers`, `map_product_category`, `map_referral_policies`, `date_dim`. |

### 2.2 Branches

`default.branch_dict_source` is the cross-system crosswalk and the backbone of the conformed model.

| branch_id | Name | City | Beds | Fusion branch segment | Fusion ledger id | Press Ganey code |
|---|---|---|---|---|---|---|
| 1 | Alrabwah | Riyadh | 310 | 102 | 300000005003378 | hnhr |
| 2 | Khamis | Aseer | 200 | 107 | 300000005003393 | hnhk |
| 3 | Jazan | Jazan | 120 | 105 | 300000005003387 | hnhj |
| 4 | Unaizah | Qassem | 250 | 106 | 300000005003390 | hnhu |
| 5 | Madinah | Madinah | 220 | 108 | 300000005003396 | hnhm |
| 6 | Abha | Aseer | 100 | 104 | 300000005003384 | hnha |
| 7 | Ghirnata | Riyadh | 100 | 103 | 300000005003381 | hnhg |
| 8 | Muhayil | Aseer | 100 | 109 | 300000010716720 | hnhmuhayil |

### 2.3 Facts about the data that shape the design

| # | Fact | Consequence |
|---|---|---|
| F1 | Source tables hold unmerged duplicates. De-duplicated counts: `patient_ad` 531,549 of 1,061,837 raw; `bed_details` 1,770,059 of 3,540,138; `patient_master_data` 3,543,516 of 4,709,827; `staff_master_data` 23,506 of 41,224. | Staging must return the latest version per key. |
| F2 | Oasis ids are typed `Nullable(Float64)` on one table and `Decimal(38,0)` on another. Joins between them fail with `NO_COMMON_TYPE`. | Staging casts every id to `Int64`. |
| F3 | Oasis timestamps are typed `DateTime64(6,'UTC')` but hold KSA wall-clock time (outpatient arrivals as stored peak at 08–11 and 16–20). | Staging re-labels, never converts. |
| F4 | Branch is not a source column; it was stamped at extract. No source join includes it. | Every Oasis key and join is `(branch_id, …)`. |
| F5 | `appointments` has 372M rows; about 4.9M (1.3%) have a patient. The rest are empty slots. | Booked rows feed the encounter fact; all rows feed a capacity aggregate. |
| F6 | `patient_episodes.admitted_flag` and `emergency_flag` are never set. | Care type comes from `patient_eligibility.attendance_type` (O, E, I, D). |
| F7 | History windows differ: `patient_episodes`, `appointments`, ER from 2022-01-01 (ER later for branches 6–8); `patient_eligibility` from 2012; `patient_ad` from 2008. | Facts start at 2022-01-01. Older admissions and eligibility rows are used only for look-back flags. |
| F8 | `codes_data` codes 93, 94, 107, 108 (code type 21) mean the same in all 8 branches. Custom codes differ per branch (three different codes for "DNA"). Code 106 is "OPD CLINIC TEAM", code type 24 — not an outcome. | Outcome grouping is by description through a seed, not by hard-coded code lists. |
| F9 | In branches 6–8, about 0.25% of `codes_data.code` values repeat across code types. | Decode lookups specify `code_type` wherever the type is known. |
| F10 | `patient_eligibility` has 10,009,298 rows with responsibility 1 for 9,962,301 episodes. | Picking the primary eligibility row needs a deterministic tie-break. |
| F11 | The latest source row is about three hours behind the load time on every table checked. | Observation only; does not affect a nightly build. Listed in open items. |

### 2.4 Inputs reviewed

- 75 Oracle extract scripts (join keys, decodes, source quirks).
- 94 views from the old warehouse (current KPI logic).
- 5 Power BI models as TMDL (measures, relationships, RLS).
- 11 exported mapping files in `static_mappings/`.

### 2.5 Tooling

Python 3.13.6, dbt-core 1.11.12, dbt-clickhouse 1.9.8, Dagster 1.13.23 are installed on the build machine. The workspace `D:\new_dwh_modeling` is not yet a git repository.

---

## 3. Architecture

### 3.1 Layers

| Layer | ClickHouse database | Materialization | Responsibility |
|---|---|---|---|
| sources | `oasis`, `fusion`, `press_ganey`, `default` | — | Declared in dbt with freshness checks. |
| staging | `stg` | view | One model per source table. Latest version per key, type casts, timestamp re-labelling, renames, removal of credential columns. No joins, no status filters, no calculations. |
| intermediate | `int` | table | Derivations reused by more than one mart, each built once. Not exposed to SSAS. |
| marts | `gold` | table | Kimball stars: `dim_*`, `fact_*`, `agg_*`, `sec_*`. The only layer SSAS reads. |
| seeds | `gold` | seed | Small hand-maintained mappings. |

**Rule:** a `gold` model never selects from a source or from `stg` directly if an `int` model exists for that entity; an `int` model never selects from a source.

### 3.2 Build policy

- `gold` and `int` are rebuilt in full every night.
- Two models are incremental: `agg_clinic_capacity_daily` (372M input rows) in Phase 1, and `fact_charge_line` in Phase 2. Strategy: `delete+insert` keyed on `(branch_key, date_key)` for every date that has a source row with `recorded_updated_at` later than the previous run's watermark. A `--full-refresh` must produce the same result.
- All fact tables honour `var('history_start_date')`, default `2022-01-01`.

### 3.3 Keys

- **Natural keys** are always `(branch_id, source_id…)`.
- **Surrogate keys** are deterministic `Int64`: `toInt64(cityHash64(branch_id, id…) >> 1)`, produced by one macro `surrogate_key(columns)`. No lookup tables, safe for incremental models, positive values for SSAS.
- `branch_key` is `branch_id` (1–8); `0` is the group-level member.
- `date_key` is `Int32` in `yyyymmdd` form. `time_key` is `Int16` minute of day (0–1439).
- Every dimension has an Unknown member with key `-1`. Fact foreign keys are never null: a missing reference maps to `-1`.

### 3.4 Staging conventions

- **Latest version:** `SELECT … FROM {{ source(...) }} FINAL`. The version column is `recorded_updated_at` (Oasis), `last_update_date` (Fusion) or `_fetched_at` (Press Ganey).
- **Ids:** `toInt64(x)`; zero is treated as null for optional references (`nullIf(toInt64(x), 0)`).
- **Timestamps:** `DateTime64(6,'UTC')` columns are re-labelled to naive `DateTime` holding the same wall-clock value. One macro, `ksa_wall_clock(column)`.
- **Julian day** (`appointments.julian_date`): `toDate('1970-01-01') + (julian_date - 2440588)`.
- **Flags:** `Y`/`N` strings become `UInt8`.
- **Excluded columns:** `maps006.password`, `maps006.lexacom_password`, `maps006.initial_pass`, `patient_master_data.portal_password`, `portal_verification_code`, `call_center_otp`, `portal_mobile_token`.
- **Names:** `stg_<system>__<table>`, snake_case columns, source typos corrected in the alias (`hight` → `height`).

### 3.5 Project layout

```
hnh_dwh/
  dbt_project.yml
  profiles.yml.example
  macros/            surrogate_key, ksa_wall_clock, julian_to_date, decode, unknown_member
  seeds/             mapping CSVs + schema.yml
  models/
    staging/
      oasis/         _oasis__sources.yml, stg_oasis__*.sql
      fusion/        (Phase 3+)
      press_ganey/   (Phase 6)
      mapping/       _mapping__sources.yml, stg_mapping__*.sql
    intermediate/
      core/          int_code_decode, int_department_conformed
      patient_flow/  int_episode, int_encounter, int_bed_segment, int_bed_day
    marts/
      conformed/     dim_*, sec_user_access
      patient_flow/  fact_*, agg_*
      reconciliation/ rec_*
  tests/             singular tests
  orchestration/     Dagster project (dagster-dbt)
  docs/
```

---

## 4. Seeds and static sources

| Name | From | Rows | Used by |
|---|---|---|---|
| `seed_branch` | `default.branch_dict_source` | 8 (+ group row) | `dim_branch` |
| `seed_unified_department` | `static_mappings/master_unified_department.csv` | 192 | `dim_department`, `dim_staff` (unified specialty, `not_admitting`, `high_value`) |
| `seed_bed_classification` | `static_mappings/bed_mapping.csv` | 5,053 | `dim_bed` |
| `seed_ward_tower` | `static_mappings/m_wards.csv` | 82 | `dim_department`. Complete: only branches 1 and 4 have two towers. |
| `seed_clinic_duration` | `static_mappings/clinic_duration_mapping.csv` | 108 | `agg_clinic_capacity_daily` (legacy capacity) |
| `seed_clinic_count` | `static_mappings/clinics_mapping.csv` | 7 | `dim_branch` |
| `seed_home_care_entity` | `static_mappings/home_care_entities.csv` | 9 | `dim_department` |
| `seed_termination_reason` | `static_mappings/termination_reason_mapping.csv` | 82 | `dim_staff` |
| `seed_claim_status` | `static_mappings/claim_status_mapping.csv` | 14 | Phase 2 |
| `seed_outcome_group` | new, authored in Phase 1 | ~60 | Maps an outcome description to a group-level label and flags (section 6.3) |
| `seed_entity_type` | new | 17 | Work-entity type letter → label and care setting |
| `seed_hijri_calendar` | generated | one row per day | `dim_date`. Produced by a checked-in script from the Umm al-Qura calendar (Python `hijridate`), covering the `dim_date` range. |
| `seed_public_holiday` | new | small | `dim_date`. Saudi official holidays; Eid dates derived from the Hijri calendar, fixed-date holidays listed. Reviewed yearly against the official announcement. |

Tables that stay in ClickHouse and are declared as sources (database `default`): `map_purchasers`, `map_referral_policies`, `map_product_category`, plus two to be loaded:

- **`default.budget_data`** — 2,166,331 rows (daily targets for 2026, three scenarios). Too large for a seed. Loaded once from `static_mappings/budget_data.csv` as part of Phase 1; later versions are maintained by the BI manager directly in the table.
- **`default.bi_users`** — loaded **without** the `Password` column. The exported `static_mappings/_BI_USERS_.csv` contains password values and must not be committed to the repository.

---

## 5. Conformed dimensions

All in `gold`. Columns listed are the business attributes; every dimension also has its surrogate key, its natural key columns and the Unknown member.

### dim_branch
Key `branch_key`. Name, city, region, licensed beds, clinic count, Fusion branch segment, Fusion ledger id, Press Ganey code, first data date. Row `0` = Group.

### dim_date
Key `date_key`. Gregorian attributes, ISO week, fiscal period (fiscal year equals calendar year), Hijri year, month and day on the Umm al-Qura calendar, Saudi public holiday flag and name (Founding Day, National Day, Eid al-Fitr, Eid al-Adha), weekend flag (Friday and Saturday), **clinic working day** flag (Friday closed — the rule the capacity measures use), relative offsets (day, month, quarter, year) from the build date. Range: 2008-01-01 to the end of the year after the build date.

### dim_time
Key `time_key` (minute of day). Hour, quarter-hour, shift: `00:00–08:00`, `08:00–12:00`, `12:00–16:30`, `16:30–24:00`.

### dim_patient
Key `(branch_id, patient_id)`. MRN (lowest `patient_file_master.user_file_id`), gender, date of birth, nationality and Saudi flag (codes type 5, left join), marital status (type 2), occupation (type 4), registration date, registering department, patient category, status, chronic, at-risk and VIP flags, `person_key` and `person_key_source`. **No names, identifiers or contact details.**

`person_key` identifies the same person across branches. It is the hash of the first identifier present, in this order: national id or iqama, passport number, border number. Each is trimmed, upper-cased, stripped of spaces and leading zeros, and prefixed with its type so a passport can never collide with a national id. These identifiers are mandatory and validated in the HIS, so the key is treated as reliable. A patient with none of them gets a key derived from `(branch_id, patient_id)`, so every patient has a non-null `person_key`.

### dim_patient_pii
Same key. Names in English and Arabic, national id, iqama, passport, mobile, email. Exposed only to a restricted SSAS role.

### dim_staff
Key `(branch_id, staff_id)`. Name EN and AR, gender, nationality and Saudi flag, staff grade (`staff_types_data`), classification, category and medical flag (`staff_type_classification`), position and home work entity (latest `staff_posts` by `date_started`, tie-break highest `posts_id`), specialty (first non-empty of: doctor list department, service department of the home work entity, work entity description), unified specialty with `not_admitting` and `high_value` (seed), SCFHS licence number, clinic duration and slots per hour (seed), contract status (`Active` / `Terminated` / `No contract`), termination date and unified reason. Role-plays as consultant, treating doctor, surgeon and anaesthetist.

### dim_department
Key `(branch_id, work_entity)`. Description, short name, entity type and label, care setting (`OP`, `IP`, `ER`, `Theatre`, `Ancillary`, `Support`), service department code and description, department type, unified department, cost centre (`gl_section_code` → `control_contexts_data.heading`), tower (`OLD` / `NEW` from the seed for branches 1 and 4, the only branches with two towers; `Main` for all others), maximum beds, flags: `is_excluded_ward` (description contains `NURS`, `BOOKING` or `PRE OP`), `is_home_care`, `is_virtual_clinic`.

### dim_payer
Key `(branch_id, purchaser_code)`. Description, account code, company, creditor, category, billing type, manual-submission flag (from `map_purchasers`), purchaser type (`CASH POLICY` when listed as a cash purchaser; `INSURANCE` when the account code starts with `INS` or the description contains `GOSI`; else `NOT INSURANCE`), TPA flag, CCHI and NPHIES licence, MOH flag (`creditor = 'Government'` in the purchaser mapping, which is the single source for MOH classification in every branch; the old per-branch MOH account list is not used). Synthetic members for every branch: `9999` Cash and `8888` Deductible. Unmapped values read `Not Mapped`.

### dim_care_type
Static. `OP`, `ER`, `IP`, `DAYCASE`, `Unknown`. Source mapping: `O` → OP, `E` → ER, `I` → IP, `D` → DAYCASE, anything else → Unknown.

### dim_bed
Key `(branch_id, work_entity, bed_location)`. Ward, room, bed number, bed class, room class, bed gender, classification from the seed (`Critical`, `Intermediate Care`, `Non Critical`, `Non-Admitting Unit`, else `Not Mapped`), `is_critical`, current status, `is_currently_available`.

### dim_eligibility_type
Key `(branch_id, eligibility_type)`. Description, attendance type, free follow-up days.

### Decode dimensions
`dim_appointment_outcome`, `dim_discharge_outcome`, `dim_admission_source`, `dim_er_priority`, `dim_procedure_type`. Each: branch-level code and description, plus the group-level label and flags from `seed_outcome_group`.

### sec_user_access
One row per user and permitted branch. Columns: `user_name`, `login_name`, `branch_key`, `unified_specialty` (nullable — no restriction), `is_admin`. Users are local accounts on the SSAS server, so `login_name` is the SSAS machine name (`var('ssas_machine_name')`), a backslash, then `user_name` — the value SSAS `USERNAME()` returns. An admin has one row per branch. A source row with no branch and `is_admin = 0` produces **no** access row. See section 9.

---

## 6. Intermediate models

### 6.1 int_code_decode
Grain `(branch_id, code_type, code)`. Description (trimmed), Arabic description, `prog_code`, `user_code`, MOH code (from the two HNH mapping tables matched on description). Macro `decode(code_column, code_type)` joins on all three columns; a variant without `code_type` is allowed only where the type is unknown, and takes the lowest `code_type`.

### 6.2 int_episode
Grain `(branch_id, patient_id, episode_no)`. Spine: `patient_episodes` from `history_start_date`.

- **Primary eligibility row:** `patient_eligibility` with `responsibility = 1`; if several, lowest `sequence`, then lowest `patient_eligibility_id`. Supplies `care_type`, consultant, eligibility service department, work entity (`coalesce(eligibility_work_entity, work_entity)`).
- **Payer:** `patient_bill_agreements` with `coalesce(status,'I') = 'I'`; lowest `responsibility_seq`, then lowest `contract_no`. Null or zero purchaser → `9999`.
- **`episode_seq`:** rank of `episode_no` within `(branch_id, patient_id)` over the full eligibility history (back to 2012), so `is_first_episode` is correct for patients first seen before 2022.
- **`previous_care_type`:** care type of the episode with the next-lower `episode_no`; null for the first episode.
- **`legacy_care_type`, `legacy_purchaser_code`:** the old `any()` picks cannot be reproduced exactly because they were non-deterministic; these fields hold the value from the *first row in source order* and are documented as approximate.

### 6.3 int_encounter
Grain: one encounter. `encounter_type` ∈ `OP`, `ER`, `IP`. Natural key `(branch_id, encounter_type, source_id)` where `source_id` is `appointment_id`, `er_visit_id` or `admission_no`.

| Column | OP (appointments, `patient_id > 0`) | ER (`patient_emergency_visit`) | IP (`patient_ad`) |
|---|---|---|---|
| encounter timestamp | `start_date` | `time_arrived` | `admit_date` |
| department | `work_entity` | `work_entity` | work entity of the first non-excluded bed |
| booked doctor | `consultant` | episode consultant | request consultant, else episode consultant |
| treating doctor | `treated_by` | `treated_by` | `treated_by` |
| `is_arrived` | `time_arrived` not null | 1 | 1 |
| `is_seen` | `time_seen` not null | `time_treatment_started` not null | 1 |
| `wait_minutes` | `time_arrived` → `time_seen` | `time_arrived` → `time_treatment_started` | null |
| `door_to_triage_minutes` | null | `time_arrived` → `time_triaged` | null |
| `service_minutes` | `time_seen` → `time_complete` | `time_treatment_started` → `time_complete` | null |

Rules:

- **Outcome group** (from `seed_outcome_group`, matched on the upper-cased trimmed description of code type 21): `Attended`, `Cancelled`, `Rescheduled`, `No-show recorded`, `Left without being seen`, `Admitted`, `Referred`, `Other`.
- **`is_cancelled`** = outcome group is `Cancelled` or `Rescheduled` (codes 93, 107, 94, 108).
- **`is_no_show`** (OP only) = not walk-in, not cancelled, not arrived, appointment date before the build date, and no other arrived OP or ER encounter for the same patient in the same branch on the same day.
- **`is_walk_in`** = `walkin_flag = 'Y'`. **`is_follow_up`** = `new_followup_flag = 'F'`. **`is_virtual`**, **`is_online_booking`** from their flags.
- **`visit_type`** = `New patient` when the episode is the patient's first; else `Free follow-up` when `is_follow_up`; else `Paid visit`.
- **`prior_encounters_4m`** = count of the patient's arrived, non-cancelled OP and ER encounters in the previous one to four calendar months, same branch. `is_returning` = that count > 0.
- **Duration guard:** a duration below 0 or above 1,440 minutes is set to null and the raw value kept in `*_minutes_raw`.
- **Care type** comes from `int_episode`; when the episode is missing, OP and ER rows take their `encounter_type`.
- **Legacy flags:** `legacy_in_op_census` = `patient_id != 0 AND episode_no != 0 AND coalesce(outcome_code,500) NOT IN (93,94,106,107)`; `legacy_is_cancelled_outpatient_model` = `outcome_code IN (93,94,107,108)`.

### 6.4 int_bed_segment
Grain: one `bed_detail_id` with `admission_no > 0` and a non-empty `bed_location`. Start, end (`end_date`, or null when open), ward, room, bed, bed class, classification, `is_excluded_ward`, `segment_seq` and `segment_seq_desc` within the admission (ordered by `start_date`, then `bed_detail_id`). Segments in excluded wards are kept and flagged; they are ignored when choosing first and last ward.

### 6.5 int_bed_day
Grain: `(branch_id, work_entity, bed_location, date)` from `history_start_date` to the build date. A bed is **occupied** on a date if a non-excluded segment covers 23:59:59 of that date (midnight census). A bed is **available** on a date if it existed and its status on that date was not `NO BED IN SLOT` or `NOT AVAILABLE`. Availability history comes from `bed_details` status rows; where no status history exists before a bed's first row, the bed is treated as not yet existing.

### 6.6 int_department_conformed
Grain `(branch_id, work_entity)`. Joins work entity → service department → unified department seed, cost centre, tower seed, entity-type seed, home-care seed.

---

## 7. Phase 1 facts

All facts carry `branch_key`, the relevant `date_key`s and `_loaded_at`. Table engine `MergeTree`, `ORDER BY (branch_key, <primary date_key>, <grain key>)`.

### 7.1 fact_encounter
Grain: one row of `int_encounter` from `history_start_date`.
Keys: encounter, episode, patient, booked staff, treating staff, department, payer, care type, eligibility type, outcome; `encounter_date_key`, `arrival_date_key`, `arrival_time_key`, `booking_date_key`.
Attributes: `encounter_type`, `visit_type`, all flags of 6.3, `booked_from` channel.
Measures: `wait_minutes`, `door_to_triage_minutes`, `service_minutes`, `booking_lead_days`, `prior_encounters_4m`, and the legacy fields `legacy_in_op_census`, `legacy_is_cancelled_outpatient_model`.

### 7.2 fact_admission
Grain: one `(branch_id, admission_no)` with an admit date on or after `history_start_date`, or still open at that date.
Keys: admission, encounter, episode, patient, consultant, treating staff, first ward, last ward, discharging ward, bed (last), payer, care type, admission source, discharge outcome; `admit_date_key`, `admit_time_key`, `clinical_discharge_date_key`, `physical_discharge_date_key`, `financial_discharge_date_key`.
Attributes and measures:

| Field | Rule |
|---|---|
| `los_hours`, `los_days` | `admit_date` → `physical_discharge_date`; `los_days = los_hours / 24`. Null while open. |
| `los_days_to_date` | For open stays, to the build timestamp. Separate column so closed-stay averages never drift. |
| `is_open` | `physical_discharge_date` is null. |
| `is_short_stay` | Closed and `los_hours < 1`. Excluded from admission counts. |
| `is_wrong_admission_outcome` | Discharge outcome group `Wrong admission` (program code 9). Excluded from admission counts. |
| `is_countable` | Not short stay, not wrong-admission outcome. The default filter for every admission KPI. |
| `is_ltc` | `los_days > 30` at discharge, or referred type `LTC`. For open stays, `is_ltc_to_date` holds the running value. |
| `admission_source` | `OP` when the request's admission department decodes to `OUTPATIENT CLINICS` or `OPD`; `ER` for `ACCIDENT & EMERGENCY` or `ER`; otherwise the previous episode's care type when it is OP or ER; else `Direct`. Case-insensitive. |
| `admission_request_*` | From the earliest `admission_request` for the admission (lowest `admission_request_id`): planned date, urgency, admission type, reason. |
| `critical_bed_hours`, `had_critical_bed`, `first_critical_at`, `last_critical_left_at` | From `int_bed_segment` where classification is `Critical`. |
| `days_since_previous_discharge` | Days from the patient's previous countable stay's physical discharge to this admit, same branch. Look-back uses all history. |
| `is_readmission_30d` | `days_since_previous_discharge` between 0 and 30. |
| `is_icu_readmission_48h` | This stay's `first_critical_at` is within 48 hours after the previous stay's `last_critical_left_at`. |
| `is_died`, `is_dama` | From the discharge outcome group. |
| `legacy_is_wrong_admission` | `dateDiff('hour', admit, coalesce(physical_discharge, build_ts)) <= 1`. |
| `legacy_is_ltc` | `legacy_los > 30 OR referred_type = 'LTC'`, with `legacy_los` measured to the build timestamp. |
| `legacy_days_since_previous_admission` | Admit date to previous admit date. |
| `legacy_in_vw_inpatients` | Last bed (by id) exists, has a location, and is not in an excluded ward. |

### 7.3 fact_episode
Grain: one row of `int_episode`.
Keys: episode, patient, consultant, department, payer, care type, eligibility type; `start_date_key`, `end_date_key`.
Attributes and measures: `episode_seq`, `is_first_episode`, `previous_care_type`, policy code, contract number, referral-policy flag (`map_referral_policies`), counts of OP, ER and IP encounters, `has_arrived_non_follow_up_encounter` (the episode-count filter).

### 7.4 fact_bed_occupancy_daily
Grain: one row of `int_bed_day`.
Keys: bed, department (ward), date, and when occupied: admission, patient.
Measures: `is_available`, `is_occupied`, `is_excluded_ward`. Occupancy = `sum(is_occupied) / sum(is_available)` over any slice.
Legacy: `legacy_current_available_beds` on `dim_branch` holds today's available-bed count, for reproducing the old occupancy denominator.

### 7.5 agg_clinic_capacity_daily
Grain: `(branch_id, slot_date, work_entity, consultant)` over **all** appointment rows.
Measures: `slots_total`, `slots_booked`, `slots_attended`, `slots_no_show`, `slots_cancelled_by_hospital`, `slots_cancelled_by_patient`, `slots_rescheduled`, `slots_walk_in`, `scheduled_minutes` (sum of `appt_length`), `break_slots`. `legacy_capacity_slots` = clinic duration × slots per hour from the seed, for a doctor-day with at least one arrived appointment.
Incremental (section 3.2).

### 7.6 fact_surgery
Grain: one `(branch_id, operating_slot_code, operation_seq)` — `operating_slot_details` joined to `operating_diary_slots` with `patient_id > 0`.
Keys: episode, patient, theatre (department), surgeon, anaesthetist, payer, care type, procedure (`ios_main`), procedure type; `operation_date_key`, `operation_time_key`.
Attributes: procedure type (`Cesarean` when the procedure description contains `C.S `, `C.S.`, `CESARIAN` or `CESAREAN`; else by theatre entity type — `J` Cath Lab, `F` Endoscopy, `Z` L&D; else `Surgery`), operation type, anaesthesia type, status, `is_cancelled`, cancel reason.
Measures (minutes, with the duration guard): hall to theatre, anaesthesia, operating, recovery handover.

### 7.7 fact_target_daily
Grain: `(branch, date, scenario, care type, stay type, creditor, specialty)` from `default.budget_data` where `is_last_value = 1`.
Keys: branch, date, care type, department (matched on unified specialty; unmatched → Unknown). Creditor is kept as an attribute and matched to `dim_payer.creditor` in SSAS measures.
Measures: target census, episodes, revenue, cost per episode, ALOS.

---

## 8. KPI definitions

Defined once here; SSAS measures are thin aggregations over these fields.

| KPI | Definition | Fact |
|---|---|---|
| OP visits | Distinct encounters, `encounter_type = 'OP'`, arrived, not cancelled | `fact_encounter` |
| ER visits | Distinct encounters, `encounter_type = 'ER'`, not cancelled | `fact_encounter` |
| Census | OP visits + ER visits | `fact_encounter` |
| Episodes | Distinct episodes with `has_arrived_non_follow_up_encounter` | `fact_episode` |
| Unique patients | Distinct `patient_key` (or `person_key` group-wide) among arrived, non-cancelled encounters | `fact_encounter` |
| New patients | Arrived encounters with `visit_type = 'New patient'` | `fact_encounter` |
| Returning patients | Distinct patients with `is_returning` | `fact_encounter` |
| Waiting time | Average and median of `wait_minutes`, arrived and not cancelled | `fact_encounter` |
| No-show rate | `is_no_show` ÷ booked non-walk-in, non-cancelled appointments | `fact_encounter` |
| Cancellation rate | `is_cancelled` ÷ booked appointments | `fact_encounter` |
| Admissions | Distinct admissions, `is_countable`, by admit date | `fact_admission` |
| Discharges | Distinct admissions, `is_countable`, by physical discharge date | `fact_admission` |
| Conversion rate | Countable admissions with source OP or ER ÷ episodes of care type OP or ER whose consultant's specialty is admitting | `fact_admission`, `fact_episode` |
| ALOS | Average `los_days` of countable stays discharged in the period; split by `is_ltc` | `fact_admission` |
| Occupancy | `sum(is_occupied) ÷ sum(is_available)`, excluded wards removed | `fact_bed_occupancy_daily` |
| Bed turnover | Discharges ÷ average available beds | both |
| 30-day readmission rate | `is_readmission_30d` ÷ countable admissions | `fact_admission` |
| ICU readmission, 48 h | `is_icu_readmission_48h` | `fact_admission` |
| Clinic utilisation | `slots_attended ÷ slots_total` | `agg_clinic_capacity_daily` |
| Theatre volume | Distinct non-cancelled operations | `fact_surgery` |

### Corrections relative to the old logic

Each row is a deliberate change; the named legacy field reproduces the old behaviour.

| Old behaviour | Correction | Legacy field |
|---|---|---|
| Census counts OP and ER together; daily report labels ER as OP | Care type is always explicit | `legacy_in_op_census` |
| Cancellation lists disagree; one includes code 106, which is not an outcome | One flag from the outcome group | `legacy_in_op_census`, `legacy_is_cancelled_outpatient_model` |
| Waiting time published as a sum | Average and median | — (sum available as a measure) |
| Wrong-admission threshold `<= 1 h` vs `< 1 h`; measured to `now()` | `is_short_stay` (`< 1 h`, closed stays) plus outcome-based flag | `legacy_is_wrong_admission` |
| LOS and LTC measured to `now()`; LTC re-tags history | Closed-stay values fixed; open-stay values in separate columns | `legacy_is_ltc` |
| Admission dropped when its last bed is in an excluded ward | Admission kept; ward segment flagged | `legacy_in_vw_inpatients` |
| Readmission measured between admit dates | Previous discharge to this admit | `legacy_days_since_previous_admission` |
| ICU readmission: `<= 2` calendar days, last ward name contains ICU or CCU | 48 hours, any `Critical` bed | — |
| Occupancy uses today's bed count for all months; a full month loses a night | Daily snapshot | `legacy_current_available_beds` |
| Episode care type, payer and consultant picked by `any()` | Deterministic ordering | `legacy_care_type`, `legacy_purchaser_code` (approximate) |
| "New patient" = `episode_no = 1`, or registration date in the report filter | Rank over full history | — |
| Missing care type classified as IP | `Unknown` | — |
| Clinic capacity hard-coded as 8 h × 4 slots | Actual scheduled slots | `legacy_capacity_slots` |

---

## 9. Security

- `gold.sec_user_access` is built from `default.bi_users`. The password column is never loaded.
- **Fail closed.** A user with no row sees no data. A non-admin source row without a branch grants nothing; it is reported by a test so the 88 such rows found today are assigned before go-live.
- One SSAS role filters `dim_branch` by the user's branches and `dim_staff` by the user's unified specialties when any are set. Every fact relates to `dim_branch`.
- Facts with no staff reference relate to the Unknown staff member, which every user may see, so a specialty restriction does not hide rows that have no doctor.
- `dim_patient_pii` is in a separate perspective and role.
- **User names** are local accounts created on the SSAS server by the BI manager. The role compares `USERNAME()` with `sec_user_access.login_name`. The machine name is a dbt variable, set once.

---

## 10. Testing and reconciliation

### 10.1 dbt tests (run in every build)
- `unique` and `not_null` on every dimension surrogate key and every fact grain key.
- `relationships` from every fact foreign key to its dimension.
- `accepted_values` on care type, encounter type, outcome groups, bed classification, visit type.
- Source freshness: warn at 30 hours, error at 54 hours on `recorded_updated_at`.
- Row-count conservation, as singular tests: `int_encounter` equals the sum of its three staged inputs; `fact_admission` equals de-duplicated `patient_ad` in the window; `fact_surgery` equals staged operations with a patient.
- Unmapped-value monitors (warn): bed classification `Not Mapped`, unified department `Not Mapped`, payer `Not Mapped`, outcome group `Other`, access rows without a branch.

### 10.2 dbt unit tests (rule-heavy models)
Fixtures with expected output for: outcome grouping and cancellation; no-show with and without a same-day arrival; duration guard; primary eligibility tie-break; payer tie-break; first-episode rank across the 2022 boundary; short stay; LTC at 30 and 31 days; readmission at 30 and 31 days; ICU readmission at 47 and 49 hours; midnight-census occupancy for a stay that crosses midnight; excluded-ward segment handling; procedure type.

### 10.3 Reconciliation (`gold.rec_*`)
- `rec_patient_flow_monthly`: per branch and month — legacy census, legacy OP census, ER census, admissions, discharges, ALOS non-LTC, occupancy — computed from the `legacy_*` fields, beside the new values.
- Acceptance for Phase 1: for a closed month chosen with the business, each legacy value matches the old `bsc.vw_customer` and `bsc.vw_hospital_beds_utilization` output exported from the old server within 0.5%, and every remaining difference is attributed to a listed correction. `legacy_care_type` and `legacy_purchaser_code` are excluded from this threshold because the old picks were non-deterministic.

---

## 11. Orchestration

- A Dagster project using `dagster-dbt` loads the dbt project as assets.
- One daily schedule after the staging loads complete: source freshness → `dbt build` → on success, trigger SSAS processing → write `gold.etl_run_log` (run id, start, end, status, row counts per model).
- On any test failure the run stops before SSAS processing; the previous SSAS data remains.
- Trigger time and the SSAS processing mechanism (TMSL via XMLA or SQL Agent job) are agreed with infrastructure before the orchestration task starts.

---

## 12. SSAS handoff contract

- SSAS reads only `gold.dim_*`, `gold.fact_*`, `gold.agg_*`, `gold.sec_user_access` and `gold.etl_run_log`, through the ClickHouse ODBC driver, by a dedicated read-only ClickHouse user.
- Relationships use single `Int64` (or `Int32` date, `Int16` time) columns. No string keys, no composite keys, no calculated columns for business rules.
- `dim_date` is marked as the date table; auto date/time is off. Role-playing dates are separate relationships or separate date views, decided in the SSAS design.
- Measures implement section 8 and nothing more.

---

## 13. Later phases (outline only)

| Phase | Domain | Main facts | Notes |
|---|---|---|---|
| 2 | Revenue cycle | `fact_charge_line`, `fact_invoice`, `fact_claim_line`, `fact_preauth_line` | Fix discount fan-out, deductible purchaser logic, "submitted" claims total, partial approvals without a reason code. The LTC ICU revenue split (old `icu_services` list) is dropped. |
| 3 | Finance | `fact_gl_journal_line`, `fact_gl_balance`, `fact_ap_invoice_line`, `fact_budget_monthly` | Fusion star is the source; branch via COA segment 1. A proposed `seed_fusion_department_unified` (Fusion department → unified department) is drafted in this phase for the BI manager to review. |
| 4 | Workforce | `fact_headcount_monthly`, `fact_payroll_cost`, `fact_absence`, `fact_worker_movement` | `dim_employee` linked to `dim_staff` by national id. |
| 5 | Supply chain | `fact_inventory_transaction`, `fact_inventory_onhand`, `fact_purchase_order_line` | |
| 6 | Patient experience | `fact_survey_response`, `fact_survey_answer` | Surveys must be analysable by doctor and clinic, so each response links to `fact_encounter` / `fact_episode`. See 13.1. |

### 13.1 Survey-to-encounter link (finding, 2026-10-01)

`pg_survey_responses.encounter_id` is a care-type letter followed by an Oasis id. Measured on surveys with a visit date in July–August 2026:

| Prefix | Links to | Match rate |
|---|---|---|
| `e` | `patient_emergency_visit.er_visit_id` | 99.6% (20,130 of 20,217) |
| `i` | `patient_ad.admission_no` | 100% (7,230 of 7,230) |
| `o` | `appointments.appointment_id` | 32% (46,725 of 145,479) |
| `o` | `delivery_charge.encounter_id` (1–14 August sample) | 85% (23,008 of 27,026) |

Resolution order for Phase 6: ER and inpatient by their own key; outpatient by `appointment_id`, else through `delivery_charge.encounter_id` to the episode, which supplies doctor and clinic. Unresolved outpatient surveys remain analysable by branch and service only. The outpatient id is the Oasis encounter id; ingesting the Oasis encounter table into `oasis` would let every outpatient survey link directly and is recommended before Phase 6.

---

## 14. Open items and assumptions

| # | Item | Needed before | Default if unresolved |
|---|---|---|---|
| O1 | A write-capable ClickHouse account for dbt and the one-off loads (creates `stg`, `int`, `gold`; writes `default.budget_data`, `default.bi_users`) | First build | Nothing can be built or loaded |
| O2 | 88 access rows have no branch | Go-live | Those users see nothing |
| O3 | Branch 8 has no budget rows and no clinic count | Scorecards for branch 8 | Targets and clinic count show as missing |
| O4 | Machine name of the SSAS server, for `ssas_machine_name` | SSAS role test | Variable left at a placeholder; the role cannot be tested |
| O5 | Join key between `bed_mapping.BED` and `bed_details` is assumed to be `bed_location` | `dim_bed` | Verified in the first implementation task; a mismatch surfaces as `Not Mapped` |
| O6 | Hard deletes in Oasis are not propagated to staging | — | Deleted source rows remain in the warehouse |
| O7 | About three hours of lag between the latest source row and the load time (F11) | — | None for a nightly build |
| O8 | Bed availability history before a bed's first status row is unknown | `fact_bed_occupancy_daily` | Bed treated as not existing before its first row |
| O9 | Trigger time and SSAS processing mechanism | Orchestration | Manual run |
| O10 | The Oasis encounter table is not ingested (section 13.1) | Phase 6 | About 15% of outpatient surveys link to branch and service only |

### Resolved on review (2026-10-01)

| Item | Decision |
|---|---|
| User-name format for SSAS security | Local users on the SSAS server; `login_name` is machine name, backslash, user name. |
| MOH account mapping missing for branches 7 and 8 | Not needed. MOH is classified through the purchaser mapping in all branches. |
| Ward tower seed covers branches 1 and 4 only | Correct as is; only those branches have two towers. Others report `Main`. |
| Budget file load and ownership | Loaded once in Phase 1. The BI manager maintains later versions. |
| Hijri calendar and public holidays | Umm al-Qura calendar generated by script from a reliable published implementation; holidays reviewed yearly. |
| Group-wide patient identity | Trusted. National id, iqama, passport and border number are mandatory and validated in the HIS; all are used for `person_key`. |
| Fusion department to unified department | A proposed mapping is drafted in Phase 3 for review. |
| Press Ganey link to Oasis | Required at doctor and clinic level. Feasibility confirmed (section 13.1). |
| ICU service list | Not needed. |

---

## 15. Decision log

| Decision | Chosen | Rejected |
|---|---|---|
| Layering | staging → intermediate → marts | Staging straight to marts (Oasis encounter logic would be duplicated per fact); Data Vault (overhead not justified for 8 branches, nightly) |
| First domain | Patient flow | Revenue cycle, Finance, thin slice across systems |
| Semantic layer | SSAS Tabular on-prem, Import | Power BI datasets, DirectQuery |
| Security source | Warehouse-supplied user access table | SSAS/AD groups only |
| Refresh | Nightly, Dagster | Intra-day; plain scheduler |
| Build policy | Full rebuild; two incremental models | Incremental everywhere |
| Surrogate keys | Deterministic hash | Sequence with lookup |
| Patient grain | Per branch, with `person_key` | Master patient index |
| ER | Own care type in one encounter fact | Folded into OP |
| ICU | `Critical` classification from the bed mapping, any segment | Ward-name pattern, last ward only |
| Legacy defects | Corrected, with `legacy_*` fields | Replicated as-is |
| Decode dimensions | One per code type, with group labels | One generic code dimension |
