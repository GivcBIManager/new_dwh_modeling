# Physician Contract Review (HNH Physician Review) design

Date: 2026-11-19. Status: approved by the user 2026-11-19, with revenue from other hospitals included for each
doctor (builder check done; data checks of 2026-11-19 are in).
Request: Corporate HR – Organization Development & Rewards, supported by Finance (text of the request in the
conversation of 2026-11-19).

## Intent

One Power BI screen that Corporate HR and Finance read when a physician's contract comes up for renewal. For **one
selected physician** it puts pay next to financial contribution, and places both against the physician's peers of the
same specialty, in the same hospital and across the Group, so renewal and remuneration decisions rest on salary
positioning, internal equity and contribution together.

### Goals

- One page, salary on the left and income on the right, for one physician and one review period.
- Peer comparison in two scopes (same hospital, Group) with the physician's rank and an above / within / below mark.
- Review period of the last 12 months by default, 24 months or any range on choice, with the previous period of equal
  length beside it.
- Context that explains differences outside the physician's control: FTE, clinic days and hours, absence, case mix.
- Exportable to PDF as one page; the data sources and the review period printed on the page.

### Non-goals (the user's decisions, 2026-11-19)

- **Financial targets and achievement %**: left out. No physician-level target exists.
- **Incentives**: left out. Payroll has no incentive category.
- **Sub-specialty**: left out. Peers are grouped by **unified specialty** (`Staff[Unified Specialty]`).
- **Collected revenue and collection %**: replaced by **claim rejection %**.
- A new access rule in the model: pay uses the existing `Can See Pay` rule; the user restricts the report itself on
  the Report Server.
- Head Office staff (no Oasis doctor record), nurses, contingent workers.
- Contract start, end or renewal dates (Fusion has none staged; Oasis contract dates are not in `dim_staff`).

### Anti-goals (a failure even if it technically works)

- A peer statistic that silently mixes specialties, grades or hospitals, or that changes when the viewer moves a
  slicer that was only meant to find the physician.
- A pay figure visible to a viewer without `Can See Pay`.
- A rank or median shown for a peer group of one.
- A page that shows a blend of several physicians when none or more than one is selected.
- An inferred figure (last increment) shown as if it were an HR record.

## Constraints

- Production server rules (CLAUDE.md): dbt builds, SSAS deploys and processing, and the upload each need the user's
  go-ahead. Read-only DAX and SELECTs do not.
- Power BI Report Server reads only the legacy `Report/Layout` package: no bookmarks, report measures, visual groups,
  AppSource visuals or hierarchy fields (`powerbi_tmdl/README.md`). All measures live in the SSAS model.
- Measures are wrapped by `ssas/tools/measure_guards.py`; a measure filtered by a table it is not meant for returns
  the guard text.
- `HNH Readers` row filters apply inside every measure and cannot be lifted: `Staff` by the viewer's unified
  specialties, `Branch` by the viewer's branches, and `Pay Category` (which hides `Payroll`) and `Staff Productivity`
  by `Can See Pay`. "Group" peers are therefore the Group **as the viewer may see it**; the two intended viewers need
  all branches, all specialties and `Can See Pay = 1` in `bi_users.csv`.
- Title-casing rule (CLAUDE.md) for mart text from source systems; labels this repo defines are not title-cased.

## Approaches considered

| | What is built | Trade-off |
|---|---|---|
| A. One physician-month table in dbt | a new mart with pay, revenue, activity, claims and FTE per physician and month; peer statistics as measures over it | fast and testable in one place; a new table to build, gate and process |
| **B. Measures over the existing tables (chosen)** | no new fact; measures over `Payroll`, `Charge Lines`, `Encounters`, `Admissions`, `Surgeries`, `Claim Lines`, `Clinic Capacity`, `Headcount`, `Staff Productivity` | least dbt work and one definition per number shared with the other reports; peer statistics iterate the peer doctors over the large facts, so query time must be checked |
| C. Peer statistics precomputed in dbt | minimum, average, median, rank per fixed window | fastest; cannot follow a free review period or the previous-period comparison |

