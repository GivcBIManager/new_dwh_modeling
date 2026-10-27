-- Update of 2026-10-27 (second): Patient Satisfaction (KPI 13) and PREMs Score (KPI 16) come from the Patient
-- Experience perspective's Press Ganey measures: Overall Satisfaction (0-100) and Top Box %. PREMs is no longer
-- entered by hand (value source measure); its manual rows stay in map_bsc_manual_value but are no longer read.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('CUS_PATIENT_SATISFACTION', 13, 'Patient Satisfaction (Press Ganey)', 'Patient Satisfaction (Press Ganey)', 'C2', 'Primary', 'higher', 'num', 'gauge', 13, 'Overall Satisfaction (0-100) of the Press Ganey surveys: the average scored answer rescaled to 0-100 (1-5 scales (score - 1) / 4, the 1-4 scale (score - 1) / 3, the 0-10 scale score / 10, each times 100).', 'active', 'none', 'measure', 'experience', now64(3), 'bsc-2026-10-27', 'from the Patient Experience perspective', 0),
    ('CUS_PREMS', 16, 'PREMs Score', 'PREMs Score', 'C2', 'Supporting', 'higher', 'pct', 'stat', 16, 'Top Box % of the Press Ganey surveys: answers at the top of their scale (5 of 5, 4 of 4, 9-10 of 10) divided by scored answers.', 'active', 'fixed', 'measure', 'experience', now64(3), 'bsc-2026-10-27', 'from the Patient Experience perspective', 0);
