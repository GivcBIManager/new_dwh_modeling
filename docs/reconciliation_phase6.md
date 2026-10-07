# Phase 6 reconciliation (patient experience)

Run after a successful `dbt build --select tag:hnh`. Figures below are measured on the live tables after the full build of 2026-10-07 (`PASS=1135 WARN=50 ERROR=0 TOTAL=1185`, about 17 minutes, re-run after the final-review fixes; peak query memory 45.0 GiB in a Phase 2 model; the Phase 6 models stay under 3.1 GiB). Branches: 1 Al-Rabwa, 2 Khamis, 3 Jazan, 4 Unaizah, 5 Madinah, 6 Abha, 7 Ghirnata, 8 Muhayil. Data is as of 2026-10-07; October 2026 is a partial month. NPS is the 5-point NPS of the spec (promoter 4–5, passive 3, detractor 1–2 on 1–5 scales; 3–4 / – / 1–2 on the 1–4 scale; 8–10 / 5–7 / 0–4 on the 0–10 scale): it is not comparable to external 0–10 NPS benchmarks (O-P6-4).

Row counts at this build: `stg.stg_pg__survey_response` 702,879; `stg.stg_pg__survey_answer` 739,968; `int.int_survey_encounter_link` 702,879; `int.int_survey_background` 30,791; `gold.dim_survey_service` 18 (17 services + unknown); `gold.dim_survey_question` 307 (306 questions + unknown); `gold.fact_survey_response` 702,879; `gold.fact_survey_answer` 739,968; `gold.rec_survey_monthly` 505. Reference maps: `default.map_pg_question_role` 61 rows, `default.map_pg_background_value` 104 rows.

## 1. Source against gold (`gold.rec_survey_monthly`)

Per branch, survey service and visit month, source invitations equal response-fact rows and the source's non-null answers, counted on the raw `responses` JSON independently of the expansion in staging, equal answer-fact rows: 505 cells, Σ invitations 702,879, Σ answers 739,968, Σ |differences| 0 (both are error-severity tests). The answer count leaves out the 54 `initial_response` values (a stray JSON array that belongs to no question) and the `comments` key, which is null on every survey: there is no free text to model (O-P6-3).

A 20-survey trace (all IP surveys with `cms_23` 0–10 and `cms_24` 1–4 answers, plus a hash sample) matched all 509 source answers to gold rows: the same answer code on all 509, the option-master score on all 449 scored answers (60 are unscored background answers), and no band differs from a recomputation. Hospital NPS for Jazan, September 2026, computed straight from the source JSON and the option master is 74.3 on 750 answers; gold gives the same 74.3 on 750.

## 2. Encounter link

| Prefix | Links to | Linked | Not found |
|---|---|---:|---:|
| `o` | `fact_encounter` OP by appointment id | 514,659 | 74,742 |
| `e` | ER by ER visit id | 80,892 | 590 |
| `i` | IP by admission no | 31,995 | 1 |

No encounter id is malformed and every `hosp` code maps to a branch. Link rate by branch and service is 97–100% everywhere except Khamis (2): OP 40.2%, DEN 38.8%, OR 34.9%, HHC 44.7%, TM 51.8% (IP, PIP, LTC and ER are 100%). Every branch-service-month with 100+ invitations and a link rate under 80% is Khamis between December 2025 and July 2026 — the Khamis outpatient appointment gap already known from Phase 1 (O-P6-1). That is also why outpatient rehab looked like a 50% link at planning time: OR outside Khamis links 100% (O-P6-2, closed). From August 2026 Khamis links fully. `warn_survey_link_rate` leaves that window out and returns 0 rows.

Doctor: IP takes the admission's consultant, else the encounter's treating doctor, else its booked doctor; OP and ER take the treating doctor, else the booked doctor. Every linked survey has a clinic; 30 linked ER surveys have no doctor. Unlinked surveys carry `staff_key = -1` and are analysable by branch and service only.

