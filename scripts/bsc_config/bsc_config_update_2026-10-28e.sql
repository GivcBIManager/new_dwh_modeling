-- Update of 2026-10-28 (fifth): fixed targets for Saudization (KPI 46) at 30% and Time to Fill (KPI 48) at 60 days.
-- Definitions unchanged; target_source becomes fixed.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('LRN_SAUDIZATION', 46, 'Saudization', 'Saudization', 'L1', 'Supporting', 'higher', 'pct', 'bullet', 46, 'Saudi heads divided by headcount without part-time doctors, at the last closed month of the period.', 'active', 'fixed', 'measure', 'workforce', now64(3), 'bsc-2026-10-28', 'fixed target 30%', 0),
    ('LRN_TIME_TO_FILL', 48, 'Time to Fill', 'Time to Fill', 'L1', 'Supporting', 'lower', 'days', 'bulletN', 48, 'Average days from requisition approval to fill, for requisitions filled in the period.', 'active', 'fixed', 'measure', 'workforce', now64(3), 'bsc-2026-10-28', 'fixed target 60 days', 0);

INSERT INTO default.map_bsc_target (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted) VALUES
    ('LRN_SAUDIZATION', 0, 2026, 0, 0.30, 0, 'BI manager target', now64(3), 'bsc-2026-10-28', 'Saudization target 30%', 0),
    ('LRN_TIME_TO_FILL', 0, 2026, 0, 60, 0, 'BI manager target', now64(3), 'bsc-2026-10-28', 'Time to Fill target 60 days', 0);
