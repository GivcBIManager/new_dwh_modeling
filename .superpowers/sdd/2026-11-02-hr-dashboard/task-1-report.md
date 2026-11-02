# Task 1 report: HR config tables, seed and runner

Status: DONE

## Implemented
- `scripts/HnhCh.psm1`: new exported `Invoke-HnhConfigApply -Ddl -Seed [-Update] [-Url] [-DryRun]`, the body of the old BSC script moved unchanged (same output, row-count checks, credential prompt only when not -DryRun). Internal DDL list is `$ddlStatements` because PowerShell variables are case-insensitive and `$ddl` would overwrite the `-Ddl` parameter (found by the BSC test failing).
- `scripts/bsc_config/apply_bsc_config.ps1`: same parameters, now imports the module and calls the function. Dry-run output diffed against the HEAD version: identical (22 lines).
- `scripts/hr_config/`: `hr_config_ddl.sql` (3 tables), `hr_config_seed.sql` (18 kpi + 15 metric rows, 19 DQ issues, no target rows), `apply_hr_config.ps1`, `ApplyHrConfig.Tests.ps1`.
- `docs/hr_config.md`.

## TDD
- RED: `Invoke-Pester -Script scripts\hr_config\ApplyHrConfig.Tests.ps1` -> Passed 0 Failed 3, "The argument ...apply_hr_config.ps1 to the -File parameter does not exist". Expected: runner not written yet.
- GREEN: after implementation, `Invoke-Pester -Script ApplyHrConfig.Tests.ps1,ApplyBscConfig.Tests.ps1,HnhCh.Tests.ps1` -> Passed 19 Failed 0.
- Also: a script checked every seed tuple has the same number of values as columns (kpi 23, dq 13) and quotes balance.

## Decisions
- Metric codes are `HR_M_<NAME>`; kpi_name for metrics is the measure name, short_label the display label (e.g. "Leavers in Fusion").
- Directions: BSC-linked copied from bsc seed (Turnover lower, Saudization higher, Vacancy lower, Time to fill lower, Staff to bed on_target, Clinical to doctor higher, Revenue per FTE/doctor higher). Not settled by the brief, my choice: Headcount on_target, Contingent share lower, Female share on_target, New hire turnover lower, Staff cost per FTE lower, Overtime lower, Sick rate lower, Leave liability lower, Visits per FTE and Revenue per payroll SAR higher. Metrics carry a direction too (counts on_target, cost/absence/leave lower, Leavers lower).
- Revenue per Doctor bsc code is `FIN_REVENUE_PER_DOCTOR`. needs_pay on metrics set where the caveat says pay access (Payroll Cost, Gross Pay x2, Current Leave Liability, Payroll Cost per Visit).
- Revenue per Payroll SAR and BSC "Staff to Bed" value_format: `num`.
- DQ `area` values are my grouping: Linkage, Employee, Leave, Absence, Payroll. Changed_by `seed`, note `seed 2026-11-02`.
- Source system text for vacancy/time to fill ("Fusion recruiting") inferred from `Requisitions` fact name; confirm.

## Concerns
- Directions/areas/source text above are drafts for the HR team.
- Nothing was run without -DryRun; no ClickHouse access.
