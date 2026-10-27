-- Update of 2026-10-27 (third): fixed targets for the Patient Experience KPIs. Patient Satisfaction (KPI 13) gets a
-- fixed target of 85 on its 0-100 scale (it had none); PREMs Score (KPI 16, Top Box %) moves from 85% to 80%.
-- Replaces the 0.85 Satisfaction row of 2026-10-27, which was on the old 0-1 scale and unused (target source none).
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('CUS_PATIENT_SATISFACTION', 13, 'Patient Satisfaction (Press Ganey)', 'Patient Satisfaction (Press Ganey)', 'C2', 'Primary', 'higher', 'num', 'gauge', 13, 'Overall Satisfaction (0-100) of the Press Ganey surveys: the average scored answer rescaled to 0-100 (1-5 scales (score - 1) / 4, the 1-4 scale (score - 1) / 3, the 0-10 scale score / 10, each times 100).', 'active', 'fixed', 'measure', 'experience', now64(3), 'bsc-2026-10-27', 'fixed target 85', 0);

INSERT INTO default.map_bsc_target (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted) VALUES
    ('CUS_PATIENT_SATISFACTION', 0, 2026, 0, 85.0, 0, 'BI manager target', now64(3), 'bsc-2026-10-27', 'Overall Satisfaction (0-100) target 85', 0),
    ('CUS_PREMS', 0, 2026, 0, 0.80, 0, 'BI manager target', now64(3), 'bsc-2026-10-27', 'Top Box % target 80%', 0);
