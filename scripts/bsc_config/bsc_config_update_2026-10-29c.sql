-- Update of 2026-10-29 (third): Staff-to-Bed Ratio (KPI 45) counts doctors and clinical staff only (the nursing,
-- paramedical and physical therapy categories), not every staff member. The target stays 4.
-- Needs the model with BSC Average Clinical FTE deployed.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('LRN_STAFF_TO_BED', 45, 'Staff-to-Bed Ratio', 'Staff-to-Bed Ratio', 'L1', 'Supporting', 'on_target', 'num', 'bullet', 45, 'Average FTE of doctors (part-time doctors at 0.5) and clinical staff (staff categories Nurse, Nurse in Other Dept, Nurse W/O License, Paramedical Dept and Physical Therapy) divided by average available beds.', 'active', 'fixed', 'measure', 'workforce', now64(3), 'bsc-2026-10-29', 'staff-to-bed counts doctors and clinical staff only; target stays 4', 0);