## 3. Survey quality (primary invitations, visits January–September 2026)

| Branch | Invitations | SMS reach % | Response rate % | Completion % | Completeness % | Median days visit → answer (submitted) | Link % | Doctor attribution % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 Al-Rabwa | 115,737 | 94.8 | 4.2 | 81.4 | 75.3 | 1 | 99.0 | 99.4 |
| 2 Khamis | 137,644 | 90.6 | 4.6 | 80.0 | 74.0 | 1 | 51.1 | 67.5 |
| 3 Jazan | 123,999 | 91.6 | 5.7 | 81.8 | 74.6 | 3 | 99.7 | 99.7 |
| 4 Unaizah | 53,108 | 91.3 | 6.6 | 82.6 | 77.5 | 1 | 100.0 | 100.0 |
| 5 Madinah | 86,041 | 93.3 | 5.5 | 81.9 | 76.0 | 1 | 100.0 | 100.0 |
| 6 Abha | 28,324 | 93.2 | 6.5 | 79.1 | 73.6 | 1 | 100.0 | 100.0 |
| 7 Ghirnata | 1,251 | 76.1 | 10.2 | 91.3 | 81.0 | 1 | 100.0 | 100.0 |
| 8 Muhayil | 77 | 0.0 | 11.7 | 100.0 | 88.0 | 1 | 100.0 | 100.0 |

Response rate divides responded invitations by **all** primary invitations, not by those with an SMS sent: 8,259 of the 24,968 submitted surveys have no `sms_send_date` (they were answered through another channel), and none of Muhayil's 77 invitations has one. 84 surveys are `submitted` in the source but carry no answer; they count as Not started, so completion is not inflated (`source_status` keeps the source value).

Repeat invitations: 79,801 branch + encounter pairs received 2–5 invitations (87,827 invitations are not primary); only 208 of those encounters have more than one answered survey. `is_primary_for_encounter` keeps a submitted invitation, else a partial one, else any, each by latest survey date.

`survey_date` is the answer date only on submitted surveys: on partial and not-started surveys it is the survey's close (expiry) date, a median 15 days after the visit (offsets of 14, 15 and 30 days dominate). `days_visit_to_answer` and `survey_date_key` are therefore filled for the 24,968 submitted surveys only (median 1 day), and a submitted survey wins the primary flag over a partial one with a later close date (47 encounters changed at the final review).

## 4. NPS

Group, visits in 2026, scored answers:

| Question role | Answers | NPS | % promoter | % passive | % detractor |
|---|---:|---:|---:|---:|---:|
| Hospital NPS | 24,265 | 68.0 | 80.1 | 7.8 | 12.1 |
| Physician NPS | 13,961 | 76.9 | 86.1 | 4.8 | 9.1 |
| All other scored questions | 549,641 | 73.5 | 82.6 | 8.3 | 9.1 |

Hospital NPS by branch and service, 2026 (n ≥ 30):

| Branch | OP | OP physician | ER | IP | PIP | DEN | DEN dentist |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 Al-Rabwa | 64.9 (2,092) | 83.5 (2,272) | 31.6 (358) | 85.2 (1,474) | — | 67.6 (148) | 75.2 (133) |
| 2 Khamis | 54.4 (2,547) | 66.7 (2,720) | 18.1 (746) | 77.7 (1,194) | 74.9 (414) | 50.0 (166) | 56.1 (164) |
| 3 Jazan | 75.1 (3,424) | 81.3 (3,668) | 55.4 (478) | 85.0 (1,571) | 85.4 (486) | 67.2 (64) | 62.5 (56) |
| 4 Unaizah | 67.2 (1,237) | 79.7 (1,326) | 48.6 (471) | 87.8 (1,046) | 88.9 (126) | 72.4 (134) | 77.3 (119) |
| 5 Madinah | 70.8 (2,217) | 78.0 (2,366) | 45.3 (583) | 88.4 (833) | 93.1 (144) | 68.8 (234) | 69.9 (226) |
| 6 Abha | 48.8 (707) | 74.3 (747) | 28.9 (395) | 77.4 (336) | — | 59.3 (59) | 65.5 (55) |
| 7 Ghirnata | 33.3 (75) | 65.4 (78) | — | 71.4 (35) | — | — | — |

