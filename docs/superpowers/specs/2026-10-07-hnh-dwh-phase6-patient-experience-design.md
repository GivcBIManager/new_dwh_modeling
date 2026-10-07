# HNH Data Warehouse — Phase 6 Patient Experience: Press Ganey Surveys, NPS and Survey Quality

- **Date:** 2026-10-07
- **Status:** Draft for review
- **Parent specs:** `2026-10-01-hnh-dwh-gold-layer-design.md` (architecture, keys, conventions, security, portability; section 13.1 survey-to-encounter link). Everything in that spec applies unless this document says otherwise. Section 13 of the parent outlined this phase.
- **Source profile:** measured 2026-10-07 (read-only) on `press_ganey` and `gold`. The findings are summarised in section 2.

---

## 1. Purpose and decisions

The aim is one patient-experience model for the group. It answers three questions:
- how satisfied patients are, expressed as NPS, by domain, question, doctor, specialty, clinic, branch and service;
- how well the survey process works: who is invited, who answers, how completely and how quickly, and how many surveys can be traced to an encounter and a doctor;
- how results differ by the patient's own background answers (respondent, first visit, booking channel, services used).

Decisions made in review (2026-10-07):

| # | Decision |
|---|---|
| X1 | **NPS on the 1–5 recommend question.** Each service has one "likelihood of recommending" question (section 4.1). Promoter = 4–5, passive = 3, detractor = 1–2. NPS = % promoters − % detractors. Outpatient and telemedicine also have a physician NPS on `cp10`, and dental on `o1` (dentist). |
| X2 | **NPS-style scoring for every scored question.** Every scored answer is banded promoter / passive / detractor, and every level (question, domain, doctor, specialty, clinic, branch) reports NPS with the three percentages and the answer count. No mean-score measure is built; the raw score stays in the fact for traceability. |
| X3 | **Bands for the other scales.** Agree 1–5: 4–5 / 3 / 1–2. Definitely 1–4: promoter 3–4, detractor 1–2, no passive. 0–10: promoter 8–10, passive 5–7, detractor 0–4 (proportional, not classic NPS). |
| X4 | **Scored and not scored.** Questions are classified as Scored, Background or Routing from the Press Ganey question master. |
| X5 | **Background questions are dimensions.** The basic (background and routing) questions become conformed attributes on each survey, so every score can be sliced by them across services (section 4.2). All answers, scored or not, also stay in the answer fact. |
| X6 | **"Survey quality" means the survey process:** invitations, SMS reach, response rate, completion, answer completeness, days from visit to answer, encounter link rate and doctor attribution, by branch, service, clinic and doctor. |
| X7 | **Doctor and specialty come from the encounter.** Every survey links to `fact_encounter` and through it to the episode, doctor (`dim_staff`, which carries the specialty) and clinic (`dim_department`). |
| X8 | **Architecture A:** a response fact (one row per invitation), an answer fact (one row per answered question), a question dimension, a service dimension, and a reconciliation model. |

---

## 2. Findings that shape the design

Measured 2026-10-07 on `press_ganey.pg_survey_responses` (`FINAL`) and `gold`.

