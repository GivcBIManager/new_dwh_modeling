-- Update of 2026-10-27 (third): targets and Referral Conversion Rate.
--   Patient Satisfaction (KPI 13): fixed target 85 on its 0-100 scale (it had none). Replaces the 0.85 row of
--     2026-10-27, which was on the old 0-1 scale and unused (target source none).
--   PREMs Score (KPI 16, Top Box %): target 85% -> 80%.
--   OP Doctor Utilization (KPI 58): fixed target 70% (it had none). Replaces the unused 0.75 row of 2026-10-27.
--   Activated Bed Rate (KPI 60): fixed target 90% (it had none; replaces the unused 0.9 row of 2026-10-27). The
--     actual is capped at 100%: each hospital's available beds count up to its licensed beds.
--   Referral Conversion Rate (KPI 61): active, measure BSC Referral Conversion Rate; no target yet.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('CUS_PATIENT_SATISFACTION', 13, 'Patient Satisfaction (Press Ganey)', 'Patient Satisfaction (Press Ganey)', 'C2', 'Primary', 'higher', 'num', 'gauge', 13, 'Overall Satisfaction (0-100) of the Press Ganey surveys: the average scored answer rescaled to 0-100 (1-5 scales (score - 1) / 4, the 1-4 scale (score - 1) / 3, the 0-10 scale score / 10, each times 100).', 'active', 'fixed', 'measure', 'experience', now64(3), 'bsc-2026-10-27', 'fixed target 85', 0),
    ('INT_DOCTOR_UTILIZATION', 58, 'OP Doctor Utilization', 'OP Doctor Utilization', 'P1', 'Supporting', 'higher', 'pct', 'gauge', 58, 'Arrived OP visits divided by clinic capacity slots (legacy capacity rule).', 'active', 'fixed', 'measure', 'volume', now64(3), 'bsc-2026-10-27', 'fixed target 70%', 0),
    ('INT_ACTIVATED_BEDS', 60, 'Activated Bed Rate', 'Activated Bed Rate', 'P1', 'Supporting', 'higher', 'pct', 'gauge', 60, 'Average available beds, capped at each hospital''s licensed beds, divided by licensed beds (the BI manager''s licensed beds per hospital and year): at most 100%.', 'active', 'fixed', 'measure', 'beds', now64(3), 'bsc-2026-10-27', 'fixed target 90%, actual capped at 100%', 0),
    ('CUS_REFERRAL_CONVERSION', 61, 'Referral Conversion Rate', 'Referral Conversion Rate', 'C3', 'Supporting', 'higher', 'pct', 'bullet', 61, 'Admissions under a referral policy divided by all episodes under a referral policy (arrived outpatient visits, ER visits and admissions, as in KPI 41).', 'active', 'none', 'measure', 'volume', now64(3), 'bsc-2026-10-27', 'definition agreed 2026-10-27', 0);

INSERT INTO default.map_bsc_target (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted) VALUES
    ('CUS_PATIENT_SATISFACTION', 0, 2026, 0, 85.0, 0, 'BI manager target', now64(3), 'bsc-2026-10-27', 'Overall Satisfaction (0-100) target 85', 0),
    ('CUS_PREMS', 0, 2026, 0, 0.80, 0, 'BI manager target', now64(3), 'bsc-2026-10-27', 'Top Box % target 80%', 0),
    ('INT_DOCTOR_UTILIZATION', 0, 2026, 0, 0.70, 0, 'BI manager target', now64(3), 'bsc-2026-10-27', 'OP doctor utilization target 70%', 0),
    ('INT_ACTIVATED_BEDS', 0, 2026, 0, 0.90, 0, 'BI manager target', now64(3), 'bsc-2026-10-27', 'Activated Bed Rate target 90%', 0);