Other services with n ≥ 30: Khamis LTC 69.6 (79), Khamis OR 71.4 (105), Jazan OR 64.1 (39), Madinah HHC 97.7 (43). ER is the weakest service in every branch.

OP domain NPS, group, 2026: Physician 79.4 (66,629 answers), Laboratory 78.6 (17,448), Personal Issues 78.1 (24,980), Pharmacy 75.4 (26,043), Nurse 73.8 (26,975), Radiology 70.3 (11,260), Access 69.3 (49,049), Overall Assessment 68.5 (49,187), Moving Through Your Visit 52.2 (27,100), Insurance office 44.3 (13,934).

Doctor slice: the ten doctors with the most OP Physician NPS answers in 2026 have 148–196 answers each (for example an ENT consultant in Al-Rabwa, 196 answers, and a GIT consultant in Jazan, 195), each with its unified specialty from `dim_staff`. The largest "doctor" is the unknown member in Khamis (1,508 answers): unlinked surveys from the appointment gap. Doctor rankings should filter `staff_key <> -1`.

## 5. Background attributes

Share of the 30,975 responded surveys with an answer: first visit 26,118, booking channel 16,013, used lab 14,040, used pharmacy 13,663, used radiology 13,647, used insurance office 13,513, respondent 13,832, admitted via ER 8,484, dental service 914; rehab, home-care and telemedicine attributes 15–218 each; `dialysis_done` and `contact_consent` 0 (no dialysis surveys; the consent box is never ticked in the source).

Hospital NPS, 2026, by respondent: Patient 73.5 (8,284), Parent or guardian 62.3 (3,101), Other 52.8 (290), Family member 61.2 (67), not answered 66.0 (12,523). OP Hospital NPS by booking channel: Reception 73.5 (2,458), Walk-in 66.4 (5,049), Online 61.8 (917), Call centre 60.2 (3,691).

## 6. Monitors at first build

| Test | Rows | Note |
|---|---:|---|
| `accepted_values_fact_survey_answer_is_option_unknown` (warn) | 1 value, 92 rows | LTC `csurvey` code 2 is answered but missing from the option master (section 7) |
| `warn_survey_link_rate` | 0 | Khamis December 2025 – July 2026 is left out (O-P6-1) |
| `relationships_fact_survey_response_encounter_key` (warn) | 0 | every linked survey's encounter exists |
| `assert_survey_hospital_nps_per_service` | 0 | every service with invitations has exactly one Hospital NPS question; returns `('IP', 0)` when IP's row is removed |

## 7. Known data findings

- **LTC `csurvey` code 2** ("who is completing this survey") is used 92 times but has no row in `pg_survey_answer_options`; code 4 (Family member) is never used. The map drafts code 2 as Family member; confirm in review (O-P6-7). The answer fact keeps the rows with `is_option_unknown = 1` and no label.
- **TM `visttype` labels** are swapped between English and Arabic in the option master: code 1 is "Video Call" / "الاتصال الهاتفي" (phone call), code 2 "Voice Call" / "الاتصال المرئي" (video call). The conformed value follows the English label.
- **Ghirnata and Muhayil** surveys start mid-September 2026 (O-P6-5); Muhayil has no SMS dates.
- **DIA, ON and OU** have survey questions but (almost) no invitations; their NPS questions are mapped for when they start.
- **Reference maps await review (O-P6-7).** `scripts/draft_pg_maps.py` drafted both; the loader never overwrites, so a reviewed version is loaded by truncating `default.map_pg_question_role` / `default.map_pg_background_value` and re-running `python scripts/load_reference_data.py --only map_pg_question_role map_pg_background_value`, then the next `dbt build`.