| # | Fact | Consequence |
|---|---|---|
| P1 | 702,879 invitations (one per `surveycode`), with visit dates from 2025-10 to today. Status: NOTSTARTED 526,334, incomplete 151,493, submitted 25,052. 31,019 surveys carry at least one answer: 25,012 submitted and 6,007 incomplete. 145,486 incomplete surveys have no answer at all. | The response fact keeps every invitation (survey quality needs the denominator). `response_status` is derived from the answers, not from the source status alone (section 6.1). |
| P2 | Answers are a JSON object per survey (`responses`), question code → answer code or null. Expanding the non-null values gives 740,022 answer rows, of which 618,952 are on scored questions. The `comments` key is always null. 54 `initial_response` values (a JSON array) belong to no question. | The answer fact holds non-null answers only. `comments` and `initial_response` are skipped. No free-text model. |
| P3 | `pg_survey_questions` (306 rows, 13 surveys) carries domain, scale type, item type and `is_scored`. `pg_survey_answer_options` (1,418 rows) maps each answer code to a label (EN/AR) and score. All 1,315 `pg_standard` options have a score; the 103 `workbook` options have none, and they are exactly the background and routing questions. | Scores and labels come from the option master. `is_scored` from the question master. |
| P4 | The 0–10 question (`cms_23`, IP/PIP) stores option codes 1–11: code 11 = score 10. All scales are oriented higher = better. | The answer score is always the option score, never the raw code. |
| P5 | There is no 0–10 "recommend" question. Every service has a 1–5 "likelihood of your recommending … to others" question. The same code means different things per survey: `o3` is "recommend" in IP and "overall rating" in OP. | NPS question per service comes from a reference map, not from the code (section 4.1). |
| P6 | Encounter id = care-type letter + Oasis id. Match to `gold.fact_encounter` by branch + `source_id` + encounter type: `o` → OP 88% (479,141 of 542,263 OP-service surveys), `e` → ER 99.3%, `i` → IP 100%. This replaces the 32% measured in parent spec section 13.1 (that figure came from a date-limited appointment lookup; O10 is closed). | Direct join, no charge-based fallback. |
| P7 | Of 63,122 unmatched OP-service surveys, 61,963 are Khamis (`hnhk`), the known gap in Khamis outpatient appointments for Jan–Jul 2026, and 1,138 are Alrabwah. Outpatient rehab (OR) matches only 50% (5,982 of 11,970). | Unlinked surveys are kept and reported by branch and service. OR investigated during the build (O-P6-2). |
| P8 | On linked surveys a doctor is always available: OP `treating_staff_key` is filled on 38% of 2026 encounters, but `booked_staff_key` on 100% and the two differ on only 26 rows. IP `treating_staff_key` is filled on 37%; `fact_admission.consultant_staff_key` is the admission's consultant. | Doctor rule in section 6.1. |
| P9 | 79,801 branch + encounter pairs received 2–5 invitations, mostly the same day and service. Only 208 of them have more than one answered survey. | `is_primary_for_encounter` flag; response rate counts primary invitations only. |
| P10 | Survey coverage by branch: Abha, Jazan, Khamis, Madinah, Alrabwah and Unaizah from Oct–Dec 2025; Ghirnata and Muhayil from mid-September 2026. Every `hosp` value matches `dim_branch.pg_branch_code`; every encounter id has the form `[oei][0-9]+`. | No branch fallback needed; `Bad encounter id` kept as a guard. |
| P11 | Answered surveys arrive quickly: 23% the same day, 31% the next day. `sms_send_date` is null on 50,460 invitations. | `days_visit_to_answer`; SMS reach measure. |
| P12 | `dim_pg_service` lists 17 services with a care setting and `is_enabled`; DIA, ON and OU have questions but no or almost no surveys. `dim_staff` already carries `specialty` and `unified_specialty`. | `dim_survey_service` from the source list; specialty needs no new work. |

---

## 3. Architecture

The same layers, tags and folders as earlier phases.

```
press_ganey (source)
  └─ stg  (views)
       stg_pg__survey_response       one row per surveycode, latest by _fetched_at (FINAL)
       stg_pg__survey_answer         JSON expanded: surveycode × question_code, non-null values only
       stg_pg__survey_question       question master
       stg_pg__answer_option         answer-option master
       stg_pg__service               service list
     stg_ref__pg_question_role       default.map_pg_question_role
     stg_ref__pg_background_value    default.map_pg_background_value
  └─ int  (tables)
       int_survey_encounter_link     survey → encounter, episode, patient, doctor, clinic, payer, care type
       int_survey_background         one row per survey with the conformed background attributes
  └─ gold (tables)
       dim_survey_service
       dim_survey_question
       fact_survey_response
       fact_survey_answer
       rec_survey_monthly
```