The user chose **B** (2026-11-19). It works because every fact above already relates to `Staff` on `Staff Key`
(`Payroll` and `Headcount` included), so `Staff` is the physician dimension and no measure has to cross the
employee-to-doctor bridge. If G3 shows the page slower than the budget below, the fallback is A for the peer inputs
only; that would come back to the user.

## Definitions

Everything below is per `Staff` row. A doctor with records in two hospitals is two rows, one per hospital.

### Population

- **Physician** (`Staff[Is Review Physician]`, see dbt): a `dim_staff` row with `category = 'DOCTORS'` that is
  linked to exactly one HR employee, not contingent, whose Fusion job is a physician job.
  - Physician jobs (my call, checked 2026-11-19; the user can correct the list): Consultant, Senior Registrar Doctor,
    Registrar Doctor, Specialist, General Physician, Resident Doctor. About 745 of the 885 linked "DOCTORS" rows.
    The rest carry jobs such as Nurse, Technician, Ancillary Specialist or Driver and are left out.
  - The three staff records shared by two employees each are left out: their pay would add up on one row.
  - **Work in other hospitals counts** (the user's decision, 2026-11-19). A doctor who also works in another
    hospital has a second `Staff` row there, not linked to HR (the bridge links an employee to the staff row of their
    own branch only). Those rows are attached to the physician's home row by `Staff[Review Physician Key]` (see dbt),
    and every income metric of a physician is the sum over the home row and the attached rows.
    - The physician is selected, and belongs to a peer group, by the **home** row: the hospital of the HR record.
      "Same hospital" means the same home hospital; each peer's value is their total across all hospitals.
    - Pay sits on the home row only.
- **Title** (`Staff[Job Title]`): the Fusion job name of the linked employee (Consultant, Specialist, ...). It is
  the "grade / title" of the request and the Grade slicer.
  - The Oasis `Staff Grade` is not used: it reads "Doctor" or "Doctors" for 479 of the linked doctors and is worded
    differently per hospital. The Fusion pay grade (G7-3 ...) is shown as context only.
- No peer rule depends on `Staff Productivity` or `Headcount`: both start in January 2026
  (`hnh_hr_snapshot_start`), while payroll and charge lines go back to January 2022.

### Peer groups

| Section | Same hospital | Group | A peer counts when |
|---|---|---|---|
| Salary | same unified specialty **and** same title, same `Branch Key` | same unified specialty and same title, all hospitals | it has a package in the latest payroll month of the review period |
| Income | same unified specialty, same `Branch Key` | same unified specialty, all hospitals | it has billed revenue in the review period |

- The peer group includes the selected physician. Rank 1 is the highest value (for rejection % the lowest).
- Income peers do not need pay access, so a reader without `Can See Pay` still gets the income section; the salary
  section and the revenue-to-salary ratio are blank for that reader.
- The peer measures remove every filter on `Staff` and `Branch` and re-apply the selected physician's own specialty,
  title and hospital, so the Hospital, Specialty, Title and Employment type slicers only narrow the physician list.
- Employment type does not narrow the peer group (my call): FTE is shown beside the package instead.
- **Peer count** is always shown. With a peer group of one, rank and the statistics are blank and the mark reads
  "No peers".

### Salary (source: `Payroll`, Oasis and Fusion, parallel runs already excluded)

| Figure | Definition |
|---|---|
| Basic | `Payroll Cost` of pay category Basic in the **latest payroll month of the review period** |
| Allowances | same month, categories Housing, Transport, Food, Clinical allowances, Other allowances |
| Monthly package | Basic + Allowances of that month |
| Annual package | Monthly package × 12 |
| Outside the package | every other pay category (Overtime, Leave pay, End of service, Awards and bonus, Absence and lateness deduction, both GOSI categories, Other employer charges): the sum over the review period as one "Other pay in period" figure, not compared. The package is not reduced by the absence deduction |
| Last increment date | the latest payroll month, in all history (from January 2022), whose Basic is higher than the previous paid month's Basic |
| Last increment value | that rise in SAR and in % |
| Peer statistics | minimum, average, median, maximum of **Monthly package**, and the physician's rank |

The last increment is inferred from payroll, since no salary history is staged; the page labels it "from payroll".
A part-month of pay (joining, unpaid leave) would look like a rise in the month after it. No paid-days column
exists, so the rule is: the first paid month, and any month whose Basic is below both the month before and the month
after, is a part month and is ignored on both sides of the comparison. The builder checks ten physicians by hand at
G3.

### Income (source: Oasis billing and NPHIES claims)

Every metric covers the physician's home row and the rows attached to it in other hospitals. The context row shows
the share of billed revenue earned outside the home hospital when it is not zero.

| Metric | Definition | Better |
|---|---|---|
| Billed revenue | `Revenue` on charge lines whose own doctor (`Charge Lines[Staff Key]`) is the physician, by delivery date. The rule `Staff Productivity` already uses | higher |
| Claim rejection % | `Claim Rejection Rate %` of claim lines whose claim-visit doctor is the physician (see dbt) | lower |
| Rejected amount | `Claims Rejected`, shown beside the % | – |
| OPD visits | `OP Visits`, treating doctor | higher |
| Admissions | `Admissions`, consultant | higher |
| Surgeries / procedures | `Theatre Volume`, surgeon | higher |
| Revenue per patient | Billed revenue ÷ distinct patients on those charge lines | higher |
| Growth % | Billed revenue of the review period ÷ that of the previous period − 1; blank when the physician has no revenue in the previous period | higher |
| Revenue-to-salary ratio | Billed revenue ÷ `Payroll Cost` (all pay categories), both over the review period, read from `Charge Lines` and `Payroll`. The same ratio as `Revenue per Payroll SAR`, but not that measure, which reads `Staff Productivity` (2026 only) | higher |

Peer statistics for each metric: average, median, highest, and the physician's rank, in both scopes. Average and
median are over the peers' own values (one value per physician), not a ratio of sums.

### Above / within / below

Against the peer **average** of the scope: within = inside ±10 % of it (my call; one constant in the model), above
and below outside it. Colour follows "better": above is green for revenue, below is green for rejection %. Salary
marks are neutral in colour (above the peer average is neither good nor bad).

### Review period

- A date slicer on `Date`: saved as "last 12 months" (whole months, ending with the last closed month), changeable to
  24 months or any range. If the generator and the Report Server cannot hold a relative-date slicer, the fallback is
  the HR report's dates-range slicer with a "Last closed month" default; the builder decides after trying.
- **Previous period**: the window of the same number of months that ends the day before the review period starts.
  Every income metric has a previous-period value; growth % is shown for revenue, the others show the previous value
  in the trend tooltip or the table.

### Context

- Employment type, title, Fusion pay grade, hire date (new `Staff` columns, see dbt), service start date.
- FTE (latest month, `Headcount`) and absence days (`Staff Productivity`): both exist from January 2026 only, so
  they cover the part of the review period from then on, and the label says so.
- Clinic days (distinct dates with scheduled minutes) and scheduled clinic hours (`Scheduled Minutes` ÷ 60), new
  measures over `Clinic Capacity`; clinic utilisation %.
- Case mix: share of revenue by care type (OP / IP / ER) and cash against insurance. No DRG exists. The builder
  picks the `Payer` column that carries the cash / insurance split (`Billing Type`, `Category` or `Purchaser Type`)
  after looking at the values.

## Data and model changes

### dbt (hnh_dwh)

1. **`fact_claim_line` gains `staff_key`** from the claim visit's doctor (`stg_oasis__claim_visits.doctor_code`),
   `-1` when unmatched; `ssas_fact_claim_line` exposes it.
   - Checked 2026-11-19 (read-only): every claim visit requested since January 2025 has a doctor code, and 100 % of
     them match a `dim_staff` staff id of the same branch, in all eight hospitals.
2. **`dim_staff` gains**, from the linked employee (`bridge_employee_staff`, `dim_employee`, `dim_job`,
   `dim_grade`), blank or "Not linked" for the other rows:
   - `is_review_physician`: the population rule above.
   - `job_title`: the Fusion job name, title-cased with `hnh_title` (source text).
   - `pay_grade`: the Fusion grade name (a code, not title-cased).
   - `employment_type`: "Full-time" / "Part-time" / "Not linked" from `is_part_time` (repo labels, so on the
     title-case test's `excluded` list). 38 of the linked doctors are part-time.
   - `hire_date`.
3. **`dim_staff` gains `review_physician_key`**: on a review physician's home row its own `staff_key`; on a row of
   another hospital that is the same person, the home row's `staff_key`; `-1` elsewhere.
   - Same person = the same `staff_id` in another hospital, not linked to HR itself, and not contradicted by the
     national id (`national_id_hash` equal, or missing on either side).
   - Checked 2026-11-19 (read-only): 636 of the 883 linked doctors have a national id. All 29 other-hospital rows
     that share a linked doctor's national id also share the staff id, and no row shares a staff id with a different
     national id. Those 29 rows carry SAR 25.8m of revenue since November 2025, against SAR 1,274.9m on the linked
     rows. Matching by staff id alone finds more rows, where the national id is missing.
   - Because the national id is often missing, the build also compares the names of each matched pair and lists the
     pairs whose names differ for the user before G3; a pair the user rejects goes on an exclusion list in the model.
   - A row that would attach to two home rows is attached to neither and listed.
   - A test asserts one home row per `review_physician_key`.
4. **A metric list** `dim_physician_review_metric` (repo-defined rows: metric code, name, section, sort, format,
   better-direction), following `dim_finance_kpi`. Not a fact; it is the row axis of the comparison tables.
5. Tests: uniqueness and not-null on the new keys; claim-line `staff_key` relationship to `dim_staff`.

### SSAS (HNH_Analytics)

- `ssas/tools/generate.py` picks up the new columns and the metric table; a relationship
  `'Claim Lines'[Staff Key]` → `Staff[Staff Key]`. No other relationship changes.
- A disconnected **`Peer Scope`** table (Same hospital / Group) and the metric table drive SWITCH measures, the
  pattern of `FR KPI Value`:
  - `PR Value`, `PR Previous Value`, `PR Peer Min`, `PR Peer Average`, `PR Peer Median`, `PR Peer Max`, `PR Rank`,
    `PR Peer Count`, `PR Position` (Above / Within / Below / No peers), `PR Position Colour`.
  - Named measures for the cards and the header: package components, increment date and value, the footer text
    (`PR Footer`: sources, review period, previous period, data-as-of), and `PR Selection Notice`.
- **Other hospitals**: the income measures take the selected home row's `Review Physician Key` and evaluate over
  every `Staff` row that carries it, with the `Branch` filter removed. A reader limited to some branches sees only
  the rows of those branches (row security cannot be lifted).
- **One physician rule**: every `PR` measure returns blank unless exactly one review-physician home row is in context;
  `PR Selection Notice` then reads "Select one physician".
- **Pay rule**: pay measures read `Payroll`, already hidden by the `Pay Category` filter; no role change. A viewer
  without pay access sees `HR Pay Notice` over the salary section. `ssas/tests/security.json` gains cases: a non-pay
  reader gets blank for every salary `PR` measure and for the revenue-to-salary ratio, and a value for billed
  revenue and its peer statistics.
- Measure tests (the repo's measure-test SQL) for each metric of one physician, and for the peer statistics of one
  specialty in both scopes, computed independently in ClickHouse.
- Performance budget: the page renders in under 10 seconds on the test slot for the largest specialty over 24 months.

### Report (`powerbi_tmdl/hnh_physician_review_report/`)

Built as the HR and finance reports: a Python generator (`build.py`, page module, tests under pytest) that writes
the PBIP, then `pbir_to_pbix.py` for the upload file, with `check_upload_rules` returning `[]`. One page,
1920 × 1080, so the Report Server's Export → PDF gives one sheet.

```
+----------------------------------------------------------------------------------------------------------+
| HNH Physician Contract Review          [Physician v] [Hospital v] [Specialty v] [Grade v] [Type v] [Dates]|
| Dr <name> · <id> · <hospital> · <unified specialty> · <title> · <type> · FTE 1.0 · Hired <date>           |
+---------------------------------------------------+------------------------------------------------------+
| SALARY                                            | INCOME                                               |
| [Basic] [Allowances] [Monthly] [Annual]           | [Billed revenue] [Growth %] [Rejection %] [Rev/pay]  |
| Last increment: <month> · +<SAR> (+x %) from payroll| [OPD visits] [Admissions] [Surgeries] [Rev/patient] |
|                                                   |                                                      |
| Package vs peers (same specialty and title)       | Metric        Physician | Hospital: Avg Median High  |
|            Min   Avg   Median   Max   Rank  Mark  |                         | Rank Mark | Group: Avg ...  |
| Hospital   ...   ...   ...      ...   3/12  Above | Billed revenue ...                                   |
| Group      ...   ...   ...      ...   9/41  Within| Rejection %    ...                                   |
|                                                   | OPD visits     ...   (8 rows)                        |
| [range bar: min–max of peers, median tick,        |                                                      |
|  physician marker, one bar per scope]             | Monthly billed revenue, review period vs previous    |
|                                                   | [line chart]                                         |
+---------------------------------------------------+------------------------------------------------------+
| CONTEXT  FTE · Clinic days · Clinic hours · Utilisation % · Absence days · Case mix: OP/IP/ER · Cash/Ins. |
| Sources: HR / Payroll (Fusion, Oasis) · Oasis billing · NPHIES claims · Review period <from>–<to> ·       |
| Previous <from>–<to> · Data as of <date>                                                    Confidential |
+----------------------------------------------------------------------------------------------------------+
```

## Access

- The report goes in a Report Server folder whose permissions the user sets (the requester and the deputy). The
  builder creates no folder permissions and changes no role members.
- In the model the pay figures are open to every reader with `Can See Pay = 1`, as today; the user accepted this
  (2026-11-19).
- An SSAS server administrator bypasses the row filters; security tests run as a non-admin member of `HNH_BI_Users`.

## Delivery gates

As the finance report (`powerbi_tmdl/hnh_finance_report/README.md`), each with the user's go-ahead:

- G2: dbt build of the changed models and `generate.py`.
- G3: deploy to `HNH_Analytics_Test`, process, measure and security tests, timing, hand check of the increments.
- G4: upload to the Report Server folder the user names.
- G5: promote to production `HNH_Analytics`.

G1 (ClickHouse config tables) does not apply: this report has no configuration table.

## Left to the builder

- Visual types within the generator's set (cards, table or matrix, bar for the range, line chart) and exact layout.
- The DAX shape of the peer measures, provided the definitions and the performance budget hold.
- Relative-date slicer or the dates-range fallback.
- Whether `Peer Scope` is a dbt model or a model-only table, following what `generate.py` supports.

## Open for Finance (not blocking the build)

- Confirmation that revenue credited to the doctor on the charge line is the figure Branch Finance validates.
- Whether claim rejection % should be read by statement month (the existing measure) or by service month.
