-- Update of 2026-10-28: OP-to-IP and Referral Conversion count admissions from OP or ER over the OP + ER census.
--   OP-to-IP Conversion (KPI 24): countable admissions from OP or ER divided by arrived outpatient visits plus ER
--     visits; the budget target is target IP census over target OP and ER census. The OP and ER parts are the
--     measures BSC OP Visit to IP Conversion and BSC ER Visit to IP Conversion.
--   Referral Conversion Rate (KPI 61): the same under a referral policy, with a fixed target of 60%; its OP and ER
--     parts are BSC OP Referral Conversion Rate and BSC ER Referral Conversion Rate.
-- Applied with apply_bsc_config.ps1 -Update; insert-only, the latest row per key wins.

INSERT INTO default.map_bsc_kpi (kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint, display_order, definition, status, target_source, value_source, detail_page, changed_at, changed_by, change_note, is_deleted) VALUES
    ('INT_OP_TO_IP', 24, 'OP-to-IP Conversion', 'OP-to-IP Conversion', 'P1', 'Supporting', 'higher', 'pct', 'bullet', 24, 'Admissions from OP or ER divided by the OP and ER census (arrived outpatient visits plus ER visits); target: budgeted IP census over budgeted OP and ER census.', 'active', 'budget', 'measure', 'volume', now64(3), 'bsc-2026-10-28', 'admissions from OP or ER over the OP + ER census', 0),
    ('CUS_REFERRAL_CONVERSION', 61, 'Referral Conversion Rate', 'Referral Conversion Rate', 'C3', 'Supporting', 'higher', 'pct', 'bullet', 61, 'Admissions from OP or ER under a referral policy divided by the OP and ER census under a referral policy (arrived outpatient visits plus ER visits).', 'active', 'fixed', 'measure', 'volume', now64(3), 'bsc-2026-10-28', 'same rule as KPI 24 under a referral policy; fixed target 60%', 0);

INSERT INTO default.map_bsc_target (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted) VALUES
    ('CUS_REFERRAL_CONVERSION', 0, 2026, 0, 0.60, 0, 'BI manager target', now64(3), 'bsc-2026-10-28', 'Referral Conversion Rate target 60%', 0);
