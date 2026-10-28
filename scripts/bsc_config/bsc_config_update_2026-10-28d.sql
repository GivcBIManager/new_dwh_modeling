-- Update of 2026-10-28 (fourth): Clinical Staff-to-Doctor Ratio (KPI 68) counts clinical staff by staff category
-- (NURSE, NURSE IN OTHER DEPT, NURSE W/O LICENSE, PARAMEDICAL DEPT, PHYSICAL THERAPY; doctors not included) over
-- doctors, with a fixed target of 2.5.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('LRN_CLINICAL_TO_DOCTOR', 68, 'Clinical Staff-to-Doctor Ratio', 'Clinical Staff-to-Doctor Ratio', 'L1', 'Supporting', 'higher', 'num', 'stat', 68, 'Average clinical staff (staff categories Nurse, Nurse in Other Dept, Nurse W/O License, Paramedical Dept and Physical Therapy) divided by average doctors (part-time doctors included).', 'active', 'fixed', 'measure', 'workforce', now64(3), 'bsc-2026-10-28', 'clinical staff by staff category; fixed target 2.5', 0);

INSERT INTO default.map_bsc_target (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted) VALUES
    ('LRN_CLINICAL_TO_DOCTOR', 0, 2026, 0, 2.5, 0, 'BI manager target', now64(3), 'bsc-2026-10-28', 'Clinical Staff-to-Doctor Ratio target 2.5', 0);