Folders: `models/hnh/staging/press_ganey/`, `models/hnh/intermediate/experience/`, `models/hnh/marts/experience/`, reconciliation in `models/hnh/marts/reconciliation/`. Macros in `macros/hnh/hnh_rules_experience.sql`.

**Source.** A new source `press_ganey` is declared in `_press_ganey__sources.yml` (tables `pg_survey_responses`, `pg_survey_questions`, `pg_survey_answer_options`, `dim_pg_service`; freshness on `_fetched_at`). The staging models do not read the source's own views (`pg_survey_answers`, `pg_survey_answers_detail`, `*_v`), so the models do not depend on objects outside the declared tables. The JSON is expanded once, in `stg_pg__survey_answer`, with `JSONExtractKeysAndValues(responses, 'Nullable(String)')`; an array value (`["6",null]`) takes its first element.

**Materialisation.** All gold models are full-rebuild tables. Each fact is under a million rows.

---

## 4. Reference data and rules

### 4.1 `default.map_pg_question_role` (drafted, reviewed, loaded once)

Columns: `service`, `question_code`, `role`. About 40 rows. Drafted by `scripts/draft_pg_question_role_map.py` from the question master, written to `static_mappings/pg_question_role.csv` (not in git) for review, then loaded by `scripts/load_reference_data.py`.

NPS roles:

| Service | `Hospital NPS` | `Physician NPS` |
|---|---|---|
| OP | `o4` | `cp10` |
| TM | `o4` | `cp10` |
| ER | `f4` | — |
| IP, PIP | `o3` | — |
| DEN | `o12` | `o1` |
| OR | `o4` | — |
| HHC | `h3` | — |
| LTC | `n10` | — |
| AS | `f3` | — |
| DIA, ON, OU | `e4` | — |

Attribute roles (background and routing questions):

| Role | Questions |
|---|---|
| `respondent` | `filling` (ER, IP, PIP, DIA, TM), `csurvey` (LTC, OR), `relation` (DEN) |
| `first_visit` | `fvisit` (OP, OU, DEN, ON), `fstay` (IP, PIP) |
| `booking_channel` | `howschvs` (OP), `itsource` (HHC), `visadvan` (OR) |
| `admitted_via_er` | `admther` (IP, PIP) |
| `used_lab` / `used_radiology` / `used_pharmacy` / `used_insurance_office` | `labtests`, `xraytest`, `onstphar`, `insurver` (OP) |
| `used_physio` / `used_speech` / `treatment_complete` | `physther`, `spchther`, `complete` (OR) |
| `meds_delivered` / `tele_spared_visit` / `tele_channel` | `medshome`, `telespar`, `visttype` (TM) |
| `hhc_service` | `itservic` (HHC) |
| `dental_service` | `service` (DEN) |
| `dialysis_done` | `dialytim` (DIA) |
| `contact_consent` | `hl_disclaimer` (all), `hl_disclamer` (TM) |

A question has at most one role per service (tested).

### 4.2 `default.map_pg_background_value` (drafted, reviewed, loaded once)

Columns: `service`, `question_code`, `answer_code`, `conformed_value`. About 103 rows, one per unscored answer option. The same meaning has different codes in different surveys (Patient is `1` in `filling` but `5` in `relation`), so each code maps to one shared vocabulary:

| Role | Conformed values |
|---|---|
| `respondent` | Patient, Parent or guardian, Family member, Other |
| `booking_channel` | Call centre, Reception, Online, Walk-in, Referral |
| Yes/No roles | Yes, No |
| `dental_service`, `hhc_service`, `tele_channel` | The option label in English, trimmed |

Drafted by the same script from the option labels, reviewed by the user, then loaded.

### 4.3 Macros (`hnh_rules_experience.sql`)

- `hnh_survey_band(scale_type, score)` → `'Promoter'` / `'Passive'` / `'Detractor'` / null:

| Scale type | Promoter | Passive | Detractor |
|---|---|---|---|
| `rating_1_5`, `agree_1_5` | 4–5 | 3 | 1–2 |
| `definitely_1_4` | 3–4 | — | 1–2 |
| `likelihood_0_10` | 8–10 | 5–7 | 0–4 |
| any other, or null score | null | null | null |

- `hnh_survey_encounter_type(encounter_id)` → `'OP'` / `'ER'` / `'IP'` / null from the prefix letter `o` / `e` / `i`.
- `hnh_survey_source_id(encounter_id)` → `toInt64OrNull(substring(encounter_id, 2))`.

---

## 5. Dimensions

### 5.1 dim_survey_service

Key `survey_service_key` (= `service_code`, String). From `stg_pg__service`: description, care setting, `is_enabled`, plus survey name from the question master. Unknown member `'-1'` for a service not in the list.

### 5.2 dim_survey_question

Key `question_key` = `concat(service, '|', question_code)`. About 306 rows.

Columns: `service_code`, `question_code`, `pg_var`, survey name EN/AR, `item_no`, `domain_en`, `domain_ar`, `question_en`, `question_ar`, `scale_type`, `scale_en`, `item_type`, `is_scored`, `question_class`, `nps_role`, `attribute_role`.

- `question_class` = `Scored` when `is_scored`; `Routing` when `item_type = 'Routing'`; else `Background`.
- `nps_role` and `attribute_role` from `map_pg_question_role`.
- Unknown member `'-1'` for answer keys not in the master.

### 5.3 Reused dimensions

`dim_branch` (`pg_branch_code`), `dim_date` (visit, SMS and survey dates), `dim_staff` (doctor; specialty and unified specialty), `dim_department` (clinic), `dim_patient`, `dim_care_type`, `dim_payer`. Unknown member `-1` where the survey is not linked.

---

## 6. Facts

### 6.1 fact_survey_response

Grain: one row per `surveycode`. About 703K rows.

**Keys:** `survey_response_key` (`cityHash64(surveycode)`), `surveycode`, `branch_key`, `survey_service_key`, `care_type_key`, `encounter_key`, `episode_key`, `patient_key`, `staff_key`, `department_key`, `payer_key`, `visit_date_key`, `sms_sent_date_key`, `survey_date_key`.

**Encounter link** (`int_survey_encounter_link`): branch from `dim_branch.pg_branch_code = hosp`; encounter by `fact_encounter.branch_key`, `encounter_type = hnh_survey_encounter_type(encounter_id)` and `source_id = hnh_survey_source_id(encounter_id)`. Episode, patient, clinic (`department_key`), payer and care type come from the encounter. `link_status`:
- `Linked` — encounter found;
- `Encounter not found` — well-formed id, no encounter;
- `Bad encounter id` — prefix not `o`/`e`/`i` or id not numeric.

**Doctor** (`staff_key`):
- IP: `fact_admission.consultant_staff_key` of the admission whose `encounter_key` is the linked encounter, else the encounter's `treating_staff_key`, else `booked_staff_key`;
- OP and ER: `treating_staff_key` when > 0, else `booked_staff_key`;
- unlinked: `-1`.

**Status and process:**

| Column | Rule |
|---|---|
| `source_status` | Source `status` as is |
| `response_status` | `Submitted` when source status is `submitted`; `Partial` when at least one non-null answer and not submitted; else `Not started` |
| `is_sms_sent` | `sms_send_date` is not null |
| `is_responded` | `answers_count > 0` |
| `is_submitted` | `response_status = 'Submitted'` |
| `is_primary_for_encounter` | 1 on one invitation per (branch, `encounter_id`): the answered one with the latest `survey_date` (tie-break highest `surveycode`), or the latest invitation when none was answered |
| `answers_count` | Non-null answers on the survey |
| `scored_questions_offered` | Count of `is_scored` questions in the service's survey |
| `scored_questions_answered` | Non-null answers on scored questions |
| `days_visit_to_sms` | `dateDiff('day', visit_date, sms_send_date)` |
| `days_visit_to_answer` | `dateDiff('day', visit_date, survey_date)` when `is_responded`, else null |
| `link_status` | Section above |

