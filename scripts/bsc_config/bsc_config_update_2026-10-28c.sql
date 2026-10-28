-- Update of 2026-10-28 (third): External/Other Facility Referrals (KPI 41) becomes a share of all encounters: visits
-- and countable admissions under a referral policy divided by all visits (OP and ER census) and countable admissions,
-- with a fixed target of 10%.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('INT_EXTERNAL_REFERRALS', 41, 'External/Other Facility Referrals %', 'External Referrals %', 'P6', 'Supporting', 'higher', 'pct', 'bullet', 41, 'Visits and countable admissions under a referral policy divided by all visits (OP and ER census) and countable admissions.', 'active', 'fixed', 'measure', 'volume', now64(3), 'bsc-2026-10-28', 'referral volume as a share of all encounters; fixed target 10%', 0);

INSERT INTO default.map_bsc_target (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted) VALUES
    ('INT_EXTERNAL_REFERRALS', 0, 2026, 0, 0.10, 0, 'BI manager target', now64(3), 'bsc-2026-10-28', 'External Referrals target 10% of encounters', 0);