**Background attributes** (from `int_survey_background`, `'Not answered'` when the survey has no answer for that role or the service has no such question): `respondent_type`, `first_visit`, `booking_channel`, `admitted_via_er`, `used_lab`, `used_radiology`, `used_pharmacy`, `used_insurance_office`, `used_physio`, `used_speech`, `treatment_complete`, `meds_delivered`, `tele_spared_visit`, `tele_channel`, `hhc_service`, `dental_service`, `dialysis_done`, `contact_consent`.

**NPS on the response:** `nps_score` and `nps_band` from the service's `Hospital NPS` answer; `physician_nps_score` and `physician_nps_band` from its `Physician NPS` answer. Null when that question was not answered.

### 6.2 fact_survey_answer

Grain: one row per `surveycode` × `question_code` with a non-null answer. About 740K rows (619K scored).

**Keys:** `survey_response_key`, `surveycode`, `question_key`, and copied from the response: `branch_key`, `survey_service_key`, `care_type_key`, `encounter_key`, `staff_key`, `department_key`, `patient_key`, `payer_key`, `visit_date_key`, `response_status`, `is_primary_for_encounter`, `link_status`.

**Answer:**

| Column | Rule |
|---|---|
| `answer_code` | Raw value from the JSON |
| `answer_label_en`, `answer_label_ar` | From the option master on (service, question, answer code) |
| `answer_score` | Option score; null for unscored questions or unknown codes |
| `is_scored`, `question_class`, `scale_type` | From `dim_survey_question` |
| `band` | `hnh_survey_band(scale_type, answer_score)` when `is_scored`, else null |
| `is_promoter`, `is_passive`, `is_detractor` | 1/0 from `band` |
| `nps_role` | From `dim_survey_question` |
| `is_option_unknown` | 1 when the code has no option row |

The response keys are copied deliberately: domain-by-doctor NPS reads one table, and SSAS does not need a bidirectional relationship through the response fact.

### 6.3 rec_survey_monthly

Grain: branch × service × visit month. Columns: source invitations, response-fact rows, source non-null answers (excluding `comments` and `initial_response`), answer-fact rows, linked invitations, link %. Used by the tests in section 8.

---

## 7. KPI definitions (for SSAS)

The warehouse supplies the columns; the measures are DAX in SSAS.

### 7.1 Survey quality (`fact_survey_response`, primary invitations unless stated)

| KPI | Definition |
|---|---|
| Invitations | Count of primary invitations. "All invitations" (no primary filter) is a secondary measure. |
| SMS reach % | Invitations with `is_sms_sent` ÷ invitations |
| Response rate % | `is_responded` ÷ invitations with `is_sms_sent` |
| Completion rate % | `is_submitted` ÷ `is_responded` |
| Answer completeness % | Σ `scored_questions_answered` ÷ Σ `scored_questions_offered`, over responded invitations |
| Median days visit → answer | Median `days_visit_to_answer` over responded invitations |
| Encounter link % | `link_status = 'Linked'` ÷ invitations |
| Doctor attribution % | Responded invitations with `staff_key` > 0 ÷ responded invitations |
| Repeat invitation rate | Non-primary invitations ÷ all invitations |

### 7.2 Satisfaction (`fact_survey_answer`, `is_scored = 1`)

| KPI | Definition |
|---|---|
| Hospital NPS | (Σ `is_promoter` − Σ `is_detractor`) ÷ count, on answers with `nps_role = 'Hospital NPS'`, × 100 |
| Physician NPS | The same on `nps_role = 'Physician NPS'` |
| NPS (any selection) | The same formula over all scored answers in the filter context: a domain, a question, a doctor, a specialty |
| % Promoter, % Passive, % Detractor | Shares of the answer count |
| Answer count (n) | Count of scored answers; shown next to every NPS |
| Low sample | n < 30 is shown as "insufficient sample" (a display rule in SSAS) |

NPS is labelled "NPS (5-point)" in SSAS; it is not comparable to external 0–10 NPS benchmarks. Response-level NPS (`fact_survey_response.nps_band`) gives the same Hospital NPS and is used when the analysis is by survey rather than by answer.

All measures slice by branch, service, care type, doctor, specialty, clinic, payer, visit month and every background attribute.

---

## 8. Testing and reconciliation

**dbt tests**
- Unique and not null: `fact_survey_response.surveycode`, `survey_response_key`; `fact_survey_answer` (`surveycode`, `question_code`); `dim_survey_question.question_key`; `dim_survey_service.survey_service_key`.
- Relationships from both facts to `dim_branch`, `dim_survey_service`, `dim_survey_question`, `dim_staff`, `dim_department`, `dim_date` (unknown members allowed).
- Accepted values: `response_status`, `link_status`, `band`, `question_class`, `nps_role`, and every background attribute against the conformed vocabulary plus `Not answered`.
- One `is_primary_for_encounter` per (branch, `encounter_id`).
- `map_pg_question_role`: at most one role per (service, question); exactly one `Hospital NPS` per service with surveys.
- `is_option_unknown`: warning when any row is 1.
- Unit test of `hnh_survey_band` on all four scales, including the boundaries (3, 4; 4, 5, 7, 8 on 0–10) and a null score.

**Reconciliation (`rec_survey_monthly`)**
- Source invitations = response-fact rows for every branch-service-month (error).
- Source non-null answers = answer-fact rows (error).
- Link % below 80% for a branch-month (warning), except Khamis OP January–July 2026 (P7).

**Spot checks (during the build, recorded in `docs/reconciliation_phase6.md`)**
- 20 surveys traced from the JSON to the answer rows, labels, scores and bands, including at least one 0–10 and one 1–4 answer.
- Hospital NPS for one branch-month and Physician NPS for one doctor recomputed by hand from the source.
- The OR (outpatient rehab) link gap investigated and its cause recorded.

---

## 9. Security and SSAS handoff

- Both facts carry `branch_key`, so the existing branch row-level security on `sec_user_access` applies unchanged.
- `patient_key` links to `dim_patient`; identifying data stays in `dim_patient_pii` as in earlier phases. The survey link URL (`survey_link`) is not loaded into gold.
- Relationships: both facts → `dim_branch`, `dim_survey_service`, `dim_staff` (role: survey doctor), `dim_department` (role: clinic), `dim_care_type`, `dim_payer`, `dim_patient`, `dim_date` (active on `visit_date_key`; `survey_date_key` and `sms_sent_date_key` inactive). `fact_survey_answer` → `dim_survey_question`. `fact_survey_answer` → `fact_survey_response` is not modelled as a relationship; the copied keys serve instead.
- `docs/receiving_project_config.md` gains the new source and folders.

---

## 10. Open items

| # | Item | Needed before | Default if unresolved |
|---|---|---|---|
| O-P6-1 | Khamis OP surveys January–July 2026 have no appointment (61,963) | — | Kept as `Encounter not found`; analysable by branch and service only |
| O-P6-2 | Outpatient rehab (OR) links only 50% | — | Investigated during the build and recorded; no fix planned |
| O-P6-3 | Survey comments are always empty in the source | Free-text analysis | Out of scope until ingestion supplies text |
| O-P6-4 | 5-point NPS is not comparable to external 0–10 benchmarks | SSAS labels | Labelled "NPS (5-point)" |
| O-P6-5 | Ghirnata and Muhayil surveys start mid-September 2026 | — | None; it is the data's start |
| O-P6-6 | Whether the receiving dbt project already declares a source named `press_ganey` | Moving the models | The `hnh` YAML declares `press_ganey`; rename it if it clashes |
| O-P6-7 | Review of `map_pg_question_role` and `map_pg_background_value` drafts | Build of the facts | Drafted values used as loaded |
